import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Response status values for incident tracking.
///
/// These are sent to the backend as part of each location update
/// so the server can differentiate trail segments by response phase.
class ResponseStatus {
  ResponseStatus._();

  static const String available = 'available';
  static const String dispatched = 'dispatched';
  static const String enRoute = 'en_route';
  static const String onScene = 'on_scene';
  static const String returning = 'returning';
}

/// Manages the incident response lifecycle state.
///
/// Tracks which incident the responder is currently assigned to,
/// the current response phase, and timestamps for calculating
/// response time metrics:
///
/// • **Response Time** — dispatch → arrival (dispatched → on_scene)
/// • **Time on Scene** — arrival → departure (on_scene → returning)
/// • **Total Handling Time** — dispatch → completion (dispatched → available)
///
/// This provider is purely state — it does NOT make HTTP calls.
/// Location uploads and incident API calls remain in their respective
/// providers ([LocationTrackingProvider] and [IncidentProvider]).
class IncidentResponseProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────

  int? _activeIncidentId;
  String _responseStatus = ResponseStatus.available;
  DateTime? _dispatchTime;
  DateTime? _arrivalTime;
  DateTime? _completionTime;

  /// Incident scene coordinates for auto-arrival detection.
  double? _incidentLat;
  double? _incidentLng;

  /// Timer to auto-reset state after completing an incident.
  Timer? _resetTimer;

  // ── Getters ────────────────────────────────────────────────

  int? get activeIncidentId => _activeIncidentId;
  String get responseStatus => _responseStatus;
  bool get isRespondingToIncident => _activeIncidentId != null;
  DateTime? get dispatchTime => _dispatchTime;
  DateTime? get arrivalTime => _arrivalTime;
  DateTime? get completionTime => _completionTime;
  double? get incidentLat => _incidentLat;
  double? get incidentLng => _incidentLng;

  /// Computed response time (dispatch → arrival). Null if not yet arrived.
  Duration? get responseTimeElapsed {
    if (_dispatchTime == null || _arrivalTime == null) return null;
    return _arrivalTime!.difference(_dispatchTime!);
  }

  /// Live elapsed time since dispatch. Null if not dispatched.
  Duration? get totalElapsed {
    if (_dispatchTime == null) return null;
    return DateTime.now().difference(_dispatchTime!);
  }

  /// Time spent on scene (arrival → completion). Null if still on scene.
  Duration? get timeOnScene {
    if (_arrivalTime == null) return null;
    final end = _completionTime ?? DateTime.now();
    return end.difference(_arrivalTime!);
  }

  // ── Public Methods ─────────────────────────────────────────

  /// Accept an incident assignment and begin tracking.
  ///
  /// Sets the response status to `en_route` (the "Respond" action
  /// in the existing UI means "I'm heading there now").
  /// Records dispatch timestamp and incident coordinates for
  /// auto-arrival detection.
  void acceptIncident({
    required int incidentId,
    required double lat,
    required double lng,
  }) {
    _resetTimer?.cancel();

    _activeIncidentId = incidentId;
    _responseStatus = ResponseStatus.enRoute;
    _dispatchTime = DateTime.now();
    _arrivalTime = null;
    _completionTime = null;
    _incidentLat = lat;
    _incidentLng = lng;

    debugPrint(
        '🚨 IncidentResponse: accepted incident #$incidentId — status=$_responseStatus');
    notifyListeners();
  }

  /// Manually mark the responder as en route.
  ///
  /// Typically called if the response flow includes a separate
  /// "dispatched" → "en_route" transition.
  void markEnRoute() {
    if (_activeIncidentId == null) return;

    _responseStatus = ResponseStatus.enRoute;
    debugPrint(
        '🚨 IncidentResponse: en_route to incident #$_activeIncidentId');
    notifyListeners();
  }

  /// Mark arrival at the incident scene.
  ///
  /// Records the arrival timestamp for response time calculation.
  /// Can be called manually (button) or automatically via [checkArrival].
  void markOnScene() {
    if (_activeIncidentId == null) return;

    _responseStatus = ResponseStatus.onScene;
    _arrivalTime = DateTime.now();

    final responseTime = responseTimeElapsed;
    debugPrint(
        '🚨 IncidentResponse: on_scene at incident #$_activeIncidentId '
        '(response time: ${_formatDuration(responseTime)})');
    notifyListeners();
  }

  /// Complete the incident and begin the returning phase.
  ///
  /// After 5 minutes the state resets to [ResponseStatus.available]
  /// so the responder can accept new incidents.
  void completeIncident() {
    if (_activeIncidentId == null) return;

    _responseStatus = ResponseStatus.returning;
    _completionTime = DateTime.now();

    debugPrint(
        '🚨 IncidentResponse: returning from incident #$_activeIncidentId');
    notifyListeners();

    // Auto-reset to available after 5 minutes
    _resetTimer = Timer(const Duration(minutes: 5), () {
      resetState();
    });
  }

  /// Full state reset (for cancel/reject or after the 5-min delay).
  void resetState() {
    _resetTimer?.cancel();
    _activeIncidentId = null;
    _responseStatus = ResponseStatus.available;
    _dispatchTime = null;
    _arrivalTime = null;
    _completionTime = null;
    _incidentLat = null;
    _incidentLng = null;

    debugPrint('🚨 IncidentResponse: state reset to available');
    notifyListeners();
  }

  // ── Auto-Arrival Detection ─────────────────────────────────

  /// Check whether the responder has arrived at the incident scene.
  ///
  /// Called by [LocationTrackingProvider] each time a valid GPS fix
  /// is captured. If the responder is within 50 meters of the
  /// incident coordinates and currently en_route, auto-marks on_scene.
  void checkArrival(Position currentPosition) {
    if (_responseStatus != ResponseStatus.enRoute) return;
    if (_activeIncidentId == null) return;
    if (_incidentLat == null || _incidentLng == null) return;

    final distanceToIncident = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      _incidentLat!,
      _incidentLng!,
    );

    debugPrint(
        '🚨 IncidentResponse: distance to scene = '
        '${distanceToIncident.toStringAsFixed(1)}m');

    if (distanceToIncident <= 50) {
      debugPrint(
          '🚨 IncidentResponse: AUTO-ARRIVAL detected (≤50m) — marking on_scene');
      markOnScene();
    }
  }

  // ── Helpers ────────────────────────────────────────────────

  String _formatDuration(Duration? d) {
    if (d == null) return 'N/A';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  /// Human-readable label for the current response status.
  String get responseStatusLabel {
    switch (_responseStatus) {
      case ResponseStatus.available:
        return 'Available';
      case ResponseStatus.dispatched:
        return 'Dispatched';
      case ResponseStatus.enRoute:
        return 'En Route';
      case ResponseStatus.onScene:
        return 'On Scene';
      case ResponseStatus.returning:
        return 'Returning';
      default:
        return _responseStatus;
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }
}
