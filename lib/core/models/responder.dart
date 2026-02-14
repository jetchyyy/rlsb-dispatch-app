import 'package:json_annotation/json_annotation.dart';

part 'responder.g.dart';

@JsonSerializable()
class Responder {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? badge;
  final String? role;
  final String? team;
  final String? status;
  @JsonKey(name: 'profile_photo_url')
  final String? profilePhotoUrl;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const Responder({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.badge,
    this.role,
    this.team,
    this.status,
    this.profilePhotoUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory Responder.fromJson(Map<String, dynamic> json) =>
      _$ResponderFromJson(json);

  Map<String, dynamic> toJson() => _$ResponderToJson(this);

  Responder copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? badge,
    String? role,
    String? team,
    String? status,
    String? profilePhotoUrl,
    String? createdAt,
    String? updatedAt,
  }) {
    return Responder(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      badge: badge ?? this.badge,
      role: role ?? this.role,
      team: team ?? this.team,
      status: status ?? this.status,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
