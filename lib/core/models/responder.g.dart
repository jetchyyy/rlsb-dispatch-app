// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'responder.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Responder _$ResponderFromJson(Map<String, dynamic> json) => Responder(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      badge: json['badge'] as String?,
      role: json['role'] as String?,
      team: json['team'] as String?,
      status: json['status'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$ResponderToJson(Responder instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'phone': instance.phone,
      'badge': instance.badge,
      'role': instance.role,
      'team': instance.team,
      'status': instance.status,
      'profile_photo_url': instance.profilePhotoUrl,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
