import 'package:cloud_firestore/cloud_firestore.dart';

class Fine {
  final String id;
  final String studentEmail;
  final String studentName;
  final String? studentId;
  final String bookId;
  final String bookTitle;
  final String? borrowingId;
  final int amount; // whole pesos
  final bool wasLate;
  final int daysLate;
  final bool damaged;
  final String damageReason;
  final String? condition; // functional | discarded
  final bool hasPhoto;
  final String status; // unpaid | paid
  final DateTime? createdAt;
  final String createdByName;
  final DateTime? paidAt;
  final String paidByName;

  const Fine({
    required this.id,
    required this.studentEmail,
    required this.studentName,
    required this.bookId,
    required this.bookTitle,
    required this.amount,
    required this.wasLate,
    required this.daysLate,
    required this.damaged,
    required this.damageReason,
    required this.hasPhoto,
    required this.status,
    required this.createdByName,
    required this.paidByName,
    this.studentId,
    this.borrowingId,
    this.condition,
    this.createdAt,
    this.paidAt,
  });

  bool get isPaid => status == 'paid';
  bool get discarded => damaged && condition == 'discarded';

  String get reasonLabel {
    if (wasLate && damaged) return 'Late return and damaged book';
    if (damaged) return 'Damaged book';
    return 'Late return';
  }

  factory Fine.fromDoc(String id, Map<String, dynamic> d) => Fine(
    id: id,
    studentEmail: (d['studentEmail'] ?? '') as String,
    studentName: (d['studentName'] ?? '') as String,
    studentId: d['studentId'] as String?,
    bookId: (d['bookId'] ?? '') as String,
    bookTitle: (d['bookTitle'] ?? '') as String,
    borrowingId: d['borrowingId'] as String?,
    amount: ((d['amount'] ?? 0) as num).toInt(),
    wasLate: (d['wasLate'] ?? false) as bool,
    daysLate: ((d['daysLate'] ?? 0) as num).toInt(),
    damaged: (d['damaged'] ?? false) as bool,
    damageReason: (d['damageReason'] ?? '') as String,
    condition: d['condition'] as String?,
    hasPhoto: (d['hasPhoto'] ?? false) as bool,
    status: (d['status'] ?? 'unpaid') as String,
    createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    createdByName: (d['createdByName'] ?? '') as String,
    paidAt: (d['paidAt'] as Timestamp?)?.toDate(),
    paidByName: (d['paidByName'] ?? '') as String,
  );
}
