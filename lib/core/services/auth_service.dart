import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../models/responder.dart';
import 'api_service.dart';

/// Handles authentication: login, logout, token storage.
class AuthService {
  final ApiService _api = ApiService();

  // ── Login ──────────────────────────────────────────────────

  /// Authenticates with [email] and [password].
  /// Returns [Responder] on success.
  Future<Responder> login(String email, String password) async {
    final response = await _api.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );

    final data = response.data as Map<String, dynamic>;

    // Check if API returned success:false
    if (data['success'] == false) {
      throw Exception(data['message'] ?? 'Login failed');
    }

    // Extract token - try different possible keys
    final token = (data['token'] ?? data['access_token']) as String?;
    if (token == null) {
      throw Exception('No authentication token received from server');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConstants.tokenKey, token);

    // Extract user/responder data - try different possible structures
    Map<String, dynamic>? userData;
    if (data['responder'] != null) {
      userData = data['responder'] as Map<String, dynamic>;
    } else if (data['user'] != null) {
      userData = data['user'] as Map<String, dynamic>;
    } else if (data['data'] != null && data['data']['user'] != null) {
      userData = data['data']['user'] as Map<String, dynamic>;
    } else if (data['data'] != null && data['data']['responder'] != null) {
      userData = data['data']['responder'] as Map<String, dynamic>;
    } else {
      throw Exception('No user data received from server');
    }

    // Parse and store responder
    final responder = Responder.fromJson(userData);
    await prefs.setString(ApiConstants.userKey, jsonEncode(responder.toJson()));

    return responder;
  }

  // ── Logout ─────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _api.post(ApiConstants.logout);
    } on DioException catch (_) {
      // Even if the API call fails, we still clear local data.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.tokenKey);
    await prefs.remove(ApiConstants.userKey);
  }

  // ── Token validation ───────────────────────────────────────

  /// Checks if a stored token exists and fetches the current profile.
  /// Returns `null` if the token is missing or invalid.
  Future<Responder?> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConstants.tokenKey);
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _api.get(ApiConstants.profile);
      final data = response.data as Map<String, dynamic>;
      final responder = Responder.fromJson(
        data['responder'] as Map<String, dynamic>? ?? data,
      );
      await prefs.setString(
          ApiConstants.userKey, jsonEncode(responder.toJson()));
      return responder;
    } on DioException catch (_) {
      return null;
    }
  }

  // ── Stored token helper ────────────────────────────────────

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(ApiConstants.tokenKey);
  }
}
