import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type; // reservation_accepted | reservation_denied | ...
  final String title;
  final String message;
  final String? bookId;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.bookId,
    this.createdAt,
  });

  factory AppNotification.fromDoc(String id, Map<String, dynamic> d) =>
      AppNotification(
        id: id,
        type: (d['type'] ?? '') as String,
        title: (d['title'] ?? '') as String,
        message: (d['message'] ?? '') as String,
        bookId: d['bookId'] as String?,
        isRead: (d['isRead'] ?? false) as bool,
        createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      );
}
