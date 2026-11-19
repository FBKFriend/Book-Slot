import 'package:cloud_firestore/cloud_firestore.dart';

class Borrowing {
  final String id;
  final String bookId;
  final String bookTitle;
  final String studentEmail;
  final String studentName;
  final String? studentId;
  final String? reservationId;
  final String status; // active | returned
  final DateTime? borrowedAt;
  final DateTime? dueAt;
  final DateTime? returnedAt;

  const Borrowing({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.studentEmail,
    required this.studentName,
    required this.status,
    this.studentId,
    this.reservationId,
    this.borrowedAt,
    this.dueAt,
    this.returnedAt,
  });

  bool get isOverdue =>
      status == 'active' && dueAt != null && dueAt!.isBefore(DateTime.now());

  factory Borrowing.fromDoc(String id, Map<String, dynamic> d) => Borrowing(
    id: id,
    bookId: (d['bookId'] ?? '') as String,
    bookTitle: (d['bookTitle'] ?? '') as String,
    studentEmail: (d['studentEmail'] ?? '') as String,
    studentName: (d['studentName'] ?? '') as String,
    studentId: d['studentId'] as String?,
    reservationId: d['reservationId'] as String?,
    status: (d['status'] ?? 'active') as String,
    borrowedAt: (d['borrowedAt'] as Timestamp?)?.toDate(),
    dueAt: (d['dueAt'] as Timestamp?)?.toDate(),
    returnedAt: (d['returnedAt'] as Timestamp?)?.toDate(),
  );
}
