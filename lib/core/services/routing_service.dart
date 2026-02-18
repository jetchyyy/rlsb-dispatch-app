import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class RoutingService {
  final Dio _dio = Dio();

  // Using OSRM public demo server
  // Note: For high-volume production, you should host your own OSRM instance
  static const String _baseUrl = 'http://router.project-osrm.org/route/v1';

  Future<Map<String, dynamic>?> getRoute(LatLng start, LatLng end) async {
    try {
      final startCoord = '${start.longitude},${start.latitude}';
      final endCoord = '${end.longitude},${end.latitude}';

      // Request driving route with full geometry overview
      final url =
          '$_baseUrl/driving/$startCoord;$endCoord?overview=full&geometries=geojson';

      debugPrint('🗺️ Fetching route: $url');

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];

          // Parse geometry (GeoJSON format: [lon, lat])
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;
          final points = coordinates.map((coord) {
            return LatLng(
                (coord[1] as num).toDouble(), (coord[0] as num).toDouble());
          }).toList();

          return {
            'points': points,
            'distance': (route['distance'] as num).toDouble(), // meters
            'duration': (route['duration'] as num).toDouble(), // seconds
          };
        }
      }
    } catch (e) {
      debugPrint('❌ Routing error: $e');
    }
    return null;
  }
}
