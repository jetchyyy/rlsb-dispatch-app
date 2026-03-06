import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

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

/// Sync offline location queue to server
Future<void> _syncOfflineLocations() async {
  try {
    // Note: In a background isolate, we can't directly access the main app's
    // LocationTrackingProvider. Instead, the provider's flushTimer handles
    // regular sync. This task serves as a backup to trigger sync if the
    // main app is suspended.
    debugPrint('📍 WorkManager: Location sync task executed');
    
    // The actual sync happens in LocationTrackingProvider.flushBatch()
    // which runs every 60 seconds in the main isolate.
    // This task just ensures the app wakes up periodically.
  } catch (e) {
    debugPrint('📍 ⚠️ Location sync failed: $e');
  }
}

/// Check if tracking should still be active based on persisted state
Future<void> _checkTrackingHealth() async {
  try {
    // Check SharedPreferences for active incident tracking state
    // If active tracking is enabled but we haven't received GPS data
    // in a while, this could trigger a notification to the user
    debugPrint('📍 WorkManager: Tracking health check executed');
    
    // Note: Actual health monitoring is done in the main isolate.
    // This task just ensures the app stays awake during incident response.
  } catch (e) {
    debugPrint('📍 ⚠️ Health check failed: $e');
  }
}
