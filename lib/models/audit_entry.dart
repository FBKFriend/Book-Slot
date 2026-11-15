import 'package:cloud_firestore/cloud_firestore.dart';

class AuditEntry {
  final String id;
  final String actorEmail;
  final String actorName;
  final String actorRole;
  final String action; // e.g. account.authorize
  final String category; // accounts | settings (more later)
  final String? targetEmail;
  final String? targetName;
  final String? details;
  final DateTime? createdAt;

  const AuditEntry({
    required this.id,
    required this.actorEmail,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.category,
    this.targetEmail,
    this.targetName,
    this.details,
    this.createdAt,
  });

  factory AuditEntry.fromDoc(String id, Map<String, dynamic> d) => AuditEntry(
    id: id,
    actorEmail: (d['actorEmail'] ?? '') as String,
    actorName: (d['actorName'] ?? '') as String,
    actorRole: (d['actorRole'] ?? '') as String,
    action: (d['action'] ?? '') as String,
    category: (d['category'] ?? '') as String,
    targetEmail: d['targetEmail'] as String?,
    targetName: d['targetName'] as String?,
    details: d['details'] as String?,
    createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
  );
}
