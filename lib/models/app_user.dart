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
  );
}
