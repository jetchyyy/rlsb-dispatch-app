# TEST FIX APPLIED - GPS Trail Recovery

## What Was Changed

Applied a **conservative test fix** to restore GPS trail visibility in MIS dispatch tracker while keeping Kalman filter active for debugging.

### Changes Made (2025-01-XX)

#### 1. Reverted to RAW GPS Coordinates ✅
**File:** `lib/core/providers/location_tracking_provider.dart:455-475`

**Before (Broken):**
```dart
final entry = <String, dynamic>{
  'latitude': smoothedLat,      // Backend rejected these
  'longitude': smoothedLng,     // Backend rejected these
  ...
};
```

**After (Test Fix):**
```dart
final entry = <String, dynamic>{
  'latitude': position.latitude,      // RAW GPS (backend expects this)
  'longitude': position.longitude,    // RAW GPS (backend expects this)
  ...
};

// Log comparison for debugging
if (kalmanResult.residualMeters > 1.0) {
  debugPrint('📍 📊 Sending RAW (backend), Kalman smoothed by ${dist}m');
}
```

**Why:** Backend likely validates coordinates against raw GPS accuracy circles or geofences. Smoothed coordinates can drift 5-50m outside valid ranges.

---

#### 2. Restored Jump Detection Check ✅
**File:** `lib/core/providers/location_tracking_provider.dart:371-387`

**Added:**
```dart
// ── Jump Detection Filter (RESTORED) ──────────────────────
// Reject GPS glitches BEFORE attempting to smooth them
if (_lastPosition != null && _lastCaptureTime != null) {
  final timeDelta = DateTime.now().difference(_lastCaptureTime!).inSeconds;
  final rawDistance = _locationService.distanceBetween(...);
  
  // Reject if moved > 500m in < 10 seconds
  if (timeDelta < 10 && rawDistance > 500) {
    debugPrint('📍 ❌ GPS glitch detected: ${rawDistance}m in ${timeDelta}s — SKIPPING');
    return;  // Don't even try to smooth this
  }
}
```

**Why:** GPS glitches (satellite switching, multipath interference) can produce impossible jumps. Without this check, bad data passes through to backend, potentially causing batch rejection.

---

## What Stays Active

✅ **Kalman Filter** - Still runs, logs smoothing metrics for debugging  
✅ **Sensor Fusion** - Still active, provides displacement estimates  
✅ **Path Simplification** - Still reduces points by 10-20% (epsilon=2.0m)  
✅ **Velocity Outlier Removal** - Still rejects superhuman speeds (>180 km/h)  

**Key Change:** We compute smoothed coordinates but **send raw GPS to backend**.

---

## Expected Behavior

### What Should Happen Now:
1. ✅ Trails appear in MIS dispatch tracker (using raw GPS)
2. ✅ Console logs show "Sending RAW, Kalman smoothed by Xm"
3. ✅ Backend accepts all location updates (no validation errors)
4. ✅ GPS glitches > 500m/10s are rejected before sending

### What You'll See in Logs:
```
📍 🔧 Kalman smoothed: residual=12.3m
📍 📊 Sending RAW (backend), Kalman smoothed by 12.3m
📍 ✅ Captured: lat=9.123456, lng=125.456789, acc=15.0m
📍 🌐 Sent 1 locations
```

### If GPS Glitch Occurs:
```
📍 ❌ GPS glitch detected: 1250m in 8s is impossible — SKIPPING
```

---

## Testing Checklist

### Phase 1: Verify Trails Appear (PRIORITY)
- [ ] Start active tracking (respond to incident)
- [ ] Drive/walk for 5+ minutes (> 50 GPS points)
- [ ] Stop tracking
- [ ] Check MIS backend → Trails should now be visible ✅
- [ ] Check mobile logs for "Sending RAW" messages

### Phase 2: Verify Data Quality
- [ ] Check trail smoothness in MIS (should show slight jitter vs Kalman smoothed)
- [ ] Verify no impossible jumps appear (jump detection should catch them)
- [ ] Check location count: Raw should have more points than if smoothed was used

### Phase 3: Offline Sync
- [ ] Turn off internet
- [ ] Track for 2+ minutes
- [ ] Turn on internet
- [ ] Check logs for "Batch sent: X locations"
- [ ] Verify offline queue clears (count goes to 0)

### Phase 4: Backend Validation
```bash
ssh server
tail -f /var/www/sdnpdrrmo/storage/logs/laravel.log | grep "location"
```
Look for:
- ✅ `200 OK` responses (success)
- ❌ No "Unknown column" errors
- ❌ No "Validation failed" errors
- ❌ No "422 Unprocessable Entity" responses

---

## Rollback Plan (If This Doesn't Work)

If trails still don't appear after this fix:

1. **Check Laravel Logs** - Backend may have other validation rules
   ```bash
   # On server:
   tail -100 /var/www/sdnpdrrmo/storage/logs/laravel.log
   ```

2. **Clear Offline Queue** - Old batches with 'simplified' field may be stuck
   ```dart
   // In app:
   await Hive.box<String>('location_queue').clear();
   ```

3. **Verify Backend Schema** - Table may have changed
   ```sql
   DESCRIBE location_updates;
   ```

4. **Test Direct API Call** - Bypass app entirely
   ```bash
   curl -X POST https://sdnpdrrmo.inno.ph/api/location/batch-update \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"locations": [{"latitude": 9.5, "longitude": 125.5, ...}]}'
   ```

---

## Future Optimization (After Trails Work)

Once trails are confirmed working with **raw GPS**, consider:

### Option A: Backend Smoothing (Recommended)
- Send raw GPS to backend (guaranteed compatibility)
- Apply Kalman filter on backend AFTER storage
- Allows A/B testing different smoothing algorithms

### Option B: Conditional Smoothing
- Add UI toggle: "High Quality Trails" (uses smoothed) vs "Standard" (uses raw)
- Send both raw + smoothed in API call
- Backend chooses which to display

### Option C: Hybrid Approach
- Use raw GPS for MIS display
- Use smoothed GPS for analytics/statistics
- Keep separated in database schema

---

## Changes Summary

| Component | Status | Action |
|-----------|--------|--------|
| Coordinates sent | ✅ FIXED | Reverted to raw GPS |
| Jump detection | ✅ FIXED | Restored 500m/10s check |
| Kalman filter | ✅ ACTIVE | Runs for logging only |
| Path simplification | ✅ ACTIVE | Epsilon = 2.0m (10-20% reduction) |
| 'simplified' field | ✅ FIXED | Already removed (previous fix) |

---

## Git Commit Message (If This Works)

```
Fix GPS trails not appearing by reverting to raw coordinates

- Send raw GPS to backend instead of Kalman-smoothed coords
- Restore jump detection check (500m/10s threshold)
- Keep Kalman filter active for debugging/logging
- Log comparison of raw vs smoothed coordinates

Backend validation likely rejects smoothed coordinates that drift
outside geofence boundaries. This fix ensures compatibility while
maintaining smoothing telemetry for future optimization.

Fixes: Trail disappearance after Kalman filter implementation
Related: BACKTRACK_ANALYSIS.md
```

---

**Status:** ✅ Ready to Test  
**Risk Level:** Low (conservative revert to known-working approach)  
**Next Steps:** Deploy to test device, track for 5+ minutes, verify MIS shows trails
