import 'package:json_annotation/json_annotation.dart';

part 'injury_entry.g.dart';

@JsonSerializable()
class InjuryEntry {
  final String type;
  final String severity;
  final String? description;
  final String? notes;

  const InjuryEntry({
    required this.type,
    required this.severity,
    this.description,
    this.notes,
  });

  factory InjuryEntry.fromJson(Map<String, dynamic> json) =>
      _$InjuryEntryFromJson(json);

  Map<String, dynamic> toJson() => _$InjuryEntryToJson(this);

  InjuryEntry copyWith({
    String? type,
    String? severity,
    String? description,
    String? notes,
  }) {
    return InjuryEntry(
      type: type ?? this.type,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      notes: notes ?? this.notes,
    );
  }

  /// List of all available injury types.
  static const List<String> injuryTypes = [
    'Laceration',
    'Contusion',
    'Fracture',
    'Burn',
    'Puncture',
    'Abrasion',
    'Avulsion',
    'Amputation',
    'Dislocation',
    'Swelling',
    'Deformity',
    'Pain',
    'Bleeding',
    'Other',
  ];

  /// List of severity levels.
  static const List<String> severityLevels = [
    'Minor',
    'Moderate',
    'Severe',
    'Critical',
  ];
}
