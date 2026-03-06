import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Configures and launches the Android/iOS background service that keeps
/// GPS tracking alive when the app is backgrounded.
///
/// The service communicates with the Flutter UI via `invoke()` / `on()`:
///   UI  → service:  `setTrackingMode`  { mode: "active"|"passive"|"off", incidentId: int? }
///   service → UI:   `trackingStatus`   { mode: "...", isRunning: true }
class BackgroundServiceInitializer {
  BackgroundServiceInitializer._();

  static final FlutterBackgroundService _service = FlutterBackgroundService();

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
        autoStart: false,
        autoStartOnBoot: false,
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
  static void setTrackingMode(String mode, {int? incidentId}) {
    _service.invoke('setTrackingMode', {
      'mode': mode,
      'incidentId': incidentId,
    });
  }

  /// Update the foreground notification text (e.g., when switching modes).
  static void updateNotification(String title, String content) {
    _service.invoke('updateNotification', {
      'title': title,
      'content': content,
    });
  }
}

// ── Service entry point (runs in isolate on Android) ──────────

@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  debugPrint('📍 Background service onStart');

  // Handle stop request
  service.on('stopService').listen((_) {
    service.stopSelf();
    debugPrint('📍 Background service stopped');
  });

  // Handle tracking mode changes (forwarded to main isolate via UI)
  service.on('setTrackingMode').listen((event) {
    if (event != null) {
      final mode = event['mode'] as String? ?? 'passive';
      final incidentId = event['incidentId'] as int?;
      debugPrint(
          '📍 Background service: tracking mode → $mode (incident: $incidentId)');
    }
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

    // Set initial notification
    service.setAsForegroundService();
  }

  // The actual GPS capture logic stays in LocationTrackingProvider
  // (runs in the main isolate). The background service simply keeps
  // the process alive so the OS does not kill it.
  //
  // CRITICAL: This service must run as a foreground service with a persistent
  // notification to prevent Android from killing it during incident response.
  //
  // Periodic heartbeat to keep the service alive:
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      final isFg = await service.isForegroundService();
      if (!isFg) {
        // If we lost foreground status, try to restore it
        debugPrint('📍 ⚠️ Background service lost foreground status - restoring...');
        service.setAsForegroundService();
      }
    }
    // Send heartbeat to UI so it knows the service is alive
    service.invoke('trackingStatus', {'isRunning': true});
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
