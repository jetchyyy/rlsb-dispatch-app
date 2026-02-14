import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import 'core/network/api_client.dart';
import 'core/network/dio_interceptor.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login_user.dart';
import 'features/auth/domain/usecases/logout_user.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/dispatch/data/datasources/dispatch_remote_datasource.dart';
import 'features/dispatch/data/repositories/dispatch_repository_impl.dart';
import 'features/dispatch/domain/repositories/dispatch_repository.dart';
import 'features/dispatch/domain/usecases/get_dispatch_list.dart';
import 'features/dispatch/presentation/providers/dispatch_provider.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ========== FEATURES ==========

  // Providers (State Management)
  sl.registerFactory(() => AuthProvider(
        loginUser: sl(),
        logoutUser: sl(),
      ));

  sl.registerFactory(() => DispatchProvider(
        getDispatchList: sl(),
      ));

  // Use Cases
  sl.registerLazySingleton(() => LoginUser(sl()));
  sl.registerLazySingleton(() => LogoutUser(sl()));
  sl.registerLazySingleton(() => GetDispatchList(sl()));

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      tokenStorage: sl(),
    ),
  );

  sl.registerLazySingleton<DispatchRepository>(
    () => DispatchRepositoryImpl(
      remoteDataSource: sl(),
    ),
  );

  // Data Sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<DispatchRemoteDataSource>(
    () => DispatchRemoteDataSourceImpl(sl()),
  );

  // ========== CORE ==========

  // Network
  sl.registerLazySingleton(() => ApiClient(sl()));
  sl.registerLazySingleton(() => DioInterceptor(sl()));

  // Storage
  sl.registerLazySingleton(() => TokenStorage(sl()));

  // External
  sl.registerLazySingleton(() => const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      ));
}