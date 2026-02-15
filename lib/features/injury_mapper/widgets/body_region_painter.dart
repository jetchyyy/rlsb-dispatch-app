import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/body_region.dart';
import '../../../core/providers/injury_provider.dart';
import '../data/body_regions_data.dart';

/// CustomPainter that draws colored polygon overlays for each body region.
///
/// - Transparent if no injuries recorded.
/// - Severity-colored with 0.4 opacity if injuries exist.
/// - Highlighted border on selected region.
class BodyRegionPainter extends CustomPainter {
  final BodyView view;
  final InjuryProvider injuryProvider;
  final String? selectedRegionId;

  BodyRegionPainter({
    required this.view,
    required this.injuryProvider,
    this.selectedRegionId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final regions = BodyRegionsData.getRegionsForView(view);

    for (final region in regions) {
      if (region.polygonPoints.isEmpty) continue;

      // Build the scaled path
      final path = ui.Path();
      path.moveTo(
        region.polygonPoints.first.dx * size.width,
        region.polygonPoints.first.dy * size.height,
      );
      for (int i = 1; i < region.polygonPoints.length; i++) {
        path.lineTo(
          region.polygonPoints[i].dx * size.width,
          region.polygonPoints[i].dy * size.height,
        );
      }
      path.close();

      // ── Fill ─────────────────────────────────────────────
      if (injuryProvider.hasInjury(region.regionId)) {
        final color = injuryProvider.getSeverityColor(region.regionId);
        final fillPaint = Paint()
          ..color = color.withOpacity(0.4)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, fillPaint);
      }

      // ── Border (selected / hover) ────────────────────────
      if (region.regionId == selectedRegionId) {
        final borderPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawPath(path, borderPaint);
      } else if (injuryProvider.hasInjury(region.regionId)) {
        final borderPaint = Paint()
          ..color = injuryProvider
              .getSeverityColor(region.regionId)
              .withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawPath(path, borderPaint);
      } else {
        // Draw subtle border for all regions so they're visible
        final borderPaint = Paint()
          ..color = Colors.grey.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawPath(path, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BodyRegionPainter oldDelegate) {
    return oldDelegate.view != view ||
        oldDelegate.selectedRegionId != selectedRegionId ||
        oldDelegate.injuryProvider != injuryProvider;
  }
}
