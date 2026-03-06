import 'dart:math';

/// A 2D Kalman filter for GPS position smoothing.
///
/// Uses a constant velocity model with state vector:
/// [latitude, longitude, velocity_lat, velocity_lng]
///
/// This filter predicts where the device should be based on its
/// current velocity, then corrects that prediction when a new GPS
/// measurement arrives. If the GPS measurement is wildly off from
/// the prediction (high residual), the filter trusts the prediction
/// more than the measurement.
class KalmanFilter2D {
  // State vector: [lat, lng, vel_lat, vel_lng]
  List<double> _state;
  
  // Error covariance matrix (4x4)
  List<List<double>> _P;
  
  // Process noise covariance (how much we expect state to change)
  final double _processNoise;
  
  // Base measurement noise (GPS accuracy baseline)
  final double _measurementNoiseBase;
  
  // Timestamp of last update
  DateTime? _lastUpdateTime;
  
  // Whether the filter has been initialized with a measurement
  bool _initialized = false;
  
  /// Creates a new Kalman filter for GPS smoothing.
  ///
  /// [processNoise] controls how responsive the filter is to changes.
  /// Higher values make it more responsive but less smooth.
  /// 
  /// [measurementNoiseBase] is the baseline GPS measurement noise.
  /// The actual noise is scaled by the reported GPS accuracy.
  KalmanFilter2D({
    double processNoise = 0.00001,
    double measurementNoiseBase = 0.00005,
  })  : _processNoise = processNoise,
        _measurementNoiseBase = measurementNoiseBase,
        _state = [0.0, 0.0, 0.0, 0.0],
        _P = _identity4x4();

  /// Whether the filter has been initialized with at least one measurement.
  bool get isInitialized => _initialized;
  
  /// Current estimated latitude.
  double get latitude => _state[0];
  
  /// Current estimated longitude.
  double get longitude => _state[1];
  
  /// Current estimated velocity in latitude direction (degrees/second).
  double get velocityLat => _state[2];
  
  /// Current estimated velocity in longitude direction (degrees/second).
  double get velocityLng => _state[3];
  
  /// Resets the filter to uninitialized state.
  void reset() {
    _initialized = false;
    _state = [0.0, 0.0, 0.0, 0.0];
    _P = _identity4x4();
    _lastUpdateTime = null;
  }
  
  /// Predicts the next state based on elapsed time.
  ///
  /// This uses a constant velocity model:
  /// new_position = old_position + velocity * dt
  void predict(double dt) {
    if (!_initialized || dt <= 0) return;
    
    // State transition matrix F (constant velocity model)
    // [1, 0, dt, 0 ]
    // [0, 1, 0,  dt]
    // [0, 0, 1,  0 ]
    // [0, 0, 0,  1 ]
    
    // Predict state: x = F * x
    final newLat = _state[0] + _state[2] * dt;
    final newLng = _state[1] + _state[3] * dt;
    _state[0] = newLat;
    _state[1] = newLng;
    // Velocities remain unchanged in prediction
    
    // Predict covariance: P = F * P * F' + Q
    // Simplified: add process noise to diagonal
    final q = _processNoise * dt * dt;
    _P[0][0] += q + _P[2][2] * dt * dt + 2 * _P[0][2] * dt;
    _P[1][1] += q + _P[3][3] * dt * dt + 2 * _P[1][3] * dt;
    _P[2][2] += q;
    _P[3][3] += q;
    
    // Cross terms
    _P[0][2] += _P[2][2] * dt;
    _P[2][0] = _P[0][2];
    _P[1][3] += _P[3][3] * dt;
    _P[3][1] = _P[1][3];
  }
  
  /// Updates the filter with a new GPS measurement.
  ///
  /// Returns a [KalmanResult] containing the smoothed position,
  /// the residual (difference between measurement and prediction),
  /// and a confidence score.
  ///
  /// [latitude] and [longitude] are the measured GPS coordinates.
  /// [accuracy] is the GPS-reported accuracy in meters.
  /// [timestamp] is when the measurement was taken.
  /// [sensorDisplacementLat] and [sensorDisplacementLng] are optional
  /// displacement estimates from accelerometer/gyroscope fusion.
  KalmanResult update({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
    double? sensorDisplacementLat,
    double? sensorDisplacementLng,
  }) {
    // First measurement: initialize state directly
    if (!_initialized) {
      _state[0] = latitude;
      _state[1] = longitude;
      _state[2] = 0.0;
      _state[3] = 0.0;
      _lastUpdateTime = timestamp;
      _initialized = true;
      
      // Set initial covariance based on accuracy
      final initialVariance = _accuracyToVariance(accuracy);
      _P = _identity4x4(scale: initialVariance);
      
      return KalmanResult(
        smoothedLatitude: latitude,
        smoothedLongitude: longitude,
        residualMeters: 0.0,
        confidence: 1.0,
        wasOutlier: false,
      );
    }
    
    // Calculate time delta
    final dt = timestamp.difference(_lastUpdateTime!).inMilliseconds / 1000.0;
    _lastUpdateTime = timestamp;
    
    // Skip if time delta is too small or negative
    if (dt <= 0.01) {
      return KalmanResult(
        smoothedLatitude: _state[0],
        smoothedLongitude: _state[1],
        residualMeters: 0.0,
        confidence: 0.5,
        wasOutlier: false,
      );
    }
    
    // Predict step
    predict(dt);
    
    // If we have sensor fusion data, incorporate it into prediction
    if (sensorDisplacementLat != null && sensorDisplacementLng != null) {
      // Weight sensor data based on how reasonable it is
      final sensorMagnitude = sqrt(
        sensorDisplacementLat * sensorDisplacementLat +
        sensorDisplacementLng * sensorDisplacementLng
      );
      // Only use sensor data if displacement is reasonable (< 100m)
      if (sensorMagnitude < 0.001) { // ~100m in degrees
        _state[0] += sensorDisplacementLat * 0.3; // 30% weight to sensors
        _state[1] += sensorDisplacementLng * 0.3;
      }
    }
    
    // Measurement noise R (scaled by GPS accuracy)
    final R = _accuracyToVariance(accuracy);
    
    // Innovation (measurement residual): y = z - H * x
    // H is [1,0,0,0; 0,1,0,0] - we only measure position, not velocity
    final innovationLat = latitude - _state[0];
    final innovationLng = longitude - _state[1];
    
    // Calculate residual in meters for outlier detection
    final residualMeters = _degreesToMeters(
      sqrt(innovationLat * innovationLat + innovationLng * innovationLng),
      _state[0],
    );
    
    // Innovation covariance: S = H * P * H' + R
    final S00 = _P[0][0] + R;
    final S11 = _P[1][1] + R;
    
    // --- Outlier Detection ---
    // If residual is too large relative to expected variance, it's an outlier
    // Mahalanobis distance threshold (chi-squared 95% for 2 DOF ≈ 5.99)
    final mahalanobisSquared = 
        (innovationLat * innovationLat / S00) + 
        (innovationLng * innovationLng / S11);
    final isOutlier = mahalanobisSquared > 9.21; // 99% threshold
    
    // Calculate confidence (inverse of normalized residual)
    final confidence = 1.0 / (1.0 + mahalanobisSquared / 5.99);
    
    // Kalman gain: K = P * H' * S^-1
    final K00 = _P[0][0] / S00;
    final K11 = _P[1][1] / S11;
    final K20 = _P[2][0] / S00;
    final K31 = _P[3][1] / S11;
    
    // If outlier, reduce Kalman gain (trust prediction more)
    final gainFactor = isOutlier ? 0.1 : 1.0;
    
    // Update state: x = x + K * y
    _state[0] += K00 * innovationLat * gainFactor;
    _state[1] += K11 * innovationLng * gainFactor;
    _state[2] += K20 * innovationLat * gainFactor;
    _state[3] += K31 * innovationLng * gainFactor;
    
    // Update covariance: P = (I - K * H) * P
    _P[0][0] *= (1 - K00 * gainFactor);
    _P[1][1] *= (1 - K11 * gainFactor);
    _P[2][0] *= (1 - K00 * gainFactor);
    _P[0][2] = _P[2][0];
    _P[3][1] *= (1 - K11 * gainFactor);
    _P[1][3] = _P[3][1];
    
    return KalmanResult(
      smoothedLatitude: _state[0],
      smoothedLongitude: _state[1],
      residualMeters: residualMeters,
      confidence: confidence,
      wasOutlier: isOutlier,
    );
  }
  
  /// Converts GPS accuracy (meters) to variance in degrees squared.
  double _accuracyToVariance(double accuracyMeters) {
    // 1 degree ≈ 111,000 meters at equator
    // variance = (accuracy_in_degrees)^2
    final accuracyDegrees = accuracyMeters / 111000.0;
    return _measurementNoiseBase + accuracyDegrees * accuracyDegrees;
  }
  
  /// Converts distance in degrees to approximate meters.
  double _degreesToMeters(double degrees, double atLatitude) {
    // Adjust for latitude (longitude degrees are smaller near poles)
    final metersPerDegree = 111000.0 * cos(atLatitude * pi / 180.0);
    return degrees * metersPerDegree;
  }
  
  /// Creates a 4x4 identity matrix, optionally scaled.
  static List<List<double>> _identity4x4({double scale = 1.0}) {
    return [
      [scale, 0.0, 0.0, 0.0],
      [0.0, scale, 0.0, 0.0],
      [0.0, 0.0, scale, 0.0],
      [0.0, 0.0, 0.0, scale],
    ];
  }
}

/// Result of a Kalman filter update.
class KalmanResult {
  /// The smoothed latitude after filtering.
  final double smoothedLatitude;
  
  /// The smoothed longitude after filtering.
  final double smoothedLongitude;
  
  /// The residual (difference between measurement and prediction) in meters.
  final double residualMeters;
  
  /// Confidence score from 0 to 1 (1 = high confidence, 0 = outlier).
  final double confidence;
  
  /// Whether this measurement was detected as an outlier.
  final bool wasOutlier;
  
  const KalmanResult({
    required this.smoothedLatitude,
    required this.smoothedLongitude,
    required this.residualMeters,
    required this.confidence,
    required this.wasOutlier,
  });
  
  @override
  String toString() => 'KalmanResult('
      'lat: ${smoothedLatitude.toStringAsFixed(6)}, '
      'lng: ${smoothedLongitude.toStringAsFixed(6)}, '
      'residual: ${residualMeters.toStringAsFixed(1)}m, '
      'confidence: ${(confidence * 100).toStringAsFixed(0)}%, '
      'outlier: $wasOutlier)';
}
