// lib/data/datasources/auth_remote_datasource.dart
import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
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
      final response = await apiClient.post(
        ApiConstants.loginEndpoint,
        data: {
          'email': email,
          'password': password,
        },
      );

      // Laravel returns: { success, message, data: { user, token, token_type } }
      if (response.data['success'] == true) {
        var userModel = UserModel.fromLoginJson(response.data);

        // Fetch full profile (roles, division, position, etc.)
        try {
          final profileResponse = await apiClient.get(
            ApiConstants.profileEndpoint,
            options: Options(
              headers: {
                ApiConstants.authorization:
                    '${ApiConstants.bearer} ${userModel.token}',
              },
            ),
          );
          if (profileResponse.data['success'] == true) {
            userModel = userModel.copyWithProfile(profileResponse.data);
          }
        } catch (_) {
          // Profile fetch is optional; login succeeds with minimal data
        }

        return userModel;
      } else {
        throw AuthException(
          message: response.data['message'] ?? 'Login failed',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw AuthException(
          message: e.response?.data['message'] ?? 'Invalid email or password',
        );
      } else if (e.response?.statusCode == 422) {
        // Validation errors
        final errors = e.response?.data['errors'] as Map<String, dynamic>?;
        final firstError = errors?.values.first;
        throw AuthException(
          message: firstError is List ? firstError.first : 'Validation failed',
        );
      } else {
        throw ServerException(
          message: e.message ?? 'Network error occurred',
          statusCode: e.response?.statusCode,
        );
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await apiClient.post(ApiConstants.logoutEndpoint);
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) {
        throw ServerException(
          message: e.message ?? 'Logout failed',
          statusCode: e.response?.statusCode,
        );
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}