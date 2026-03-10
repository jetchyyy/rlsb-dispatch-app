import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../constants/api_constants.dart';

/// WorkManager service for background tasks that run even when app is killed.
/// 
/// This complements the foreground service by ensuring offline location data
/// gets synced periodically, and tracking state is maintained across app restarts.
class WorkManagerService {
  static const String _locationSyncTask = 'location-sync-task';
  static const String _trackingHealthCheckTask = 'tracking-health-check';

  /// Initialize WorkManager (call once in main())
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      debugPrint('📍 WorkManager initialized');
    } catch (e) {
      debugPrint('📍 ⚠️ Failed to initialize WorkManager: $e');
    }
  }

  /// Register periodic location sync task.
  /// This runs every 15 minutes to sync offline queue to server.
  static Future<void> registerLocationSync() async {
    try {
      await Workmanager().registerPeriodicTask(
        _locationSyncTask,
        _locationSyncTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
      debugPrint('📍 ✅ Location sync task registered (every 15 min)');
    } catch (e) {
      debugPrint('📍 ⚠️ Failed to register location sync task: $e');
    }
  }

  /// Register tracking health check task.
  /// This runs every 30 minutes to ensure tracking is still active during incidents.
  static Future<void> registerTrackingHealthCheck() async {
    try {
      await Workmanager().registerPeriodicTask(
        _trackingHealthCheckTask,
        _trackingHealthCheckTask,
        frequency: const Duration(minutes: 30),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
      debugPrint('📍 ✅ Tracking health check registered (every 30 min)');
    } catch (e) {
      debugPrint('📍 ⚠️ Failed to register health check task: $e');
    }
  }

  /// Cancel all background tasks (call on logout)
  static Future<void> cancelAll() async {
    try {
      await Workmanager().cancelAll();
      debugPrint('📍 All WorkManager tasks cancelled');
    } catch (e) {
      debugPrint('📍 ⚠️ Failed to cancel WorkManager tasks: $e');
    }
  }
}

/// WorkManager callback dispatcher - runs in background isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('📍 WorkManager task started: $task');

    try {
      switch (task) {
        case 'location-sync-task':
          // Sync offline location data to server
          await _syncOfflineLocations();
          break;

        case 'tracking-health-check':
          // Check if tracking should still be active
          await _checkTrackingHealth();
          break;

        default:
          debugPrint('📍 Unknown WorkManager task: $task');
      }

      return Future.value(true);
    } catch (e) {
      debugPrint('📍 ⚠️ WorkManager task failed: $task - $e');
      return Future.value(false);
    }
  });
}

/// Sync offline location queue to server.
/// Runs in a background isolate — cannot access providers directly.
/// Instead, checks the Hive queue and sends a notification to wake the app.
Future<void> _syncOfflineLocations() async {
  try {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(ApiConstants.locationQueueBox);
    final queueSize = box.length;
    debugPrint('📍 WorkManager: Location sync — queue has $queueSize entries');

    if (queueSize > 0) {
      // Send a notification to prompt the user to open the app,
      // which will trigger the provider's flush logic.
      final flnp = FlutterLocalNotificationsPlugin();
      await flnp.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await flnp.show(
        9999,
        'PDRRMO Dispatch',
        '$queueSize location updates pending — open app to sync',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'location_sync_channel',
            'Location Sync',
            channelDescription: 'Alerts when offline location data needs syncing',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
      debugPrint('📍 WorkManager: Notification sent for $queueSize pending locations');
    }

    await box.close();
  } catch (e) {
    debugPrint('📍 ⚠️ Location sync failed: $e');
  }
}

/// Check if tracking should still be active based on persisted state.
/// Alerts responder if tracking appears to have stopped unexpectedly.
Future<void> _checkTrackingHealth() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('loc_tracking_mode');
    final incidentId = prefs.getInt('loc_active_incident_id');

    debugPrint('📍 WorkManager: Health check — mode=$mode, incident=$incidentId');

    if (mode == 'active' && incidentId != null) {
      // Active tracking should be running — send a reminder notification
      // in case the main app was killed and tracking stopped.
      final flnp = FlutterLocalNotificationsPlugin();
      await flnp.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await flnp.show(
        9998,
        'PDRRMO Dispatch — Tracking Check',
        'Active tracking for incident #$incidentId — open app to verify',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'tracking_health_channel',
            'Tracking Health',
            channelDescription: 'Alerts when active tracking may have stopped',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  } catch (e) {
    debugPrint('📍 ⚠️ Health check failed: $e');
  }
}
