class ApiConstants {
  ApiConstants._();

  // Base URL
  static const String baseUrl = 'https://your-laravel-api.com';

  // Auth Endpoints
  static const String login = '/api/responder/login';
  static const String logout = '/api/responder/logout';
  static const String profile = '/api/responder/profile';

  // Location
  static const String updateLocation = '/api/responder/location';

  // Assignments
  static const String assignments = '/api/responder/assignments';
  static String acceptAssignment(int id) =>
      '/api/responder/assignments/$id/accept';
  static String rejectAssignment(int id) =>
      '/api/responder/assignments/$id/reject';
  static String updateAssignmentStatus(int id) =>
      '/api/responder/assignments/$id/status';

  // Incidents
  static String incidentDetail(int id) => '/api/responder/incidents/$id';
  static String injuryReport(int id) =>
      '/api/responder/incidents/$id/injury-report';

  // Headers
  static const String contentType = 'Content-Type';
  static const String applicationJson = 'application/json';
  static const String authorization = 'Authorization';
  static const String bearer = 'Bearer';

  // Timeout (milliseconds)
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
  static const int sendTimeout = 30000;

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}