import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/providers/incident_provider.dart';
import 'core/providers/incident_response_provider.dart';
import 'core/providers/location_tracking_provider.dart';
import 'core/services/background_service_initializer.dart';
import 'core/widgets/incident_alert_overlay.dart';
import 'core/widgets/response_status_banner.dart';
import 'features/admin/screens/dispatcher_tracker_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/incidents/screens/incidents_list_screen.dart';
import 'features/incidents/screens/incident_detail_screen.dart';
import 'features/incidents/screens/create_incident_screen.dart';
import 'features/incidents/screens/analytics_screen.dart';
import 'features/map/screens/live_map_screen.dart';
import 'features/profile/screens/profile_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  List<Map<String, dynamic>>? _pendingAlertIncidents;

  /// Track the last auth state so we can react to login/logout transitions.
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    // Register callbacks after the first frame so providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerAlarmCallback();
      _registerLocationCallbacks();
      _listenToAuthChanges();
    });
  }

  // ── Alarm ────────────────────────────────────────────────────

  void _registerAlarmCallback() {
    final incidentProvider = context.read<IncidentProvider>();
    incidentProvider.alarmService.onNewIncidents = (newIncidents) {
      if (mounted) {
        setState(() {
          _pendingAlertIncidents = newIncidents;
        });
      }
    };
  }

  // ── Location Tracking ↔ Incident Actions ─────────────────────

  void _registerLocationCallbacks() {
    final incidentProvider = context.read<IncidentProvider>();
    final locationProvider = context.read<LocationTrackingProvider>();
    final responseProvider = context.read<IncidentResponseProvider>();

    // When the responder taps "Respond" → switch to 5-second active tracking
    // and start the response lifecycle (en_route).
    incidentProvider.onRespondStarted = (incidentId) {
      try {
        debugPrint(
            '📍 App: Respond started → activating GPS for incident #$incidentId');
        locationProvider.startActiveTracking(incidentId);
        BackgroundServiceInitializer.setTrackingMode('active',
            incidentId: incidentId);
        BackgroundServiceInitializer.updateNotification(
          'PDRRMO Dispatch',
          'Active tracking — responding to incident #$incidentId',
        );

        // Read incident coordinates from the loaded detail
        final incident = incidentProvider.currentIncident;
        final lat = (incident?['latitude'] as num?)?.toDouble() ?? 0.0;
        final lng = (incident?['longitude'] as num?)?.toDouble() ?? 0.0;

        // Start response tracking with incident coordinates
        responseProvider.acceptIncident(
          incidentId: incidentId,
          lat: lat,
          lng: lng,
        );
        locationProvider.responseStatus = responseProvider.responseStatus;
      } catch (e, stackTrace) {
        debugPrint('❌ Error starting response tracking: $e');
        debugPrint(stackTrace.toString());
      }
    };

    // When on-scene is reached (manual via incident action button)
    incidentProvider.onOnSceneReached = (incidentId) {
      debugPrint('📍 App: On-scene reached for incident #$incidentId');
      // Only mark on_scene if the response provider hasn't auto-detected it
      if (responseProvider.responseStatus != ResponseStatus.onScene) {
        responseProvider.markOnScene();
      }
      locationProvider.responseStatus = responseProvider.responseStatus;
      BackgroundServiceInitializer.updateNotification(
        'PDRRMO Dispatch',
        'On scene — incident #$incidentId',
      );
    };

    // When the incident is resolved → revert to 5-minute passive tracking
    incidentProvider.onRespondEnded = (incidentId) {
      debugPrint(
          '📍 App: Respond ended for incident #$incidentId → reverting to passive GPS');
      locationProvider.stopActiveTracking();
      BackgroundServiceInitializer.setTrackingMode('passive');
      BackgroundServiceInitializer.updateNotification(
        'PDRRMO Dispatch',
        'Location tracking is active',
      );

      responseProvider.completeIncident(incidentId: incidentId);
      locationProvider.responseStatus = responseProvider.responseStatus;
    };

    // Auto-arrival detection: delegate each GPS fix to the response provider
    locationProvider.onPositionCaptured = (position) {
      responseProvider.checkArrival(position);
    };

    // Sync response status changes back to the location provider
    responseProvider.addListener(() {
      locationProvider.responseStatus = responseProvider.responseStatus;
    });
  }

  // ── Auth State Transitions ─────────────────────────────────

  void _listenToAuthChanges() {
    final authProvider = context.read<AuthProvider>();
    _wasAuthenticated = authProvider.isAuthenticated;

    authProvider.addListener(() {
      if (!mounted) return;

      final isNowAuthenticated = authProvider.isAuthenticated;

      // Login transition: start passive tracking + background service
      if (!_wasAuthenticated && isNowAuthenticated) {
        debugPrint('📍 App: Login detected → starting passive GPS tracking');
        final locationProvider = context.read<LocationTrackingProvider>();
        locationProvider.startPassiveTracking();
        BackgroundServiceInitializer.startService();
      }

      // Logout transition: stop everything
      if (_wasAuthenticated && !isNowAuthenticated) {
        debugPrint('📍 App: Logout detected → stopping all GPS tracking');
        final locationProvider = context.read<LocationTrackingProvider>();
        locationProvider.stopAllTracking();
        BackgroundServiceInitializer.stopService();
      }

      _wasAuthenticated = isNowAuthenticated;
    });
  }

  void _dismissAlert() {
    final incidentProvider = context.read<IncidentProvider>();
    incidentProvider.alarmService.stopAlarm();
    setState(() {
      _pendingAlertIncidents = null;
    });
  }

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
        ShellRoute(
          builder: (context, state, child) {
            return Stack(
              children: [
                // The actual routed page — push down below the banner
                // when actively responding to an incident.
                Consumer<IncidentResponseProvider>(
                  builder: (context, rp, _) {
                    if (!rp.isRespondingToIncident) {
                      return child;
                    }
                    // Reserve space at the top for the response banner
                    return Padding(
                      padding: const EdgeInsets.only(top: 56),
                      child: child,
                    );
                  },
                ),

                // Response status banner (top, across all screens)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ResponseStatusBanner(),
                ),

                // Red flash overlay when new incidents arrive
                if (_pendingAlertIncidents != null &&
                    _pendingAlertIncidents!.isNotEmpty)
                  Positioned.fill(
                    child: IncidentAlertOverlay(
                      newIncidents: _pendingAlertIncidents!,
                      onDismiss: _dismissAlert,
                    ),
                  ),
              ],
            );
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

            // ── Admin Tracker (hidden) ─────────────────────────────
            GoRoute(
              path: '/admin/tracker',
              name: 'adminTracker',
              builder: (context, state) => const DispatcherTrackerScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
