import 'package:flutter/foundation.dart';
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
import 'core/services/sensor_fusion_service.dart';
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
  final sensorFusionService = SensorFusionService();

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
    sensorFusionService: sensorFusionService,
  );

  // Create incident response provider (pure state, no dependencies)
  final incidentResponseProvider = IncidentResponseProvider();

  // Load token from secure storage to SharedPreferences (for Dio interceptor)
  await tokenStorage.loadTokenToRuntime();

  // Check if user is already logged in
  await authProvider.checkAuthStatus();
  
  // If user is authenticated, refresh profile from backend to get latest data (including unit field)
  if (authProvider.isAuthenticated) {
    await authProvider.refreshProfile();
  }

  // Initialize background service for keeping GPS alive when backgrounded
  await BackgroundServiceInitializer.initialize();

  // If user is already authenticated, start location tracking + background service
  if (authProvider.isAuthenticated) {
    // Wait for location provider to restore any saved state (active incident)
    await locationTrackingProvider.initialized;

    // Check if we have a restored active incident from a previous session
    if (locationTrackingProvider.activeIncidentId != null) {
      // Resume active tracking for the restored incident
      final restoredIncidentId = locationTrackingProvider.activeIncidentId!;
      debugPrint(
          '🔄 main: Resuming active tracking for restored incident #$restoredIncidentId');
      await locationTrackingProvider.startActiveTracking(restoredIncidentId);
      BackgroundServiceInitializer.setTrackingMode('active',
          incidentId: restoredIncidentId);
      BackgroundServiceInitializer.updateNotification(
        'PDRRMO Dispatch',
        'Active tracking — responding to incident #$restoredIncidentId',
      );
    } else {
      // No active incident, start passive tracking
      await locationTrackingProvider.startPassiveTracking();
    }

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
