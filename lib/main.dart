import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/constants/api_constants.dart';
import 'core/network/api_client.dart';
import 'core/providers/incident_provider.dart';
import 'core/providers/incident_response_provider.dart';
import 'core/providers/injury_provider.dart';
import 'core/providers/location_tracking_provider.dart';
import 'core/services/background_service_initializer.dart';
import 'core/services/location_service.dart';
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

  // Open the offline location queue box
  final locationQueueBox =
      await Hive.openBox<String>(ApiConstants.locationQueueBox);

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
  final locationService = LocationService();

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

  // Create location tracking provider
  final locationTrackingProvider = LocationTrackingProvider(
    apiClient: apiClient,
    locationService: locationService,
    offlineBox: locationQueueBox,
  );

  // Create incident response provider (pure state, no dependencies)
  final incidentResponseProvider = IncidentResponseProvider();

  // Load token from secure storage to SharedPreferences (for Dio interceptor)
  await tokenStorage.loadTokenToRuntime();

  // Check if user is already logged in
  await authProvider.checkAuthStatus();

  // Initialize background service for keeping GPS alive when backgrounded
  await BackgroundServiceInitializer.initialize();

  // If user is already authenticated, start passive tracking + background service
  if (authProvider.isAuthenticated) {
    await locationTrackingProvider.startPassiveTracking();
    await BackgroundServiceInitializer.startService();
  }

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
        ChangeNotifierProvider.value(
          value: locationTrackingProvider,
        ),
        ChangeNotifierProvider.value(
          value: incidentResponseProvider,
        ),
      ],
      child: const App(),
    ),
  );
}
