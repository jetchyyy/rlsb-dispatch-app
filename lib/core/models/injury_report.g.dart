// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'injury_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InjuryReport _$InjuryReportFromJson(Map<String, dynamic> json) => InjuryReport(
      id: (json['id'] as num?)?.toInt(),
      incidentId: (json['incident_id'] as num?)?.toInt(),
      responderId: (json['responder_id'] as num?)?.toInt(),
      triageCategory: json['triage_category'] as String?,
      notes: json['notes'] as String?,
      injuries: (json['injuries'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
            k,
            (e as List<dynamic>)
                .map((e) => InjuryEntry.fromJson(e as Map<String, dynamic>))
                .toList()),
      ),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$InjuryReportToJson(InjuryReport instance) =>
    <String, dynamic>{
      'id': instance.id,
      'incident_id': instance.incidentId,
      'responder_id': instance.responderId,
      'triage_category': instance.triageCategory,
      'notes': instance.notes,
      'injuries': instance.injuries,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
