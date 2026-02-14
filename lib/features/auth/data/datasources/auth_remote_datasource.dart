import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login({
    required String email,
    required String password,
  });

  Future<void> logout();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl(this.apiClient);

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      // MOCK IMPLEMENTATION - Replace with real API call later
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Mock validation
      if (email == 'admin@test.com' && password == '123456') {
        return UserModel(
          id: 1,
          name: 'Super Admin',
          email: email,
          role: 'superadmin',
          token: 'mock_token_superadmin_${DateTime.now().millisecondsSinceEpoch}',
        );
      } else if (email == 'staff@test.com' && password == '123456') {
        return UserModel(
          id: 2,
          name: 'Staff User',
          email: email,
          role: 'staff',
          token: 'mock_token_staff_${DateTime.now().millisecondsSinceEpoch}',
        );
      } else {
        throw AuthException(message: 'Invalid email or password');
      }

      // Real API implementation (commented out for now)
      /*
      final response = await apiClient.post(
        ApiConstants.loginEndpoint,
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data['data']);
      } else {
        throw ServerException(
          message: response.data['message'] ?? 'Login failed',
          statusCode: response.statusCode,
        );
      }
      */
    } catch (e) {
      if (e is AuthException) {
        rethrow;
      }
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      // MOCK IMPLEMENTATION - Replace with real API call later
      await Future.delayed(const Duration(milliseconds: 500));

      // Real API implementation (commented out for now)
      /*
      await apiClient.post(ApiConstants.logoutEndpoint);
      */
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}