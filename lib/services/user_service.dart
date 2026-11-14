import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Live stream of one account. Emits null when no record exists yet.
  Stream<AppUser?> watchUser(String email) {
    final id = email.toLowerCase();
    return _db.collection('users').doc(id).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return AppUser.fromMap(id, data);
    });
  }
}
