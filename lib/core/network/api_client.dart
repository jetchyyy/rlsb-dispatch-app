import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class ApiClient {
  late final Dio _dio;
  final SharedPreferences prefs;

  ApiClient(this.prefs) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout:
            const Duration(milliseconds: ApiConstants.connectTimeout),
        receiveTimeout:
            const Duration(milliseconds: ApiConstants.receiveTimeout),
        sendTimeout: const Duration(milliseconds: ApiConstants.sendTimeout),
        headers: {
          ApiConstants.accept: ApiConstants.applicationJson,
          ApiConstants.contentType: ApiConstants.applicationJson,
        },
      ),
    );

    // ── Bearer token interceptor ──────────────────────────────
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = prefs.getString(ApiConstants.tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers[ApiConstants.authorization] =
                '${ApiConstants.bearer} $token';
          }
          return handler.next(options);
        },
        // Note: We don't remove tokens on 401 here.
        // The IncidentProvider and other providers handle 401 errors
        // and trigger proper logout through AuthProvider if needed.
      ),
    );

    // ── Debug logging ─────────────────────────────────────────
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get(path,
        queryParameters: queryParameters, options: options);
  }

  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post(path,
        data: data, queryParameters: queryParameters, options: options);
  }

  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put(path,
        data: data, queryParameters: queryParameters, options: options);
  }

  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete(path,
        data: data, queryParameters: queryParameters, options: options);
  }
}