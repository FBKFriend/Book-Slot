import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/audit_entry.dart';

class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> newRef() =>
      _db.collection('auditLogs').doc();

  String get currentEmail =>
      (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase();

  /// Data for one log entry. Write it inside the same transaction/batch as
  /// the action itself so the two always succeed or fail together.
  Map<String, Object?> entryData({
    required String action,
    required String category,
    String actorRole = 'superadmin', // other roles pass their own later
    String? targetEmail,
    String? targetName,
    String? details,
  }) {
    final me = FirebaseAuth.instance.currentUser;
    return {
      'actorEmail': (me?.email ?? '').toLowerCase(),
      'actorName': me?.displayName ?? '',
      'actorRole': actorRole,
      'action': action,
      'category': category,
      // ignore: use_null_aware_elements
      if (targetEmail != null) 'targetEmail': targetEmail,
      if (targetName != null && targetName.isNotEmpty) 'targetName': targetName,
      if (details != null && details.isNotEmpty) 'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Query<Map<String, dynamic>> _rangeQuery(
    DateTime? start,
    DateTime? endExclusive,
  ) {
    Query<Map<String, dynamic>> q = _db.collection('auditLogs');
    if (start != null) {
      q = q.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    }
    if (endExclusive != null) {
      q = q.where('createdAt', isLessThan: Timestamp.fromDate(endExclusive));
    }
    return q.orderBy('createdAt', descending: true);
  }

  List<AuditEntry> _toEntries(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => AuditEntry.fromDoc(d.id, d.data())).toList();

  /// Live list for the Audit tab (newest first).
  Stream<List<AuditEntry>> watchRange({
    DateTime? start,
    DateTime? endExclusive,
    int limit = 200,
  }) =>
      _rangeQuery(start, endExclusive).limit(limit).snapshots().map(_toEntries);

  /// One-time fetch for printing.
  Future<List<AuditEntry>> fetchRange({
    DateTime? start,
    DateTime? endExclusive,
    int limit = 5000,
  }) async =>
      _toEntries(await _rangeQuery(start, endExclusive).limit(limit).get());
}
