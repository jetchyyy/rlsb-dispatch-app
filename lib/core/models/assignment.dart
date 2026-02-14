import 'package:json_annotation/json_annotation.dart';
import 'incident.dart';

part 'assignment.g.dart';

/// Assignment status values:
/// pending, accepted, rejected, en_route, on_scene, completed
@JsonSerializable()
class Assignment {
  final int id;
  @JsonKey(name: 'incident_id')
  final int? incidentId;
  @JsonKey(name: 'responder_id')
  final int? responderId;
  final String? status;
  final String? role;
  @JsonKey(name: 'dispatched_at')
  final String? dispatchedAt;
  @JsonKey(name: 'accepted_at')
  final String? acceptedAt;
  @JsonKey(name: 'rejected_at')
  final String? rejectedAt;
  @JsonKey(name: 'en_route_at')
  final String? enRouteAt;
  @JsonKey(name: 'on_scene_at')
  final String? onSceneAt;
  @JsonKey(name: 'completed_at')
  final String? completedAt;
  @JsonKey(name: 'rejection_reason')
  final String? rejectionReason;
  final Incident? incident;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const Assignment({
    required this.id,
    this.incidentId,
    this.responderId,
    this.status,
    this.role,
    this.dispatchedAt,
    this.acceptedAt,
    this.rejectedAt,
    this.enRouteAt,
    this.onSceneAt,
    this.completedAt,
    this.rejectionReason,
    this.incident,
    this.createdAt,
    this.updatedAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) =>
      _$AssignmentFromJson(json);

  Map<String, dynamic> toJson() => _$AssignmentToJson(this);

  /// Whether the responder can still act on this assignment.
  bool get isActionable =>
      status == 'pending' || status == 'accepted' || status == 'en_route' || status == 'on_scene';

  /// Human-readable status label.
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'en_route':
        return 'En Route';
      case 'on_scene':
        return 'On Scene';
      case 'completed':
        return 'Completed';
      default:
        return status ?? 'Unknown';
    }
  }
}
