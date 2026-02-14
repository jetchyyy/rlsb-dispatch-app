import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class TokenStorage {
  final FlutterSecureStorage _secureStorage;

  TokenStorage(this._secureStorage);

  // Save token
  Future<void> saveToken(String token) async {
    await _secureStorage.write(
      key: ApiConstants.tokenKey,
      value: token,
    );
  }

  // Get token
  Future<String?> getToken() async {
    return await _secureStorage.read(key: ApiConstants.tokenKey);
  }

  // Delete token
  Future<void> deleteToken() async {
    await _secureStorage.delete(key: ApiConstants.tokenKey);
  }

  // Save user data
  Future<void> saveUserData(String userData) async {
    await _secureStorage.write(
      key: ApiConstants.userKey,
      value: userData,
    );
  }

  // Get user data
  Future<String?> getUserData() async {
    return await _secureStorage.read(key: ApiConstants.userKey);
  }

  // Delete user data
  Future<void> deleteUserData() async {
    await _secureStorage.delete(key: ApiConstants.userKey);
  }

  // Clear all data
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }

  // Check if token exists
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}