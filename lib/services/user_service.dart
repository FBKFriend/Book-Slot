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

  /// Live list of everyone with a role. Pending first, then by name.
  Stream<List<AppUser>> watchUsersByRole(String role) {
    return _db
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => AppUser.fromMap(d.id, d.data()))
              .toList();
          const order = {'pending': 0, 'active': 1, 'suspended': 2};
          list.sort((a, b) {
            final byStatus = (order[a.status] ?? 3).compareTo(
              order[b.status] ?? 3,
            );
            return byStatus != 0
                ? byStatus
                : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
          return list;
        });
  }

  Future<void> setStatus(String email, String status) => _db
      .collection('users')
      .doc(email.toLowerCase())
      .update({'status': status});

  Future<void> deleteUser(String email) =>
      _db.collection('users').doc(email.toLowerCase()).delete();

  /// TESTING ONLY: creates fake students. Remove before release.
  Future<void> seedSampleStudents() async {
    final samples = [
      {
        'email': 'maria.santos@example.com',
        'fullName': 'Maria Clara Santos',
        'studentId': '2026-0001',
        'age': 19,
        'sex': 'Female',
        'course': 'BSIT',
        'status': 'pending',
      },
      {
        'email': 'juan.reyes@example.com',
        'fullName': 'Juan Miguel Reyes',
        'studentId': '2026-0002',
        'age': 20,
        'sex': 'Male',
        'course': 'BSCS',
        'status': 'pending',
      },
      {
        'email': 'ana.lopez@example.com',
        'fullName': 'Ana Beatriz Lopez',
        'studentId': '2025-0148',
        'age': 21,
        'sex': 'Female',
        'course': 'BSIT',
        'status': 'active',
      },
      {
        'email': 'very.long.email.address.for.testing.ellipsis@example.com',
        'fullName': 'Maximilian Bartholomew Fernandez-Villanueva',
        'studentId': '2025-0099',
        'age': 22,
        'sex': 'Male',
        'course': 'BSIT',
        'status': 'suspended',
      },
    ];
    final batch = _db.batch();
    for (final s in samples) {
      batch.set(_db.collection('users').doc(s['email'] as String), {
        ...s,
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
