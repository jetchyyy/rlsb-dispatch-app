import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:velocity_x/velocity_x.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class StaffDashboardScreen extends StatelessWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF020617) : AppColors.background,
        appBar: AppBar(
          title: AppStrings.staffDashboard
              .toUpperCase()
              .text
              .textStyle(AppTextStyles.h4)
              .color(isDark ? AppColors.textWhite : AppColors.textPrimary)
              .bold
              .size(22) // Added .size(22) here
              .make(),
          backgroundColor: isDark ? Colors.transparent : AppColors.primary,
          foregroundColor: AppColors.textWhite,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<ThemeProvider>().toggleTheme();
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                _showLogoutDialog(context);
              },
            ),
          ],
        ),
        extendBodyBehindAppBar: true,
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
                    child: _buildBodyContent(context, user, isDark),
                  ),
                )
              : _buildBodyContent(context, user, isDark),
        ),
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context, dynamic user, bool isDark) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSizes.paddingL),
              decoration: BoxDecoration(
                gradient: isDark
                    ? LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : null,
                color: isDark ? null : AppColors.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  '${AppStrings.welcome},'
                      .text
                      .textStyle(AppTextStyles.bodyLarge)
                      .color(isDark
                          ? AppColors.textWhite.withOpacity(0.9)
                          : Colors.white70)
                      .make(),
                  SizedBox(height: AppSizes.spacingS),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: (user?.name ?? 'Staff')
                            .toUpperCase()
                            .text
                            .textStyle(AppTextStyles.h2)
                            .color(AppColors.textWhite)
                            .bold
                            .maxLines(1)
                            .ellipsis
                            .make(),
                      ),
                      StreamBuilder<DateTime>(
                        stream: Stream.periodic(
                            const Duration(seconds: 1), (_) => DateTime.now()),
                        initialData: DateTime.now(),
                        builder: (context, snapshot) {
                          final time = snapshot.data!;
                          final hour = time.hour > 12
                              ? time.hour - 12
                              : (time.hour == 0 ? 12 : time.hour);
                          final minute = time.minute.toString().padLeft(2, '0');
                          final second = time.second.toString().padLeft(2, '0');
                          final period = time.hour >= 12 ? 'PM' : 'AM';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$hour:$minute:$second $period',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.secondary,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                DateFormat('EEEE, MMM d, yyyy')
                                    .format(time)
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isDark ? Colors.white70 : Colors.white60,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: AppSizes.spacingS),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(AppSizes.radiusL),
                    ),
                    child: 'Staff Member'
                        .text
                        .textStyle(AppTextStyles.bodySmall)
                        .color(AppColors.textWhite)
                        .bold
                        .make(),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppSizes.spacingL),

            // Quick Actions
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  'MY ACTIONS'
                      .text
                      .textStyle(AppTextStyles.h3)
                      .color(isDark ? Colors.white : AppColors.textPrimary)
                      .bold
                      .make(),
                  SizedBox(height: AppSizes.spacingM),

                  // Action Cards
                  _ActionCard(
                    title: 'View Dispatches',
                    subtitle: 'Access all dispatch assignments',
                    icon: Icons.list_alt,
                    color: AppColors.primary,
                    onTap: () => context.push('/dispatch-list'),
                  ),

                  SizedBox(height: AppSizes.spacingM),

                  _ActionCard(
                    title: 'My Profile',
                    subtitle: 'View and update your information',
                    icon: Icons.person,
                    color: AppColors.info,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile feature coming soon'),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: AppSizes.spacingM),

                  _ActionCard(
                    title: 'Notifications',
                    subtitle: 'Check your latest updates',
                    icon: Icons.notifications,
                    color: AppColors.warning,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notifications coming soon'),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: AppSizes.spacingXL),

                  // Info Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppSizes.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: AppSizes.iconM,
                              color: AppColors.success,
                            ),
                            SizedBox(width: AppSizes.spacingS),
                            'STAFF ACCESS'
                                .text
                                .textStyle(AppTextStyles.label)
                                .color(AppColors.success)
                                .bold
                                .make(),
                          ],
                        ),
                        SizedBox(height: AppSizes.spacingS),
                        'You have access to view dispatches, manage your assignments, and update your profile. Contact your administrator for additional permissions.'
                            .text
                            .textStyle(AppTextStyles.bodySmall)
                            .color(isDark
                                ? Colors.white70
                                : AppColors.textSecondary)
                            .make(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppSizes.spacingXL),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: 'Logout'.text.make(),
        content: 'Are you sure you want to logout?'.text.make(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: AppStrings.cancel.text.make(),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
              context.go('/');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textWhite,
            ),
            child: AppStrings.logout.text.make(),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.15) : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F172A).withOpacity(0.5)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          padding: EdgeInsets.all(AppSizes.paddingM),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(16.sp),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
                child: Icon(
                  icon,
                  size: AppSizes.iconL,
                  color: color,
                ),
              ),
              SizedBox(width: AppSizes.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title
                        .toUpperCase()
                        .text
                        .textStyle(AppTextStyles.h4)
                        .color(isDark ? Colors.white : AppColors.textPrimary)
                        .bold
                        .make(),
                    SizedBox(height: 4.h),
                    subtitle.text
                        .textStyle(AppTextStyles.bodySmall)
                        .color(
                            isDark ? Colors.white70 : AppColors.textSecondary)
                        .make(),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: AppSizes.iconS,
                color: isDark ? Colors.white54 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
