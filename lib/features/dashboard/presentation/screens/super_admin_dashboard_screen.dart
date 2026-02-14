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

class SuperAdminDashboardScreen extends StatelessWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: AppStrings.superAdminDashboard.text
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
                  (user?.name ?? 'Admin').text
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
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(AppSizes.radiusL),
                    ),
                    child: 'Super Admin'.text
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
                  'Quick Actions'.text
                      .textStyle(AppTextStyles.h3)
                      .color(AppColors.textPrimary)
                      .make(),
                  SizedBox(height: AppSizes.spacingM),

                  // Action Cards Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSizes.spacingM,
                    mainAxisSpacing: AppSizes.spacingM,
                    children: [
                      _ActionCard(
                        title: 'Dispatch List',
                        icon: Icons.list_alt,
                        color: AppColors.primary,
                        onTap: () => context.push('/dispatch-list'),
                      ),
                      _ActionCard(
                        title: 'Reports',
                        icon: Icons.assessment,
                        color: AppColors.success,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reports feature coming soon'),
                            ),
                          );
                        },
                      ),
                      _ActionCard(
                        title: 'Users',
                        icon: Icons.people,
                        color: AppColors.info,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Users management coming soon'),
                            ),
                          );
                        },
                      ),
                      _ActionCard(
                        title: 'Settings',
                        icon: Icons.settings,
                        color: AppColors.warning,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Settings coming soon'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: AppSizes.spacingXL),

                  // Info Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppSizes.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      border: Border.all(
                        color: AppColors.info.withOpacity(0.3),
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
                              color: AppColors.info,
                            ),
                            SizedBox(width: AppSizes.spacingS),
                            'Super Admin Access'.text
                                .textStyle(AppTextStyles.label)
                                .color(AppColors.info)
                                .bold
                                .make(),
                          ],
                        ),
                        SizedBox(height: AppSizes.spacingS),
                        'You have full administrative access to the MIS Dispatch system. You can manage users, view all dispatches, generate reports, and configure system settings.'
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
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
              SizedBox(height: AppSizes.spacingM),
              title.text
                  .textStyle(AppTextStyles.label)
                  .color(AppColors.textPrimary)
                  .center
                  .make(),
            ],
          ),
        ),
      ),
    );
  }
}