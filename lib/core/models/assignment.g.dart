// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assignment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Assignment _$AssignmentFromJson(Map<String, dynamic> json) => Assignment(
      id: (json['id'] as num).toInt(),
      incidentId: (json['incident_id'] as num?)?.toInt(),
      responderId: (json['responder_id'] as num?)?.toInt(),
      status: json['status'] as String?,
      role: json['role'] as String?,
      dispatchedAt: json['dispatched_at'] as String?,
      acceptedAt: json['accepted_at'] as String?,
      rejectedAt: json['rejected_at'] as String?,
      enRouteAt: json['en_route_at'] as String?,
      onSceneAt: json['on_scene_at'] as String?,
      completedAt: json['completed_at'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      incident: json['incident'] == null
          ? null
          : Incident.fromJson(json['incident'] as Map<String, dynamic>),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$AssignmentToJson(Assignment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'incident_id': instance.incidentId,
      'responder_id': instance.responderId,
      'status': instance.status,
      'role': instance.role,
      'dispatched_at': instance.dispatchedAt,
      'accepted_at': instance.acceptedAt,
      'rejected_at': instance.rejectedAt,
      'en_route_at': instance.enRouteAt,
      'on_scene_at': instance.onSceneAt,
      'completed_at': instance.completedAt,
      'rejection_reason': instance.rejectionReason,
      'incident': instance.incident,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
