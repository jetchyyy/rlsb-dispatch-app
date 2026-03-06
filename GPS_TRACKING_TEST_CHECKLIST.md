# GPS Tracking Fix - Quick Testing Checklist

## Pre-Test Setup ✅

- [ ] Run `flutter pub get` to install dependencies
- [ ] Build and install app on physical device (not emulator)
- [ ] Ensure device has GPS enabled
- [ ] Grant location permissions: "Allow all the time" / "Always"
- [ ] Disable battery optimization for the app (Settings → Apps → PDRRMO Dispatch → Battery → Unrestricted)

## Test 1: Basic Active Tracking (5 min) 🎯

**Steps:**
1. Login to app
2. Accept an incident and start responding
3. Verify notification shows "Emergency Response Active"
4. Lock phone screen for 2 minutes
5. Unlock and check tracking still active
6. Resolve incident

**Pass Criteria:**
- [ ] Background notification visible throughout
- [ ] GPS tracking maintained while screen locked
- [ ] Backend shows GPS points for entire duration

## Test 2: App Backgrounding (10 min) 🎯

**Steps:**
1. Start incident response
2. Switch to another app (e.g., Chrome) for 5 minutes
3. Return to PDRRMO app
4. Check response is still active
5. Resolve incident

**Pass Criteria:**
- [ ] Tracking continues while in background
- [ ] No gaps > 30 seconds in GPS trail
- [ ] Incident ID preserved throughout

## Test 3: Offline Sync (5 min) 🎯

**Steps:**
1. Start incident response
2. Enable airplane mode (GPS only)
3. Move around for 3-5 minutes
4. Disable airplane mode (restore network)
5. Wait 60 seconds

**Pass Criteria:**
- [ ] Offline queue accumulates data (check app logs)
- [ ] Queue flushes when network restored
- [ ] All offline points appear in backend with incident_id

## Test 4: Force Kill Recovery (5 min) 🎯

**Steps:**
1. Start incident response
2. Force kill app from task manager
3. Wait 2 minutes
4. Reopen app
5. Verify tracking resumes automatically

**Pass Criteria:**
- [ ] App restores active incident on reopen
- [ ] Tracking resumes within 10 seconds
- [ ] Background service notification reappears

## Backend Validation 🔍

**Run this SQL after each test:**
```sql
-- Check GPS trail for test incident
SELECT 
    COUNT(*) as total_points,
    MIN(captured_at) as first_point,
    MAX(captured_at) as last_point,
    TIMESTAMPDIFF(MINUTE, MIN(captured_at), MAX(captured_at)) as duration_minutes
FROM dispatch_locations 
WHERE incident_id = [YOUR_TEST_INCIDENT_ID];
```

**Expected Results:**
- Total points > 0 (should have many points)
- Duration matches actual incident response time
- No gaps > 30 seconds in `captured_at` timestamps

**Check for gaps:**
```sql
SELECT 
    captured_at,
    LAG(captured_at) OVER (ORDER BY captured_at) as prev_time,
    TIMESTAMPDIFF(SECOND, 
        LAG(captured_at) OVER (ORDER BY captured_at), 
        captured_at
    ) as gap_seconds
FROM dispatch_locations
WHERE incident_id = [YOUR_TEST_INCIDENT_ID]
HAVING gap_seconds > 30
ORDER BY captured_at;
```

**Expected:** Zero rows (no gaps > 30 seconds)

## Logcat Monitoring 📊

**Watch logs in real-time:**
```bash
adb logcat | grep "📍"
```

**Key logs to watch for:**
- ✅ `Active tracking started for incident #X`
- ✅ `Background foreground service activated`
- ✅ `Captured: lat=... lng=...` (every 5 seconds during active tracking)
- ✅ `Location sent to /location/update`
- ⚠️ `Background service lost foreground status` (should auto-restore)

## Common Issues & Solutions 🔧

### Issue: Tracking stops after app backgrounded
**Solution:**
- Check battery optimization settings
- Ensure "Allow all the time" location permission
- Check if notification is still visible

### Issue: No GPS points in backend
**Solution:**
- Check network connectivity
- Look for "Stored in offline queue" logs
- Wait for next flush cycle (60 seconds)

### Issue: App doesn't restore tracking on reopen
**Solution:**
- Check SharedPreferences has `loc_tracking_mode=active`
- Check logcat for restore errors
- Verify incident wasn't already resolved

### Issue: WorkManager tasks not running
**Solution:**
- Check Android Doze mode isn't blocking
- Run `adb shell dumpsys jobscheduler` to see scheduled jobs
- Ensure app has SCHEDULE_EXACT_ALARM permission

## Success Metrics ✨

**All tests passed if:**
- ✅ Zero GPS gaps > 30 seconds during active tracking
- ✅ All points have correct `incident_id` in database
- ✅ Tracking survives screen lock, app switching, force kill
- ✅ Offline data syncs within 90 seconds of network restore
- ✅ Background notification visible throughout incident

## Field Testing Recommendations 📱

**Test on various devices:**
- Samsung Galaxy (aggressive battery optimization)
- Xiaomi/Redmi (MIUI has strict background limits)
- Google Pixel (stock Android)
- Different Android versions (10, 11, 12, 13, 14)

**Real-world scenarios:**
- Actual incident response in field
- Poor GPS signal areas (buildings, tunnels)
- Weak/intermittent network connectivity
- Extended response times (30+ minutes)

---

**After all tests pass:** Mark implementation as production-ready in GPS_TRACKING_FIX_SUMMARY.md
