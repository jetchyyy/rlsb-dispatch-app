class User {
  final int id;
  final String name;
  final String email;
  final String? division;
  final String? unit;  // e.g., "PDRRMO-ASSERT", "BFP", "PNP"
  final String? position;
  final String? phoneNumber;
  final String? idNumber;
  final List<String> roles;
  final List<String> permissions;
  final String token;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.division,
    this.unit,
    this.position,
    this.phoneNumber,
    this.idNumber,
    this.roles = const [],
    this.permissions = const [],
    required this.token,
  });

  /// Display-friendly role label (first role or 'Staff').
  String get roleLabel =>
      roles.isNotEmpty ? roles.first.replaceAll('-', ' ') : 'Staff';

  bool get isAdmin =>
      roles.contains('admin') || roles.contains('super-admin');
  bool get isStaff => roles.isNotEmpty;
}