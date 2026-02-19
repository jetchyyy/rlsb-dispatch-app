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
  
  Future<UserModel> fetchUserProfile();
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
  
  @override
  Future<UserModel> fetchUserProfile() async {
    try {
      final response = await apiClient.get(ApiConstants.profileEndpoint);
      
      if (response.data['success'] == true) {
        // Get current user data from storage to merge with profile
        final profileData = response.data;
        final userData = profileData['user'];
        
        // Debug logging to show what we received from backend
        print('🔄 Fetched user profile from backend:');
        print('   ID: ${userData['id']}');
        print('   Name: ${userData['name']}');
        print('   Email: ${userData['email']}');
        print('   Division: ${userData['division']}');
        print('   Unit: ${userData['unit']}');
        print('   Position: ${userData['position']}');
        print('   Roles: ${userData['roles']}');
        print('   Permissions: ${userData['permissions']}');
        
        return UserModel.fromJson(profileData['user']);
      } else {
        throw ServerException(
          message: response.data['message'] ?? 'Failed to fetch profile',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw AuthException(
          message: 'Session expired. Please login again.',
        );
      } else {
        throw ServerException(
          message: e.message ?? 'Failed to fetch user profile',
          statusCode: e.response?.statusCode,
        );
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}