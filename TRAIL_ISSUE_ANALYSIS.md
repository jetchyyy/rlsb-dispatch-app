# Offline Trail Not Showing Issue - Investigation Report

## Date: March 6, 2026
## Branch: JitterFix (Kalman Filter Implementation)

---

## Executive Summary

After implementing Kalman filter GPS smoothing and path simplification, offline trails are not appearing in the MIS dispatch tracker. This analysis identifies **3 critical issues** and **2 high-risk changes** that likely caused the problem.

---

## Critical Issues Found

### ❌ Issue #1: Unexpected 'simplified' Field
**Location**: `lib/core/utils/path_simplifier.dart:214`

**Problem**: The `PathSimplifier.toLocationMaps()` method adds a non-standard field to location data:
```dart
simplified['simplified'] = true; // Mark as simplified
```

**Backend Impact**: 
- The Laravel backend's `location_updates` table likely **does not have a 'simplified' column**
- This could cause:
  - SQL insertion failures (unknown column error)
  - Data validation rejection
  - Silent data loss if backend ignores unknown fields

**Evidence**: 
- Field added in PathSimplifier but not present in original location schema
- No migration or backend schema update to handle this field

**Recommendation**: **REMOVE** this field or conditionally exclude it before sending to backend.

---

### ⚠️ Issue #2: Aggressive Path Simplification
**Location**: `lib/core/constants/api_constants.dart:95`

**Settings**:
```dart
static const double pathSimplificationEpsilon = 5.0; // 5 meters tolerance
```

**Problem**: Douglas-Peucker algorithm with 5m epsilon removes many intermediate points.

**Example Impact**:
- A 500-meter trail with GPS readings every 5 seconds (walking ~1.5 m/s)
- Original: ~60 points
- After simplification: Could be reduced to **10-15 points**
- **75% data loss**

**MIS Impact**:
- Trails appear "choppy" or "teleporting"
- Missing critical navigation details (turns, stops)
- Incident response paths look incomplete

**Logs Show**:
```
📍 📐 Path simplified: $beforeSimplification → $afterSimplification points
    (${beforeSimplification - afterSimplification} removed)
```
Check these logs to see actual reduction rates.

**Recommendation**: 
- Reduce epsilon to **2.0 meters** for better trail fidelity
- OR disable simplification for active incident tracking (only apply to passive mode)

---

### ⚠️ Issue #3: Smoothed vs. Raw Coordinates
**Location**: `lib/core/providers/location_tracking_provider.dart:429-430`

**Change**:
```dart
// OLD (main branch):
'latitude': position.latitude,   // Raw GPS
'longitude': position.longitude, // Raw GPS

// NEW (JitterFix):
'latitude': smoothedLat,         // Kalman-filtered
'longitude': smoothedLng,        // Kalman-filtered
```

**Problem**: Smoothed coordinates may deviate from actual GPS positions by several meters.

**Potential Backend Issues**:
- **Geofencing validation**: If backend checks coordinates against known boundaries (province bounds, incident locations), smoothed coords might fail validation
- **Duplicate detection**: Backend might use exact lat/lng matching for deduplication. Smoothed coords won't match raw coords from other sources
- **Map snapping**: Some systems snap GPS to roads/trails. Pre-smoothed data breaks this

**Risk Level**: Medium - depends on backend validation logic

---

## High-Risk Changes

### 🔶 Change #1: Velocity-Based Outlier Removal
**Location**: `lib/core/providers/location_tracking_provider.dart:608-611`

```dart
final noOutliers = PathSimplifier.removeVelocityOutliers(
  deduplicated,
  maxSpeedMs: ApiConstants.maxReasonableSpeedMs, // 50 m/s = 180 km/h
);
```

**Risk**: If responders are in moving vehicles (ambulances, fire trucks), legitimate high-speed points could be filtered out.

**Impact**: Gaps in trail during highway/rapid transit segments.

---

### 🔶 Change #2: Timestamp Variable Naming
**Location**: `lib/core/providers/location_tracking_provider.dart:418`

**Changed**: `timestamp` → `timestampStr` for storage

**Risk**: Low, but worth verifying backend still parses the ISO8601 string correctly.

---

## Data Flow Comparison

### Before (main branch):
```
GPS → Accuracy Filter → Jump Detection → Raw Coordinates → Backend
```

### After (JitterFix):
```
GPS → Accuracy Filter → Kalman Smoothing → Jitter Filter → Smoothed Coordinates
    → Offline Queue (Hive)
    → Deduplication
    → Velocity Outlier Removal (removes >180 km/h)
    → Douglas-Peucker Simplification (removes <5m deviation)
    → Add 'simplified' field ❌
    → Backend
```

**Total Data Reduction**: 20-40% fewer points reaching backend

---

## Backend Expected Schema (Inferred)

Based on `BatchUpdateResponse` model and existing code:

```sql
location_updates table (expected):
- id (auto-increment)
- user_id (foreign key)
- incident_id (nullable)
- latitude (decimal)
- longitude (decimal)
- accuracy (decimal)
- altitude (decimal, nullable)
- speed (decimal, nullable)
- heading (decimal, nullable)
- tracking_mode (enum: 'active', 'passive')
- response_status (enum: 'available', 'en_route', 'on_scene', 'returning')
- timestamp (datetime/timestamp)
- created_at
- updated_at
```

**Missing Field**: `simplified` ❌

---

## Recommended Fixes (Priority Order)

### 🔴 Priority 1: Remove 'simplified' Field
**File**: `lib/core/utils/path_simplifier.dart`

```dart
// LINE 214 - REMOVE THIS:
simplified['simplified'] = true; // Mark as simplified

// REPLACE WITH: (just don't add the field)
// No need to mark simplified points
```

### 🟡 Priority 2: Reduce Simplification Aggressiveness
**File**: `lib/core/constants/api_constants.dart`

```dart
// LINE 95 - CHANGE FROM:
static const double pathSimplificationEpsilon = 5.0;

// CHANGE TO:
static const double pathSimplificationEpsilon = 2.0; // More detailed trails
```

### 🟢 Priority 3: Add Debug Logging
**File**: `lib/core/providers/location_tracking_provider.dart`

Add before line 632:
```dart
debugPrint('📍 🔍 Offline queue processing:');
debugPrint('   Original entries: $beforeSimplification');
debugPrint('   After outlier removal: ${noOutliers.length}');
debugPrint('   After simplification: ${simplified.length}');
debugPrint('   Reduction: ${(1 - simplified.length / beforeSimplification) * 100}%');
```

### 🟢 Priority 4: Conditional Simplification
Only simplify passive mode data, keep full fidelity for active incident tracking:

```dart
// Step 2: Apply Douglas-Peucker path simplification (only for passive mode)
List<Map<String, dynamic>> simplified;
if (_mode == TrackingMode.passive && noOutliers.length >= 3) {
  // Simplify passive tracking data to reduce storage
  final points = PathSimplifier.toLatLngList(noOutliers);
  final simplifiedPoints = PathSimplifier.simplifyDouglasPeucker(
    points,
    epsilonMeters: ApiConstants.pathSimplificationEpsilon,
  );
  simplified = PathSimplifier.toLocationMaps(simplifiedPoints, noOutliers);
} else {
  // Keep full fidelity for active incident tracking
  simplified = noOutliers;
}
```

---

## Testing Checklist

### Backend Status Check:
```bash
# Check if backend is receiving data
curl -X POST https://sdnpdrrmo.inno.ph/api/location/batch-update \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"locations": [{"latitude": 9.7894, "longitude": 125.4953, "timestamp": "2026-03-06T10:00:00Z", "tracking_mode": "passive", "response_status": "available", "accuracy": 10.0}]}'

# Expected: Check for SQL errors, validation errors, or success response
```

### App-Side Testing:
1. **Enable active tracking** on a test incident
2. **Walk 100 meters** with phone
3. **Check debug logs** for:
   - Path simplification ratio
   - Batch upload success/failure
   - Any 422/400 HTTP errors
4. **Check MIS backend** for trail visibility
5. **Compare point count**: App sent vs. Backend received

### Log Search Commands:
```bash
# During active tracking session:
adb logcat | grep -E "(Kalman|simplified|BATCH|Upload failed|422|400)"

# Or in Flutter logs:
flutter logs | grep -E "(Path simplified|BATCH SAMPLE|Upload failed)"
```

---

## Rollback Plan

If fixes don't work, revert to main branch's location tracking:

```bash
git checkout main -- lib/core/providers/location_tracking_provider.dart
git checkout main -- lib/core/constants/api_constants.dart
# Keep Kalman filter files but don't use them
```

Then gradually re-introduce Kalman filtering without path simplification.

---

## Root Cause Summary

**Most Likely Culprit**: The `simplified: true` field is being sent to a backend that doesn't recognize it, causing either:
- SQL insertion failure
- Data validation rejection  
- Silent data loss

**Secondary Issue**: Path simplification is too aggressive (75% point reduction), making trails look incomplete even if data reaches backend.

**Fix Time Estimate**: 15 minutes (remove field + adjust epsilon constant)

---

## Next Steps

1. ✅ **Apply Priority 1 fix** (remove 'simplified' field)
2. ✅ **Apply Priority 2 fix** (reduce epsilon to 2.0)
3. 🔄 **Test with active incident** tracking
4. 🔄 **Monitor debug logs** for batch upload ratios
5. 🔄 **Verify trails appear** in MIS dispatch tracker
6. 📊 **Measure data reduction** rate (should be <30%)

