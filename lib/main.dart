import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/providers/incident_provider.dart';
import 'core/providers/injury_provider.dart';
import 'core/services/map_preloader.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/usecases/login_user.dart';
import 'features/auth/domain/usecases/logout_user.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Ensure SharedPreferences is ready
  final prefs = await SharedPreferences.getInstance();

  // Initialize secure storage for tokens
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  final tokenStorage = TokenStorage(secureStorage);

  // ── Build dependency graph ─────────────────────────────────
  final apiClient = ApiClient(prefs);
  final authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient);
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
    tokenStorage: tokenStorage,
  );
  final loginUser = LoginUser(authRepository);
  final logoutUser = LogoutUser(authRepository);

  // Create auth provider and check authentication status
  final authProvider = AuthProvider(
    loginUser: loginUser,
    logoutUser: logoutUser,
  );

  // Load token from secure storage to SharedPreferences (for Dio interceptor)
  await tokenStorage.loadTokenToRuntime();

  // Check if user is already logged in
  await authProvider.checkAuthStatus();

  // Preload map tiles in background (non-blocking)
  MapPreloader().preloadTiles();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: authProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => IncidentProvider(apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => InjuryProvider(),
        ),
      ],
      child: const App(),
    ),
  );
}
