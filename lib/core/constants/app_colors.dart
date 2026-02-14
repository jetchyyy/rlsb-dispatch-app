import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF3F51B5);
  static const Color primaryDark = Color(0xFF303F9F);
  static const Color primaryLight = Color(0xFFC5CAE9);

  // Secondary Colors
  static const Color secondary = Color(0xFFFF4081);
  static const Color secondaryDark = Color(0xFFC51162);
  static const Color secondaryLight = Color(0xFFFF80AB);

  // Background Colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFBDBDBD);

  // Status-specific colors for dispatch
  static const Color statusActive = Color(0xFFFF5722);
  static const Color statusCompleted = Color(0xFF4CAF50);
  static const Color statusPending = Color(0xFFFFC107);
  static const Color statusCancelled = Color(0xFF9E9E9E);
}