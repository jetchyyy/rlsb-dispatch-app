import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login_user.dart';
import '../../domain/usecases/logout_user.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final LoginUser loginUser;
  final LogoutUser logoutUser;

  AuthProvider({
    required this.loginUser,
    required this.logoutUser,
  });

  AuthState _state = AuthState.initial;
  User? _user;
  String? _errorMessage;
  bool _hasCompletedPreDispatch = false;

  AuthState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get hasCompletedPreDispatch => _hasCompletedPreDispatch;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  Future<void> _loadPreDispatchState() async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    _hasCompletedPreDispatch =
        prefs.getBool('has_completed_pre_dispatch_${_user!.id}') ?? false;
  }

  Future<void> completePreDispatch() async {
    if (_user == null) return;
    _hasCompletedPreDispatch = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_pre_dispatch_${_user!.id}', true);
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await loginUser(email: email, password: password);

    result.fold(
      (failure) {
        _state = AuthState.error;
        _errorMessage = failure.message;
        _user = null;
      },
      (user) {
        _state = AuthState.authenticated;
        _user = user;
        _errorMessage = null;
      },
    );

    if (_state == AuthState.authenticated) {
      await _loadPreDispatchState();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _state = AuthState.loading;
    notifyListeners();

    final result = await logoutUser();

    result.fold(
      (failure) {
        _state = AuthState.error;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (_) async {
        if (_user != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('has_completed_pre_dispatch_${_user!.id}');
        }
        _state = AuthState.unauthenticated;
        _user = null;
        _errorMessage = null;
        _hasCompletedPreDispatch = false;
        notifyListeners();
      },
    );
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Check if user is already logged in (on app startup)
  Future<void> checkAuthStatus() async {
    _state = AuthState.loading;
    notifyListeners();

    final result = await loginUser.repository.getCurrentUser();

    result.fold(
      (failure) {
        _state = AuthState.unauthenticated;
        _user = null;
      },
      (user) {
        if (user != null) {
          _state = AuthState.authenticated;
          _user = user;
          _errorMessage = null;
        } else {
          _state = AuthState.unauthenticated;
          _user = null;
        }
      },
    );

    if (_state == AuthState.authenticated) {
      await _loadPreDispatchState();
    }
    notifyListeners();
  }

  // Refresh user profile from backend
  Future<void> refreshProfile() async {
    debugPrint('🔄 Refreshing user profile from backend...');

    final result = await loginUser.repository.refreshUserProfile();

    result.fold(
      (failure) {
        debugPrint('❌ Failed to refresh profile: ${failure.message}');
        // Don't change auth state, just log the error
      },
      (user) {
        debugPrint('✅ Profile refreshed successfully');
        _user = user;
        notifyListeners();
      },
    );
  }
}
