import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../models/batch_update_response.dart';
import '../network/api_client.dart';
import '../services/background_service_initializer.dart';
import '../services/connectivity_service.dart';
import '../services/location_service.dart';
import '../services/sensor_fusion_service.dart';
import '../utils/kalman_filter.dart';
import '../utils/path_simplifier.dart';

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
  final SensorFusionService _sensorFusion;
  final ConnectivityService _connectivityService;
  
  /// Kalman filter for GPS position smoothing.
  final KalmanFilter2D _kalmanFilter = KalmanFilter2D(
    processNoise: ApiConstants.kalmanProcessNoise,
    measurementNoiseBase: ApiConstants.kalmanMeasurementNoise,
  );

  /// Completer that signals when state restoration is complete.
  final Completer<void> _initialized = Completer<void>();

  /// Future that completes when the provider has finished restoring state.
  /// Await this before starting passive tracking to avoid race conditions.
  Future<void> get initialized => _initialized.future;

  // ── Persistence Keys ───────────────────────────────────────
  static const String _keyTrackingMode = 'loc_tracking_mode';
  static const String _keyActiveIncidentId = 'loc_active_incident_id';

  LocationTrackingProvider({
    required ApiClient apiClient,
    required LocationService locationService,
    required Box<String> offlineBox,
    required SensorFusionService sensorFusionService,
    ConnectivityService? connectivityService,
  })  : _api = apiClient,
        _locationService = locationService,
        _offlineBox = offlineBox,
        _sensorFusion = sensorFusionService,
        _connectivityService = connectivityService ?? ConnectivityService.instance {
    // Listen for connectivity restoration to flush offline queue immediately
    _connectivityService.onConnectionRestored(_onConnectionRestored);
    _restoreState();
    _subscribeToBackgroundUpdates();
  }

  // ── Background-to-main bridge ──────────────────────────────

  /// Listens for `locationUpdate` events emitted by the background service
  /// isolate so that [lastPosition] stays fresh even when the app is closed
  /// and GPS captures happen in the background service.
  void _subscribeToBackgroundUpdates() {
    _bgLocationSub =
        FlutterBackgroundService().on('locationUpdate').listen((event) {
      if (event == null) return;
      try {
        final ts = DateTime.tryParse(event['timestamp'] as String? ?? '') ??
            DateTime.now();
        _lastPosition = Position(
          latitude: (event['latitude'] as num).toDouble(),
          longitude: (event['longitude'] as num).toDouble(),
          accuracy: (event['accuracy'] as num? ?? 0).toDouble(),
          altitude: (event['altitude'] as num? ?? 0).toDouble(),
          altitudeAccuracy: 0,
          speed: (event['speed'] as num? ?? 0).toDouble(),
          speedAccuracy: 0,
          heading: (event['heading'] as num? ?? 0).toDouble(),
          headingAccuracy: 0,
          timestamp: ts,
        );
        _lastCaptureTime = ts;
        debugPrint(
            '📍 [Provider] Updated lastPosition from background service');
        notifyListeners();
      } catch (e) {
        debugPrint(
            '📍 [Provider] Failed to parse background locationUpdate: $e');
      }
    });
  }

  // ── Callbacks ──────────────────────────────────────────────

  /// Called after each valid GPS fix so the wiring layer can
  /// delegate to [IncidentResponseProvider.checkArrival].
  void Function(Position position)? onPositionCaptured;

  // ── State ──────────────────────────────────────────────────

  TrackingMode _mode = TrackingMode.off;
  int? _activeIncidentId;
  Position? _lastPosition;
  DateTime? _lastCaptureTime;
  bool _isTracking = false;
  String? _errorMessage;

  /// Current response status sent with every location update.
  /// Defaults to `'available'` and is synced by the wiring layer
  /// whenever [IncidentResponseProvider] changes state.
  String _responseStatus = 'available';

  /// Last captured response status to detect status transitions.
  String _lastCapturedStatus = 'available';

  /// Flag to prevent concurrent batch sends
  bool _isSendingBatch = false;

  /// Subscription to position updates broadcast from the background service isolate.
  StreamSubscription? _bgLocationSub;

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

  /// Whether the device currently has network connectivity.
  bool get hasNetworkConnection => _connectivityService.hasConnection;

  /// Whether there are offline entries waiting to be synced.
  bool get isQueueing => _offlineBox.isNotEmpty;

  /// Update the response status included in location payloads.
  /// Resets the capture filters when status changes (e.g., en_route → on_scene)
  /// to ensure the next periodic capture will happen regardless of time/distance thresholds.
  set responseStatus(String value) {
    final statusChanged = _responseStatus != value;
    debugPrint('📍 LocationTracking: responseStatus setter called');
    debugPrint(
        '📍   Old: $_responseStatus, New: $value, Changed: $statusChanged');
    _responseStatus = value;
    debugPrint('📍   Response status updated to: $value');

    // Reset capture filters on status change to ensure next capture happens
    // This avoids forcing an immediate capture that might use stale GPS data
    if (statusChanged && _isTracking) {
      debugPrint('📍 🔄 Status changed — resetting filters for next capture');
      debugPrint('📍   Last captured: $_lastCapturedStatus, Current: $value');
      _lastCaptureTime = null; // Next capture will bypass time filter
      _lastPosition = null; // Next capture will bypass distance filter
    }
  }

  // ── Public API ─────────────────────────────────────────────

  /// Stream of real-time position updates (for UI/Map).
  /// Uses a small distance filter (2m) for smooth movement on map.
  Stream<Position> get locationStream =>
      _locationService.getPositionStream(distanceFilter: 2);

  /// Capture one immediate GPS point with optional status override.
  /// Used to create a final GPS point with status="resolved" before stopping tracking.
  Future<void> captureImmediatePoint({String? statusOverride}) async {
    if (_lastPosition == null) {
      debugPrint('📍 ⚠️ Cannot capture immediate point: no last position available');
      return;
    }
    
    final status = statusOverride ?? _responseStatus;
    final timestampStr = DateTime.now().toUtc().toIso8601String();
    
    final entry = <String, dynamic>{
      'latitude': _lastPosition!.latitude,
      'longitude': _lastPosition!.longitude,
      'accuracy': _lastPosition!.accuracy,
      'altitude': _lastPosition!.altitude,
      'speed': _lastPosition!.speed,
      'heading': _lastPosition!.heading,
      'tracking_mode': _mode == TrackingMode.active ? 'active' : 'passive',
      'timestamp': timestampStr,
      'response_status': status,
      if (_activeIncidentId != null) 'incident_id': _activeIncidentId,
    };
    
    debugPrint('📍 ✅ Capturing immediate point with status="$status"');
    debugPrint('📍    lat=${_lastPosition!.latitude.toStringAsFixed(6)}, '
        'lng=${_lastPosition!.longitude.toStringAsFixed(6)}');
    
    try {
      await _api.post('/location/update', data: entry);
      debugPrint('📍 Immediate point sent to /location/update');
    } on DioException catch (e) {
      debugPrint('📍 Upload failed (${e.response?.statusCode}): ${e.message}');
      // Save to offline queue for retry
      final jsonEntry = jsonEncode(entry);
      _offlineBox.add(jsonEntry);
      debugPrint('📍 💾 Stored immediate point in offline queue');
      notifyListeners();
    }
  }

  /// Begin passive tracking (every 5 minutes). Call after login.
  ///
  /// **Important:** This will clear `_activeIncidentId`. If you need to
  /// preserve an active incident context, call [startActiveTracking] instead.
  Future<void> startPassiveTracking() async {
    // Guard: Don't switch to passive if we're actively tracking an incident
    // This prevents race conditions on app restart where passive tracking
    // could wipe the restored incident context.
    if (_activeIncidentId != null) {
      debugPrint(
          '📍 ⚠️ startPassiveTracking() blocked — active incident #$_activeIncidentId in progress');
      debugPrint(
          '   Call startActiveTracking() or stopActiveTracking() instead');
      return;
    }

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

    // Start sensor fusion for position smoothing
    _sensorFusion.start();
    _kalmanFilter.reset();
    debugPrint('📍 🔧 Kalman filter reset, sensor fusion started');

    _startCaptureTimer(ApiConstants.passiveTrackingInterval);
    _startFlushTimer();

    // Persist state
    _saveState();

    // Start background service for passive tracking so it survives app close
    try {
      await BackgroundServiceInitializer.startService();
      BackgroundServiceInitializer.setTrackingMode('passive');
      // Pause BG capture — main isolate handles GPS while app is open
      BackgroundServiceInitializer.pauseCapture();
      debugPrint('📍 ✅ Background service started for passive tracking');
    } catch (e) {
      debugPrint('📍 ⚠️ Failed to start background service: $e');
    }

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

    // !! CRITICAL: Ensure background service is running as foreground service
    // This prevents the OS from killing the app when backgrounded
    try {
      await BackgroundServiceInitializer.startService();
      BackgroundServiceInitializer.setTrackingMode('active',
          incidentId: incidentId);
      // Pause BG capture — main isolate handles GPS while app is open
      BackgroundServiceInitializer.pauseCapture();
      BackgroundServiceInitializer.updateNotification(
        'Emergency Response Active',
        'Tracking location for incident #$incidentId',
      );
      debugPrint(
          '📍 ✅ Background foreground service activated for incident #$incidentId');
    } catch (e) {
      debugPrint('📍 ⚠️ Failed to start background service: $e');
    }

    // Start sensor fusion for position smoothing (or ensure it's running)
    if (!_sensorFusion.isRunning) {
      _sensorFusion.start();
    }
    _kalmanFilter.reset();
    debugPrint('📍 🔧 Kalman filter reset for active tracking');

    _startCaptureTimer(ApiConstants.activeTrackingInterval);
    _startFlushTimer();

    // Persist state so it survives app restart
    _saveState();

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

    // Try to flush any remaining offline data for the resolved incident.
    // DON'T delete it — the backend needs the complete trail even after
    // the incident is closed. The flush logic (and the fixed stale-incident
    // check in flushBatch) will send these to the server.
    if (oldIncidentId != null && _offlineBox.isNotEmpty) {
      debugPrint(
          '📍 Incident #$oldIncidentId resolved with ${_offlineBox.length} queued entries — attempting flush');
      flushBatch();
    }

    // Update background service notification to reflect passive mode
    try {
      BackgroundServiceInitializer.setTrackingMode('passive');
      BackgroundServiceInitializer.updateNotification(
        'PDRRMO Dispatch',
        'Location tracking is active',
      );
      debugPrint('📍 Background service updated to passive mode');
    } catch (e) {
      debugPrint('📍 ⚠️ Failed to update background service: $e');
    }

    // Persist cleared state
    _saveState();

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
    _bgLocationSub?.cancel();
    _bgLocationSub = null;
    _mode = TrackingMode.off;
    _isTracking = false;
    _activeIncidentId = null;

    // Stop sensor fusion and reset filters
    _sensorFusion.stop();
    _kalmanFilter.reset();
    debugPrint('📍 🔧 Kalman filter reset, sensor fusion stopped');

    // Stop background service GPS capture too
    try {
      BackgroundServiceInitializer.setTrackingMode('off');
      BackgroundServiceInitializer.stopService();
      debugPrint('📍 Background service stopped on logout');
    } catch (e) {
      debugPrint('📍 ⚠️ Failed to stop background service: $e');
    }

    // Clear persisted state on logout
    _clearState();

    // Persist any unsent fixes to Hive before stopping
    _persistBufferToHive();

    notifyListeners();
  }

  /// Call this when the app enters the foreground.
  /// Pauses the background service's GPS timer to prevent double-pinging.
  void notifyAppForegrounded() {
    if (_mode == TrackingMode.off) return;
    BackgroundServiceInitializer.pauseCapture();
    debugPrint('📍 App foregrounded — background GPS capture paused');
  }

  /// Call this when the app moves to the background or is swiped away.
  /// Resumes the background service's GPS timer to keep tracking alive.
  void notifyAppBackgrounded() {
    if (_mode == TrackingMode.off) return;
    BackgroundServiceInitializer.resumeCapture();
    debugPrint('📍 App backgrounded — background GPS capture resumed');
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

  /// Called by ConnectivityService when connection transitions offline → online.
  /// Triggers an immediate flush of the offline queue instead of waiting
  /// for the 60-second flush timer.
  void _onConnectionRestored() {
    if (_offlineBox.isNotEmpty && _isTracking) {
      debugPrint('📍 🌐 Connection restored — flushing ${_offlineBox.length} queued locations immediately');
      flushBatch();
    }
  }

  /// Ensures capture and flush timers are running. Call this to recover
  /// from situations where timers died (e.g., background service killed
  /// by OS during network outage).
  ///
  /// Safe to call repeatedly — cancels and restarts timers if active.
  void ensureTimersRunning() {
    if (_mode == TrackingMode.off || !_isTracking) return;

    final interval = _mode == TrackingMode.active
        ? ApiConstants.activeTrackingInterval
        : ApiConstants.passiveTrackingInterval;

    final captureWasDead = _captureTimer == null || !_captureTimer!.isActive;
    final flushWasDead = _flushTimer == null || !_flushTimer!.isActive;

    if (captureWasDead || flushWasDead) {
      debugPrint('📍 🔁 Restarting dead timers (capture: $captureWasDead, flush: $flushWasDead)');
      if (captureWasDead) _startCaptureTimer(interval);
      if (flushWasDead) _startFlushTimer();
    }
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

      // ── Jump Detection Filter (RESTORED) ──────────────────────
      // Reject GPS glitches BEFORE attempting to smooth them
      // This prevents Kalman filter from averaging bad data into output
      if (_lastPosition != null && _lastCaptureTime != null) {
        final timeDelta =
            DateTime.now().difference(_lastCaptureTime!).inSeconds;
        final rawDistance = _locationService.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        // Reject if moved > 500m in < 10 seconds (unrealistic for ground vehicles)
        if (timeDelta < 10 && rawDistance > 500) {
          debugPrint(
              '📍 ❌ GPS glitch detected: ${rawDistance.toStringAsFixed(0)}m in ${timeDelta}s is impossible — SKIPPING');
          return; // Don't even try to smooth this
        }
      }

      // ── Kalman Filter Smoothing ───────────────────────────────
      // Get sensor fusion displacement estimate (if available)
      double? sensorDisplacementLat;
      double? sensorDisplacementLng;

      if (_sensorFusion.isRunning && _lastPosition != null) {
        final displacement =
            _sensorFusion.getDisplacementDegrees(_lastPosition!.latitude);
        sensorDisplacementLat = displacement.latDelta;
        sensorDisplacementLng = displacement.lngDelta;

        if (_sensorFusion.totalDisplacement > 0.1) {
          debugPrint(
              '📍 🔧 Sensor fusion: ${_sensorFusion.totalDisplacement.toStringAsFixed(1)}m displacement estimated');
        }

        // Reset sensor fusion displacement after using it
        _sensorFusion.resetDisplacement();
      }

      // Apply Kalman filter to smooth the GPS position
      final timestamp = DateTime.now();
      final kalmanResult = _kalmanFilter.update(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: timestamp,
        sensorDisplacementLat: sensorDisplacementLat,
        sensorDisplacementLng: sensorDisplacementLng,
      );

      // Log Kalman filter results
      final rawLat = position.latitude;
      final rawLng = position.longitude;
      final smoothedLat = kalmanResult.smoothedLatitude;
      final smoothedLng = kalmanResult.smoothedLongitude;

      if (kalmanResult.wasOutlier) {
        debugPrint(
            '📍 🔧 Kalman OUTLIER detected: residual=${kalmanResult.residualMeters.toStringAsFixed(1)}m, confidence=${(kalmanResult.confidence * 100).toStringAsFixed(0)}%');
        debugPrint(
            '📍    Raw: ($rawLat, $rawLng) → Smoothed: ($smoothedLat, $smoothedLng)');
      } else if (kalmanResult.residualMeters > 5) {
        debugPrint(
            '📍 🔧 Kalman smoothed: residual=${kalmanResult.residualMeters.toStringAsFixed(1)}m');
      }

      // ── Jitter Filter ─────────────────────────────────────────
      // Skip if barely moved (using smoothed position)
      if (_lastPosition != null && _lastCaptureTime != null) {
        final timeDelta = timestamp.difference(_lastCaptureTime!).inSeconds;
        final distance = _locationService.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          smoothedLat,
          smoothedLng,
        );

        // Skip only if BOTH time < threshold AND distance < threshold (jitter scenario)
        if (timeDelta < ApiConstants.minTimeDeltaSeconds &&
            distance < ApiConstants.minDistanceMeters) {
          debugPrint(
              '📍 ⏭️  Position skipped (jitter filter): ${timeDelta}s < ${ApiConstants.minTimeDeltaSeconds}s AND ${distance.toStringAsFixed(1)}m < ${ApiConstants.minDistanceMeters}m');
          return;
        }
      }

      // Update state with smoothed position (create a mock Position for callback)
      _lastPosition =
          position; // Keep raw for next iteration's distance calc baseline
      _lastCaptureTime = timestamp;
      _lastCapturedStatus = _responseStatus;

      // Notify listeners with raw position (for auto-arrival detection)
      onPositionCaptured?.call(position);

      // Use current system time for timestamp (more reliable than GPS timestamp)
      final timestampStr = timestamp.toUtc().toIso8601String();

      // Debug: Show both UTC and local time for comparison
      final localTime = DateTime.now().toIso8601String();
      final utcTime = timestampStr;
      debugPrint('📍 🕐 Timestamp DEBUG:');
      debugPrint('   Local Time: $localTime');
      debugPrint('   UTC Time:   $utcTime');
      debugPrint('   Timezone offset: ${DateTime.now().timeZoneOffset}');
      if (!utcTime.endsWith('Z')) {
        debugPrint('   ⚠️ WARNING: UTC timestamp does not end with Z!');
      }

      // TEST FIX: Send RAW coordinates to backend (smoothed may fail validation)
      // Keep Kalman filter active for logging/debugging but don't send smoothed coords
      final entry = <String, dynamic>{
        'latitude': position.latitude, // RAW GPS (backend expects this)
        'longitude': position.longitude, // RAW GPS (backend expects this)
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'tracking_mode': _mode == TrackingMode.active ? 'active' : 'passive',
        'timestamp': timestampStr,
        'response_status': _responseStatus,
      };

      // Log comparison of raw vs smoothed for debugging
      if (kalmanResult.residualMeters > 1.0) {
        final rawToSmoothedDist = _locationService.distanceBetween(
          position.latitude,
          position.longitude,
          smoothedLat,
          smoothedLng,
        );
        debugPrint(
            '📍 📊 Sending RAW (backend), Kalman smoothed by ${rawToSmoothedDist.toStringAsFixed(1)}m');
      }
      if (_activeIncidentId != null) {
        entry['incident_id'] = _activeIncidentId;
      }

      debugPrint('📍 ✅ Captured: lat=${position.latitude.toStringAsFixed(6)}, '
          'lng=${position.longitude.toStringAsFixed(6)}, '
          'acc=${position.accuracy.toStringAsFixed(1)}m, '
          'timestamp=$timestampStr');
      debugPrint(
          '📍    response_status: $_responseStatus, incident_id: $_activeIncidentId');

      // Try to send immediately
      try {
        await _api.post(
          '/location/update',
          data: entry,
        );
        debugPrint('📍 Location sent to /location/update');

        // Smart Sync: If upload succeeds, it means we have internet.
        // Flush any offline items immediately.
        final hasBgPending =
            await BackgroundServiceInitializer.hasFailedLocationQueue();
        if (_offlineBox.isNotEmpty || hasBgPending) {
          debugPrint('📍 Online detected — flushing offline queue...');
          flushBatch();
        }
      } on DioException catch (e) {
        debugPrint(
            '📍 Upload failed (${e.response?.statusCode}): ${e.message}');
        // Save to offline queue for retry
        final jsonEntry = jsonEncode(entry);
        _offlineBox.add(jsonEntry);
        debugPrint(
            '📍 💾 Stored in offline queue: ${jsonEntry.substring(0, 100)}...');
        debugPrint('   Queue size: ${_offlineBox.length} entries');
        notifyListeners(); // Update UI count
      } catch (e) {
        debugPrint('📍 Upload error: $e');
        final jsonEntry = jsonEncode(entry);
        _offlineBox.add(jsonEntry);
        debugPrint('📍 💾 Stored in offline queue due to error');
        notifyListeners(); // Update UI count
      }
    } catch (e) {
      debugPrint('📍 ⚠️ GPS capture failed: $e');
      debugPrint(
          '   This may indicate GPS signal issues or permission problems');
    }
  }

  // ── Private — Flush / Upload ───────────────────────────────

  /// Deduplicate offline queue entries by timestamp.
  /// Normalizes timestamps to second precision to catch millisecond duplicates.
  List<Map<String, dynamic>> _deduplicateEntries(
      List<Map<String, dynamic>> entries) {
    final seen = <String>{};
    final deduplicated = <Map<String, dynamic>>[];

    for (final entry in entries) {
      final timestamp = entry['timestamp'] as String?;
      if (timestamp == null) {
        // Skip entries without timestamp (shouldn't happen, but be safe)
        debugPrint('📍 ⚠️ Skipping entry without timestamp');
        continue;
      }

      // Normalize to second precision (ignore milliseconds)
      // Timestamps are ISO8601: "2026-03-03T10:30:00.123Z" -> "2026-03-03T10:30:00"
      final normalizedTimestamp = timestamp.split('.').first;

      if (seen.contains(normalizedTimestamp)) {
        debugPrint('📍 🔄 Skipping duplicate cached point: $timestamp');
        continue;
      }

      seen.add(normalizedTimestamp);
      deduplicated.add(entry);
    }

    final removed = entries.length - deduplicated.length;
    if (removed > 0) {
      debugPrint(
          '📍 Deduplicated: ${entries.length} → ${deduplicated.length} points ($removed duplicates removed)');
    }

    return deduplicated;
  }

  /// Split a list into chunks of specified size.
  List<List<T>> _splitIntoChunks<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, min(i + chunkSize, list.length)));
    }
    return chunks;
  }

  /// Imports failed background-service payloads into the primary offline box.
  Future<int> _importBackgroundOfflineQueue() async {
    final imported =
        await BackgroundServiceInitializer.drainFailedLocationQueue();
    if (imported.isEmpty) {
      return 0;
    }

    int count = 0;
    for (final entry in imported) {
      try {
        await _offlineBox.add(jsonEncode(entry));
        count++;
      } catch (e) {
        debugPrint('📍 ⚠️ Failed to import background offline entry: $e');
      }
    }

    if (count > 0) {
      debugPrint('📍 Imported $count background offline locations into queue');
    }
    return count;
  }

  /// Retry sending any failed location updates from the offline queue.
  /// Uses the batch API endpoint for efficiency and handles deduplication.
  Future<void> flushBatch() async {
    // Prevent concurrent batch sends
    if (_isSendingBatch) {
      debugPrint('📍 Batch send already in progress, skipping...');
      return;
    }

    _isSendingBatch = true;

    try {
      await _importBackgroundOfflineQueue();

      if (_offlineBox.isEmpty) {
        return;
      }

      debugPrint('📍 Flushing ${_offlineBox.length} offline location updates');

      // Collect all valid entries
      final allEntries = <Map<String, dynamic>>[];
      final indicesToDelete = <int>[];

      for (int i = 0; i < _offlineBox.length; i++) {
        try {
          final raw = _offlineBox.getAt(i);
          if (raw == null) {
            indicesToDelete.add(i); // Remove corrupted/null entries
            continue;
          }

          final entry = jsonDecode(raw) as Map<String, dynamic>;

          // Migrate old 'captured_at' to 'timestamp' for backward compatibility
          if (entry.containsKey('captured_at') &&
              !entry.containsKey('timestamp')) {
            entry['timestamp'] = entry.remove('captured_at');
          }
          
          // Skip entries only if we're currently tracking a DIFFERENT incident.
          // Don't prune data from resolved incidents — backend needs the
          // complete historical trail even after the incident is closed.
          final entryIncidentId = entry['incident_id'] as int?;
          if (entryIncidentId != null &&
              _activeIncidentId != null &&
              entryIncidentId != _activeIncidentId) {
            debugPrint(
                '📍 Skipping stale ping for incident #$entryIncidentId (current: #$_activeIncidentId)');
            indicesToDelete.add(i);
            continue;
          }

          allEntries.add(entry);
        } catch (e) {
          debugPrint('📍 Error parsing offline entry [index $i]: $e');
          indicesToDelete.add(i); // Remove malformed entries
        }
      }

      // Remove invalid entries first
      for (final idx in indicesToDelete.reversed) {
        await _offlineBox.deleteAt(idx);
      }

      if (allEntries.isEmpty) {
        debugPrint('📍 No valid entries to send after filtering');
        notifyListeners();
        return;
      }

      // Deduplicate entries by timestamp before sending
      final deduplicated = _deduplicateEntries(allEntries);

      if (deduplicated.isEmpty) {
        debugPrint('📍 All entries were duplicates, clearing queue');
        await _offlineBox.clear();
        notifyListeners();
        return;
      }

      // ── Path Simplification ───────────────────────────────────
      // Apply velocity-based outlier removal and Douglas-Peucker simplification
      // This reduces data sent to server and ensures clean trails
      final beforeSimplification = deduplicated.length;

      // Step 1: Remove velocity-based outliers (superhuman speed)
      final noOutliers = PathSimplifier.removeVelocityOutliers(
        deduplicated,
        maxSpeedMs: ApiConstants.maxReasonableSpeedMs,
      );

      debugPrint(
          '📍 🔍 Outlier removal: $beforeSimplification → ${noOutliers.length} points '
          '(${beforeSimplification - noOutliers.length} velocity outliers removed)');

      // Step 2: Preserve full-fidelity trails for active incidents.
      final hasActiveTrailData = noOutliers.any((entry) {
        final mode = entry['tracking_mode']?.toString().toLowerCase();
        return mode == 'active' || entry['incident_id'] != null;
      });

      // Step 3: Apply Douglas-Peucker simplification only for passive trails.
      List<Map<String, dynamic>> simplified;
      if (!hasActiveTrailData && noOutliers.length >= 3) {
        final points = PathSimplifier.toLatLngList(noOutliers);
        final simplifiedPoints = PathSimplifier.simplifyDouglasPeucker(
          points,
          epsilonMeters: ApiConstants.pathSimplificationEpsilon,
        );
        simplified =
            PathSimplifier.toLocationMaps(simplifiedPoints, noOutliers);
      } else {
        if (hasActiveTrailData) {
          debugPrint(
              '📍 Active/incident trail detected — skipping path simplification');
        }
        simplified = noOutliers;
      }

      final afterSimplification = simplified.length;
      final totalReduction = beforeSimplification - afterSimplification;
      final reductionPercent =
          (totalReduction / beforeSimplification * 100).toStringAsFixed(1);

      if (totalReduction > 0) {
        debugPrint(
            '📍 📐 Path simplified: $beforeSimplification → $afterSimplification points '
            '($totalReduction removed = $reductionPercent%)');

        // Warn if reduction is too aggressive
        if (totalReduction / beforeSimplification > 0.5) {
          debugPrint(
              '📍 ⚠️ WARNING: >50% data reduction! Trails may look incomplete in MIS.');
        }
      }

      // Split into chunks to avoid overwhelming the server
      final chunks = _splitIntoChunks(simplified, ApiConstants.batchChunkSize);
      debugPrint(
          '📍 Sending ${simplified.length} locations in ${chunks.length} batch(es)');

      // Debug: Show sample of what's being sent
      if (simplified.isNotEmpty) {
        final sample = simplified.first;
        debugPrint('📍 📤 BATCH SAMPLE (first entry):');
        debugPrint('   timestamp: ${sample['timestamp']}');
        debugPrint('   response_status: ${sample['response_status']}');
        debugPrint('   incident_id: ${sample['incident_id']}');
        debugPrint('   lat/lng: ${sample['latitude']}, ${sample['longitude']}');
        debugPrint('   tracking_mode: ${sample['tracking_mode']}');
        final ts = sample['timestamp'] as String?;
        if (ts != null && !ts.endsWith('Z')) {
          debugPrint('   ⚠️ WARNING: Batch timestamp does not end with Z!');
        }
      }

      int totalSent = 0;
      int totalServerDuplicates = 0;
      int successfulChunks = 0;

      for (int chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
        final chunk = chunks[chunkIndex];

        try {
          final response = await _api.post(
            ApiConstants.locationBatchUpdate,
            data: {'locations': chunk},
          );

          // Parse the batch response
          final batchResponse = BatchUpdateResponse.fromJson(response.data);

          if (batchResponse.success) {
            totalSent += batchResponse.data.savedCount;
            totalServerDuplicates += batchResponse.data.duplicatesSkipped;
            successfulChunks++;

            debugPrint('📍 ✅ Batch ${chunkIndex + 1}/${chunks.length}: '
                '${batchResponse.data.savedCount} saved, '
                '${batchResponse.data.duplicatesSkipped} duplicates skipped by server');
          } else {
            debugPrint(
                '📍 ❌ Batch ${chunkIndex + 1} failed: ${batchResponse.message}');
            // Don't clear queue on failure, will retry next time
            break;
          }

          // Small delay between chunks to avoid overwhelming server
          if (chunks.length > 1 && chunkIndex < chunks.length - 1) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } on DioException catch (e) {
          debugPrint(
              '📍 Batch upload failed (${e.response?.statusCode}): ${e.message}');

          // If it's a permanent error (e.g. 400, 422), clear the problematic chunk
          if (e.response != null &&
              (e.response!.statusCode! >= 400 &&
                  e.response!.statusCode! < 500)) {
            debugPrint('📍 Discarding invalid batch chunk [${chunkIndex + 1}]');
            successfulChunks++; // Count as "processed" to clear from queue
          } else {
            // Network/Server error — stop trying for now
            break;
          }
        } catch (e) {
          debugPrint('📍 Batch upload error: $e');
          break;
        }
      }

      // Clear the offline queue if all chunks were processed successfully
      if (successfulChunks == chunks.length) {
        await _offlineBox.clear();
        debugPrint('📍 ✅ Batch update complete: $totalSent sent to server');

        // Check for high duplicate rate and log warning
        final totalInBatch = totalSent + totalServerDuplicates;
        if (totalInBatch > 0) {
          final duplicateRate = totalServerDuplicates / totalInBatch;
          if (duplicateRate > 0.3) {
            debugPrint(
                '📍 ⚠️ WARNING: High duplicate rate (${(duplicateRate * 100).toStringAsFixed(1)}%). '
                'Consider increasing MIN_TIME_DELTA or MIN_DISTANCE thresholds.');
          }
        }
      } else {
        debugPrint(
            '📍 ⚠️ Partial batch send: $successfulChunks/${chunks.length} chunks processed');
      }
    } finally {
      _isSendingBatch = false;
      notifyListeners();
    }
  }

  /// No-op: buffer is not used anymore, only offline queue remains.
  void _persistBufferToHive() {}

  // ── State Persistence ──────────────────────────────────────

  /// Restore tracking state from SharedPreferences.
  /// This ensures active tracking survives app restarts.
  Future<void> _restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_keyTrackingMode);
      final savedIncidentId = prefs.getInt(_keyActiveIncidentId);

      if (savedMode == 'active' && savedIncidentId != null) {
        _activeIncidentId = savedIncidentId;
        _mode = TrackingMode.active;
        _isTracking = true; // tracking was in progress before app closed
        debugPrint(
            '📍 State restored: active tracking for incident #$savedIncidentId');
      } else if (savedMode == 'passive') {
        _mode = TrackingMode.passive;
        _isTracking = true; // tracking was in progress before app closed
        debugPrint('📍 State restored: passive tracking');
      } else {
        debugPrint('📍 No saved tracking state found');
      }
    } catch (e) {
      debugPrint('📍 ⚠️ Failed to restore tracking state: $e');
    } finally {
      _initialized.complete();
    }
  }

  /// Persist current tracking state to SharedPreferences.
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_mode == TrackingMode.active && _activeIncidentId != null) {
        await prefs.setString(_keyTrackingMode, 'active');
        await prefs.setInt(_keyActiveIncidentId, _activeIncidentId!);
        debugPrint(
            '💾 Location state saved: active, incident #$_activeIncidentId');
      } else if (_mode == TrackingMode.passive) {
        await prefs.setString(_keyTrackingMode, 'passive');
        await prefs.remove(_keyActiveIncidentId);
        debugPrint('💾 Location state saved: passive');
      } else {
        await _clearState();
      }
    } catch (e) {
      debugPrint('📍 ⚠️ Failed to save tracking state: $e');
    }
  }

  /// Clear persisted tracking state.
  Future<void> _clearState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyTrackingMode);
      await prefs.remove(_keyActiveIncidentId);
      debugPrint('💾 Location state cleared');
    } catch (e) {
      debugPrint('📍 ⚠️ Failed to clear tracking state: $e');
    }
  }

  // ── Dispose ────────────────────────────────────────────────

  @override
  void dispose() {
    _captureTimer?.cancel();
    _flushTimer?.cancel();
    _connectivityService.removeOnConnectionRestored(_onConnectionRestored);
    _persistBufferToHive();
    super.dispose();
  }
}
