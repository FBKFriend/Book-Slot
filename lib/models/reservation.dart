import 'package:cloud_firestore/cloud_firestore.dart';

class Reservation {
  final String id;
  final String bookId;
  final String bookTitle;
  final String studentEmail;
  final String studentName;
  final String? studentId;
  final String status; // pending | accepted | denied | expired | dropped | cancelled | picked_up | returned
  final DateTime? createdAt;
  final DateTime? pickupDeadline; // set when accepted
  final DateTime? dueAt; // set when picked up

  const Reservation({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.studentEmail,
    required this.studentName,
    required this.status,
    this.studentId,
    this.createdAt,
    this.pickupDeadline,
    this.dueAt,
  });

  bool get isActive => status == 'pending' || status == 'accepted';
  bool get isBorrowing => status == 'picked_up';

  factory Reservation.fromDoc(String id, Map<String, dynamic> d) => Reservation(
    id: id,
    bookId: (d['bookId'] ?? '') as String,
    bookTitle: (d['bookTitle'] ?? '') as String,
    studentEmail: (d['studentEmail'] ?? '') as String,
    studentName: (d['studentName'] ?? '') as String,
    studentId: d['studentId'] as String?,
    status: (d['status'] ?? 'pending') as String,
    createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    pickupDeadline: (d['pickupDeadline'] as Timestamp?)?.toDate(),
    dueAt: (d['dueAt'] as Timestamp?)?.toDate(),
  );
}
