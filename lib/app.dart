import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/incident/screens/assignment_action_screen.dart';
import 'features/incident/screens/incident_detail_screen.dart';
import 'features/injury_mapper/screens/injury_mapper_screen.dart';
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

        // ── Incident Detail ────────────────────────────────
        GoRoute(
          path: '/incident/:id',
          name: 'incidentDetail',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return IncidentDetailScreen(incidentId: id);
          },
          routes: [
            // ── Assignment Action ────────────────────────────
            GoRoute(
              path: 'assignment/:assignmentId',
              name: 'assignmentAction',
              builder: (context, state) {
                final incidentId =
                    int.parse(state.pathParameters['id']!);
                final assignmentId =
                    int.parse(state.pathParameters['assignmentId']!);
                return AssignmentActionScreen(
                  incidentId: incidentId,
                  assignmentId: assignmentId,
                );
              },
            ),

            // ── Injury Mapper ────────────────────────────────
            GoRoute(
              path: 'injury-mapper',
              name: 'injuryMapper',
              builder: (context, state) {
                final incidentId =
                    int.parse(state.pathParameters['id']!);
                return InjuryMapperScreen(incidentId: incidentId);
              },
            ),
          ],
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
