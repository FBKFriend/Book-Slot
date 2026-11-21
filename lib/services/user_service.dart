import 'audit_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class AccountExistsException implements Exception {
  const AccountExistsException();
}

class UserCounts {
  final int students; // authorized students (active or suspended)
  final int pending;
  final int librarians;
  const UserCounts({
    required this.students,
    required this.pending,
    required this.librarians,
  });
}

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

  /// Live counts for the superadmin dashboard.
  Stream<UserCounts> watchUserCounts() {
    return _db.collection('users').snapshots().map((snap) {
      var students = 0, pending = 0, librarians = 0;
      for (final d in snap.docs) {
        final data = d.data();
        final role = data['role'];
        final status = data['status'];
        if (role == 'student') {
          if (status == 'pending') {
            pending++;
          } else {
            students++;
          }
        } else if (role == 'librarian') {
          librarians++;
        }
      }
      return UserCounts(
        students: students,
        pending: pending,
        librarians: librarians,
      );
    });
  }

  static Map<String, Object?> nameFields(
    String first,
    String middle,
    String last,
  ) {
    final f = first.trim(), m = middle.trim(), l = last.trim();
    return {
      'firstName': f,
      'middleName': m,
      'lastName': l,
      'fullName': [f, m, l].where((s) => s.isNotEmpty).join(' '),
    };
  }

  Future<void> addLibrarian({
    required String email,
    required String first,
    required String middle,
    required String last,
  }) {
    final id = email.trim().toLowerCase();
    final ref = _db.collection('users').doc(id);
    final logRef = AuditService.instance.newRef();
    final name = nameFields(first, middle, last);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) throw const AccountExistsException();
      tx.set(ref, {
        'email': id,
        'role': 'librarian',
        'status': 'active',
        ...name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: 'account.add_librarian',
          category: 'accounts',
          targetEmail: id,
          targetName: name['fullName'] as String,
        ),
      );
    });
  }

  /// A student signs up: creates their own record as pending.
  Future<void> registerStudent({
    required String email,
    required String first,
    required String middle,
    required String last,
    required String studentId,
    required int age,
    required String sex,
    required String course,
  }) {
    final id = email.trim().toLowerCase();
    final ref = _db.collection('users').doc(id);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) throw const AccountExistsException();
      tx.set(ref, {
        'email': id,
        'role': 'student',
        'status': 'pending',
        ...nameFields(first, middle, last),
        'studentId': studentId,
        'age': age,
        'sex': sex,
        'course': course.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// A student saves their own preferred genres (empty list = skipped).
  Future<void> savePreferredGenres(String email, List<String> genres) {
    return _db.collection('users').doc(email.toLowerCase()).update({
      'preferredGenres': genres,
      'genresPrompted': true,
    });
  }

  Future<void> _updateAndLog({
    required String email,
    required Map<String, Object?> changes,
    required String action,
    String? details,
  }) {
    final ref = _db.collection('users').doc(email.toLowerCase());
    final logRef = AuditService.instance.newRef();
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      tx.update(ref, changes);
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: action,
          category: 'accounts',
          targetEmail: ref.id,
          targetName: (snap.data()?['fullName'] ?? '') as String,
          details: details,
        ),
      );
    });
  }

  Future<void> setStatus(String email, String status) => _updateAndLog(
    email: email,
    changes: {'status': status},
    action: status == 'suspended' ? 'account.suspend' : 'account.reactivate',
  );

  Future<void> authorize(String email) => _updateAndLog(
    email: email,
    changes: {'status': 'active', 'authorizedAt': FieldValue.serverTimestamp()},
    action: 'account.authorize',
  );

  Future<void> setRole(String email, String role) => _updateAndLog(
    email: email,
    changes: {'role': role},
    action: 'account.role_change',
    details: 'New role: $role',
  );

  Future<void> updateInfo(String email, Map<String, Object?> fields) =>
      _updateAndLog(
        email: email,
        changes: fields,
        action: 'account.edit',
        details: 'Updated profile information',
      );

  Future<void> deleteUser(String email) {
    final ref = _db.collection('users').doc(email.toLowerCase());
    final logRef = AuditService.instance.newRef();
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      tx.delete(ref);
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: 'account.reject',
          category: 'accounts',
          targetEmail: ref.id,
          targetName: (snap.data()?['fullName'] ?? '') as String,
        ),
      );
    });
  }
}
