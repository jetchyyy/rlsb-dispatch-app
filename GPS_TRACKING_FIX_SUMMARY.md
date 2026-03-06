# GPS Tracking Offline Trails Fix Implementation

## Date: March 6, 2026

## Problem Summary

Based on the investigation document (OFFLINE_TRAILS_INVESTIGATION.md), GPS tracking was stopping after ~35 seconds during active incident response, resulting in:
- ❌ 13-minute gap in GPS data during critical incident response period
- ❌ No GPS trail visualization in dispatch tracker
- ❌ Missing location data during arrival and resolution events

**Root Cause**: The mobile app was not maintaining continuous location tracking during incident response. The background service existed but tracking timers were not robust against app backgrounding/suspension.

## Fixes Implemented

### 1. Enhanced Background Service Integration

**File**: `lib/core/providers/location_tracking_provider.dart`

#### Changes:
- Added explicit `BackgroundServiceInitializer` import
- Modified `startActiveTracking()` to ensure background foreground service starts when active tracking begins
- Enhanced notification message to show "Emergency Response Active" with incident number
- Updated `stopActiveTracking()` to properly update background service notification when reverting to passive mode

#### Key Code:
```dart
// Ensure background service is running as foreground service
await BackgroundServiceInitializer.startService();
BackgroundServiceInitializer.setTrackingMode('active', incidentId: incidentId);
BackgroundServiceInitializer.updateNotification(
  'Emergency Response Active',
  'Tracking location for incident #$incidentId',
);
```

**Impact**: Background service now explicitly starts and maintains foreground status during active tracking, preventing OS from killing the app.

---

### 2. WorkManager Integration for Reliability

**New File**: `lib/core/services/workmanager_service.dart`

#### Purpose:
WorkManager provides a robust background task scheduler that works even when the app is killed or in deep sleep. It complements the foreground service by ensuring:
- Offline location queue syncs every 15 minutes
- Tracking health check every 30 minutes
- Tasks survive app restarts and system reboots

#### Features:
```dart
// Periodic location sync task (every 15 min)
await WorkManagerService.registerLocationSync();

// Health check task (every 30 min)
await WorkManagerService.registerTrackingHealthCheck();

// Cancel all tasks on logout
await WorkManagerService.cancelAll();
```

**Dependencies Added**:
- `workmanager: ^0.5.2` in `pubspec.yaml`

**Impact**: Even if the foreground service is somehow stopped, WorkManager ensures the app wakes up periodically to sync offline data and check tracking health.

---

### 3. Improved Background Service Lifecycle

**File**: `lib/core/services/background_service_initializer.dart`

#### Changes:
- Added watchdog timer to restore foreground status if lost
- Added additional heartbeat every 10 seconds for monitoring
- Enhanced logging to track service health
- Prevents service from canceling itself if foreground status is temporarily lost

#### Key Code:
```dart
Timer.periodic(const Duration(seconds: 30), (timer) async {
  if (service is AndroidServiceInstance) {
    final isFg = await service.isForegroundService();
    if (!isFg) {
      // If we lost foreground status, try to restore it
      debugPrint('📍 ⚠️ Background service lost foreground status - restoring...');
      service.setAsForegroundService();
    }
  }
  service.invoke('trackingStatus', {'isRunning': true});
});
```

**Impact**: Service is more resilient to Android's aggressive battery optimization and will attempt to restore itself if interrupted.

---

### 4. Main App Integration

**Files Modified**:
- `lib/main.dart`
- `lib/app.dart`

#### Changes in main.dart:
```dart
// Initialize WorkManager
await WorkManagerService.initialize();

// Start WorkManager tasks when already authenticated
await WorkManagerService.registerLocationSync();
await WorkManagerService.registerTrackingHealthCheck();
```

#### Changes in app.dart:
```dart
// On login
WorkManagerService.registerLocationSync();
WorkManagerService.registerTrackingHealthCheck();

// On logout
WorkManagerService.cancelAll();
```

**Impact**: WorkManager tasks are properly managed across authentication state changes.

---

### 5. Enhanced Android Permissions

**File**: `android/app/src/main/AndroidManifest.xml`

#### Permissions Added:
```xml
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

**Existing Permissions** (verified):
- ✅ `ACCESS_BACKGROUND_LOCATION` - Critical for tracking when app is backgrounded
- ✅ `FOREGROUND_SERVICE` - Allows foreground service to run
- ✅ `FOREGROUND_SERVICE_LOCATION` - Specifies location type foreground service
- ✅ `WAKE_LOCK` - Prevents device from sleeping during tracking
- ✅ `RECEIVE_BOOT_COMPLETED` - Allows service restart after device reboot

**Impact**: App can now request battery optimization exemption and schedule exact alarms for WorkManager tasks.

---

## Testing Required

### Test Scenario 1: Complete Incident Response Cycle
**Goal**: Verify continuous GPS tracking throughout entire incident response

1. **Setup**: 
   - Login to app
   - Ensure GPS permission granted (including "Always Allow")
   - Verify background service notification appears

2. **Test Steps**:
   ```
   a. Accept new incident → Start responding
   b. Lock phone screen (wait 2 minutes)
   c. Unlock → Verify tracking still active
   d. Switch to different app (wait 2 minutes)
   e. Return to app → Verify tracking still active
   f. Mark "On Scene" status
   g. Lock phone for 5 minutes
   h. Unlock and resolve incident
   ```

3. **Validation**:
   - Check backend database: 
     ```sql
     SELECT COUNT(*) as points, 
            MIN(captured_at) as first, 
            MAX(captured_at) as last,
            TIMESTAMPDIFF(SECOND, MIN(captured_at), MAX(captured_at)) as duration_seconds
     FROM dispatch_locations 
     WHERE incident_id = [TEST_INCIDENT_ID];
     ```
   - ✅ Should have GPS points throughout entire duration
   - ✅ No gaps > 30 seconds in active tracking
   - ✅ All points should have correct `incident_id`
   - ✅ `tracking_mode` = 'active' for incident points

### Test Scenario 2: App Backgrounded/Killed
**Goal**: Verify tracking survives app backgrounding and restart

1. **Test Steps**:
   ```
   a. Start incident response
   b. Put app in background for 5 minutes
   c. Force kill app from task manager
   d. Wait 2 minutes
   e. Reopen app
   f. Verify tracking resumes automatically
   g. Resolve incident
   ```

2. **Validation**:
   - Check SharedPreferences for persisted state:
     - `loc_tracking_mode` should restore to 'active'
     - `loc_active_incident_id` should restore correctly
   - Backend should show GPS points even during "killed" period (if background service stayed alive)
   - On app reopen, tracking should resume within 10 seconds

### Test Scenario 3: Offline Queue Sync
**Goal**: Verify offline data syncs properly

1. **Test Steps**:
   ```
   a. Start incident response
   b. Disable mobile data/WiFi (airplane mode)
   c. Move around for 5 minutes (GPS only)
   d. Re-enable network
   e. Wait 60 seconds (flush timer interval)
   ```

2. **Validation**:
   - Check `LocationTrackingProvider.pendingUpdates` in UI
   - Should show offline queue filling up (e.g., 60+ entries)
   - After network restored, queue should flush within 60-90 seconds
   - Backend should receive batched data with all points having `incident_id`

### Test Scenario 4: Battery Optimization
**Goal**: Ensure tracking survives aggressive battery saving

1. **Test Steps**:
   ```
   a. Enable battery saver mode on device
   b. Start incident response
   c. Lock phone for 10 minutes
   d. Check notification: Should still show "Emergency Response Active"
   e. Unlock and resolve incident
   ```

2. **Validation**:
   - Foreground notification should remain visible throughout
   - GPS data should have no gaps > 30 seconds
   - Check logcat for "Background service lost foreground status" warnings
   - If warnings appear, verify service restored itself

### Test Scenario 5: WorkManager Tasks
**Goal**: Verify WorkManager periodic tasks execute

1. **Test Steps**:
   ```
   a. Login and start passive tracking
   b. Check logcat for "WorkManager task started: location-sync-task"
   c. Wait 15+ minutes
   d. Should see periodic sync logs
   ```

2. **Validation**:
   ```bash
   # Check logcat for WorkManager execution
   adb logcat | grep "WorkManager"
   ```
   - Should see task execution every 15 minutes (sync)
   - Should see health check every 30 minutes
   - No task failures

---

## Database Validation Queries

### Check GPS Trail Completeness
```sql
-- Check if incident has continuous GPS trail
SELECT 
    incident_id,
    COUNT(*) as total_points,
    MIN(captured_at) as first_point,
    MAX(captured_at) as last_point,
    TIMESTAMPDIFF(SECOND, MIN(captured_at), MAX(captured_at)) as duration_seconds
FROM dispatch_locations 
WHERE incident_id = [INCIDENT_ID]
GROUP BY incident_id;
```

### Detect Tracking Gaps
```sql
-- Find gaps > 30 seconds in GPS trail
SELECT 
    id,
    captured_at,
    LAG(captured_at) OVER (ORDER BY captured_at) as prev_time,
    TIMESTAMPDIFF(SECOND, 
        LAG(captured_at) OVER (ORDER BY captured_at), 
        captured_at
    ) as gap_seconds
FROM dispatch_locations
WHERE incident_id = [INCIDENT_ID]
HAVING gap_seconds > 30
ORDER BY captured_at;
```

### Verify Incident Context
```sql
-- Check that all points have incident_id during response
SELECT 
    tracking_mode,
    COUNT(*) as points,
    COUNT(incident_id) as points_with_incident,
    MIN(captured_at) as first,
    MAX(captured_at) as last
FROM dispatch_locations
WHERE user_id = [USER_ID]
  AND captured_at BETWEEN [INCIDENT_START] AND [INCIDENT_END]
GROUP BY tracking_mode;
```

**Expected Results**:
- ✅ `tracking_mode = 'active'` should have 100% `points_with_incident`
- ✅ No GPS points during incident period should have NULL `incident_id`
- ✅ Duration should match incident timeline (start → resolve)

---

## Monitoring & Debugging

### Logcat Filters

**Monitor GPS Tracking**:
```bash
adb logcat | grep "📍"
```

**Monitor Background Service**:
```bash
adb logcat *:S flutter:V | grep -E "(Background service|foreground)"
```

**Monitor WorkManager**:
```bash
adb logcat *:S WM-WorkerWrapper:V | grep -E "(starting|finished|failed)"
```

### Key Debug Logs to Watch

| Log Message | Meaning | Status |
|-------------|---------|--------|
| `📍 Active tracking started for incident #X` | Active tracking initiated | ✅ Expected |
| `📍 ✅ Background foreground service activated` | Service started successfully | ✅ Expected |
| `📍 ⚠️ Background service lost foreground status` | Service was interrupted | ⚠️ Should restore |
| `📍 ⚠️ GPS capture failed` | GPS signal issue | ⚠️ Check permissions/signal |
| `📍 💾 Stored in offline queue` | No network, queued for later | ✅ Expected offline |
| `📍 ✅ Batch update complete: X sent` | Offline queue synced | ✅ Expected online |

---

## Known Limitations & Recommendations

### Android Manufacturer-Specific Issues

Some Android manufacturers (Xiaomi, Huawei, Samsung, etc.) have aggressive battery optimization that may kill background services despite proper configuration.

**Recommended User Actions**:
1. Manually exclude app from battery optimization:
   - Settings → Apps → PDRRMO Dispatch → Battery → Unrestricted
2. Enable "Autostart" permission (Xiaomi/Huawei):
   - Security app → Permissions → Autostart → Enable for PDRRMO Dispatch
3. Lock app in recent apps (prevents swipe-away kill):
   - Recent apps → Long press app → Lock

**Future Enhancement**: Add an in-app settings screen with links to manufacturer-specific battery settings.

### iOS Considerations

The current implementation is Android-focused. iOS has different background execution limitations:
- **Background Location**: Already implemented via `IosConfiguration` in background service
- **Significant Location Change**: iOS may throttle location updates when app is backgrounded
- **Background App Refresh**: User must enable in iOS settings

**Recommendation**: Test extensively on iOS devices. May need iOS-specific adjustments in `BackgroundServiceInitializer`.

### Server-Side Enhancements (Optional)

While the backend is working correctly, these enhancements could improve resilience:

1. **Auto-Associate Orphaned Locations**:
```php
// In batch-update endpoint
if (!$incident_id && $user->hasActiveIncident()) {
    $incident_id = $user->activeIncidents()
        ->where('created_at', '>=', $timestamp->subHours(2))
        ->first()?->id;
}
```

2. **Tracking Health Alert**:
```php
// Monitor for tracking stalls during active incidents
if ($incident->isActive() && $lastLocationAge > 5 minutes) {
    // Send push notification to responder
    // Alert operations center
}
```

---

## Dependencies Installed

| Package | Version | Purpose |
|---------|---------|---------|
| `workmanager` | ^0.5.2 | Background task scheduling |

**Installation**:
```bash
cd rlsb-dispatch-app
flutter pub get
```

---

## Files Modified

### Created:
- `lib/core/services/workmanager_service.dart` - WorkManager task orchestration

### Modified:
- `lib/core/providers/location_tracking_provider.dart` - Enhanced background service calls
- `lib/core/services/background_service_initializer.dart` - Improved service lifecycle
- `lib/main.dart` - WorkManager initialization
- `lib/app.dart` - WorkManager task registration on login/logout
- `pubspec.yaml` - Added workmanager dependency
- `android/app/src/main/AndroidManifest.xml` - Enhanced permissions

---

## Next Steps

### Immediate (Before Production):
1. ✅ Run `flutter pub get` to install workmanager dependency
2. ⏳ Execute all test scenarios above on physical devices (not emulator)
3. ⏳ Verify backend database shows continuous GPS trails
4. ⏳ Test on multiple Android versions (Android 10, 11, 12, 13, 14)
5. ⏳ Test on iOS devices (if applicable)

### Short-Term:
1. Add user-facing battery optimization exclusion prompt
2. Implement in-app tracking health indicator (shows if GPS is working)
3. Add server-side tracking health monitoring
4. Create admin dashboard alert for stalled tracking

### Long-Term:
1. Implement machine learning to detect anomalous gaps
2. Auto-recover from tracking failures
3. Offline trail replay visualization in mobile app
4. Real-time trail streaming to dispatch console

---

## Summary

The GPS tracking offline trails issue has been addressed with a **multi-layered reliability approach**:

1. **Foreground Service** - Keeps app alive with persistent notification (primary defense)
2. **WorkManager** - Periodic background tasks for sync and health monitoring (backup defense)
3. **State Persistence** - Tracks incident context across app restarts (recovery mechanism)
4. **Enhanced Permissions** - Battery optimization exclusion and exact alarms (system cooperation)
5. **Service Watchdog** - Auto-restores foreground status if lost (self-healing)

**Expected Outcome**: Continuous GPS tracking throughout entire incident response lifecycle with no gaps > 30 seconds, ensuring accurate offline trail visualization in the dispatch tracker.

**Risk Assessment**: ⚠️ Medium - Still dependent on Android manufacturer-specific battery optimization. Requires extensive field testing on diverse devices.

---

**Implementation Status**: ✅ Complete  
**Testing Status**: ⏳ Pending  
**Production Ready**: ⚠️ Requires field testing first
