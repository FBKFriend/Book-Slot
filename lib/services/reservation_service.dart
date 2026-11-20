import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/book.dart';
import '../models/reservation.dart';
import '../models/system_settings.dart';
import '../utils/format.dart';
import 'audit_service.dart';
import 'book_service.dart';

class AlreadyReservedException implements Exception {
  const AlreadyReservedException();
}

class ReservationLimitException implements Exception {
  final int limit;
  const ReservationLimitException(this.limit);
}

class BookUnavailableException implements Exception {
  const BookUnavailableException();
}

class ReservationChangedException implements Exception {
  const ReservationChangedException();
}

class NoFreeCopyException implements Exception {
  const NoFreeCopyException();
}

class ReservationService {
  ReservationService._();
  static final ReservationService instance = ReservationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// All of one student's reservations, newest first.
  Stream<List<Reservation>> watchForStudent(String email) {
    return _db
        .collection('reservations')
        .where('studentEmail', isEqualTo: email.toLowerCase())
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => Reservation.fromDoc(d.id, d.data()))
              .toList();
          final now = DateTime.now();
          list.sort(
            (a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now),
          );
          return list;
        });
  }

  /// Pending + accepted reservations, for the librarian.
  Stream<List<Reservation>> watchOpen() {
    return _db
        .collection('reservations')
        .where('status', whereIn: ['pending', 'accepted'])
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Reservation.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  Map<String, Object?> _note({
    required String toEmail,
    required String type,
    required String title,
    required String message,
    required String bookId,
  }) => {
    'toEmail': toEmail,
    'type': type,
    'title': title,
    'message': message,
    'bookId': bookId,
    'isRead': false,
    'createdAt': FieldValue.serverTimestamp(),
  };

  // ───────────── Student ─────────────

  Future<void> reserve({required Book book, required AppUser user}) async {
    final settings = SystemSettings.fromMap(
      (await _db.collection('settings').doc('system').get()).data(),
    );

    // Filtered here (not in the query) so no extra index is needed
    final mine = await _db
        .collection('reservations')
        .where('studentEmail', isEqualTo: user.email)
        .get();
    final active = mine.docs.where((d) {
      final s = d.data()['status'];
      return s == 'pending' || s == 'accepted';
    }).toList();

    if (active.any((d) => d.data()['bookId'] == book.id)) {
      throw const AlreadyReservedException();
    }

    final holding = mine.docs.any(
      (d) => d.data()['bookId'] == book.id && d.data()['status'] == 'picked_up',
    );
    if (holding) throw const AlreadyReservedException();

    if (active.length >= settings.maxActiveReservations) {
      throw ReservationLimitException(settings.maxActiveReservations);
    }

    final bookSnap = await _db.collection('books').doc(book.id).get();
    final stock = ((bookSnap.data()?['availableCopies'] ?? 0) as num).toInt();
    if (stock <= 0) throw const BookUnavailableException();

    final ref = _db.collection('reservations').doc();
    final logRef = AuditService.instance.newRef();
    final batch = _db.batch();
    batch.set(ref, {
      'bookId': book.id,
      'bookTitle': book.title,
      'studentEmail': user.email,
      'studentName': user.name,
      'studentId': ?user.studentId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      logRef,
      AuditService.instance.entryData(
        action: 'reservation.create',
        category: 'reservations',
        actorRole: 'student',
        details: '${book.id} - ${book.title}',
      ),
    );
    await batch.commit();
  }

  // ───────────── Librarian ─────────────

  /// Accepts a pending request and holds one copy for the student.
  Future<void> accept(Reservation r, {required String actorRole}) {
    final resRef = _db.collection('reservations').doc(r.id);
    final bookRef = _db.collection('books').doc(r.bookId);
    final settingsRef = _db.collection('settings').doc('system');
    final noteRef = _db.collection('notifications').doc();
    final logRef = AuditService.instance.newRef();

    return _db.runTransaction<void>((tx) async {
      final resSnap = await tx.get(resRef);
      if (resSnap.data()?['status'] != 'pending') {
        throw const ReservationChangedException();
      }
      final book = (await tx.get(bookRef)).data();
      if (book == null) throw const BookNotFoundException();
      final settings = SystemSettings.fromMap(
        (await tx.get(settingsRef)).data(),
      );

      final available = ((book['availableCopies'] ?? 0) as num).toInt();
      final reserved = ((book['reservedCopies'] ?? 0) as num).toInt();
      if (available - reserved <= 0) throw const NoFreeCopyException();

      final now = DateTime.now();
      final deadline = DateTime(
        now.year,
        now.month,
        now.day + settings.pickupDeadlineDays,
        23,
        59,
      );

      tx.update(bookRef, {'reservedCopies': reserved + 1});
      tx.update(resRef, {
        'status': 'accepted',
        'decidedAt': FieldValue.serverTimestamp(),
        'decidedBy': AuditService.instance.currentEmail,
        'pickupDeadline': Timestamp.fromDate(deadline),
      });
      tx.set(
        noteRef,
        _note(
          toEmail: r.studentEmail,
          type: 'reservation_accepted',
          title: 'Reservation accepted',
          message:
              '"${r.bookTitle}" is ready for pickup. Please get it from the library by ${formatDate(deadline)}.',
          bookId: r.bookId,
        ),
      );
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: 'reservation.accept',
          category: 'reservations',
          actorRole: actorRole,
          targetEmail: r.studentEmail,
          targetName: r.studentName,
          details: '${r.bookId} - ${r.bookTitle}',
        ),
      );
    });
  }

  Future<void> deny(Reservation r, {required String actorRole}) {
    final resRef = _db.collection('reservations').doc(r.id);
    final noteRef = _db.collection('notifications').doc();
    final logRef = AuditService.instance.newRef();

    return _db.runTransaction<void>((tx) async {
      final resSnap = await tx.get(resRef);
      if (resSnap.data()?['status'] != 'pending') {
        throw const ReservationChangedException();
      }
      tx.update(resRef, {
        'status': 'denied',
        'decidedAt': FieldValue.serverTimestamp(),
        'decidedBy': AuditService.instance.currentEmail,
      });
      tx.set(
        noteRef,
        _note(
          toEmail: r.studentEmail,
          type: 'reservation_denied',
          title: 'Reservation denied',
          message:
              'Your reservation for "${r.bookTitle}" was denied. Please ask the librarian if you have questions.',
          bookId: r.bookId,
        ),
      );
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: 'reservation.deny',
          category: 'reservations',
          actorRole: actorRole,
          targetEmail: r.studentEmail,
          targetName: r.studentName,
          details: '${r.bookId} - ${r.bookTitle}',
        ),
      );
    });
  }

  /// Expires accepted reservations whose pickup deadline has passed and
  /// frees the held copy. Returns how many were expired.
  Future<int> expireOverdue({required String actorRole}) async {
    final snap = await _db
        .collection('reservations')
        .where('status', isEqualTo: 'accepted')
        .get();
    final now = DateTime.now();
    var count = 0;
    for (final d in snap.docs) {
      final r = Reservation.fromDoc(d.id, d.data());
      final deadline = r.pickupDeadline;
      if (deadline == null || !deadline.isBefore(now)) continue;
      try {
        if (await _expireOne(r, actorRole)) count++;
      } catch (e) {
        debugPrint('expire ${r.id} failed: $e');
      }
    }
    return count;
  }

  Future<bool> _expireOne(Reservation r, String actorRole) {
    final resRef = _db.collection('reservations').doc(r.id);
    final bookRef = _db.collection('books').doc(r.bookId);
    final noteRef = _db.collection('notifications').doc();
    final logRef = AuditService.instance.newRef();

    return _db.runTransaction<bool>((tx) async {
      final resSnap = await tx.get(resRef);
      if (resSnap.data()?['status'] != 'accepted') return false;
      final book = (await tx.get(bookRef)).data();

      if (book != null) {
        final reserved = ((book['reservedCopies'] ?? 0) as num).toInt();
        tx.update(bookRef, {'reservedCopies': reserved > 0 ? reserved - 1 : 0});
      }
      tx.update(resRef, {'status': 'expired'});
      tx.set(
        noteRef,
        _note(
          toEmail: r.studentEmail,
          type: 'reservation_expired',
          title: 'Reservation expired',
          message:
              'You did not pick up "${r.bookTitle}" in time, so the reservation was cancelled. You can reserve it again if it is available.',
          bookId: r.bookId,
        ),
      );
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: 'reservation.expire',
          category: 'reservations',
          actorRole: actorRole,
          targetEmail: r.studentEmail,
          targetName: r.studentName,
          details: '${r.bookId} - ${r.bookTitle}\nPickup deadline passed',
        ),
      );
      return true;
    });
  }

  /// Called after a pickup. If no copy is left on the shelf, every request
  /// still pending for that book is dropped and the students are told.
  Future<int> dropPendingIfOutOfStock({
    required String bookId,
    required String actorRole,
  }) async {
    final book = (await _db.collection('books').doc(bookId).get()).data();
    final available = ((book?['availableCopies'] ?? 0) as num).toInt();
    if (available > 0) return 0;

    final snap = await _db
        .collection('reservations')
        .where('bookId', isEqualTo: bookId)
        .get();
    var count = 0;
    for (final d in snap.docs) {
      final r = Reservation.fromDoc(d.id, d.data());
      if (r.status != 'pending') continue;
      try {
        if (await _dropOne(r, actorRole)) count++;
      } catch (e) {
        debugPrint('drop ${r.id} failed: $e');
      }
    }
    return count;
  }

  Future<bool> _dropOne(Reservation r, String actorRole) {
    final resRef = _db.collection('reservations').doc(r.id);
    final noteRef = _db.collection('notifications').doc();
    final logRef = AuditService.instance.newRef();

    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(resRef);
      if (snap.data()?['status'] != 'pending') return false;

      tx.update(resRef, {'status': 'dropped'});
      tx.set(
        noteRef,
        _note(
          toEmail: r.studentEmail,
          type: 'reservation_dropped',
          title: 'Reservation cancelled',
          message:
              'The last copy of "${r.bookTitle}" was picked up by another student, so your reservation was cancelled. You can reserve it again once a copy is returned.',
          bookId: r.bookId,
        ),
      );
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: 'reservation.drop',
          category: 'reservations',
          actorRole: actorRole,
          targetEmail: r.studentEmail,
          targetName: r.studentName,
          details: '${r.bookId} - ${r.bookTitle}\nLast copy was picked up',
        ),
      );
      return true;
    });
  }

  /// Student cancels their own request while it is still pending.
  Future<void> cancel(Reservation r) {
    final resRef = _db.collection('reservations').doc(r.id);
    final logRef = AuditService.instance.newRef();

    return _db.runTransaction<void>((tx) async {
      final snap = await tx.get(resRef);
      if (snap.data()?['status'] != 'pending') {
        throw const ReservationChangedException();
      }
      tx.update(resRef, {'status': 'cancelled'});
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: 'reservation.cancel',
          category: 'reservations',
          actorRole: 'student',
          details: '${r.bookId} - ${r.bookTitle}',
        ),
      );
    });
  }
}
