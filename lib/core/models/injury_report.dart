import 'package:json_annotation/json_annotation.dart';
import 'injury_entry.dart';

part 'injury_report.g.dart';

@JsonSerializable()
class InjuryReport {
  final int? id;
  @JsonKey(name: 'incident_id')
  final int? incidentId;
  @JsonKey(name: 'responder_id')
  final int? responderId;
  @JsonKey(name: 'triage_category')
  final String? triageCategory;
  final String? notes;
  final Map<String, List<InjuryEntry>>? injuries;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const InjuryReport({
    this.id,
    this.incidentId,
    this.responderId,
    this.triageCategory,
    this.notes,
    this.injuries,
    this.createdAt,
    this.updatedAt,
  });

  factory InjuryReport.fromJson(Map<String, dynamic> json) =>
      _$InjuryReportFromJson(json);

  Map<String, dynamic> toJson() => _$InjuryReportToJson(this);
}
