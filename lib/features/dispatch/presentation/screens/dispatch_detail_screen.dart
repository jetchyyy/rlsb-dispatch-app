import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:velocity_x/velocity_x.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/entities/dispatch.dart';
import '../providers/dispatch_provider.dart';

class DispatchDetailScreen extends StatelessWidget {
  final String id;

  const DispatchDetailScreen({
    super.key,
    required this.id,
  });

  Color _getStatusColor(Dispatch dispatch) {
    if (dispatch.isActive) return AppColors.statusActive;
    if (dispatch.isCompleted) return AppColors.statusCompleted;
    if (dispatch.isPending) return AppColors.statusPending;
    if (dispatch.isCancelled) return AppColors.statusCancelled;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppStrings.dispatchDetails.text
            .textStyle(AppTextStyles.h4)
            .color(AppColors.textWhite)
            .make(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        elevation: 0,
      ),
      body: Consumer<DispatchProvider>(
        builder: (context, provider, _) {
          final dispatch = provider.selectedDispatch;

          if (dispatch == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.sp,
                    color: AppColors.error,
                  ),
                  SizedBox(height: AppSizes.spacingM),
                  'Dispatch not found'.text
                      .textStyle(AppTextStyles.bodyMedium)
                      .color(AppColors.textSecondary)
                      .make(),
                ],
              ),
            );
          }

          final statusColor = _getStatusColor(dispatch);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section with Status
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
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(AppSizes.radiusL),
                        ),
                        child: dispatch.status.text
                            .textStyle(AppTextStyles.label)
                            .color(AppColors.textWhite)
                            .bold
                            .make(),
                      ),
                      SizedBox(height: AppSizes.spacingM),
                      dispatch.title.text
                          .textStyle(AppTextStyles.h2)
                          .color(AppColors.textWhite)
                          .make(),
                    ],
                  ),
                ),

                // Details Section
                Padding(
                  padding: EdgeInsets.all(AppSizes.paddingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ID Card
                      _DetailCard(
                        icon: Icons.tag,
                        title: 'Dispatch ID',
                        value: '#${dispatch.id.toString().padLeft(4, '0')}',
                      ),

                      SizedBox(height: AppSizes.spacingM),

                      // Location Card
                      _DetailCard(
                        icon: Icons.location_on,
                        title: AppStrings.location,
                        value: dispatch.location,
                      ),

                      SizedBox(height: AppSizes.spacingM),

                      // Created At Card
                      _DetailCard(
                        icon: Icons.calendar_today,
                        title: AppStrings.createdAt,
                        value: dispatch.createdAt,
                      ),

                      SizedBox(height: AppSizes.spacingXL),

                      // Additional Information Section
                      'Additional Information'.text
                          .textStyle(AppTextStyles.h4)
                          .color(AppColors.textPrimary)
                          .make(),

                      SizedBox(height: AppSizes.spacingM),

                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(AppSizes.paddingM),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusL),
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
                                'Note'.text
                                    .textStyle(AppTextStyles.label)
                                    .color(AppColors.info)
                                    .bold
                                    .make(),
                              ],
                            ),
                            SizedBox(height: AppSizes.spacingS),
                            'This is a mock dispatch detail screen. When connected to the Laravel API, this screen will display complete dispatch information including assigned personnel, equipment, timeline, and real-time updates.'
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.sp),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Icon(
              icon,
              size: AppSizes.iconM,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: AppSizes.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title.text
                    .textStyle(AppTextStyles.bodySmall)
                    .color(AppColors.textSecondary)
                    .make(),
                SizedBox(height: 4.h),
                value.text
                    .textStyle(AppTextStyles.bodyLarge)
                    .color(AppColors.textPrimary)
                    .bold
                    .make(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}