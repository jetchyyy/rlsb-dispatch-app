import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class GeocodingService {
  final Dio _dio;

  GeocodingService({Dio? dio}) : _dio = dio ?? Dio();

  /// Fetch address from lat/lng using OpenStreetMap Nominatim API
  Future<String?> getAddress(double lat, double lng) async {
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
          'zoom': 18,
          'addressdetails': 1,
        },
        options: Options(
          headers: {
            'User-Agent': 'RLSBDispatchApp/1.0 (ph.inno.sdnpdrrmo.dispatch)',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          // Prioritize specific address fields
          final address = data['address'] as Map<String, dynamic>?;
          if (address != null) {
            final road = address['road'] ?? address['unknown'];
            final suburb = address['suburb'] ?? address['neighbourhood'];
            final city = address['city'] ?? address['town'] ?? address['village'];

            if (road != null) {
              return [road, suburb, city].where((e) => e != null).join(', ');
            }
          }
          return data['display_name'] as String?;
        }
      }
    } catch (e) {
      debugPrint('❌ Geocoding error: $e');
    }
    return null;
  }
}
