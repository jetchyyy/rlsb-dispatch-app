import 'package:json_annotation/json_annotation.dart';

part 'incident.g.dart';

@JsonSerializable()
class Incident {
  final int id;
  final String? type;
  final String? title;
  final String? description;
  final String? severity;
  final String? status;
  final double? latitude;
  final double? longitude;
  final String? address;
  @JsonKey(name: 'reported_by')
  final String? reportedBy;
  @JsonKey(name: 'reported_at')
  final String? reportedAt;
  @JsonKey(name: 'patient_name')
  final String? patientName;
  @JsonKey(name: 'patient_age')
  final int? patientAge;
  @JsonKey(name: 'patient_gender')
  final String? patientGender;
  @JsonKey(name: 'patient_contact')
  final String? patientContact;
  final String? notes;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const Incident({
    required this.id,
    this.type,
    this.title,
    this.description,
    this.severity,
    this.status,
    this.latitude,
    this.longitude,
    this.address,
    this.reportedBy,
    this.reportedAt,
    this.patientName,
    this.patientAge,
    this.patientGender,
    this.patientContact,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Incident.fromJson(Map<String, dynamic> json) =>
      _$IncidentFromJson(json);

  Map<String, dynamic> toJson() => _$IncidentToJson(this);
}
