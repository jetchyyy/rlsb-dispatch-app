import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';

/// Singleton Dio HTTP client with Bearer token interceptor and 401 auto-logout.
class ApiService {
  static ApiService? _instance;
  late final Dio _dio;

  /// Callback invoked when a 401 is received — triggers logout.
  VoidCallback? onUnauthorized;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
        sendTimeout: const Duration(milliseconds: ApiConstants.sendTimeout),
        headers: {
          ApiConstants.contentType: ApiConstants.applicationJson,
        },
      ),
    );

    // ── Request Interceptor ──────────────────────────────────
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(ApiConstants.tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers[ApiConstants.authorization] =
                '${ApiConstants.bearer} $token';
          }
          return handler.next(options);
        },

        // ── Response Interceptor ─────────────────────────────
        onResponse: (response, handler) {
          return handler.next(response);
        },

        // ── Error Interceptor ────────────────────────────────
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            // Clear stored token
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(ApiConstants.tokenKey);
            await prefs.remove(ApiConstants.userKey);

            // Trigger logout callback
            onUnauthorized?.call();
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Returns the singleton instance.
  factory ApiService() {
    _instance ??= ApiService._internal();
    return _instance!;
  }

  /// Underlying Dio instance for direct use if needed.
  Dio get dio => _dio;

  // ── Convenience wrappers ───────────────────────────────────

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post(path,
        data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put(path,
        data: data, queryParameters: queryParameters, options: options);
  }

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
