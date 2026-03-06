class ApiConstants {
  ApiConstants._();

  // Base URL — points to the Laravel API
  static const String baseUrl = 'https://sdnpdrrmo.inno.ph/api';
  
  // Storage URL — points to the Laravel storage folder for PDF files and media
  static const String storageBaseUrl = 'https://sdnpdrrmo.inno.ph/storage';

  // Auth Endpoints (authenticates against the 'users' table)
  static const String loginEndpoint = '/login';
  static const String logoutEndpoint = '/logout';
  static const String profileEndpoint = '/web/user';

  // Incident Endpoints
  static const String incidentsEndpoint = '/incidents';
  static String incidentDetail(int id) => '/incidents/$id';
  
  // Incident Action Endpoints
  static String incidentAcknowledge(int id) => '/incidents/$id/acknowledge';
  static String incidentRespond(int id) => '/incidents/$id/respond';
  static String incidentOnScene(int id) => '/incidents/$id/on-scene';
  static String incidentResolve(int id) => '/incidents/$id/resolve';
  static String incidentClose(int id) => '/incidents/$id/close';
  static String incidentCancel(int id) => '/incidents/$id/cancel';

  // Emergency Incident Endpoints
  static const String emergencyIncidents = '/emergency-incidents';
  static const String emergencyIncidentStats = '/emergency-incidents/statistics';
  static const String emergencyCitizenMapping = '/emergency-incidents/citizen-mapping-data';
  static String emergencyIncidentDetail(int id) => '/emergency-incidents/$id';
  static String emergencyLocationUpdates(int id) => '/emergency-incidents/$id/location-updates';
  static String emergencyUpdateStatus(int id) => '/emergency-incidents/$id/update-status';
  static String emergencyAssign(int id) => '/emergency-incidents/$id/assign';

  // Staff Chat Endpoints
  static String staffChatSend(int id) => '/staff/incidents/$id/chat/send';
  static String staffChatMessages(int id) => '/staff/incidents/$id/chat/messages';
  static String staffChatPoll(int id) => '/staff/incidents/$id/chat/poll';
  static const String staffChatPollAll = '/staff/chat/poll-all';

  // Location Endpoints
  static const String locationUpdate = '/location/update';
  static const String locationBatchUpdate = '/location/batch-update';
  static const String locationHistory = '/location/history';
  static const String locationSharingStatus = '/location/sharing-status';
  static const String locationToggleSharing = '/location/toggle-sharing';

  // Injury Report Endpoints
  static String injuryReport(int incidentId) => '/incidents/$incidentId/injury-report';

  // E-Street Form Endpoints
  static String eStreetForm(int incidentId) => '/incidents/$incidentId/e-street-form';

  // Pre-Dispatch Checklist Endpoints
  static const String preDispatchChecklistsEndpoint = '/pre-dispatch-checklists';

  // Pre-Logout Turnover Endpoints
  static const String preLogoutTurnoversEndpoint = '/pre-logout-turnovers';

  // Headers
  static const String contentType = 'Content-Type';
  static const String accept = 'Accept';
  static const String applicationJson = 'application/json';
  static const String authorization = 'Authorization';
  static const String bearer = 'Bearer';

  // Timeout (milliseconds)
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
  static const int sendTimeout = 30000;

  // Location Tracking Intervals
  static const Duration passiveTrackingInterval = Duration(seconds: 10);
  static const Duration activeTrackingInterval = Duration(seconds: 5);
  static const Duration batchFlushInterval = Duration(seconds: 30);

  // Location Accuracy Thresholds
  /// Maximum acceptable GPS accuracy in meters. Positions with worse accuracy are rejected.
  /// Reduced from 50m to 20m to prevent jittery GPS readings.
  static const double maxAccuracyMeters = 20.0;
  /// Minimum distance in meters before sending a new location update (prevents jitter).
  static const double minDistanceMeters = 5.0;
  /// Minimum time in seconds between location captures (prevents rapid duplicate points).
  static const int minTimeDeltaSeconds = 3;
  /// Maximum number of locations to send in a single batch request.
  static const int batchChunkSize = 50;

  // Kalman Filter / GPS Smoothing Constants
  /// Kalman filter process noise. Higher = more responsive, less smooth.
  static const double kalmanProcessNoise = 0.00001;
  /// Kalman filter base measurement noise. Scaled by GPS accuracy.
  static const double kalmanMeasurementNoise = 0.00005;
  /// Douglas-Peucker path simplification epsilon (meters).
  /// Points within this distance of the simplified line are removed.
  static const double pathSimplificationEpsilon = 5.0;
  /// Maximum reasonable speed in m/s for outlier detection (~180 km/h).
  static const double maxReasonableSpeedMs = 50.0;
  /// Minimum confidence score from Kalman filter to accept a measurement.
  /// Below this, the smoothed/predicted position is used instead.
  static const double minKalmanConfidence = 0.3;

  // Hive Box Names
  static const String locationQueueBox = 'location_queue';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}
