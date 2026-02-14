import '../../domain/entities/user.dart';

/// Maps the Laravel `users` table API responses to a Dart object.
///
/// Login response (POST /api/login):
/// ```json
/// { "success": true, "data": { "user": { id, name, email }, "token": "..." } }
/// ```
///
/// Profile response (GET /api/web/user):
/// ```json
/// { "success": true, "data": { id, name, email, division, position,
///     phone_number, id_number, roles: [...], permissions: [...] } }
/// ```
class UserModel {
  final int id;
  final String name;
  final String email;
  final String? division;
  final String? position;
  final String? phoneNumber;
  final String? idNumber;
  final List<String> roles;
  final List<String> permissions;
  final String token;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.division,
    this.position,
    this.phoneNumber,
    this.idNumber,
    this.roles = const [],
    this.permissions = const [],
    required this.token,
  });

  /// Parse the login response (minimal user + token).
  factory UserModel.fromLoginJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final user = data['user'] ?? data;

    return UserModel(
      id: user['id'] as int,
      name: user['name'] as String,
      email: user['email'] as String,
      token: (data['token'] as String?) ?? '',
    );
  }

  /// Return a copy enriched with the /web/user profile response.
  UserModel copyWithProfile(Map<String, dynamic> profileJson) {
    final data = profileJson['data'] ?? profileJson;
    return UserModel(
      id: id,
      name: (data['name'] as String?) ?? name,
      email: (data['email'] as String?) ?? email,
      division: data['division'] as String?,
      position: data['position'] as String?,
      phoneNumber: data['phone_number'] as String?,
      idNumber: data['id_number'] as String?,
      roles: List<String>.from(data['roles'] ?? []),
      permissions: List<String>.from(data['permissions'] ?? []),
      token: token,
    );
  }

  /// Parse from stored JSON (SharedPreferences) or an API response.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final user = data['user'] ?? data;

    return UserModel(
      id: user['id'] as int,
      name: user['name'] as String,
      email: user['email'] as String,
      division: user['division'] as String?,
      position: user['position'] as String?,
      phoneNumber: user['phone_number'] as String?,
      idNumber: user['id_number'] as String?,
      roles: List<String>.from(user['roles'] ?? []),
      permissions: List<String>.from(user['permissions'] ?? []),
      token: (data['token'] ?? user['token'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'division': division,
        'position': position,
        'phone_number': phoneNumber,
        'id_number': idNumber,
        'roles': roles,
        'permissions': permissions,
        'token': token,
      };

  /// Convert to domain entity.
  User toEntity() => User(
        id: id,
        name: name,
        email: email,
        division: division,
        position: position,
        phoneNumber: phoneNumber,
        idNumber: idNumber,
        roles: roles,
        permissions: permissions,
        token: token,
      );
}