import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

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

  // ── Callbacks ──────────────────────────────────────────────

  /// Called after each valid GPS fix so the wiring layer can
  /// delegate to [IncidentResponseProvider.checkArrival].
  void Function(Position position)? onPositionCaptured;

  // ── State ──────────────────────────────────────────────────

  TrackingMode _mode = TrackingMode.off;
  int? _activeIncidentId;
  Position? _lastPosition;
  bool _isTracking = false;
  String? _errorMessage;

  /// Current response status sent with every location update.
  /// Defaults to `'available'` and is synced by the wiring layer
  /// whenever [IncidentResponseProvider] changes state.
  String _responseStatus = 'available';

  /// Timer that fires to capture a GPS fix.
  /// Timer for periodic active/passive updates
  Timer? _captureTimer;

  /// Timer for retrying offline uploads
  Timer? _flushTimer;

  // ── Getters ────────────────────────────────────────────────

  TrackingMode get mode => _mode;
  int? get activeIncidentId => _activeIncidentId;
  Position? get lastPosition => _lastPosition;
  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;
  String get responseStatus => _responseStatus;
  int get pendingUpdates => _offlineBox.length;

  /// Update the response status included in location payloads.
  set responseStatus(String value) {
    _responseStatus = value;
    debugPrint('📍 Response status updated to: $value');
  }

  // ── Public API ─────────────────────────────────────────────

  /// Stream of real-time position updates (for UI/Map).
  /// Uses a small distance filter (2m) for smooth movement on map.
  Stream<Position> get locationStream =>
      _locationService.getPositionStream(distanceFilter: 2);

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
        '📍 Passive tracking started (every ${ApiConstants.passiveTrackingInterval.inSeconds}s)');

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
    _startFlushTimer();

    // Capture an immediate fix
    _capturePosition();

    notifyListeners();
  }

  /// Revert from active tracking back to passive.
  /// Called when the incident is resolved.
  void stopActiveTracking() {
    final wasActive = _mode == TrackingMode.active;
    final hadIncidentId = _activeIncidentId != null;
    final oldIncidentId = _activeIncidentId;

    // Always clear the incident ID, even if mode changed
    _activeIncidentId = null;

    // Clear offline queue entries that contain the old incident ID
    // to prevent resolved incident pings from being sent later
    if (oldIncidentId != null && _offlineBox.isNotEmpty) {
      final toDelete = <int>[];
      for (int i = 0; i < _offlineBox.length; i++) {
        try {
          final raw = _offlineBox.getAt(i);
          if (raw != null) {
            final entry = jsonDecode(raw) as Map<String, dynamic>;
            if (entry['incident_id'] == oldIncidentId) {
              toDelete.add(i);
            }
          }
        } catch (e) {
          debugPrint('📍 Error checking offline entry: $e');
        }
      }
      for (final idx in toDelete.reversed) {
        _offlineBox.deleteAt(idx);
      }
      if (toDelete.isNotEmpty) {
        debugPrint(
            '📍 Cleared ${toDelete.length} offline pings for incident #$oldIncidentId');
      }
    }

    // If we were already in passive mode, just log and return
    if (!wasActive) {
      if (hadIncidentId) {
        debugPrint(
            '📍 Cleared incident ID while in $_mode mode (was not active)');
      }
      notifyListeners();
      return;
    }

    debugPrint('📍 Active tracking stopped – reverting to passive');

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
    // Retry offline uploads every 60 seconds
    _flushTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_offlineBox.isNotEmpty) {
        debugPrint('📍 Periodic flush check...');
        flushBatch();
      }
    });
  }

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

      // Notify listeners (e.g. auto-arrival detection)
      onPositionCaptured?.call(position);

      // Use current system time for timestamp (more reliable than GPS timestamp)
      final timestamp = DateTime.now().toUtc().toIso8601String();

      final entry = <String, dynamic>{
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'tracking_mode': _mode == TrackingMode.active ? 'active' : 'passive',
        'timestamp': timestamp,
        'response_status': _responseStatus,
      };
      if (_activeIncidentId != null) {
        entry['incident_id'] = _activeIncidentId;
      }

      debugPrint('📍 ✅ Captured: lat=${position.latitude.toStringAsFixed(6)}, '
          'lng=${position.longitude.toStringAsFixed(6)}, '
          'acc=${position.accuracy.toStringAsFixed(1)}m, '
          'timestamp=$timestamp');

      // Try to send immediately
      try {
        await _api.post(
          '/location/update',
          data: entry,
        );
        debugPrint('📍 Location sent to /location/update');

        // Smart Sync: If upload succeeds, it means we have internet.
        // Flush any offline items immediately.
        if (_offlineBox.isNotEmpty) {
          debugPrint('📍 Online detected — flushing offline queue...');
          flushBatch();
        }
      } on DioException catch (e) {
        debugPrint(
            '📍 Upload failed (${e.response?.statusCode}): ${e.message}');
        // Save to offline queue for retry
        _offlineBox.add(jsonEncode(entry));
        notifyListeners(); // Update UI count
      } catch (e) {
        debugPrint('📍 Upload error: $e');
        _offlineBox.add(jsonEncode(entry));
        notifyListeners(); // Update UI count
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
        if (raw == null) {
          successfulIndices.add(i); // Remove corrupted/null entries
          continue;
        }
        final entry = jsonDecode(raw) as Map<String, dynamic>;

        // Migrate old 'captured_at' to 'timestamp' for backward compatibility
        if (entry.containsKey('captured_at') &&
            !entry.containsKey('timestamp')) {
          entry['timestamp'] = entry.remove('captured_at');
        }

        // Skip entries with stale incident IDs (from completed incidents)
        final entryIncidentId = entry['incident_id'] as int?;
        if (entryIncidentId != null && entryIncidentId != _activeIncidentId) {
          debugPrint(
              '📍 Skipping stale ping for incident #$entryIncidentId (current: ${_activeIncidentId ?? "none"})');
          stale.add(i);
          continue;
        }

        await _api.post(
          '/location/update',
          data: entry,
        );
        debugPrint('📍 Flushed offline location: $entry');
        failed.add(i);
      } on DioException catch (e) {
        // Stop flushing on network error to avoid unnecessary requests
        // But if it's a 4xx error (validation), we should probably delete it?
        // For 422 (unprocessable), we should delete to avoid loop.
        // For now, only stop on connection errors (0 or 5xx or Unknown).
        debugPrint(
            '📍 Offline upload failed (${e.response?.statusCode}): ${e.message}');

        // If it's a permanent error (e.g. 400, 422), discard it
        if (e.response != null &&
            (e.response!.statusCode! >= 400 && e.response!.statusCode! < 500)) {
          debugPrint('📍 Discarding invalid offline entry [index $i]');
          successfulIndices.add(i);
        } else {
          // Network/Server error — stop trying for now
          break;
        }
      } catch (e) {
        debugPrint('📍 Offline upload error: $e');
        // Likely a parsing error, discard
        successfulIndices.add(i);
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
