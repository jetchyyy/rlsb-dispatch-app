import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // ── Persistence Keys ───────────────────────────────────────
  static const String _keyActiveIncidentId = 'resp_active_id';
  static const String _keyResponseStatus = 'resp_status';
  static const String _keyDispatchTime = 'resp_dispatch_time';
  static const String _keyArrivalTime = 'resp_arrival_time';
  static const String _keyIncidentLat = 'resp_incident_lat';
  static const String _keyIncidentLng = 'resp_incident_lng';

  IncidentResponseProvider() {
    _restoreState();
  }

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
  Future<void> acceptIncident({
    required int incidentId,
    required double lat,
    required double lng,
  }) async {
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
    _saveState();
  }

  /// Manually mark the responder as en route.
  ///
  /// Typically called if the response flow includes a separate
  /// "dispatched" → "en_route" transition.
  Future<void> markEnRoute() async {
    if (_activeIncidentId == null) return;

    _responseStatus = ResponseStatus.enRoute;
    debugPrint('🚨 IncidentResponse: en_route to incident #$_activeIncidentId');
    notifyListeners();
    _saveState();
  }

  /// Mark arrival at the incident scene.
  ///
  /// Records the arrival timestamp for response time calculation.
  /// Can be called manually (button) or automatically via [checkArrival].
  Future<void> markOnScene() async {
    if (_activeIncidentId == null) return;

    _responseStatus = ResponseStatus.onScene;
    _arrivalTime = DateTime.now();

    final responseTime = responseTimeElapsed;
    debugPrint('🚨 IncidentResponse: on_scene at incident #$_activeIncidentId '
        '(response time: ${_formatDuration(responseTime)})');
    notifyListeners();
    _saveState();
  }

  /// Complete the incident and begin the returning phase.
  ///
  /// After 5 minutes the state resets to [ResponseStatus.available]
  /// so the responder can accept new incidents.
  ///
  /// [incidentId]: Optional. If provided, completion only occurs if
  /// it matches the currently active incident.
  Future<void> completeIncident({int? incidentId}) async {
    // If a specific ID is requested to be completed, but we are tracking
    // a different one, ignore the request. (e.g., resolving a different incident)
    if (incidentId != null && _activeIncidentId != incidentId) {
      debugPrint(
          '🚨 IncidentResponse: Ignoring completion for #$incidentId (currently tracking #$_activeIncidentId)');
      return;
    }

    if (_activeIncidentId == null) return;

    _responseStatus = ResponseStatus.returning;
    _completionTime = DateTime.now();

    debugPrint(
        '🚨 IncidentResponse: returning from incident #$_activeIncidentId — resetting state immediately per user request');
    notifyListeners();

    // Reset immediately to close the banner
    resetState();
  }

  /// Full state reset (for cancel/reject or after the 5-min delay).
  Future<void> resetState() async {
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
    _clearState();
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

    debugPrint('🚨 IncidentResponse: distance to scene = '
        '${distanceToIncident.toStringAsFixed(1)}m');

    if (distanceToIncident <= 50) {
      debugPrint(
          '🚨 IncidentResponse: AUTO-ARRIVAL detected (≤50m) — marking on_scene');
      markOnScene();
    }
  }

  // ── Persistence Helpers ────────────────────────────────────

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_activeIncidentId != null) {
        await prefs.setInt(_keyActiveIncidentId, _activeIncidentId!);
        await prefs.setString(_keyResponseStatus, _responseStatus);
        if (_dispatchTime != null) {
          await prefs.setString(
              _keyDispatchTime, _dispatchTime!.toIso8601String());
        }
        if (_arrivalTime != null) {
          await prefs.setString(
              _keyArrivalTime, _arrivalTime!.toIso8601String());
        }
        if (_incidentLat != null) {
          await prefs.setDouble(_keyIncidentLat, _incidentLat!);
        }
        if (_incidentLng != null) {
          await prefs.setDouble(_keyIncidentLng, _incidentLng!);
        }
        debugPrint('💾 IncidentResponse: State saved');
      }
    } catch (e) {
      debugPrint('⚠️ IncidentResponse: Failed to save state: $e');
    }
  }

  Future<void> _restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_keyActiveIncidentId)) {
        _activeIncidentId = prefs.getInt(_keyActiveIncidentId);
        _responseStatus =
            prefs.getString(_keyResponseStatus) ?? ResponseStatus.available;

        final dispatchStr = prefs.getString(_keyDispatchTime);
        if (dispatchStr != null) _dispatchTime = DateTime.parse(dispatchStr);

        final arrivalStr = prefs.getString(_keyArrivalTime);
        if (arrivalStr != null) _arrivalTime = DateTime.parse(arrivalStr);

        _incidentLat = prefs.getDouble(_keyIncidentLat);
        _incidentLng = prefs.getDouble(_keyIncidentLng);

        debugPrint(
            '📂 IncidentResponse: State restored (Active ID: $_activeIncidentId)');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ IncidentResponse: Failed to restore state: $e');
    }
  }

  Future<void> _clearState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyActiveIncidentId);
      await prefs.remove(_keyResponseStatus);
      await prefs.remove(_keyDispatchTime);
      await prefs.remove(_keyArrivalTime);
      await prefs.remove(_keyIncidentLat);
      await prefs.remove(_keyIncidentLng);
      // We don't clear completion time usually needed for history but here we reset fully
      debugPrint('🗑️ IncidentResponse: State cleared');
    } catch (e) {
      debugPrint('⚠️ IncidentResponse: Failed to clear state: $e');
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
