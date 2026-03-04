import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';

class RoutingService {
  RoutingService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ));

  static const String _baseUrl = 'http://router.project-osrm.org/route/v1';
  static const String _routeCacheBox = 'route_cache_box';
  static const String _cacheVersion = 'v1';

  final Dio _dio;
  final Distance _distance = const Distance();

  Future<Box<String>> _openCacheBox() async {
    if (Hive.isBoxOpen(_routeCacheBox)) {
      return Hive.box<String>(_routeCacheBox);
    }
    return Hive.openBox<String>(_routeCacheBox);
  }

  String _coordKey(LatLng value) {
    final lat = value.latitude.toStringAsFixed(5);
    final lng = value.longitude.toStringAsFixed(5);
    return '$lat,$lng';
  }

  String _cacheKey(LatLng start, LatLng end) {
    return '$_cacheVersion:${_coordKey(start)}->${_coordKey(end)}';
  }

  Future<void> _saveRouteToCache(
      LatLng start, LatLng end, Map<String, dynamic> route) async {
    try {
      final box = await _openCacheBox();
      final points = (route['points'] as List<LatLng>)
          .map((p) => [p.latitude, p.longitude])
          .toList();
      final payload = <String, dynamic>{
        'points': points,
        'distance': route['distance'],
        'duration': route['duration'],
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      };
      await box.put(_cacheKey(start, end), jsonEncode(payload));
    } catch (e) {
      debugPrint('RoutingService: failed to cache route: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadCachedRoute(LatLng start, LatLng end) async {
    try {
      final box = await _openCacheBox();
      final raw = box.get(_cacheKey(start, end));
      if (raw == null) return null;

      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final pts = (payload['points'] as List)
          .map((e) => e as List)
          .map((pair) => LatLng(
                (pair[0] as num).toDouble(),
                (pair[1] as num).toDouble(),
              ))
          .toList();
      if (pts.isEmpty) return null;

      return {
        'points': pts,
        'distance': (payload['distance'] as num).toDouble(),
        'duration': (payload['duration'] as num).toDouble(),
        'source': 'cached',
      };
    } catch (e) {
      debugPrint('RoutingService: failed to load cache: $e');
      return null;
    }
  }

  Map<String, dynamic> _fallbackStraightRoute(LatLng start, LatLng end) {
    final meters = _distance(start, end);
    const averageSpeedMps = 9.7; // ~35km/h urban responder baseline
    final seconds = meters / averageSpeedMps;
    return {
      'points': [start, end],
      'distance': meters,
      'duration': seconds,
      'source': 'fallback',
    };
  }

  Future<Map<String, dynamic>?> _fetchOnlineRoute(LatLng start, LatLng end) async {
    final startCoord = '${start.longitude},${start.latitude}';
    final endCoord = '${end.longitude},${end.latitude}';
    final url =
        '$_baseUrl/driving/$startCoord;$endCoord?overview=full&geometries=geojson&alternatives=true';

    final response = await _dio.get(url);
    if (response.statusCode != 200) return null;

    final data = response.data;
    if (data['routes'] == null || (data['routes'] as List).isEmpty) return null;

    final route = (data['routes'] as List)
        .cast<Map<String, dynamic>>()
        .reduce((a, b) =>
            ((a['duration'] as num) <= (b['duration'] as num)) ? a : b);

    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List;
    final points = coordinates.map((coord) {
      return LatLng(
        (coord[1] as num).toDouble(),
        (coord[0] as num).toDouble(),
      );
    }).toList();

    if (points.isEmpty) return null;

    return {
      'points': points,
      'distance': (route['distance'] as num).toDouble(),
      'duration': (route['duration'] as num).toDouble(),
      'source': 'online',
    };
  }

  /// Returns route data with source:
  /// `online`, `cached`, or `fallback`.
  Future<Map<String, dynamic>?> getRoute(LatLng start, LatLng end) async {
    try {
      final online = await _fetchOnlineRoute(start, end);
      if (online != null) {
        await _saveRouteToCache(start, end, online);
        return online;
      }
    } catch (e) {
      debugPrint('RoutingService: online route failed: $e');
    }

    final cached = await _loadCachedRoute(start, end);
    if (cached != null) return cached;

    return _fallbackStraightRoute(start, end);
  }
}
