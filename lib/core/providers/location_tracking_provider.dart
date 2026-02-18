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
    // Public method to force flush the offline queue (for admin/manual use)
    // (Implementation is below; this stub is removed)
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

  /// Timer that fires to capture a GPS fix.
  Timer? _captureTimer;

  // ── Getters ────────────────────────────────────────────────

  TrackingMode get mode => _mode;
  int? get activeIncidentId => _activeIncidentId;
  Position? get lastPosition => _lastPosition;
  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;
  int get pendingUpdates => _offlineBox.length;

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

  // No-op: batch flush timer removed (per-fix upload)

  Future<void> _capturePosition() async {
    try {
      final position = await _locationService.getCurrentPosition();

      // ── Accuracy Filter ───────────────────────────────────────
      // Reject positions with poor accuracy to prevent jumpy/inaccurate pings
      if (position.accuracy > ApiConstants.maxAccuracyMeters) {
        debugPrint(
            '📍 ❌ Position rejected: accuracy ${position.accuracy.toStringAsFixed(1)}m > ${ApiConstants.maxAccuracyMeters}m threshold');
        return;
      }

      // ── Distance Filter ───────────────────────────────────────
      // Skip update if device hasn't moved enough (prevents jitter/noise)
      if (_lastPosition != null) {
        final distance = _locationService.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (distance < ApiConstants.minDistanceMeters) {
          debugPrint(
              '📍 ⏭️  Position skipped: moved only ${distance.toStringAsFixed(1)}m < ${ApiConstants.minDistanceMeters}m threshold');
          // Still update lastPosition timestamp but don't send to server
          _lastPosition = position;
          return;
        }
      }

      _lastPosition = position;

      final entry = <String, dynamic>{
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'tracking_mode': _mode == TrackingMode.active ? 'active' : 'passive',
        'timestamp': position.timestamp.toUtc().toIso8601String(),
      };
      if (_activeIncidentId != null) {
        entry['incident_id'] = _activeIncidentId;
      }

      debugPrint('📍 ✅ Captured: lat=${position.latitude.toStringAsFixed(6)}, '
          'lng=${position.longitude.toStringAsFixed(6)}, '
          'acc=${position.accuracy.toStringAsFixed(1)}m');

      // Try to send immediately
      try {
        await _api.post(
          '/location/update',
          data: entry,
        );
        debugPrint('📍 Location sent to /location/update');
      } on DioException catch (e) {
        debugPrint('📍 Upload failed (${e.response?.statusCode}): ${e.message}');
        // Save to offline queue for retry
        _offlineBox.add(jsonEncode(entry));
      } catch (e) {
        debugPrint('📍 Upload error: $e');
        _offlineBox.add(jsonEncode(entry));
      }
    } catch (e) {
      debugPrint('📍 Capture error: $e');
    }
  }

  // ── Private — Flush / Upload ───────────────────────────────

  /// Retry sending any failed location updates from the offline queue.
  Future<void> flushBatch() async {
    if (_offlineBox.isEmpty) return;
    debugPrint('📍 Flushing ${_offlineBox.length} offline location updates');
    final failed = <int>[];
    for (int i = 0; i < _offlineBox.length; i++) {
      try {
        final raw = _offlineBox.getAt(i);
        if (raw == null) continue;
        final entry = jsonDecode(raw) as Map<String, dynamic>;
        
        // Migrate old 'captured_at' to 'timestamp' for backward compatibility
        if (entry.containsKey('captured_at') && !entry.containsKey('timestamp')) {
          entry['timestamp'] = entry.remove('captured_at');
        }
        
        await _api.post(
          '/location/update',
          data: entry,
        );
        debugPrint('📍 Flushed offline location: $entry');
        failed.add(i);
      } on DioException catch (e) {
        debugPrint('📍 Offline upload failed (${e.response?.statusCode}): ${e.message}');
      } catch (e) {
        debugPrint('📍 Offline upload error: $e');
      }
    }
    // Remove successfully sent entries
    for (final idx in failed.reversed) {
      await _offlineBox.deleteAt(idx);
    }
    notifyListeners();
  }

  /// No-op: buffer is not used anymore, only offline queue remains.
  void _persistBufferToHive() {}

  // ── Dispose ────────────────────────────────────────────────

  @override
  void dispose() {
    _captureTimer?.cancel();
    _persistBufferToHive();
    super.dispose();
  }
}
