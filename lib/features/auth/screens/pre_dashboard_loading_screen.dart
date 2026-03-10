import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class PreDashboardLoadingScreen extends StatefulWidget {
  const PreDashboardLoadingScreen({super.key});

  @override
  State<PreDashboardLoadingScreen> createState() =>
      _PreDashboardLoadingScreenState();
}

class _PreDashboardLoadingScreenState extends State<PreDashboardLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutBack,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Determine the route based on the user's role (Wait 3 seconds)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        // Here you could fetch the role and route appropriately, e.g.:
        // final role = context.read<AuthProvider>().role;
        // if (role == 'super_admin') context.go('/super-admin-dashboard');

        // Navigating to the staff dashboard by default for this example
        context.go('/dashboard');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.primary, Colors.black, 0.7)!,
          image: const DecorationImage(
            image: AssetImage('assets/images/pdrrmosplash.png'),
            fit: BoxFit.cover,
            opacity: 0.4,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.black.withOpacity(0.35),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _opacityAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Main Logo ─────────────────────────────────
                        Hero(
                          tag: 'pdrrmo_logo',
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.6),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                )
                              ],
                            ),
                            child: Image.asset('assets/images/pdrrmologo.png'),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          'PDRRMO',
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 4,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.8),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'EMERGENCY DISPATCH UNIT',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.amberAccent.shade100,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.8),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 64),
                        // ── Loading Bar ──────────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'SYNCING DISPATCH DATA...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 6,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: LinearProgressIndicator(
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.amberAccent),
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'PREPARING YOUR DASHBOARD',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Text(
                          'Surigao Del Norte\nProvincial Disaster Risk Reduction and Management Office',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.1,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
