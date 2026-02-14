import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF42A5F5);

  // Secondary Colors
  static const Color secondary = Color(0xFFFF6F00);
  static const Color secondaryDark = Color(0xFFE65100);
  static const Color secondaryLight = Color(0xFFFFB74D);

  // Background Colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Severity Colors (for injury mapping)
  static const Color severityMinor = Color(0xFF4CAF50);     // Green
  static const Color severityModerate = Color(0xFFFFEB3B);   // Yellow
  static const Color severitySevere = Color(0xFFF44336);     // Red
  static const Color severityCritical = Color(0xFF212121);   // Black

  // Triage Colors
  static const Color triageGreen = Color(0xFF4CAF50);
  static const Color triageYellow = Color(0xFFFFEB3B);
  static const Color triageRed = Color(0xFFF44336);
  static const Color triageBlack = Color(0xFF212121);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFBDBDBD);

  // Assignment Status Colors
  static const Color statusPending = Color(0xFFFFC107);
  static const Color statusAccepted = Color(0xFF2196F3);
  static const Color statusRejected = Color(0xFF9E9E9E);
  static const Color statusEnRoute = Color(0xFFFF9800);
  static const Color statusOnScene = Color(0xFF4CAF50);
  static const Color statusCompleted = Color(0xFF607D8B);

  /// Returns the color for a given severity string.
  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'minor':
        return severityMinor;
      case 'moderate':
        return severityModerate;
      case 'severe':
        return severitySevere;
      case 'critical':
        return severityCritical;
      default:
        return Colors.grey;
    }
  }

  /// Returns the color for a given assignment status.
  static Color assignmentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return statusPending;
      case 'accepted':
        return statusAccepted;
      case 'rejected':
        return statusRejected;
      case 'en_route':
        return statusEnRoute;
      case 'on_scene':
        return statusOnScene;
      case 'completed':
        return statusCompleted;
      default:
        return Colors.grey;
    }
  }
}