import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/incidents/screens/incidents_list_screen.dart';
import 'features/incidents/screens/incident_detail_screen.dart';
import 'features/incidents/screens/create_incident_screen.dart';
import 'features/incidents/screens/analytics_screen.dart';
import 'features/map/screens/live_map_screen.dart';
import 'features/profile/screens/profile_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PDRRMO First Responder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textWhite,
          elevation: 2,
        ),
      ),
      routerConfig: _router(context),
    );
  }

  GoRouter _router(BuildContext context) {
    return GoRouter(
      initialLocation: '/login',
      redirect: (BuildContext context, GoRouterState state) {
        final authProvider = context.read<AuthProvider>();
        final isAuthenticated = authProvider.isAuthenticated;
        final isLoginRoute = state.matchedLocation == '/login';

        if (!isAuthenticated && !isLoginRoute) return '/login';
        if (isAuthenticated && isLoginRoute) return '/dashboard';

        return null;
      },
      routes: [
        // ── Login ──────────────────────────────────────────
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),

        // ── Dashboard ──────────────────────────────────────
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),

        // ── Incidents List ─────────────────────────────────
        GoRoute(
          path: '/incidents',
          name: 'incidents',
          builder: (context, state) => const IncidentsListScreen(),
        ),

        // ── Create Incident ────────────────────────────────
        GoRoute(
          path: '/incidents/create',
          name: 'createIncident',
          builder: (context, state) => const CreateIncidentScreen(),
        ),

        // ── Incident Detail ────────────────────────────────
        GoRoute(
          path: '/incidents/:id',
          name: 'incidentDetail',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return IncidentDetailScreen(incidentId: id);
          },
        ),

        // ── Analytics ──────────────────────────────────────
        GoRoute(
          path: '/analytics',
          name: 'analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),

        // ── Live Map ───────────────────────────────────────
        GoRoute(
          path: '/map',
          name: 'map',
          builder: (context, state) => const LiveMapScreen(),
        ),

        // ── Profile ────────────────────────────────────────
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    );
  }
}
