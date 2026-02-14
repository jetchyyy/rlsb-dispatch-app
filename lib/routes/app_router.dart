import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/screens/login_screen.dart';
import '../features/dashboard/presentation/screens/staff_dashboard_screen.dart';
import '../features/dashboard/presentation/screens/super_admin_dashboard_screen.dart';
import '../features/dispatch/presentation/screens/dispatch_detail_screen.dart';
import '../features/dispatch/presentation/screens/dispatch_list_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // Login Route
      GoRoute(
        path: '/',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Super Admin Dashboard
      GoRoute(
        path: '/super-admin-dashboard',
        name: 'superAdminDashboard',
        builder: (context, state) => const SuperAdminDashboardScreen(),
      ),

      // Staff Dashboard
      GoRoute(
        path: '/staff-dashboard',
        name: 'staffDashboard',
        builder: (context, state) => const StaffDashboardScreen(),
      ),

      // Dispatch List
      GoRoute(
        path: '/dispatch-list',
        name: 'dispatchList',
        builder: (context, state) => const DispatchListScreen(),
      ),

      // Dispatch Detail
      GoRoute(
        path: '/dispatch-detail/:id',
        name: 'dispatchDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DispatchDetailScreen(id: id);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              '404 - Page Not Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.matchedLocation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    ),
  );
}