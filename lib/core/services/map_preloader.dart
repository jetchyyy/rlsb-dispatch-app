import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Preloads OpenStreetMap tiles in the background for Surigao del Norte
/// to prevent jitter when opening the map.
class MapPreloader {
  static final MapPreloader _instance = MapPreloader._internal();
  factory MapPreloader() => _instance;
  MapPreloader._internal();

  bool _isPreloaded = false;
  bool _isPreloading = false;

  bool get isPreloaded => _isPreloaded;

  // Surigao del Norte bounds
  static const _minLat = 9.4;
  static const _maxLat = 10.5;
  static const _minLng = 125.0;
  static const _maxLng = 126.2;

  // Center point
  static const _centerLat = 9.85;
  static const _centerLng = 125.55;

  /// Preload tiles for zoom levels 9-12 around Surigao del Norte
  Future<void> preloadTiles() async {
    if (_isPreloaded || _isPreloading) return;
    _isPreloading = true;

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'User-Agent': 'ph.inno.sdnpdrrmo.dispatch'},
      ));
      final futures = <Future<void>>[];

      // Preload tiles at zoom levels 9, 10, 11 (most common views)
      for (final zoom in [9, 10, 11]) {
        final tiles = _getTilesForBounds(
          minLat: _minLat,
          maxLat: _maxLat,
          minLng: _minLng,
          maxLng: _maxLng,
          zoom: zoom,
        );

        // Limit to center tiles to avoid too many requests
        final limitedTiles = tiles.take(20).toList();

        for (final tile in limitedTiles) {
          futures.add(_preloadTile(dio, tile.x, tile.y, zoom));
        }
      }

      // Also preload center tiles at higher zoom
      final centerTiles12 = _getTilesForPoint(_centerLat, _centerLng, 12);
      for (final tile in centerTiles12.take(9)) {
        futures.add(_preloadTile(dio, tile.x, tile.y, 12));
      }

      // Run all preloads in parallel (but silently)
      await Future.wait(futures, eagerError: false);

      dio.close();
      _isPreloaded = true;

      if (kDebugMode) {
        print('🗺️ Map tiles preloaded successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Map preload error (non-fatal): $e');
      }
    } finally {
      _isPreloading = false;
    }
  }

  /// Preload a single tile (fire and forget)
  Future<void> _preloadTile(Dio dio, int x, int y, int z) async {
    try {
      final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
      await dio.get(url);
    } catch (_) {
      // Silently ignore individual tile failures
    }
  }

  /// Get tile coordinates for bounds at a given zoom level
  List<_TileCoord> _getTilesForBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int zoom,
  }) {
    final tiles = <_TileCoord>[];

    final minTile = _latLngToTile(maxLat, minLng, zoom); // NW corner
    final maxTile = _latLngToTile(minLat, maxLng, zoom); // SE corner

    for (int x = minTile.x; x <= maxTile.x; x++) {
      for (int y = minTile.y; y <= maxTile.y; y++) {
        tiles.add(_TileCoord(x, y));
      }
    }

    return tiles;
  }

  /// Get tiles around a center point
  List<_TileCoord> _getTilesForPoint(double lat, double lng, int zoom) {
    final center = _latLngToTile(lat, lng, zoom);
    final tiles = <_TileCoord>[];

    // 3x3 grid around center
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        tiles.add(_TileCoord(center.x + dx, center.y + dy));
      }
    }

    return tiles;
  }

  /// Convert lat/lng to tile coordinates
  _TileCoord _latLngToTile(double lat, double lng, int zoom) {
    final n = 1 << zoom; // 2^zoom
    final x = ((lng + 180.0) / 360.0 * n).floor();
    final latRad = lat * math.pi / 180.0;
    final y =
        ((1.0 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
                2.0 *
                n)
            .floor();
    return _TileCoord(x, y);
  }
}

class _TileCoord {
  final int x;
  final int y;
  _TileCoord(this.x, this.y);
}
