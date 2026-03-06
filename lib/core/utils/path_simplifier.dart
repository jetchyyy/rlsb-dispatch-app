import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Utility class for simplifying GPS paths and removing outliers.
///
/// Implements:
/// - Douglas-Peucker algorithm for path simplification
/// - Velocity-based outlier detection and removal
/// - Moving average smoothing
class PathSimplifier {
  /// Simplifies a path using the Douglas-Peucker algorithm.
  ///
  /// This algorithm recursively removes points that don't significantly
  /// contribute to the shape of the path, reducing the number of points
  /// while preserving the overall route geometry.
  ///
  /// [points] is the list of coordinates to simplify.
  /// [epsilonMeters] is the maximum allowed perpendicular distance
  /// from the simplified line (in meters). Larger values = more simplification.
  ///
  /// Returns a new list with fewer points that approximates the original path.
  static List<LatLng> simplifyDouglasPeucker(
    List<LatLng> points, {
    double epsilonMeters = 5.0,
  }) {
    if (points.length < 3) return List.from(points);
    
    // Find the point with maximum distance from the line between first and last
    double maxDistance = 0;
    int maxIndex = 0;
    
    final first = points.first;
    final last = points.last;
    
    for (int i = 1; i < points.length - 1; i++) {
      final distance = _perpendicularDistance(points[i], first, last);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }
    
    // If max distance exceeds epsilon, recursively simplify
    if (maxDistance > epsilonMeters) {
      // Recursive call on two halves
      final left = simplifyDouglasPeucker(
        points.sublist(0, maxIndex + 1),
        epsilonMeters: epsilonMeters,
      );
      final right = simplifyDouglasPeucker(
        points.sublist(maxIndex),
        epsilonMeters: epsilonMeters,
      );
      
      // Combine results (remove duplicate middle point)
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      // All points between first and last are within epsilon
      return [first, last];
    }
  }
  
  /// Removes velocity-based outliers from a list of location updates.
  ///
  /// Detects points that would require superhuman speed to reach from
  /// the previous point and removes them.
  ///
  /// [locations] is a list of location maps with 'latitude', 'longitude',
  /// and 'timestamp' keys.
  /// [maxSpeedMs] is the maximum reasonable speed in meters/second.
  /// Default is 50 m/s (~180 km/h).
  ///
  /// Returns a new list with outliers removed.
  static List<Map<String, dynamic>> removeVelocityOutliers(
    List<Map<String, dynamic>> locations, {
    double maxSpeedMs = 50.0,
  }) {
    if (locations.length < 2) return List.from(locations);
    
    final result = <Map<String, dynamic>>[locations.first];
    
    for (int i = 1; i < locations.length; i++) {
      final prev = result.last;
      final current = locations[i];
      
      // Parse coordinates
      final lat1 = (prev['latitude'] as num).toDouble();
      final lng1 = (prev['longitude'] as num).toDouble();
      final lat2 = (current['latitude'] as num).toDouble();
      final lng2 = (current['longitude'] as num).toDouble();
      
      // Parse timestamps
      final time1 = DateTime.parse(prev['timestamp'] as String);
      final time2 = DateTime.parse(current['timestamp'] as String);
      
      // Calculate distance and time
      final distance = _haversineDistance(lat1, lng1, lat2, lng2);
      final timeDelta = time2.difference(time1).inMilliseconds / 1000.0;
      
      // Skip if time delta is too small (avoid division by zero)
      if (timeDelta < 0.1) {
        // Keep the point but don't use it for velocity check
        result.add(current);
        continue;
      }
      
      // Calculate required speed
      final speed = distance / timeDelta;
      
      if (speed <= maxSpeedMs) {
        result.add(current);
      } else {
        // Outlier detected - skip this point
        // debugPrint omitted to avoid import, caller can log
      }
    }
    
    return result;
  }
  
  /// Applies a simple moving average smoothing to coordinates.
  ///
  /// [locations] is a list of location maps.
  /// [windowSize] is the number of points to average (must be odd).
  ///
  /// Returns a new list with smoothed coordinates.
  static List<Map<String, dynamic>> movingAverageSmooth(
    List<Map<String, dynamic>> locations, {
    int windowSize = 3,
  }) {
    if (locations.length < windowSize) return List.from(locations);
    
    // Ensure window size is odd
    if (windowSize % 2 == 0) windowSize++;
    final halfWindow = windowSize ~/ 2;
    
    final result = <Map<String, dynamic>>[];
    
    for (int i = 0; i < locations.length; i++) {
      // Determine window bounds
      final start = (i - halfWindow).clamp(0, locations.length - 1);
      final end = (i + halfWindow).clamp(0, locations.length - 1);
      final windowLength = end - start + 1;
      
      // Calculate average
      double sumLat = 0;
      double sumLng = 0;
      
      for (int j = start; j <= end; j++) {
        sumLat += (locations[j]['latitude'] as num).toDouble();
        sumLng += (locations[j]['longitude'] as num).toDouble();
      }
      
      // Create smoothed copy
      final smoothed = Map<String, dynamic>.from(locations[i]);
      smoothed['latitude'] = sumLat / windowLength;
      smoothed['longitude'] = sumLng / windowLength;
      
      result.add(smoothed);
    }
    
    return result;
  }
  
  /// Converts a list of location maps to LatLng points.
  static List<LatLng> toLatLngList(List<Map<String, dynamic>> locations) {
    return locations.map((loc) {
      final lat = (loc['latitude'] as num).toDouble();
      final lng = (loc['longitude'] as num).toDouble();
      return LatLng(lat, lng);
    }).toList();
  }
  
  /// Converts a list of LatLng points back to location maps.
  ///
  /// [points] is the simplified list of coordinates.
  /// [originalLocations] is used to find the closest original location
  /// for each simplified point (to preserve timestamps and other metadata).
  static List<Map<String, dynamic>> toLocationMaps(
    List<LatLng> points,
    List<Map<String, dynamic>> originalLocations,
  ) {
    if (points.isEmpty || originalLocations.isEmpty) return [];
    
    final result = <Map<String, dynamic>>[];
    
    for (final point in points) {
      // Find the closest original location
      Map<String, dynamic>? closest;
      double minDistance = double.infinity;
      
      for (final original in originalLocations) {
        final lat = (original['latitude'] as num).toDouble();
        final lng = (original['longitude'] as num).toDouble();
        final distance = _haversineDistance(
          point.latitude, point.longitude, lat, lng
        );
        
        if (distance < minDistance) {
          minDistance = distance;
          closest = original;
        }
      }
      
      if (closest != null && minDistance < 1.0) {
        // Use original if very close (within 1 meter)
        result.add(closest);
      } else if (closest != null) {
        // Create a new map with simplified coordinates but original metadata
        final simplified = Map<String, dynamic>.from(closest);
        simplified['latitude'] = point.latitude;
        simplified['longitude'] = point.longitude;
        simplified['simplified'] = true; // Mark as simplified
        result.add(simplified);
      }
    }
    
    return result;
  }
  
  /// Calculates perpendicular distance from a point to a line (in meters).
  static double _perpendicularDistance(
    LatLng point,
    LatLng lineStart,
    LatLng lineEnd,
  ) {
    // Convert to simple Cartesian approximation for small distances
    // This is faster than full geodesic calculation and accurate enough
    // for the Douglas-Peucker algorithm
    
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;
    
    // Line length squared
    final lineLengthSq = dx * dx + dy * dy;
    
    if (lineLengthSq == 0) {
      // Start and end are the same point
      return _haversineDistance(
        point.latitude, point.longitude,
        lineStart.latitude, lineStart.longitude,
      );
    }
    
    // Project point onto line, clamped to segment
    final t = ((point.longitude - lineStart.longitude) * dx +
               (point.latitude - lineStart.latitude) * dy) / lineLengthSq;
    final tClamped = t.clamp(0.0, 1.0);
    
    // Closest point on line
    final closestLng = lineStart.longitude + tClamped * dx;
    final closestLat = lineStart.latitude + tClamped * dy;
    
    // Distance from point to closest point on line
    return _haversineDistance(
      point.latitude, point.longitude,
      closestLat, closestLng,
    );
  }
  
  /// Calculates distance between two coordinates using Haversine formula.
  static double _haversineDistance(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    const earthRadius = 6371000.0; // meters
    
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
              sin(dLng / 2) * sin(dLng / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double _toRadians(double degrees) => degrees * pi / 180.0;
}
