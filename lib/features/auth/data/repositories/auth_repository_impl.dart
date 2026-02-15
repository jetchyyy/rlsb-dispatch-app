import 'dart:convert';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final TokenStorage tokenStorage;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.tokenStorage,
  });

  @override
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  }) async {
    try {
      final userModel = await remoteDataSource.login(
        email: email,
        password: password,
      );

      // Save token and user data to secure storage
      await tokenStorage.saveToken(userModel.token);
      await tokenStorage.saveUserData(jsonEncode(userModel.toJson()));

      return Right(userModel.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await remoteDataSource.logout();
    } catch (_) {
      // Even if server logout fails, clear local data
    }
    await tokenStorage.deleteToken();
    await tokenStorage.deleteUserData();
    return const Right(null);
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final token = await tokenStorage.getToken();
      if (token == null || token.isEmpty) {
        return const Right(null);
      }

      final userDataString = await tokenStorage.getUserData();
      if (userDataString == null) {
        return const Right(null);
      }

      final userJson = jsonDecode(userDataString) as Map<String, dynamic>;
      final userModel = UserModel.fromJson(userJson);
      return Right(userModel.toEntity());
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }
}