import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:velocity_x/velocity_x.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class StaffDashboardScreen extends StatelessWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: AppStrings.staffDashboard.text
            .textStyle(AppTextStyles.h4)
            .color(AppColors.textWhite)
            .make(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSizes.paddingL),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  '${AppStrings.welcome},'.text
                      .textStyle(AppTextStyles.bodyLarge)
                      .color(AppColors.textWhite.withOpacity(0.9))
                      .make(),
                  SizedBox(height: AppSizes.spacingS),
                  (user?.name ?? 'Staff').text
                      .textStyle(AppTextStyles.h2)
                      .color(AppColors.textWhite)
                      .bold
                      .make(),
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
                    child: 'Staff Member'.text
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
                  'My Actions'.text
                      .textStyle(AppTextStyles.h3)
                      .color(AppColors.textPrimary)
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
                      color: AppColors.success.withOpacity(0.1),
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
                            'Staff Access'.text
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
                            .color(AppColors.textSecondary)
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
    return Card(
      elevation: AppSizes.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Padding(
          padding: EdgeInsets.all(AppSizes.paddingM),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(16.sp),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
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
                    title.text
                        .textStyle(AppTextStyles.h4)
                        .color(AppColors.textPrimary)
                        .make(),
                    SizedBox(height: 4.h),
                    subtitle.text
                        .textStyle(AppTextStyles.bodySmall)
                        .color(AppColors.textSecondary)
                        .make(),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: AppSizes.iconS,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}