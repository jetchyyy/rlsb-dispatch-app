import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class TokenStorage {
  final FlutterSecureStorage _secureStorage;

  TokenStorage(this._secureStorage);

  // Save token to both secure storage and SharedPreferences for runtime access
  Future<void> saveToken(String token) async {
    await _secureStorage.write(
      key: ApiConstants.tokenKey,
      value: token,
    );
    
    // Also save to SharedPreferences for quick synchronous access by Dio interceptor
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConstants.tokenKey, token);
  }

  // Get token from secure storage
  Future<String?> getToken() async {
    return await _secureStorage.read(key: ApiConstants.tokenKey);
  }

  // Delete token from both storages
  Future<void> deleteToken() async {
    await _secureStorage.delete(key: ApiConstants.tokenKey);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.tokenKey);
  }

  // Save user data to both storages
  Future<void> saveUserData(String userData) async {
    await _secureStorage.write(
      key: ApiConstants.userKey,
      value: userData,
    );
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConstants.userKey, userData);
  }

  // Get user data from secure storage
  Future<String?> getUserData() async {
    return await _secureStorage.read(key: ApiConstants.userKey);
  }

  // Delete user data from both storages
  Future<void> deleteUserData() async {
    await _secureStorage.delete(key: ApiConstants.userKey);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.userKey);
  }

  // Clear all data from both storages
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.tokenKey);
    await prefs.remove(ApiConstants.userKey);
  }

  // Check if token exists in secure storage
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
  
  // Load token from secure storage to SharedPreferences (for app startup)
  Future<void> loadTokenToRuntime() async {
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.tokenKey, token);
    }
    
    final userData = await getUserData();
    if (userData != null && userData.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.userKey, userData);
    }
  }
}