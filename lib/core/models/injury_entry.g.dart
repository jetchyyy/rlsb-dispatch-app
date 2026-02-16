// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'injury_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InjuryEntry _$InjuryEntryFromJson(Map<String, dynamic> json) => InjuryEntry(
      type: json['type'] as String,
      severity: json['severity'] as String,
      description: json['description'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$InjuryEntryToJson(InjuryEntry instance) =>
    <String, dynamic>{
      'type': instance.type,
      'severity': instance.severity,
      'description': instance.description,
      'notes': instance.notes,
    };
