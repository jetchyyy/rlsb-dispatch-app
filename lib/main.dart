import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/constants/api_constants.dart';
import 'core/network/api_client.dart';
import 'core/providers/incident_provider.dart';
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

  // ── Build dependency graph ─────────────────────────────────
  final apiClient = ApiClient(prefs);
  final authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient);
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
    prefs: prefs,
  );
  final loginUser = LoginUser(authRepository);
  final logoutUser = LogoutUser(authRepository);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            loginUser: loginUser,
            logoutUser: logoutUser,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => IncidentProvider(apiClient),
        ),
      ],
      child: const App(),
    ),
  );
}