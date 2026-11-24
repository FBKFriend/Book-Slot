import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/fine.dart';
import '../utils/format.dart';
import 'audit_service.dart';

/// The student has an unpaid fine, so they can't reserve or pick up books.
class UnpaidFineException implements Exception {
  const UnpaidFineException();
}

class FineChangedException implements Exception {
  const FineChangedException();
}

class FineService {
  FineService._();
  static final FineService instance = FineService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, Future<Uint8List?>> _photoCache = {};

  List<Fine> _sorted(List<Fine> list) {
    final now = DateTime.now();
    list.sort((a, b) {
      final byStatus = (a.isPaid ? 1 : 0).compareTo(b.isPaid ? 1 : 0);
      if (byStatus != 0) return byStatus;
      return (b.createdAt ?? now).compareTo(a.createdAt ?? now);
    });
    return list;
  }

  /// All fines for the librarian: unpaid first, then newest.
  Stream<List<Fine>> watchAll() {
    return _db
        .collection('fines')
        .snapshots()
        .map(
          (snap) => _sorted(
            snap.docs.map((d) => Fine.fromDoc(d.id, d.data())).toList(),
          ),
        );
  }

  /// One student's fines (used by the student side).
  Stream<List<Fine>> watchForStudent(String email) {
    return _db
        .collection('fines')
        .where('studentEmail', isEqualTo: email.toLowerCase())
        .snapshots()
        .map(
          (snap) => _sorted(
            snap.docs.map((d) => Fine.fromDoc(d.id, d.data())).toList(),
          ),
        );
  }

  Stream<Fine?> watchFine(String id) {
    return _db.collection('fines').doc(id).snapshots().map((s) {
      final d = s.data();
      return d == null ? null : Fine.fromDoc(s.id, d);
    });
  }

  /// How many unpaid fines a student has.
  Stream<int> watchUnpaidCount(String email) {
    return _db
        .collection('fineSummaries')
        .doc(email.toLowerCase())
        .snapshots()
        .map((s) => ((s.data()?['unpaidCount'] ?? 0) as num).toInt());
  }

  /// The damage photo, remembered for this app session.
  Future<Uint8List?> loadPhoto(String fineId) {
    return _photoCache.putIfAbsent(fineId, () async {
      try {
        final snap = await _db.collection('fineEvidence').doc(fineId).get();
        final data = snap.data()?['data'];
        return data is Blob ? data.bytes : null;
      } catch (_) {
        _photoCache.remove(fineId);
        return null;
      }
    });
  }

  static Map<String, Object?> noteData({
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

  /// One line for the librarian History tab.
  static Map<String, Object?> eventData({
    required String
    type, // fine | fine_paid | damage_functional | damage_discarded
    required String fineId,
    required String bookId,
    required String bookTitle,
    required String studentEmail,
    required String studentName,
    required String? studentId,
    required AppUser staff,
    int? amount,
    String? detail,
  }) => {
    'type': type,
    'fineId': fineId,
    'bookId': bookId,
    'bookTitle': bookTitle,
    'studentEmail': studentEmail,
    'studentName': studentName,
    'studentId': ?studentId,
    'staffEmail': staff.email,
    'staffName': staff.name,
    'amount': ?amount,
    'detail': ?detail,
    'createdAt': FieldValue.serverTimestamp(),
  };

  /// The student paid: the fine is closed and, once they have no unpaid
  /// fines left, they can reserve and pick up books again.
  Future<void> markPaid(Fine f, {required AppUser staff}) {
    final fineRef = _db.collection('fines').doc(f.id);
    final summaryRef = _db.collection('fineSummaries').doc(f.studentEmail);
    final noteRef = _db.collection('notifications').doc();
    final eventRef = _db.collection('transactions').doc();
    final logRef = AuditService.instance.newRef();

    return _db.runTransaction<void>((tx) async {
      final snap = await tx.get(fineRef);
      if (snap.data()?['status'] != 'unpaid') {
        throw const FineChangedException();
      }
      final summary = (await tx.get(summaryRef)).data();
      final count = ((summary?['unpaidCount'] ?? 0) as num).toInt();
      final total = ((summary?['unpaidTotal'] ?? 0) as num).toInt();
      final newCount = count > 0 ? count - 1 : 0;
      final newTotal = total - f.amount > 0 ? total - f.amount : 0;

      tx.update(fineRef, {
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'paidBy': staff.email,
        'paidByName': staff.name,
      });
      tx.set(summaryRef, {
        'unpaidCount': newCount,
        'unpaidTotal': newTotal,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        noteRef,
        noteData(
          toEmail: f.studentEmail,
          type: 'fine_paid',
          title: 'Fine paid',
          message: newCount == 0
              ? 'Your fine of ${formatPeso(f.amount)} for "${f.bookTitle}" was marked as paid. You can reserve and pick up books again.'
              : 'Your fine of ${formatPeso(f.amount)} for "${f.bookTitle}" was marked as paid. You still have $newCount unpaid ${newCount == 1 ? 'fine' : 'fines'}.',
          bookId: f.bookId,
        ),
      );
      tx.set(
        eventRef,
        eventData(
          type: 'fine_paid',
          fineId: f.id,
          bookId: f.bookId,
          bookTitle: f.bookTitle,
          studentEmail: f.studentEmail,
          studentName: f.studentName,
          studentId: f.studentId,
          staff: staff,
          amount: f.amount,
        ),
      );
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: 'fine.paid',
          category: 'fines',
          actorRole: staff.role,
          targetEmail: f.studentEmail,
          targetName: f.studentName,
          details: '${f.bookId} - ${f.bookTitle}\n${formatPeso(f.amount)} paid',
        ),
      );
    });
  }
}
