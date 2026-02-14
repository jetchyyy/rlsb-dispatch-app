// GENERATED CODE - DO NOT MODIFY BY HAND
// Run `dart run build_runner build` to regenerate.

part of 'injury_report.dart';

InjuryReport _$InjuryReportFromJson(Map<String, dynamic> json) => InjuryReport(
      id: (json['id'] as num?)?.toInt(),
      incidentId: (json['incident_id'] as num?)?.toInt(),
      responderId: (json['responder_id'] as num?)?.toInt(),
      triageCategory: json['triage_category'] as String?,
      notes: json['notes'] as String?,
      injuries: (json['injuries'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(
          k,
          (v as List<dynamic>)
              .map((e) => InjuryEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
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
      'injuries': instance.injuries?.map(
        (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
      ),
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
