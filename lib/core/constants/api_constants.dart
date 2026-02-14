class ApiConstants {
  ApiConstants._();

  // Base URL (will be used when connecting to Laravel)
  static const String baseUrl = 'https://your-laravel-api.com/api';

  // Auth Endpoints
  static const String loginEndpoint = '/login';
  static const String logoutEndpoint = '/logout';
  static const String refreshTokenEndpoint = '/refresh';

  // Dispatch Endpoints
  static const String dispatchListEndpoint = '/dispatches';
  static String dispatchDetailEndpoint(int id) => '/dispatches/$id';

  // Headers
  static const String contentType = 'Content-Type';
  static const String applicationJson = 'application/json';
  static const String authorization = 'Authorization';
  static const String bearer = 'Bearer';

  // Timeout
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
  static const int sendTimeout = 30000; // 30 seconds

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}