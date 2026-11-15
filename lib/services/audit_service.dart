import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/audit_entry.dart';

class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> newRef() =>
      _db.collection('auditLogs').doc();

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
      if (targetEmail != null) 'targetEmail': targetEmail,
      if (targetName != null && targetName.isNotEmpty) 'targetName': targetName,
      if (details != null && details.isNotEmpty) 'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Stream<List<AuditEntry>> watchLatest({int limit = 200}) {
    return _db
        .collection('auditLogs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => AuditEntry.fromDoc(d.id, d.data())).toList(),
        );
  }
}
