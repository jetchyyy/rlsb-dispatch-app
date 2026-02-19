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
/// { "success": true, "data": { id, name, email, division, unit, position,
///     phone_number, id_number, roles: [...], permissions: [...] } }
/// ```
class UserModel {
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

  UserModel({
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
      unit: data['unit'] as String?,
      position: data['position'] as String?,
      phoneNumber: data['phone_number'] as String?,
      idNumber: data['id_number'] as String?,
      roles: List<String>.from(data['roles'] ?? []),
      permissions: List<String>.from(data['permissions'] ?? []),
      token: token,
    );
  }

  /// Return a copy with specific fields updated.
  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? division,
    String? unit,
    String? position,
    String? phoneNumber,
    String? idNumber,
    List<String>? roles,
    List<String>? permissions,
    String? token,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      division: division ?? this.division,
      unit: unit ?? this.unit,
      position: position ?? this.position,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      idNumber: idNumber ?? this.idNumber,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      token: token ?? this.token,
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
      unit: user['unit'] as String?,
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
        'unit': unit,
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
        unit: unit,
        position: position,
        phoneNumber: phoneNumber,
        idNumber: idNumber,
        roles: roles,
        permissions: permissions,
        token: token,
      );
}