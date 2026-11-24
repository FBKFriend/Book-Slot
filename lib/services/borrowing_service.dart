import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/return_incident.dart';
import 'fine_service.dart';
import '../models/app_user.dart';
import '../models/borrowing.dart';
import '../models/history_entry.dart';
import '../models/reservation.dart';
import '../models/system_settings.dart';
import '../utils/format.dart';
import 'audit_service.dart';
import 'book_service.dart';
import 'reservation_service.dart';

class BorrowLimitException implements Exception {
  final int limit;
  const BorrowLimitException(this.limit);
}

class PickupExpiredException implements Exception {
  const PickupExpiredException();
}

class BorrowingChangedException implements Exception {
  const BorrowingChangedException();
}

class BorrowingService {
  BorrowingService._();
  static final BorrowingService instance = BorrowingService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Books currently out, soonest due date first.
  Stream<List<Borrowing>> watchActive() {
    return _db
        .collection('borrowings')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => Borrowing.fromDoc(d.id, d.data()))
              .toList();
          final far = DateTime(9999);
          list.sort((a, b) => (a.dueAt ?? far).compareTo(b.dueAt ?? far));
          return list;
        });
  }

  /// Borrow and return events, newest first.
  Stream<List<HistoryEntry>> watchHistory({
    DateTime? start,
    DateTime? endExclusive,
    int limit = 200,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('transactions');
    if (start != null) {
      q = q.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    }
    if (endExclusive != null) {
      q = q.where('createdAt', isLessThan: Timestamp.fromDate(endExclusive));
    }
    return q
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => HistoryEntry.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  Map<String, Object?> _event({
    required String type,
    required String borrowingId,
    required String bookId,
    required String bookTitle,
    required String studentEmail,
    required String studentName,
    required String? studentId,
    required AppUser staff,
    required DateTime? dueAt,
    bool overdue = false,
  }) {
    final dueTs = dueAt == null ? null : Timestamp.fromDate(dueAt);
    return {
      'type': type,
      'borrowingId': borrowingId,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'studentEmail': studentEmail,
      'studentName': studentName,
      'studentId': ?studentId,
      'staffEmail': staff.email,
      'staffName': staff.name,
      'dueAt': ?dueTs,
      'overdue': overdue,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Student collected an accepted reservation: the borrow starts now.
  /// The QR scanner will call this same method later.
  Future<void> startBorrow(Reservation r, {required AppUser staff}) async {
    final settings = SystemSettings.fromMap(
      (await _db.collection('settings').doc('system').get()).data(),
    );

    // Max books at once. Filtered here so no extra index is needed.
    final mine = await _db
        .collection('borrowings')
        .where('studentEmail', isEqualTo: r.studentEmail)
        .get();
    final out = mine.docs.where((d) => d.data()['status'] == 'active').length;
    if (out >= settings.maxBorrowedBooks) {
      throw BorrowLimitException(settings.maxBorrowedBooks);
    }

    final resRef = _db.collection('reservations').doc(r.id);
    final bookRef = _db.collection('books').doc(r.bookId);
    final borrowRef = _db.collection('borrowings').doc();
    final eventRef = _db.collection('transactions').doc();
    final logRef = AuditService.instance.newRef();

    await _db.runTransaction<void>((tx) async {
      final res = (await tx.get(resRef)).data();
      if (res?['status'] != 'accepted') {
        throw const ReservationChangedException();
      }
      final deadline = (res?['pickupDeadline'] as Timestamp?)?.toDate();
      if (deadline != null && deadline.isBefore(DateTime.now())) {
        throw const PickupExpiredException();
      }
      final book = (await tx.get(bookRef)).data();
      if (book == null) throw const BookNotFoundException();

      final available = ((book['availableCopies'] ?? 0) as num).toInt();
      final reserved = ((book['reservedCopies'] ?? 0) as num).toInt();
      if (available <= 0) throw const NoFreeCopyException();

      final fineSummary = (await tx.get(
        _db.collection('fineSummaries').doc(r.studentEmail),
      )).data();
      if (((fineSummary?['unpaidCount'] ?? 0) as num) > 0) {
        throw const UnpaidFineException();
      }

      final now = DateTime.now();
      final due = DateTime(
        now.year,
        now.month,
        now.day + settings.borrowDays,
        23,
        59,
      );

      // The held copy turns into a borrowed one
      tx.update(bookRef, {
        'availableCopies': available - 1,
        'reservedCopies': reserved > 0 ? reserved - 1 : 0,
      });
      tx.update(resRef, {
        'status': 'picked_up',
        'pickedUpAt': FieldValue.serverTimestamp(),
        'dueAt': Timestamp.fromDate(due),
      });
      tx.set(borrowRef, {
        'bookId': r.bookId,
        'bookTitle': r.bookTitle,
        'studentEmail': r.studentEmail,
        'studentName': r.studentName,
        'studentId': ?r.studentId,
        'reservationId': r.id,
        'status': 'active',
        'borrowedAt': FieldValue.serverTimestamp(),
        'dueAt': Timestamp.fromDate(due),
        'borrowedBy': staff.email,
      });
      tx.set(
        eventRef,
        _event(
          type: 'borrow',
          borrowingId: borrowRef.id,
          bookId: r.bookId,
          bookTitle: r.bookTitle,
          studentEmail: r.studentEmail,
          studentName: r.studentName,
          studentId: r.studentId,
          staff: staff,
          dueAt: due,
        ),
      );
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: 'borrow.start',
          category: 'borrowing',
          actorRole: staff.role,
          targetEmail: r.studentEmail,
          targetName: r.studentName,
          details: '${r.bookId} - ${r.bookTitle}\nDue: ${formatDate(due)}',
        ),
      );
    });

    // If that was the last copy on the shelf, drop the other pending requests.
    // Best effort: the borrow itself already succeeded.
    try {
      await ReservationService.instance.dropPendingIfOutOfStock(
        bookId: r.bookId,
        actorRole: staff.role,
      );
    } catch (e) {
      debugPrint('drop pending failed: $e');
    }
  }

  /// Book came back: stock goes up and the borrow is closed. A fine and any
  /// damage report from the librarian are saved in the same step.
  Future<void> returnBook(
    Borrowing b, {
    required AppUser staff,
    ReturnIncident? incident,
  }) async {
    final borrowRef = _db.collection('borrowings').doc(b.id);
    final bookRef = _db.collection('books').doc(b.bookId);
    final resId = b.reservationId;
    final resRef = resId == null
        ? null
        : _db.collection('reservations').doc(resId);
    final eventRef = _db.collection('transactions').doc();
    final logRef = AuditService.instance.newRef();

    // Only an incident with a fine counts (damage always comes with one)
    final inc = (incident != null && incident.hasFine) ? incident : null;
    final fineRef = inc == null ? null : _db.collection('fines').doc();
    final summaryRef = _db.collection('fineSummaries').doc(b.studentEmail);
    final fineEventRef = _db.collection('transactions').doc();
    final damageEventRef = _db.collection('transactions').doc();
    final noteRef = _db.collection('notifications').doc();
    final fineLogRef = AuditService.instance.newRef();
    final damageLogRef = AuditService.instance.newRef();

    await _db.runTransaction<void>((tx) async {
      final snap = await tx.get(borrowRef);
      if (snap.data()?['status'] != 'active') {
        throw const BorrowingChangedException();
      }
      final book = (await tx.get(bookRef)).data();
      final resSnap = resRef == null ? null : await tx.get(resRef);
      final summary = fineRef == null
          ? null
          : (await tx.get(summaryRef)).data();

      final now = DateTime.now();
      final due = b.dueAt;
      final wasLate = due != null && due.isBefore(now);
      // ignore: unnecessary_null_comparison
      final daysLate = (wasLate && due != null) ? daysLateOf(due, now) : 0;
      final discard = inc != null && inc.discarded;

      if (book != null) {
        if (discard) {
          // The damaged copy never goes back on the shelf
          final total = ((book['totalCopies'] ?? 0) as num).toInt();
          tx.update(bookRef, {'totalCopies': total > 0 ? total - 1 : 0});
        } else {
          final available = ((book['availableCopies'] ?? 0) as num).toInt();
          final total = ((book['totalCopies'] ?? 0) as num).toInt();
          tx.update(bookRef, {
            'availableCopies': available + 1 > total ? total : available + 1,
          });
        }
      }
      tx.update(borrowRef, {
        'status': 'returned',
        'returnedAt': FieldValue.serverTimestamp(),
        'returnedBy': staff.email,
      });
      if (resRef != null && (resSnap?.exists ?? false)) {
        tx.update(resRef, {
          'status': 'returned',
          'returnedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.set(
        eventRef,
        _event(
          type: 'return',
          borrowingId: b.id,
          bookId: b.bookId,
          bookTitle: b.bookTitle,
          studentEmail: b.studentEmail,
          studentName: b.studentName,
          studentId: b.studentId,
          staff: staff,
          dueAt: b.dueAt,
          overdue: wasLate,
        ),
      );
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: 'borrow.return',
          category: 'borrowing',
          actorRole: staff.role,
          targetEmail: b.studentEmail,
          targetName: b.studentName,
          details: wasLate
              ? '${b.bookId} - ${b.bookTitle}\nReturned late'
              : '${b.bookId} - ${b.bookTitle}',
        ),
      );

      if (inc != null && fineRef != null) {
        final amount = inc.fineAmount!;
        final reason = inc.damageReason.trim();
        final lateText =
            'Late return ($daysLate ${daysLate == 1 ? 'day' : 'days'})';
        final reasonText = inc.damaged
            ? (wasLate ? '$lateText and damaged book' : 'Damaged book')
            : lateText;
        final condition = inc.damaged ? inc.condition : null;

        tx.set(fineRef, {
          'studentEmail': b.studentEmail,
          'studentName': b.studentName,
          'studentId': ?b.studentId,
          'bookId': b.bookId,
          'bookTitle': b.bookTitle,
          'borrowingId': b.id,
          'amount': amount,
          'wasLate': wasLate,
          'daysLate': daysLate,
          'damaged': inc.damaged,
          'damageReason': inc.damaged ? reason : '',
          'condition': ?condition,
          'hasPhoto': inc.damaged && inc.photo != null,
          'status': 'unpaid',
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': staff.email,
          'createdByName': staff.name,
        });
        if (inc.damaged && inc.photo != null) {
          tx.set(_db.collection('fineEvidence').doc(fineRef.id), {
            'data': Blob(inc.photo!),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // The student now has an unpaid fine
        final count = ((summary?['unpaidCount'] ?? 0) as num).toInt();
        final total = ((summary?['unpaidTotal'] ?? 0) as num).toInt();
        tx.set(summaryRef, {
          'unpaidCount': count + 1,
          'unpaidTotal': total + amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(
          noteRef,
          FineService.noteData(
            toEmail: b.studentEmail,
            type: 'fine_issued',
            title: 'You have a new fine',
            message:
                'You were fined ${formatPeso(amount)} for "${b.bookTitle}" ($reasonText). Please settle it at the library. Reserving and picking up books is paused until it is paid.',
            bookId: b.bookId,
          ),
        );

        // History + audit
        tx.set(
          fineEventRef,
          FineService.eventData(
            type: 'fine',
            fineId: fineRef.id,
            bookId: b.bookId,
            bookTitle: b.bookTitle,
            studentEmail: b.studentEmail,
            studentName: b.studentName,
            studentId: b.studentId,
            staff: staff,
            amount: amount,
            detail: reason.isEmpty ? reasonText : '$reasonText: $reason',
          ),
        );
        tx.set(
          fineLogRef,
          AuditService.instance.entryData(
            action: 'fine.issue',
            category: 'fines',
            actorRole: staff.role,
            targetEmail: b.studentEmail,
            targetName: b.studentName,
            details:
                '${b.bookId} - ${b.bookTitle}\n${formatPeso(amount)} · $reasonText',
          ),
        );
        if (inc.damaged) {
          tx.set(
            damageEventRef,
            FineService.eventData(
              type: discard ? 'damage_discarded' : 'damage_functional',
              fineId: fineRef.id,
              bookId: b.bookId,
              bookTitle: b.bookTitle,
              studentEmail: b.studentEmail,
              studentName: b.studentName,
              studentId: b.studentId,
              staff: staff,
              detail: reason,
            ),
          );
          tx.set(
            damageLogRef,
            AuditService.instance.entryData(
              action: discard
                  ? 'book.damage_discarded'
                  : 'book.damage_functional',
              category: 'books',
              actorRole: staff.role,
              targetEmail: b.studentEmail,
              targetName: b.studentName,
              details:
                  '${b.bookId} - ${b.bookTitle}\n$reason\n${discard ? 'Copy removed from the total copies' : 'Still functional'}',
            ),
          );
        }
      }
    });

    // The fined student's pending and approved requests are dropped.
    // Best effort: the return and the fine are already saved.
    if (inc != null) {
      try {
        await ReservationService.instance.dropAllForFine(
          studentEmail: b.studentEmail,
          actorRole: staff.role,
        );
      } catch (e) {
        debugPrint('drop for fine failed: $e');
      }
    }
  }
}
