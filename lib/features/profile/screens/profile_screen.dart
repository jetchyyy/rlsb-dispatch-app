import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/theme_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  /// Counter for hidden admin mode unlock.
  /// Tap "Roles" 10 times to reveal the dispatcher tracker.
  int _adminTapCount = 0;
  static const int _adminUnlockTaps = 10;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onRolesTapped(BuildContext context) {
    setState(() {
      _adminTapCount++;
    });

    if (_adminTapCount >= _adminUnlockTaps) {
      _adminTapCount = 0;
      context.push('/admin/tracker');
    } else if (_adminTapCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_adminUnlockTaps - _adminTapCount} more taps...'),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final user = authProvider.user;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF020617) : AppColors.background,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: isDark
              ? BoxDecoration(
                  color: Color.lerp(AppColors.primary, Colors.black, 0.8)!,
                  image: const DecorationImage(
                    image: AssetImage('assets/images/pdrrmosplash.png'),
                    fit: BoxFit.cover,
                    opacity: 0.35,
                  ),
                )
              : BoxDecoration(color: AppColors.background),
          child: isDark
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    child: _buildContent(context, authProvider, user, isDark),
                  ),
                )
              : _buildContent(context, authProvider, user, isDark),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AuthProvider authProvider,
      dynamic user, bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero Header ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? Colors.transparent : AppColors.primary,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                  color: Colors.white.withOpacity(0.85),
                  size: 22,
                ),
                tooltip: 'Toggle Theme',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.read<ThemeProvider>().toggleTheme();
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.0),
                            Colors.black.withOpacity(0.6),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primaryDark,
                          ],
                        ),
                  image: isDark
                      ? null
                      : const DecorationImage(
                          image: AssetImage('assets/images/header.jpg'),
                          fit: BoxFit.cover,
                          opacity: 0.18,
                        ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.35),
                                width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          (user?.name ?? 'Staff').toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              collapseMode: CollapseMode.pin,
            ),
            title: const Text(
              'MY PROFILE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),

          // ── Body Content ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Role Badge ─────────────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.secondary.withOpacity(0.15)
                            : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.secondary.withOpacity(0.4)
                              : AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        (user?.roleLabel ?? 'Staff').toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color:
                              isDark ? AppColors.secondary : AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Info Panel ─────────────────────────────
                  _buildInfoPanel(isDark, [
                    _InfoItem(Icons.badge_outlined, 'ID Number',
                        user?.idNumber ?? 'N/A'),
                    _InfoItem(
                        Icons.email_outlined, 'Email', user?.email ?? 'N/A'),
                    _InfoItem(Icons.phone_outlined, 'Phone',
                        user?.phoneNumber ?? 'N/A'),
                  ]),

                  const SizedBox(height: 16),

                  // ── Assignment Panel ───────────────────────
                  _buildSectionLabel('ASSIGNMENT', Icons.work_outline, isDark),
                  const SizedBox(height: 8),
                  _buildInfoPanel(isDark, [
                    _InfoItem(Icons.business_outlined, 'Division',
                        user?.division ?? 'N/A'),
                    _InfoItem(Icons.local_fire_department_outlined, 'Unit',
                        user?.unit ?? 'N/A'),
                    _InfoItem(Icons.military_tech_outlined, 'Position',
                        user?.position ?? 'N/A'),
                  ]),

                  const SizedBox(height: 16),

                  // ── Roles panel (tappable for secret)──────
                  _buildSectionLabel('ROLES', Icons.security_outlined, isDark),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _onRolesTapped(context),
                    child: _buildInfoPanel(isDark, [
                      _InfoItem(Icons.verified_user_outlined, 'Assigned Roles',
                          user?.roles.join(', ') ?? 'N/A'),
                    ]),
                  ),

                  const SizedBox(height: 32),

                  // ── Logout Button ─────────────────────────
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: authProvider.isLoading
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              context.push('/pre-logout-checklist');
                            },
                      icon: authProvider.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.logout_rounded),
                      label: Text(
                        authProvider.isLoading ? 'Logging out...' : 'Logout',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon,
            size: 14,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPanel(bool isDark, List<_InfoItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: items
            .asMap()
            .entries
            .map((e) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.07)
                                  : AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              e.value.icon,
                              size: 18,
                              color:
                                  isDark ? Colors.white60 : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.value.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  e.value.value,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (e.key < items.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 64,
                        color: isDark
                            ? Colors.white.withOpacity(0.07)
                            : Colors.grey.shade100,
                      ),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem(this.icon, this.label, this.value);
}
