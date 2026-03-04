import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persistent map tile cache for online/offline responder navigation.
///
/// This stores OpenStreetMap tiles on disk so map rendering can continue
/// when the device loses connectivity.
class MapPreloader {
  static final MapPreloader _instance = MapPreloader._internal();
  factory MapPreloader() => _instance;
  MapPreloader._internal();

  static const String _tileServerBase = 'https://tile.openstreetmap.org';
  static const String _cacheDirName = 'map_tiles';
  static const String _packageName = 'ph.inno.sdnpdrrmo.dispatch';

  // Surigao del Norte bounds
  static const _minLat = 9.4;
  static const _maxLat = 10.5;
  static const _minLng = 125.0;
  static const _maxLng = 126.2;

  // Center point
  static const _centerLat = 9.85;
  static const _centerLng = 125.55;

  bool _isPreloaded = false;
  bool _isPreloading = false;

  bool get isPreloaded => _isPreloaded;

  Future<Directory> _cacheRoot() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_cacheDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String tileUrl(int z, int x, int y) => '$_tileServerBase/$z/$x/$y.png';

  Future<String> localTilePath(int z, int x, int y) async {
    final root = await _cacheRoot();
    return '${root.path}/$z/$x/$y.png';
  }

  Future<String> localTileUrlTemplate() async {
    final root = await _cacheRoot();
    return '${Uri.directory(root.path).toString()}{z}/{x}/{y}.png';
  }

  Future<bool> hasAnyCachedTiles() async {
    final root = await _cacheRoot();
    if (!await root.exists()) return false;
    await for (final entity in root.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.png')) {
        return true;
      }
    }
    return false;
  }

  /// Best effort connectivity probe against tile server.
  Future<bool> canReachTileServer() async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
      headers: {'User-Agent': _packageName},
    ));
    try {
      await dio.get(tileUrl(11, 1935, 1022));
      return true;
    } catch (_) {
      return false;
    } finally {
      dio.close();
    }
  }

  /// Download and persist a practical tile pack for the responder area.
  Future<void> preloadTiles() async {
    if (_isPreloaded || _isPreloading) return;
    _isPreloading = true;

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'User-Agent': _packageName},
    ));

    try {
      final queue = <Future<void>>[];
      for (final zoom in [9, 10, 11, 12]) {
        final tiles = _getTilesForBounds(
          minLat: _minLat,
          maxLat: _maxLat,
          minLng: _minLng,
          maxLng: _maxLng,
          zoom: zoom,
        );

        tiles.sort((a, b) => a.distanceTo(_centerLat, _centerLng, zoom)
            .compareTo(b.distanceTo(_centerLat, _centerLng, zoom)));

        final maxTiles = zoom == 12 ? 40 : 70;
        for (final tile in tiles.take(maxTiles)) {
          queue.add(_downloadTileIfMissing(dio, tile.x, tile.y, zoom));
        }
      }

      await Future.wait(queue, eagerError: false);
      _isPreloaded = true;
      if (kDebugMode) {
        debugPrint('MapPreloader: tile pack is ready for offline fallback');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MapPreloader: preload failed (non-fatal): $e');
      }
    } finally {
      dio.close();
      _isPreloading = false;
    }
  }

  Future<void> _downloadTileIfMissing(Dio dio, int x, int y, int z) async {
    try {
      final filePath = await localTilePath(z, x, y);
      final file = File(filePath);
      if (await file.exists()) return;

      await file.parent.create(recursive: true);
      final response = await dio.get<List<int>>(
        tileUrl(z, x, y),
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes != null && bytes.isNotEmpty) {
        await file.writeAsBytes(bytes, flush: true);
      }
    } catch (_) {
      // Ignore individual tile failures. We only need a useful partial cache.
    }
  }

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

  _TileCoord _latLngToTile(double lat, double lng, int zoom) {
    final n = 1 << zoom;
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

  double distanceTo(double lat, double lng, int zoom) {
    final n = 1 << zoom;
    final tileLng = (x / n) * 360.0 - 180.0;
    final t = math.pi - (2.0 * math.pi * y) / n;
    final tileLat =
        180.0 / math.pi * math.atan(0.5 * (math.exp(t) - math.exp(-t)));
    final dLat = tileLat - lat;
    final dLng = tileLng - lng;
    return dLat * dLat + dLng * dLng;
  }
}
