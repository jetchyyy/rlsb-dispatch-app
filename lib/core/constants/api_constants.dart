class ApiConstants {
  ApiConstants._();

  // Base URL — points to the Laravel API
  static const String baseUrl = 'https://pdrrmosdn-sandbox.inno.ph/api';

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
  static const Duration passiveTrackingInterval = Duration(minutes: 5);
  static const Duration activeTrackingInterval = Duration(seconds: 5);
  static const Duration batchFlushInterval = Duration(seconds: 30);

  // Hive Box Names
  static const String locationQueueBox = 'location_queue';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}