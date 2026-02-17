import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../services/location_service.dart';

/// Tracking mode for GPS updates.
enum TrackingMode {
  /// No tracking running.
  off,

  /// Silent 5-minute interval tracking (default when logged in).
  passive,

  /// High-frequency 5-second interval tracking (during incident response).
  active,
}

/// Manages GPS location tracking with adaptive intervals.
///
/// • **Passive mode** — captures a fix every 5 minutes and batches them
///   to `POST /location/batch-update` every 30 seconds.
/// • **Active mode** — captures a fix every 5 seconds (triggered when the
///   responder taps "Respond" on an incident) and batches the same way.
/// • **Offline queue** — unsent updates are persisted in a Hive box and
///   retried automatically on the next flush cycle.
class LocationTrackingProvider extends ChangeNotifier {
  final ApiClient _api;
  final LocationService _locationService;
  final Box<String> _offlineBox;

  LocationTrackingProvider({
    required ApiClient apiClient,
    required LocationService locationService,
    required Box<String> offlineBox,
  })  : _api = apiClient,
        _locationService = locationService,
        _offlineBox = offlineBox;

  // ── State ──────────────────────────────────────────────────

  TrackingMode _mode = TrackingMode.off;
  int? _activeIncidentId;
  Position? _lastPosition;
  bool _isTracking = false;
  String? _errorMessage;

  /// In-memory buffer of location fixes not yet sent.
  final List<Map<String, dynamic>> _locationBuffer = [];

  /// Timer that fires to capture a GPS fix.
  Timer? _captureTimer;

  /// Timer that fires to flush the buffer to the API.
  Timer? _flushTimer;

  // ── Getters ────────────────────────────────────────────────

  TrackingMode get mode => _mode;
  int? get activeIncidentId => _activeIncidentId;
  Position? get lastPosition => _lastPosition;
  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;
  int get pendingUpdates => _locationBuffer.length + _offlineBox.length;

  // ── Public API ─────────────────────────────────────────────

  /// Begin passive tracking (every 5 minutes). Call after login.
  Future<void> startPassiveTracking() async {
    if (_mode == TrackingMode.passive) return;

    final hasPermission = await _locationService.ensurePermission();
    if (!hasPermission) {
      _errorMessage = 'Location permission not granted';
      debugPrint('📍 Cannot start passive tracking — no permission');
      notifyListeners();
      return;
    }

    _mode = TrackingMode.passive;
    _isTracking = true;
    _activeIncidentId = null;
    _errorMessage = null;
    debugPrint(
        '📍 Passive tracking started (every ${ApiConstants.passiveTrackingInterval.inMinutes}m)');

    _startCaptureTimer(ApiConstants.passiveTrackingInterval);
    _startFlushTimer();

    // Capture an initial fix immediately
    _capturePosition();

    notifyListeners();
  }

  /// Switch to active (5-second) tracking for a specific incident.
  /// Also requests background location permission if not yet granted.
  Future<void> startActiveTracking(int incidentId) async {
    // Request background permission if not already granted
    final hasBgPermission = await _locationService.hasBackgroundPermission();
    if (!hasBgPermission) {
      debugPrint('📍 Requesting background location permission…');
      await _locationService.requestBackgroundPermission();
    }

    _activeIncidentId = incidentId;
    _mode = TrackingMode.active;
    _isTracking = true;
    _errorMessage = null;
    debugPrint(
        '📍 Active tracking started for incident #$incidentId (every ${ApiConstants.activeTrackingInterval.inSeconds}s)');

    _startCaptureTimer(ApiConstants.activeTrackingInterval);
    // Keep flush timer running as-is (or restart if not running)
    _flushTimer ??= Timer.periodic(
        ApiConstants.batchFlushInterval, (_) => _flushBuffer());

    // Capture an immediate fix
    _capturePosition();

    notifyListeners();
  }

  /// Revert from active tracking back to passive.
  /// Called when the incident is resolved.
  void stopActiveTracking() {
    if (_mode != TrackingMode.active) return;

    debugPrint(
        '📍 Active tracking stopped for incident #$_activeIncidentId – reverting to passive');
    _activeIncidentId = null;

    // Flush any remaining active-mode fixes immediately
    _flushBuffer();

    // Resume passive tracking
    _mode = TrackingMode.passive;
    _startCaptureTimer(ApiConstants.passiveTrackingInterval);
    notifyListeners();
  }

  /// Stop all tracking completely. Call on logout.
  void stopAllTracking() {
    debugPrint('📍 All tracking stopped');
    _captureTimer?.cancel();
    _captureTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _mode = TrackingMode.off;
    _isTracking = false;
    _activeIncidentId = null;

    // Persist any unsent fixes to Hive before stopping
    _persistBufferToHive();

    notifyListeners();
  }

  // ── Private — Capture ──────────────────────────────────────

  void _startCaptureTimer(Duration interval) {
    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(interval, (_) => _capturePosition());
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
        ApiConstants.batchFlushInterval, (_) => _flushBuffer());
  }

  Future<void> _capturePosition() async {
    try {
      final position = await _locationService.getCurrentPosition();
      _lastPosition = position;

      final entry = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'altitude': position.altitude,
        'timestamp': position.timestamp.toUtc().toIso8601String(),
        if (_activeIncidentId != null) 'incident_id': _activeIncidentId,
        'tracking_mode': _mode == TrackingMode.active ? 'active' : 'passive',
      };

      _locationBuffer.add(entry);
      debugPrint(
          '📍 Fix captured: ${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)} '
          '(buffer: ${_locationBuffer.length}, '
          'mode: ${_mode.name})');
    } catch (e) {
      debugPrint('📍 Capture error: $e');
    }
  }

  // ── Private — Flush / Upload ───────────────────────────────

  Future<void> _flushBuffer() async {
    // Collect everything: in-memory buffer + offline Hive queue
    final allUpdates = <Map<String, dynamic>>[..._locationBuffer];

    // Load any previously failed sends from Hive
    for (int i = 0; i < _offlineBox.length; i++) {
      try {
        final raw = _offlineBox.getAt(i);
        if (raw != null) {
          allUpdates.add(
              Map<String, dynamic>.from(jsonDecode(raw) as Map));
        }
      } catch (_) {}
    }

    if (allUpdates.isEmpty) return;

    debugPrint(
        '📍 Flushing ${allUpdates.length} location updates '
        '(${_locationBuffer.length} new + ${_offlineBox.length} queued)');

    try {
      await _api.post(
        ApiConstants.locationBatchUpdate,
        data: {'locations': allUpdates},
      );

      debugPrint('📍 Batch upload successful');

      // Clear everything on success
      _locationBuffer.clear();
      await _offlineBox.clear();
    } on DioException catch (e) {
      debugPrint(
          '📍 Batch upload failed (${e.response?.statusCode}): ${e.message}');
      // Persist current in-memory buffer to Hive for retry
      _persistBufferToHive();
    } catch (e) {
      debugPrint('📍 Batch upload error: $e');
      _persistBufferToHive();
    }
  }

  /// Moves in-memory buffer entries into the Hive offline queue.
  void _persistBufferToHive() {
    if (_locationBuffer.isEmpty) return;

    debugPrint(
        '📍 Persisting ${_locationBuffer.length} fixes to offline queue');
    for (final entry in _locationBuffer) {
      _offlineBox.add(jsonEncode(entry));
    }
    _locationBuffer.clear();
  }

  // ── Dispose ────────────────────────────────────────────────

  @override
  void dispose() {
    _captureTimer?.cancel();
    _flushTimer?.cancel();
    _persistBufferToHive();
    super.dispose();
  }
}
