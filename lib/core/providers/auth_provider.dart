import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/responder.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// Manages authentication state across the app.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  bool _isAuthenticated = false;
  bool _isLoading = false;
  Responder? _responder;
  String? _token;
  String? _errorMessage;

  // ── Getters ────────────────────────────────────────────────

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  Responder? get responder => _responder;
  String? get token => _token;
  String? get errorMessage => _errorMessage;

  // ── Login ──────────────────────────────────────────────────

  /// Authenticates the responder with [email] and [password].
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _responder = await _authService.login(email, password);
      _token = await _authService.getToken();
      _isAuthenticated = true;

      // Register with OneSignal using responder ID
      await _notificationService
          .setExternalUserId(_responder!.id.toString());

      // Wire up 401 auto-logout
      ApiService().onUnauthorized = () => logout();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Logout ─────────────────────────────────────────────────

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      await _notificationService.removeExternalUserId();
    } catch (_) {
      // Proceed with local logout regardless.
    }

    _isAuthenticated = false;
    _responder = null;
    _token = null;
    _isLoading = false;
    notifyListeners();
  }

  // ── Check Auth on App Start ────────────────────────────────

  /// Reads stored token and validates against the API.
  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      _responder = await _authService.checkAuth();
      if (_responder != null) {
        _token = await _authService.getToken();
        _isAuthenticated = true;
        ApiService().onUnauthorized = () => logout();
        await _notificationService
            .setExternalUserId(_responder!.id.toString());
      } else {
        _isAuthenticated = false;
      }
    } catch (_) {
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────

  String _parseError(dynamic e) {
    // Handle DioException specifically
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Connection timeout. Please check your internet.';
      }
      
      if (e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }

      // HTTP errors
      final statusCode = e.response?.statusCode;
      if (statusCode != null) {
        switch (statusCode) {
          case 401:
            return 'Invalid email or password.';
          case 404:
            return 'Login endpoint not found. Please contact support.';
          case 422:
            // Validation error - try to get the message from response
            final data = e.response?.data;
            if (data is Map && data['message'] != null) {
              return data['message'].toString();
            }
            return 'Invalid credentials format.';
          case 500:
            return 'Server error. Please try again later.';
          default:
            return 'Login failed (Error $statusCode). Please try again.';
        }
      }

      // Other network errors
      if (e.message?.contains('SocketException') ?? false) {
        return 'Cannot reach server. Check your connection.';
      }

      return 'Network error: ${e.message ?? "Unknown error"}';
    }
    
    // Generic exception handling
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('401')) return 'Invalid email or password.';
      if (msg.contains('SocketException') || msg.contains('connection')) {
        return 'No internet connection.';
      }
      return 'Login failed. Please try again.';
    }
    
    return 'An unexpected error occurred.';
  }
}
