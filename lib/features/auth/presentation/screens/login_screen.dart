import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:velocity_x/velocity_x.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/header.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              // Navigate on successful authentication
              if (authProvider.isAuthenticated && authProvider.user != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (authProvider.user!.isSuperAdmin) {
                    context.go('/super-admin-dashboard');
                  } else if (authProvider.user!.isStaff) {
                    context.go('/staff-dashboard');
                  }
                });
              }

              return Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.paddingL),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 450),
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          color: AppColors.surface.withOpacity(0.95),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // App Logo/Title
                                  Icon(
                                    Icons.local_shipping_rounded,
                                    size: 64.sp,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(height: AppSizes.spacingM),

                                  AppStrings.appName.text
                                      .textStyle(AppTextStyles.h2)
                                      .color(AppColors.primary)
                                      .center
                                      .make(),

                                  SizedBox(height: AppSizes.spacingS),

                                  AppStrings.login.text
                                      .textStyle(AppTextStyles.bodyMedium)
                                      .color(AppColors.textSecondary)
                                      .center
                                      .make(),

                                  SizedBox(height: 40.h),

                                  // Email Field
                                  AppStrings.email.text
                                      .textStyle(AppTextStyles.label)
                                      .make(),
                                  SizedBox(height: AppSizes.spacingS),

                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    enabled: !authProvider.isLoading,
                                    decoration: InputDecoration(
                                      hintText: AppStrings.enterEmail,
                                      prefixIcon:
                                          const Icon(Icons.email_outlined),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppSizes.radiusM),
                                      ),
                                      filled: true,
                                      fillColor: AppColors.surface,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter email';
                                      }
                                      if (!value.contains('@')) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),

                                  SizedBox(height: AppSizes.spacingL),

                                  // Password Field
                                  AppStrings.password.text
                                      .textStyle(AppTextStyles.label)
                                      .make(),
                                  SizedBox(height: AppSizes.spacingS),

                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    enabled: !authProvider.isLoading,
                                    decoration: InputDecoration(
                                      hintText: AppStrings.enterPassword,
                                      prefixIcon:
                                          const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppSizes.radiusM),
                                      ),
                                      filled: true,
                                      fillColor: AppColors.surface,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter password';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),

                                  SizedBox(height: AppSizes.spacingXL),

                                  // Error Message
                                  if (authProvider.errorMessage != null)
                                    Container(
                                      padding:
                                          EdgeInsets.all(AppSizes.paddingM),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                            AppSizes.radiusM),
                                        border:
                                            Border.all(color: AppColors.error),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: AppColors.error,
                                            size: AppSizes.iconM,
                                          ),
                                          SizedBox(width: AppSizes.spacingS),
                                          Expanded(
                                            child: authProvider
                                                .errorMessage!.text
                                                .textStyle(
                                                    AppTextStyles.bodySmall)
                                                .color(AppColors.error)
                                                .make(),
                                          ),
                                        ],
                                      ),
                                    ).pOnly(bottom: AppSizes.spacingL),

                                  // Login Button
                                  SizedBox(
                                    height: AppSizes.buttonHeightM,
                                    child: ElevatedButton(
                                      onPressed: authProvider.isLoading
                                          ? null
                                          : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: AppColors.textWhite,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppSizes.radiusM),
                                        ),
                                      ),
                                      child: authProvider.isLoading
                                          ? SizedBox(
                                              height: 20.sp,
                                              width: 20.sp,
                                              child:
                                                  const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  AppColors.textWhite,
                                                ),
                                              ),
                                            )
                                          : AppStrings.loginButton.text
                                              .textStyle(AppTextStyles.button)
                                              .make(),
                                    ),
                                  ),

                                  SizedBox(height: AppSizes.spacingXL),

                                  // Demo Credentials Info
                                  Container(
                                    padding: EdgeInsets.all(AppSizes.paddingM),
                                    decoration: BoxDecoration(
                                      color: AppColors.info.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(
                                          AppSizes.radiusM),
                                      border: Border.all(
                                        color: AppColors.info.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        'Demo Credentials'
                                            .text
                                            .textStyle(AppTextStyles.label)
                                            .color(AppColors.info)
                                            .bold
                                            .make(),
                                        SizedBox(height: AppSizes.spacingS),
                                        'Super Admin:'
                                            .text
                                            .textStyle(AppTextStyles.bodySmall)
                                            .make(),
                                        'admin@test.com / 123456'
                                            .text
                                            .textStyle(AppTextStyles.bodySmall)
                                            .color(AppColors.textSecondary)
                                            .make(),
                                        SizedBox(height: AppSizes.spacingS),
                                        'Staff:'
                                            .text
                                            .textStyle(AppTextStyles.bodySmall)
                                            .make(),
                                        'staff@test.com / 123456'
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
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
