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

  // ── Incident Severity Colors ────────────────────────────
  static const Color severityCritical = Color(0xFFDC2626); // red-600
  static const Color severityHigh = Color(0xFFEA580C);     // orange-600
  static const Color severityMedium = Color(0xFFFBBF24);   // yellow-400
  static const Color severityLow = Color(0xFF10B981);      // green-500

  // ── Incident Status Colors ──────────────────────────────
  static const Color statusReported = Color(0xFF3B82F6);     // blue-500
  static const Color statusAcknowledged = Color(0xFF8B5CF6); // purple-500
  static const Color statusResponding = Color(0xFFF59E0B);   // amber-500
  static const Color statusOnScene = Color(0xFF06B6D4);      // cyan-500
  static const Color statusResolved = Color(0xFF10B981);     // green-500
  static const Color statusClosed = Color(0xFF6B7280);       // gray-500
  static const Color statusCancelled = Color(0xFF9CA3AF);    // gray-400

  // Legacy severity colors (injury mapping)
  static const Color severityMinor = Color(0xFF4CAF50);     // Green
  static const Color severityModerate = Color(0xFFFFEB3B);   // Yellow
  static const Color severitySevere = Color(0xFFF44336);     // Red

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
  static const Color assignmentOnScene = Color(0xFF4CAF50);
  static const Color statusCompleted = Color(0xFF607D8B);

  /// Returns the color for a given incident severity string.
  static Color incidentSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return severityCritical;
      case 'high':
        return severityHigh;
      case 'medium':
        return severityMedium;
      case 'low':
        return severityLow;
      default:
        return Colors.grey;
    }
  }

  /// Returns the color for a given incident status string.
  static Color incidentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'reported':
        return statusReported;
      case 'acknowledged':
        return statusAcknowledged;
      case 'responding':
        return statusResponding;
      case 'on_scene':
      case 'on scene':
        return statusOnScene;
      case 'resolved':
        return statusResolved;
      case 'closed':
        return statusClosed;
      case 'cancelled':
        return statusCancelled;
      default:
        return Colors.grey;
    }
  }

  /// Returns the color for a given severity string (legacy).
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
        return assignmentOnScene;
      case 'completed':
        return statusCompleted;
      default:
        return Colors.grey;
    }
  }
}