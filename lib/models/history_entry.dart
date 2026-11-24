import 'package:cloud_firestore/cloud_firestore.dart';

/// One line in the History tab: a book was borrowed or returned.
class HistoryEntry {
  final String id;
  final String type; // borrow | return
  final String bookId;
  final String bookTitle;
  final String studentEmail;
  final String studentName;
  final String? studentId;
  final String staffEmail;
  final String staffName;
  final DateTime? dueAt;
  final bool overdue; // for returns: was it late?
  final int? amount; // fines: whole pesos
  final String? detail; // fines: reason, damage: what is wrong
  final String? fineId;
  final DateTime? createdAt;

  const HistoryEntry({
    required this.id,
    required this.type,
    required this.bookId,
    required this.bookTitle,
    required this.studentEmail,
    required this.studentName,
    required this.staffEmail,
    required this.staffName,
    required this.overdue,
    this.studentId,
    this.dueAt,
    this.createdAt,
    this.amount,
    this.detail,
    this.fineId,
  });

  factory HistoryEntry.fromDoc(String id, Map<String, dynamic> d) =>
      HistoryEntry(
        id: id,
        type: (d['type'] ?? '') as String,
        bookId: (d['bookId'] ?? '') as String,
        bookTitle: (d['bookTitle'] ?? '') as String,
        studentEmail: (d['studentEmail'] ?? '') as String,
        studentName: (d['studentName'] ?? '') as String,
        studentId: d['studentId'] as String?,
        staffEmail: (d['staffEmail'] ?? '') as String,
        staffName: (d['staffName'] ?? '') as String,
        dueAt: (d['dueAt'] as Timestamp?)?.toDate(),
        overdue: (d['overdue'] ?? false) as bool,
        amount: (d['amount'] as num?)?.toInt(),
        detail: d['detail'] as String?,
        fineId: d['fineId'] as String?,
        createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      );
}
