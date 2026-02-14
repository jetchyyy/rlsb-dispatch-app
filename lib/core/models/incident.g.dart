// GENERATED CODE - DO NOT MODIFY BY HAND
// Run `dart run build_runner build` to regenerate.

part of 'incident.dart';

Incident _$IncidentFromJson(Map<String, dynamic> json) => Incident(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      severity: json['severity'] as String?,
      status: json['status'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      reportedBy: json['reported_by'] as String?,
      reportedAt: json['reported_at'] as String?,
      patientName: json['patient_name'] as String?,
      patientAge: (json['patient_age'] as num?)?.toInt(),
      patientGender: json['patient_gender'] as String?,
      patientContact: json['patient_contact'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$IncidentToJson(Incident instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'title': instance.title,
      'description': instance.description,
      'severity': instance.severity,
      'status': instance.status,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'address': instance.address,
      'reported_by': instance.reportedBy,
      'reported_at': instance.reportedAt,
      'patient_name': instance.patientName,
      'patient_age': instance.patientAge,
      'patient_gender': instance.patientGender,
      'patient_contact': instance.patientContact,
      'notes': instance.notes,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
