import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Live alerts for one student, newest first.
  Stream<List<AppNotification>> watchFor(String email) {
    return _db
        .collection('notifications')
        .where('toEmail', isEqualTo: email.toLowerCase())
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => AppNotification.fromDoc(d.id, d.data()))
              .toList();
          final now = DateTime.now();
          list.sort(
            (a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now),
          );
          return list;
        });
  }

  Future<void> markRead(String id) =>
      _db.collection('notifications').doc(id).update({'isRead': true});

  Future<void> markAllRead(List<AppNotification> notes) {
    final batch = _db.batch();
    for (final n in notes.where((n) => !n.isRead)) {
      batch.update(_db.collection('notifications').doc(n.id), {'isRead': true});
    }
    return batch.commit();
  }
}
