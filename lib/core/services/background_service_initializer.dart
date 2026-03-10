import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configures and launches the Android/iOS background service that keeps
/// GPS tracking alive when the app is backgrounded or killed.
///
/// The service communicates with the Flutter UI via `invoke()` / `on()`:
///   UI  → service:  `setTrackingMode`  { mode: "active"|"passive"|"off", incidentId: int? }
///   UI  → service:  `pauseCapture`     { } — issued when app is foregrounded to avoid double-pinging
///   UI  → service:  `resumeCapture`    { } — issued when app moves to background
///   service → UI:   `trackingStatus`   { mode: "...", isRunning: true }
class BackgroundServiceInitializer {
  BackgroundServiceInitializer._();

  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static const String _failedLocationQueueKey = 'bg_failed_location_queue';
  static const int _maxFailedLocationQueueSize = 3000;

  /// Initialize and configure the background service.
  /// Call once in `main()` before `runApp()`.
  static Future<void> initialize() async {
    // ── Notification channel (Android foreground service) ──────
    const androidChannel = AndroidNotificationChannel(
      'location_tracking_channel',
      'Location Tracking',
      description: 'Keeps GPS tracking active for dispatch response time.',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // ── Configure the service ─────────────────────────────────
    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: true,
        autoStartOnBoot: true,
        notificationChannelId: 'location_tracking_channel',
        initialNotificationTitle: 'PDRRMO Dispatch',
        initialNotificationContent: 'Location tracking is active',
        foregroundServiceNotificationId: 8888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
    );

    debugPrint('📍 Background service initialized');
  }

  /// Start the background service (call after login + permission grant).
  static Future<void> startService() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
      debugPrint('📍 Background service started');
    }
  }

  /// Stop the background service (call on logout).
  static Future<void> stopService() async {
    _service.invoke('stopService');
    debugPrint('📍 Background service stop requested');
  }

  /// Tell the background service which tracking mode to use.
  /// mode: "active" | "passive" | "off"
  static void setTrackingMode(String mode, {int? incidentId}) {
    _service.invoke('setTrackingMode', {
      'mode': mode,
      'incidentId': incidentId,
    });
  }

  /// Pause GPS capture in the background service (call when app comes to foreground).
  /// This prevents double-pinging while the main isolate's LocationTrackingProvider is active.
  static void pauseCapture() {
    _service.invoke('pauseCapture');
  }

  /// Resume GPS capture in the background service (call when app goes to background).
  /// The background service takes over GPS capture while the main isolate is suspended.
  static void resumeCapture() {
    _service.invoke('resumeCapture');
  }

  /// Update the foreground notification text (e.g., when switching modes).
  static void updateNotification(String title, String content) {
    _service.invoke('updateNotification', {
      'title': title,
      'content': content,
    });
  }

  /// Returns true when background service has unsent location payloads.
  static Future<bool> hasFailedLocationQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queued = prefs.getStringList(_failedLocationQueueKey) ?? const [];
    return queued.isNotEmpty;
  }

  /// Moves queued background payloads into the caller and clears stored values.
  static Future<List<Map<String, dynamic>>> drainFailedLocationQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queued = prefs.getStringList(_failedLocationQueueKey) ?? const [];
    if (queued.isEmpty) {
      return const [];
    }

    final parsed = <Map<String, dynamic>>[];
    for (final raw in queued) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          parsed.add(decoded);
        }
      } catch (_) {
        // Ignore malformed entries and continue draining the queue.
      }
    }

    await prefs.remove(_failedLocationQueueKey);
    return parsed;
  }
}

// ── Service entry point (runs in its own isolate on Android) ────

@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  debugPrint('📍 Background service onStart');

  // ── State ────────────────────────────────────────────────────
  String _trackingMode = 'passive';
  int? _activeIncidentId;
  Timer? _captureTimer;
  bool _isPaused = false; // True when main isolate is handling capture

  // ── Helpers ──────────────────────────────────────────────────

  /// Read the auth token from SharedPreferences (set by the main isolate).
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Queues failed background payloads so they can be batch-uploaded later.
  Future<void> _queueFailedLocationPayload(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queued = List<String>.from(prefs.getStringList(
              BackgroundServiceInitializer._failedLocationQueueKey) ??
          const []);
      queued.add(jsonEncode(payload));

      if (queued.length >
          BackgroundServiceInitializer._maxFailedLocationQueueSize) {
        final overflow = queued.length -
            BackgroundServiceInitializer._maxFailedLocationQueueSize;
        queued.removeRange(0, overflow);
      }

      await prefs.setStringList(
        BackgroundServiceInitializer._failedLocationQueueKey,
        queued,
      );
      debugPrint(
          '📍 [BG] Queued failed location payload (pending: ${queued.length})');
    } catch (e) {
      debugPrint('📍 [BG] Failed to queue background payload: $e');
    }
  }

  /// POST a location update to the API.
  Future<void> _sendLocation(Position pos, String token) async {
    final payload = <String, dynamic>{
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
      'altitude': pos.altitude,
      'speed': pos.speed,
      'heading': pos.heading,
      'tracking_mode': _trackingMode,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'response_status': 'available',
    };

    if (_activeIncidentId != null) {
      payload['incident_id'] = _activeIncidentId;
    }

    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://sdnpdrrmo.inno.ph/api',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      await dio.post('/location/update', data: payload);
      debugPrint(
          '📍 [BG] Location sent: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}');
    } catch (e) {
      debugPrint('📍 [BG] Location send failed: $e');
      await _queueFailedLocationPayload(payload);
    }
  }

  /// Capture position and send to API.
  Future<void> _captureAndSend() async {
    if (_isPaused) {
      debugPrint('📍 [BG] Capture paused (main isolate is active)');
      return;
    }

    if (_trackingMode == 'off') {
      debugPrint('📍 [BG] Tracking is off, skipping capture');
      return;
    }

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        debugPrint('📍 [BG] No auth token — skipping GPS capture');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      await _sendLocation(position, token);

      // Notify the main isolate about the captured position so that
      // LocationTrackingProvider.lastPosition stays in sync for the
      // dispatcher tracker screen.
      service.invoke('locationUpdate', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': position.timestamp.toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('📍 [BG] GPS capture failed: $e');
    }
  }

  /// (Re)start the capture timer with the given interval.
  void _restartTimer(Duration interval) {
    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(interval, (_) => _captureAndSend());
    debugPrint('📍 [BG] Capture timer set to ${interval.inSeconds}s intervals');
  }

  // ── Event listeners ──────────────────────────────────────────

  // Handle stop request
  service.on('stopService').listen((_) {
    _captureTimer?.cancel();
    service.stopSelf();
    debugPrint('📍 Background service stopped');
  });

  // Handle tracking mode changes from the main isolate
  service.on('setTrackingMode').listen((event) {
    if (event == null) return;
    final mode = event['mode'] as String? ?? 'passive';
    final incidentId = event['incidentId'] as int?;

    _trackingMode = mode;
    _activeIncidentId = incidentId;
    debugPrint('📍 [BG] Tracking mode → $mode (incident: $incidentId)');

    if (mode == 'off') {
      _captureTimer?.cancel();
      _captureTimer = null;
    } else if (mode == 'active') {
      _restartTimer(const Duration(seconds: 5));
    } else {
      // passive
      _restartTimer(const Duration(seconds: 10));
    }
  });

  // Main isolate is now in foreground — pause background captures
  service.on('pauseCapture').listen((_) {
    _isPaused = true;
    debugPrint('📍 [BG] Capture PAUSED — main isolate handling GPS');
  });

  // Main isolate moved to background — background service resumes capture
  service.on('resumeCapture').listen((_) {
    _isPaused = false;
    debugPrint('📍 [BG] Capture RESUMED — main isolate suspended');
  });

  // Handle notification updates
  if (service is AndroidServiceInstance) {
    service.on('updateNotification').listen((event) {
      if (event != null) {
        service.setForegroundNotificationInfo(
          title: event['title'] as String? ?? 'PDRRMO Dispatch',
          content: event['content'] as String? ?? 'Location tracking is active',
        );
      }
    });

    // Set initial notification and foreground status
    service.setAsForegroundService();
  }

  // The actual GPS capture logic stays in LocationTrackingProvider
  // (runs in the main isolate). The background service simply keeps
  // the process alive so the OS does not kill it.
  //
  // CRITICAL: This service must run as a foreground service with a persistent
  // notification to prevent Android from killing it during incident response.
  //
  // Periodic heartbeat to keep the service alive and verify timer health:
  // ── Startup: begin passive tracking by default ───────────────
  // Load tracking mode from SharedPreferences (persisted by main isolate)
  final prefs = await SharedPreferences.getInstance();
  final savedMode = prefs.getString('loc_tracking_mode') ?? 'passive';
  final savedIncidentId = prefs.getInt('loc_active_incident_id');

  _trackingMode = savedMode;
  _activeIncidentId = savedIncidentId;

  if (savedMode != 'off') {
    final interval = savedMode == 'active'
        ? const Duration(seconds: 5)
        : const Duration(seconds: 10);
    _restartTimer(interval);
    debugPrint(
        '📍 [BG] Started with saved mode "$savedMode" (${interval.inSeconds}s interval)');
  }

  // ── Heartbeat — keeps the foreground service alive ───────────
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      final isFg = await service.isForegroundService();
      if (!isFg) {
        debugPrint(
            '📍 ⚠️ Background service lost foreground status - restoring...');
        service.setAsForegroundService();
      }
    }
    // Send heartbeat to UI so it knows the service is alive
    service.invoke('trackingStatus', {'isRunning': true});
    // Ask UI to verify GPS timers are still running
    service.invoke('checkTimers');
  });
  
  // Additional watchdog: Ensure the service stays alive when screen is off
  // This prevents Android's aggressive battery optimization from killing tracking
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      final isFg = await service.isForegroundService();
      if (isFg) {
        // Service is alive and well, just log periodically
        if (DateTime.now().second % 60 == 0) {
          debugPrint('📍 ✅ Background service heartbeat - tracking active');
        }
      }
    }
  });
}

// iOS background fetch handler
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
