import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Wraps OneSignal for push notification setup and handling.
class NotificationService {
  /// Replace with your actual OneSignal App ID.
  static const String _oneSignalAppId = 'YOUR_ONESIGNAL_APP_ID';

  /// Initializes OneSignal with required configuration.
  Future<void> initialize() async {
    // Initialize OneSignal
    OneSignal.initialize(_oneSignalAppId);

    // Request push notification permission
    OneSignal.Notifications.requestPermission(true);

    // Log permission status in debug mode
    if (kDebugMode) {
      OneSignal.Notifications.addPermissionObserver((permission) {
        debugPrint('OneSignal permission changed: $permission');
      });
    }

    // Listen for notification clicks
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data != null) {
        _handleNotificationData(data);
      }
    });

    // Listen for foreground notifications
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      // Allow the notification to display
      event.notification.display();
    });
  }

  /// Sets the external user ID for targeting (e.g. responder ID).
  Future<void> setExternalUserId(String userId) async {
    await OneSignal.login(userId);
  }

  /// Clears the external user ID on logout.
  Future<void> removeExternalUserId() async {
    await OneSignal.logout();
  }

  /// Internal handler for notification payloads.
  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    debugPrint('Notification received — type: $type, data: $data');

    // Route based on notification type — extend as needed.
    switch (type) {
      case 'new_assignment':
        // TODO: Navigate to assignment detail
        break;
      case 'assignment_update':
        // TODO: Refresh assignments list
        break;
      default:
        break;
    }
  }
}
