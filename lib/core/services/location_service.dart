import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

/// Wrapper around the Geolocator package for GPS location updates.
class LocationService {
  /// Checks and requests foreground location permission.
  /// Returns `true` if permission is granted.
  Future<bool> ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('📍 Location services disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('📍 Location permission denied');
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      debugPrint('📍 Location permission permanently denied');
      return false;
    }

    debugPrint('📍 Location permission granted');
    return true;
  }

  /// Requests background location ("always") permission.
  /// Must be called AFTER [ensurePermission] grants foreground access.
  /// On Android 10+ this triggers the separate "Allow all the time" prompt.
  Future<bool> requestBackgroundPermission() async {
    final status =
        await permission_handler.Permission.locationAlways.request();
    final granted = status.isGranted;
    debugPrint(
        '📍 Background location permission: ${granted ? "granted" : "denied ($status)"}');
    return granted;
  }

  /// Whether background location permission is currently granted.
  Future<bool> hasBackgroundPermission() async {
    final status =
        await permission_handler.Permission.locationAlways.status;
    return status.isGranted;
  }

  /// Returns the current device position.
  Future<Position> getCurrentPosition() async {
    final hasPermission = await ensurePermission();
    if (!hasPermission) {
      throw Exception('Location permission not granted');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Streams position updates at [distanceFilter] metre intervals.
  Stream<Position> getPositionStream({int distanceFilter = 10}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Calculates distance in metres between two coordinates.
  double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
