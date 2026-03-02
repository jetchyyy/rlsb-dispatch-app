import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;

class PreDashboardLoadingScreen extends StatefulWidget {
  const PreDashboardLoadingScreen({super.key});

  @override
  State<PreDashboardLoadingScreen> createState() =>
      _PreDashboardLoadingScreenState();
}

class _PreDashboardLoadingScreenState extends State<PreDashboardLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();

    // Heartbeat Pulse Animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Background Sweep Animation (Radar/Siren effect)
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _simulateLoadingAndNavigate();
  }

  Future<void> _simulateLoadingAndNavigate() async {
    // Simulate loading process (e.g. uploading photos, validating assets)
    await Future.delayed(const Duration(seconds: 4));

    if (mounted) {
      context.go('/dashboard');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Deep Emergency / Medical Theme Red & Blue
    final Color emergencyRed = const Color(0xFFD32F2F);
    final Color darkBlue = const Color(0xFF0D47A1);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient (Dark Blue mapping to hospital tech)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A192F), darkBlue],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Radar/Sweep effect for emergency vibe
          AnimatedBuilder(
            animation: _sweepController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _sweepController.value * 2 * math.pi,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.transparent,
                        emergencyRed.withOpacity(0.1),
                        emergencyRed.withOpacity(0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 0.9, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulse Logo Container
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Center(
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: Image.asset(
                        'assets/images/pdrrmologo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 64),

                // Tech / Hospital Progress Bar
                Container(
                  width: 250,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: const LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Typography Phase
                Text(
                  'INITIALIZING RESPONSE',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Verifying assets and establishing secure connection...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 24),

                // Simulated ECG pulse line icon
                Icon(
                  Icons.monitor_heart,
                  color: emergencyRed.withOpacity(0.8),
                  size: 32,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
