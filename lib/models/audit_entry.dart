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

String auditActionTitle(String action) {
  switch (action) {
    case 'account.authorize':
      return 'Authorized account';
    case 'account.reject':
      return 'Rejected registration';
    case 'account.suspend':
      return 'Suspended account';
    case 'account.reactivate':
      return 'Reactivated account';
    case 'account.add_librarian':
      return 'Added librarian';
    case 'account.edit':
      return 'Edited user information';
    case 'account.role_change':
      return 'Changed role';
    case 'settings.update':
      return 'Updated system settings';
    case 'book.add':
      return 'Added book';
    case 'book.edit':
      return 'Edited book';
    case 'book.delete':
      return 'Deleted book';
    case 'reservation.create':
      return 'Reserved a book';
    case 'reservation.accept':
      return 'Accepted reservation';
    case 'reservation.deny':
      return 'Denied reservation';
    case 'reservation.expire':
      return 'Reservation expired';
    case 'reservation.drop':
      return 'Reservation dropped';
    case 'borrow.start':
      return 'Book picked up';
    case 'borrow.return':
      return 'Book returned';
    default:
      return action;
  }
}

const Map<String, String> kAuditActorOptions = {
  'all': 'All',
  'superadmin': 'SuperAdmin',
  'student': 'Students',
  'librarian': 'Librarians',
};
