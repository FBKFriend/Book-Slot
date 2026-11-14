import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String email;
  final String role; // student | librarian | superadmin
  final String status; // pending | active | suspended
  final String name;
  final String? studentId;
  final int? age;
  final String? sex;
  final String? course;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final DateTime? authorizedAt;
  final DateTime? createdAt;

  const AppUser({
    required this.email,
    required this.role,
    required this.status,
    required this.name,
    this.studentId,
    this.age,
    this.sex,
    this.course,
    this.createdAt,
    this.firstName,
    this.middleName,
    this.lastName,
    this.authorizedAt,
  });

  factory AppUser.fromMap(String email, Map<String, dynamic> d) => AppUser(
    email: email,
    role: (d['role'] ?? 'student') as String,
    status: (d['status'] ?? 'pending') as String,
    name: (d['fullName'] ?? '') as String,
    studentId: d['studentId'] as String?,
    age: (d['age'] as num?)?.toInt(),
    sex: d['sex'] as String?,
    course: d['course'] as String?,
    createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    firstName: d['firstName'] as String?,
    middleName: d['middleName'] as String?,
    lastName: d['lastName'] as String?,
    authorizedAt: (d['authorizedAt'] as Timestamp?)?.toDate(),
  );

  /// Name parts for the edit form; falls back to splitting the full name.
  ({String first, String middle, String last}) get nameParts {
    if ((firstName ?? '').isNotEmpty || (lastName ?? '').isNotEmpty) {
      return (
        first: firstName ?? '',
        middle: middleName ?? '',
        last: lastName ?? '',
      );
    }
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return (first: '', middle: '', last: '');
    if (words.length == 1) return (first: words.first, middle: '', last: '');
    return (
      first: words.first,
      middle: words.sublist(1, words.length - 1).join(' '),
      last: words.last,
    );
  }
}
