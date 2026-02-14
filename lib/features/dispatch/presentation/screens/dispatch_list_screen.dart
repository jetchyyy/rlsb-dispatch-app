import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:velocity_x/velocity_x.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/entities/dispatch.dart';
import '../providers/dispatch_provider.dart';

class DispatchListScreen extends StatefulWidget {
  const DispatchListScreen({super.key});

  @override
  State<DispatchListScreen> createState() => _DispatchListScreenState();
}

class _DispatchListScreenState extends State<DispatchListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DispatchProvider>().fetchDispatches();
    });
  }

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
        title: AppStrings.dispatchList.text
            .textStyle(AppTextStyles.h4)
            .color(AppColors.textWhite)
            .make(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        elevation: 0,
      ),
      body: Consumer<DispatchProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                  SizedBox(height: AppSizes.spacingM),
                  AppStrings.loadingDispatches.text
                      .textStyle(AppTextStyles.bodyMedium)
                      .color(AppColors.textSecondary)
                      .make(),
                ],
              ),
            );
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(AppSizes.paddingL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64.sp,
                      color: AppColors.error,
                    ),
                    SizedBox(height: AppSizes.spacingM),
                    provider.errorMessage!.text
                        .textStyle(AppTextStyles.bodyMedium)
                        .color(AppColors.error)
                        .center
                        .make(),
                    SizedBox(height: AppSizes.spacingL),
                    ElevatedButton.icon(
                      onPressed: () => provider.fetchDispatches(),
                      icon: const Icon(Icons.refresh),
                      label: AppStrings.retry.text.make(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textWhite,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!provider.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64.sp,
                    color: AppColors.textHint,
                  ),
                  SizedBox(height: AppSizes.spacingM),
                  AppStrings.noDispatches.text
                      .textStyle(AppTextStyles.bodyMedium)
                      .color(AppColors.textSecondary)
                      .make(),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchDispatches(),
            color: AppColors.primary,
            child: ListView.builder(
              padding: EdgeInsets.all(AppSizes.paddingM),
              itemCount: provider.dispatches.length,
              itemBuilder: (context, index) {
                final dispatch = provider.dispatches[index];
                return _DispatchCard(
                  dispatch: dispatch,
                  statusColor: _getStatusColor(dispatch),
                  onTap: () {
                    provider.selectDispatch(dispatch);
                    context.push('/dispatch-detail/${dispatch.id}');
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _DispatchCard extends StatelessWidget {
  final Dispatch dispatch;
  final Color statusColor;
  final VoidCallback onTap;

  const _DispatchCard({
    required this.dispatch,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: AppSizes.marginM),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: dispatch.title.text
                        .textStyle(AppTextStyles.h4)
                        .color(AppColors.textPrimary)
                        .make(),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      border: Border.all(color: statusColor),
                    ),
                    child: dispatch.status.text
                        .textStyle(AppTextStyles.bodySmall)
                        .color(statusColor)
                        .bold
                        .make(),
                  ),
                ],
              ),
              SizedBox(height: AppSizes.spacingM),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: AppSizes.iconS,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: AppSizes.spacingS),
                  Expanded(
                    child: dispatch.location.text
                        .textStyle(AppTextStyles.bodyMedium)
                        .color(AppColors.textSecondary)
                        .make(),
                  ),
                ],
              ),
              SizedBox(height: AppSizes.spacingS),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: AppSizes.iconS,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: AppSizes.spacingS),
                  dispatch.createdAt.text
                      .textStyle(AppTextStyles.bodySmall)
                      .color(AppColors.textHint)
                      .make(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}