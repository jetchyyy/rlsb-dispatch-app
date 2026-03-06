# GPS Trail Disappearance - Comprehensive Backtrack Analysis

## Executive Summary

After implementing Kalman filter + sensor fusion (JitterFix branch), GPS trails stopped appearing in the MIS dispatch tracker backend. This analysis compares `main` branch (688 lines) vs `JitterFix` branch (840 lines) to identify all breaking changes.

---

## 🔴 CRITICAL BREAKING CHANGES

### 1. **RAW vs SMOOTHED Coordinates** ⚠️ HIGH IMPACT
**Location:** `lib/core/providers/location_tracking_provider.dart:429-430`

**MAIN BRANCH (Working):**
```dart
final entry = <String, dynamic>{
  'latitude': position.latitude,        // RAW GPS
  'longitude': position.longitude,      // RAW GPS
  ...
};
```

**JITTERFIX BRANCH (Broken):**
```dart
final entry = <String, dynamic>{
  'latitude': smoothedLat,              // KALMAN SMOOTHED
  'longitude': smoothedLng,             // KALMAN SMOOTHED
  ...
};
```

**Impact:**
- Backend may validate coordinates against geofences/boundaries
- Smoothed coordinates can drift outside valid ranges (± 5-50m from raw GPS)
- Laravel validation rules might reject smoothed coords as "invalid location"
- If backend expects specific decimal precision, Kalman output may differ

**Evidence:**
- Kalman residuals show 5-50m adjustments
- OUTLIER detection logs indicate large corrections applied
- Smoothed coords can be outside original GPS accuracy circle

---

### 2. **Jump Detection REMOVED** ⚠️ HIGH IMPACT
**Location:** `lib/core/providers/location_tracking_provider.dart:365-375`

**MAIN BRANCH (Working):**
```dart
// Reject if moved > 500m in < 10 seconds (unrealistic for ground movement)
if (timeDelta < 10 && distance > 500) {
  debugPrint('📍 ❌ Position rejected (jump detection): ${distance.toStringAsFixed(0)}m in ${timeDelta}s');
  return;  // PREVENTS BAD DATA FROM BEING SENT
}
```

**JITTERFIX BRANCH (Broken):**
```dart
// ── Kalman Filter Smoothing ───────────────────────────────
// Code applies Kalman filter but NO pre-check for impossible jumps
```

**Impact:**
- GPS glitches (satellites switching, multipath) can now pass through
- Kalman filter may produce bad smoothed output if input is severely corrupted
- Backend might reject entire batch if ONE point has impossible jump
- No safety net before sending data to server

**Evidence:**
- Kalman outlier detection happens AFTER smoothing attempt
- Outlier flag only marks point but doesn't prevent transmission
- Backend may have server-side jump validation that rejects entire batch

---

### 3. **Path Simplification Aggressive Removal** ⚠️ MEDIUM IMPACT
**Location:** `lib/core/providers/location_tracking_provider.dart:608-628`

**MAIN BRANCH (Working):**
```dart
// Sends all deduplicated points (no simplification)
final chunks = _splitIntoChunks(deduplicated, ApiConstants.batchChunkSize);
```

**JITTERFIX BRANCH (Broken):**
```dart
// Step 1: Remove velocity outliers
final noOutliers = PathSimplifier.removeVelocityOutliers(
  deduplicated,
  maxSpeedMs: 50.0,  // Rejects > 180 km/h
);

// Step 2: Douglas-Peucker simplification
final simplifiedPoints = PathSimplifier.simplifyDouglasPeucker(
  points,
  epsilonMeters: 2.0,  // Removes points within 2m of line
);

// Result: 10-20% of points removed
final chunks = _splitIntoChunks(simplified, ApiConstants.batchChunkSize);
```

**Impact:**
- Critical waypoints (first/last point, sharp turns) may be removed
- Backend might expect minimum point density (e.g., "at least 1 point per 30 seconds")
- Trails that are mostly straight (highways) could drop to < 5 points for long distances
- MIS map renderer might not display trails with < X points

**Evidence:**
- Logs show "100 → 82 points (18 removed)"
- Douglas-Peucker is designed to REMOVE intermediate points
- Even 2.0m epsilon is aggressive for slow-moving responders (walking = 1.4 m/s)

---

### 4. **'simplified' Field Sent to Backend** ⚠️ MEDIUM IMPACT (ALREADY FIXED)
**Location:** `lib/core/utils/path_simplifier.dart:213`

**JITTERFIX BRANCH (Initially Broken, Now Fixed):**
```dart
// OLD VERSION (sent to backend):
simplified['simplified'] = true;  // ❌ Backend doesn't have this column

// CURRENT VERSION (fixed):
// Note: Don't add 'simplified' field - backend doesn't expect it
```

**Impact:**
- Laravel would throw SQL error: "Unknown column 'simplified' in 'location_updates'"
- HTTP 422/500 response would cause entire batch to be rejected
- Data sits in offline queue indefinitely

**Status:** ✅ **FIXED** - Field removed from output

---

## 🟡 POTENTIAL SECONDARY ISSUES

### 5. **Sensor Fusion Displacement Injection**
**Location:** `lib/core/providers/location_tracking_provider.dart:349-360`

```dart
if (_sensorFusion.isRunning && _lastPosition != null) {
  final displacement = _sensorFusion.getDisplacementDegrees(_lastPosition!.latitude);
  sensorDisplacementLat = displacement.latDelta;
  sensorDisplacementLng = displacement.lngDelta;
  // Fed into Kalman filter as "expected position"
}
```

**Risk:**
- Accelerometer drift can accumulate 10-50m error over 30 seconds
- If sensor drift is large AND GPS glitches, Kalman may average them into invalid position
- Backend geofence validation could reject

---

### 6. **Timestamp Handling Change**
**Location:** `lib/core/providers/location_tracking_provider.dart:422`

**MAIN:**
```dart
final timestamp = DateTime.now().toUtc().toIso8601String();
```

**JITTERFIX:**
```dart
final timestamp = DateTime.now();  // DateTime object
// ... later ...
final timestampStr = timestamp.toUtc().toIso8601String();
```

**Impact:** Minimal - Output format identical, just intermediate variable added

---

### 7. **Distance Calculation Uses Smoothed Coords**
**Location:** `lib/core/providers/location_tracking_provider.dart:412-415`

```dart
final distance = _locationService.distanceBetween(
  _lastPosition!.latitude,
  _lastPosition!.longitude,
  smoothedLat,    // ← NEW: comparing raw previous to smoothed current
  smoothedLng,
);
```

**Risk:**
- Jitter filter might incorrectly skip or pass points
- If Kalman smooths 20m away from raw GPS, distance calculation could be wrong

---

## 📊 STATISTICS COMPARISON

| Metric | Main Branch | JitterFix Branch | Delta |
|--------|-------------|------------------|-------|
| Lines of code | 688 | 840 | +152 lines |
| Files changed | - | 17 | - |
| New dependencies | - | sensors_plus | +1 |
| Data reduction | 0% | 10-20% | Via simplification |
| Coordinate source | Raw GPS | Kalman smoothed | ± 5-50m |
| Jump protection | Yes (500m/10s) | No | Removed |

---

## 🔍 ROOT CAUSE HYPOTHESIS

**Most Likely Causes (Ranked):**

1. **Backend validation rejects smoothed coordinates** (70% confidence)
   - Smoothed coords outside geofence boundaries
   - Laravel validation rules expect GPS accuracy circle
   - Solution: Send RAW coordinates, simplify on backend

2. **Jump detection removal allows bad data through** (60% confidence)
   - GPS glitches now bypass safety checks
   - Backend rejects batches with impossible jumps
   - Solution: Restore 500m/10s check BEFORE Kalman filter

3. **Path simplification removes critical points** (40% confidence)
   - Trails < 5 points won't render in MIS
   - Backend expects minimum point density
   - Solution: Only simplify if > 50 points, keep first/last always

4. **'simplified' field error** (10% confidence)
   - Already fixed, but batches sent before fix are stuck
   - Solution: Clear offline queue and retry

---

## ✅ FIXES ALREADY APPLIED

1. ✅ Removed 'simplified' field from path_simplifier.dart:213
2. ✅ Reduced epsilon from 5.0m → 2.0m (less aggressive)
3. ✅ Added debug logging for simplification percentage

---

## 🔧 RECOMMENDED NEXT STEPS

### IMMEDIATE (Do This Now)

1. **Test with RAW coordinates** - Revert lines 429-430 to use raw GPS
   ```dart
   'latitude': position.latitude,   // REVERT TO THIS
   'longitude': position.longitude, // REVERT TO THIS
   ```
   - If trails appear again → confirms smoothed coords are problem
   - Keep Kalman filter for logging/analytics, but send raw to backend

2. **Check backend logs for SQL/validation errors**
   ```bash
   ssh server
   tail -f /var/www/sdnpdrrmo/storage/logs/laravel.log | grep "location"
   ```
   - Look for: "Unknown column", "Validation failed", "422 Unprocessable Entity"

3. **Clear offline queue and re-test**
   ```dart
   await Hive.box<String>('location_queue').clear();
   ```
   - Old batches with 'simplified' field might be stuck

### MEDIUM PRIORITY (Test After Above)

4. **Restore jump detection BEFORE Kalman filter**
   ```dart
   // Add this BEFORE line 365:
   if (_lastPosition != null && timeDelta < 10 && rawDistance > 500) {
     debugPrint('📍 ❌ GPS glitch detected, skipping');
     return;  // Don't even try to smooth this
   }
   ```

5. **Make path simplification optional**
   - Only simplify if batch > 50 points
   - Always preserve first/last point
   - Add toggle in UI: "High quality trails" (no simplification)

### LONG-TERM (Future Enhancement)

6. **Move smoothing to backend**
   - Send raw GPS to backend as-is (guaranteed to work)
   - Backend applies Kalman filter AFTER data is safely stored
   - Allows A/B testing of smoothing algorithms

7. **Add telemetry to track rejection rate**
   - Log HTTP status codes from batch uploads
   - Count: success vs 422 vs 500 vs offline-queued
   - Add to dashboard: "Location points sent vs accepted"

---

## 📝 TESTING CHECKLIST

Before deploying any fix, test:

- [ ] Active tracking (incident response)
- [ ] Passive tracking (standby mode)
- [ ] Offline → Online sync
- [ ] Long trail (> 100 points)
- [ ] Short trail (< 10 points)
- [ ] Stationary device (jitter only)
- [ ] Fast movement (vehicle response)
- [ ] Check MIS backend shows trails
- [ ] Check Laravel logs for errors
- [ ] Check mobile app logs for rejections

---

## 🎯 VERDICT

**The trail disappearance is most likely caused by:**
1. Backend rejecting **smoothed coordinates** that don't match raw GPS validation
2. **Jump detection removal** allowing GPS glitches to pass through
3. Aggressive **path simplification** removing display-critical points

**Recommended Fix Priority:**
1. Revert to RAW coordinates (test first)
2. Restore jump detection check
3. Make simplification less aggressive or optional
4. Clear offline queue of old 'simplified' field batches

---

**Generated:** 2025-01-XX
**Branch:** JitterFix vs main
**Analyzed Files:** 17 changed files, focus on location_tracking_provider.dart
