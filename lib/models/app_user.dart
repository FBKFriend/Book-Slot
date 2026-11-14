class AppUser {
  final String email;
  final String role; // student | librarian | superadmin
  final String status; // pending | active | suspended
  final String name;

  const AppUser({
    required this.email,
    required this.role,
    required this.status,
    required this.name,
  });

  factory AppUser.fromMap(String email, Map<String, dynamic> d) => AppUser(
    email: email,
    role: (d['role'] ?? 'student') as String,
    status: (d['status'] ?? 'pending') as String,
    name: (d['fullName'] ?? '') as String,
  );
}
