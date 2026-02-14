class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String token;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
  });

  bool get isSuperAdmin => role.toLowerCase() == 'superadmin';
  bool get isStaff => role.toLowerCase() == 'staff';
}