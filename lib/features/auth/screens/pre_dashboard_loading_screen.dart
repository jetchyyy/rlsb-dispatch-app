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
        decoration: BoxDecoration(
          color: AppColors.primary,
          image: DecorationImage(
            image: const AssetImage('assets/images/hero1.png'), // Background
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              AppColors.primary.withOpacity(0.85),
              BlendMode.darken,
            ),
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Animated Logo
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/pdrrmologo.png',
                              fit: BoxFit
                                  .contain, // Maintain original logo ratio
                              width: 450,
                              height: 450,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 48),

                // Animated Text & Loader
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _opacityAnimation.value,
                      child: Column(
                        children: [
                          Text(
                            'Preparing Your Dashboard',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Syncing dispatch data...',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                          const SizedBox(height: 32),
                          const SizedBox(
                            width: 200,
                            child: LinearProgressIndicator(
                              color: Colors.white,
                              backgroundColor: Colors.white24,
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const Spacer(),

                // Footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Text(
                    'PDRRMO Response System',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 2.0,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
