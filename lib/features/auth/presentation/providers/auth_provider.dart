import 'package:flutter/material.dart';
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

  AuthState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

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
        notifyListeners();
      },
      (user) {
        _state = AuthState.authenticated;
        _user = user;
        _errorMessage = null;
        notifyListeners();
      },
    );
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
      (_) {
        _state = AuthState.unauthenticated;
        _user = null;
        _errorMessage = null;
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
        notifyListeners();
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
        notifyListeners();
      },
    );
  }
}