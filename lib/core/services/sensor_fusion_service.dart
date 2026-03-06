import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Service for fusing accelerometer and gyroscope data to estimate
/// device movement between GPS fixes.
///
/// Uses dead reckoning: integrates acceleration to get velocity,
/// then velocity to get displacement. This provides short-term
/// position estimates that help the Kalman filter detect GPS outliers.
///
/// Limitations:
/// - Drift accumulates over time (reset periodically with GPS)
/// - Assumes phone orientation is relatively stable
/// - Works best when device is in pocket/hand during walking/running
class SensorFusionService extends ChangeNotifier {
  // Sensor subscriptions
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  
  // Low-pass filter state for accelerometer
  double _filteredAccelX = 0.0;
  double _filteredAccelY = 0.0;
  double _filteredAccelZ = 0.0;
  
  // Velocity estimates (m/s) in device frame
  double _velocityX = 0.0;
  double _velocityY = 0.0;
  
  // Displacement since last GPS fix (meters)
  double _displacementNorth = 0.0;
  double _displacementEast = 0.0;
  
  // Device heading from gyroscope integration (radians)
  double _heading = 0.0;
  
  // Timestamps
  DateTime? _lastAccelTime;
  DateTime? _lastGyroTime;
  DateTime? _lastResetTime;
  
  // Configuration
  static const double _lowPassAlpha = 0.1; // Smoothing factor (0-1)
  static const double _noiseThreshold = 0.3; // Ignore accelerations below this
  static const double _maxVelocity = 15.0; // Cap velocity at ~54 km/h
  static const double _velocityDecay = 0.95; // Velocity decay per update (drag)
  
  /// Whether the service is currently running.
  bool _isRunning = false;
  bool get isRunning => _isRunning;
  
  /// Current estimated displacement north since last reset (meters).
  double get displacementNorth => _displacementNorth;
  
  /// Current estimated displacement east since last reset (meters).
  double get displacementEast => _displacementEast;
  
  /// Total displacement magnitude since last reset (meters).
  double get totalDisplacement => sqrt(
    _displacementNorth * _displacementNorth + 
    _displacementEast * _displacementEast
  );
  
  /// Current heading in radians (0 = initial heading).
  double get heading => _heading;
  
  /// Time since last reset.
  Duration get timeSinceReset => _lastResetTime != null 
      ? DateTime.now().difference(_lastResetTime!) 
      : Duration.zero;
  
  /// Starts listening to accelerometer and gyroscope sensors.
  void start() {
    if (_isRunning) return;
    
    _isRunning = true;
    _resetState();
    
    // Subscribe to accelerometer (user acceleration)
    _accelSubscription = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20), // 50 Hz
    ).listen(_onAccelerometerEvent, onError: (e) {
      debugPrint('🔧 Accelerometer error: $e');
    });
    
    // Subscribe to gyroscope
    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 20), // 50 Hz
    ).listen(_onGyroscopeEvent, onError: (e) {
      debugPrint('🔧 Gyroscope error: $e');
    });
    
    debugPrint('🔧 SensorFusionService started');
  }
  
  /// Stops listening to sensors.
  void stop() {
    if (!_isRunning) return;
    
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;
    
    _isRunning = false;
    debugPrint('🔧 SensorFusionService stopped');
  }
  
  /// Resets displacement and velocity estimates.
  /// Call this after each GPS fix to prevent drift accumulation.
  void resetDisplacement() {
    _displacementNorth = 0.0;
    _displacementEast = 0.0;
    _velocityX = 0.0;
    _velocityY = 0.0;
    _lastResetTime = DateTime.now();
    debugPrint('🔧 Displacement reset');
  }
  
  /// Gets displacement in lat/lng degrees since last reset.
  /// 
  /// Returns a record with (latDelta, lngDelta) in degrees.
  /// These values can be added to the last known GPS position
  /// to estimate current position.
  ({double latDelta, double lngDelta}) getDisplacementDegrees(double atLatitude) {
    // Convert meters to degrees
    // 1 degree latitude ≈ 111,000 meters
    // 1 degree longitude ≈ 111,000 * cos(latitude) meters
    const metersPerDegreeLat = 111000.0;
    final metersPerDegreeLng = 111000.0 * cos(atLatitude * pi / 180.0);
    
    return (
      latDelta: _displacementNorth / metersPerDegreeLat,
      lngDelta: _displacementEast / metersPerDegreeLng,
    );
  }
  
  void _resetState() {
    _filteredAccelX = 0.0;
    _filteredAccelY = 0.0;
    _filteredAccelZ = 0.0;
    _velocityX = 0.0;
    _velocityY = 0.0;
    _displacementNorth = 0.0;
    _displacementEast = 0.0;
    _heading = 0.0;
    _lastAccelTime = null;
    _lastGyroTime = null;
    _lastResetTime = DateTime.now();
  }
  
  void _onAccelerometerEvent(UserAccelerometerEvent event) {
    final now = DateTime.now();
    
    if (_lastAccelTime == null) {
      _lastAccelTime = now;
      _filteredAccelX = event.x;
      _filteredAccelY = event.y;
      _filteredAccelZ = event.z;
      return;
    }
    
    // Time delta in seconds
    final dt = now.difference(_lastAccelTime!).inMicroseconds / 1000000.0;
    _lastAccelTime = now;
    
    // Skip if time delta is unreasonable
    if (dt <= 0 || dt > 0.5) return;
    
    // Low-pass filter to remove noise
    _filteredAccelX = _lowPassAlpha * event.x + (1 - _lowPassAlpha) * _filteredAccelX;
    _filteredAccelY = _lowPassAlpha * event.y + (1 - _lowPassAlpha) * _filteredAccelY;
    _filteredAccelZ = _lowPassAlpha * event.z + (1 - _lowPassAlpha) * _filteredAccelZ;
    
    // Use horizontal acceleration (X and Y in device frame)
    // Ignore Z as it's mostly gravity
    double accelX = _filteredAccelX;
    double accelY = _filteredAccelY;
    
    // Apply noise threshold
    if (accelX.abs() < _noiseThreshold) accelX = 0;
    if (accelY.abs() < _noiseThreshold) accelY = 0;
    
    // Integrate acceleration to velocity (trapezoidal rule simplified)
    _velocityX += accelX * dt;
    _velocityY += accelY * dt;
    
    // Apply velocity decay (simulates friction/drag, prevents runaway integration)
    _velocityX *= _velocityDecay;
    _velocityY *= _velocityDecay;
    
    // Cap velocity
    final speed = sqrt(_velocityX * _velocityX + _velocityY * _velocityY);
    if (speed > _maxVelocity) {
      final scale = _maxVelocity / speed;
      _velocityX *= scale;
      _velocityY *= scale;
    }
    
    // Transform device velocity to world frame using heading
    // North = Y axis rotated by heading
    final cosH = cos(_heading);
    final sinH = sin(_heading);
    final velocityNorth = _velocityY * cosH - _velocityX * sinH;
    final velocityEast = _velocityY * sinH + _velocityX * cosH;
    
    // Integrate velocity to displacement
    _displacementNorth += velocityNorth * dt;
    _displacementEast += velocityEast * dt;
  }
  
  void _onGyroscopeEvent(GyroscopeEvent event) {
    final now = DateTime.now();
    
    if (_lastGyroTime == null) {
      _lastGyroTime = now;
      return;
    }
    
    // Time delta in seconds
    final dt = now.difference(_lastGyroTime!).inMicroseconds / 1000000.0;
    _lastGyroTime = now;
    
    // Skip if time delta is unreasonable
    if (dt <= 0 || dt > 0.5) return;
    
    // Integrate Z-axis rotation (yaw) to heading
    // event.z is rotation rate around vertical axis in rad/s
    _heading += event.z * dt;
    
    // Normalize heading to [-pi, pi]
    while (_heading > pi) _heading -= 2 * pi;
    while (_heading < -pi) _heading += 2 * pi;
  }
  
  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
