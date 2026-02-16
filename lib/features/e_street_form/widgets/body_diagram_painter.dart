import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/body_part.dart';
import '../models/body_parts_data.dart';

/// Draws the human body silhouette outline plus body-part regions.
///
/// Regions colored:
///  - Default:     transparent fill, thin gray stroke
///  - Tap/hover:   light blue fill + blue stroke
///  - Observation:  light green fill + green stroke
class BodyDiagramPainter extends CustomPainter {
  final BodyPartView view;
  final Map<String, String> observations;
  final String? tappedKey;

  BodyDiagramPainter({
    required this.view,
    required this.observations,
    this.tappedKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBodyOutline(canvas, size);
    _drawRegions(canvas, size);
  }

  // ── Body Outline (silhouette) ──────────────────────────────
  void _drawBodyOutline(Canvas canvas, Size size) {
    final sx = size.width / 300.0;
    final sy = size.height / 500.0;

    final outlinePaint = Paint()
      ..color = const Color(0xFF607D8B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * sx
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final skinFill = Paint()
      ..color = const Color(0xFFF5E6D3)
      ..style = PaintingStyle.fill;

    final path = Path();

    // ── Head ──
    path.addOval(Rect.fromCenter(
      center: Offset(150 * sx, 48 * sy),
      width: 62 * sx,
      height: 70 * sy,
    ));

    // ── Neck ──
    final neckPath = Path()
      ..moveTo(138 * sx, 82 * sy)
      ..lineTo(138 * sx, 100 * sy)
      ..lineTo(162 * sx, 100 * sy)
      ..lineTo(162 * sx, 82 * sy);

    // ── Torso ──
    final torsoPath = Path()
      ..moveTo(100 * sx, 100 * sy)
      ..cubicTo(95 * sx, 105 * sy, 90 * sx, 110 * sy, 92 * sx, 135 * sy)
      ..cubicTo(92 * sx, 160 * sy, 95 * sx, 195 * sy, 105 * sx, 225 * sy)
      ..lineTo(115 * sx, 250 * sy)
      ..lineTo(150 * sx, 255 * sy)
      ..lineTo(185 * sx, 250 * sy)
      ..lineTo(195 * sx, 225 * sy)
      ..cubicTo(205 * sx, 195 * sy, 208 * sx, 160 * sy, 208 * sx, 135 * sy)
      ..cubicTo(210 * sx, 110 * sy, 205 * sx, 105 * sy, 200 * sx, 100 * sy)
      ..lineTo(162 * sx, 100 * sy)
      ..lineTo(138 * sx, 100 * sy)
      ..close();

    // ── Left Arm ──
    final leftArm = Path()
      ..moveTo(100 * sx, 105 * sy)
      ..cubicTo(85 * sx, 108 * sy, 78 * sx, 120 * sy, 72 * sx, 140 * sy)
      ..cubicTo(66 * sx, 160 * sy, 60 * sx, 185 * sy, 55 * sx, 210 * sy)
      ..cubicTo(50 * sx, 230 * sy, 48 * sx, 240 * sy, 48 * sx, 250 * sy)
      ..cubicTo(44 * sx, 258 * sy, 42 * sx, 268 * sy, 48 * sx, 270 * sy)
      ..cubicTo(54 * sx, 272 * sy, 60 * sx, 260 * sy, 64 * sx, 250 * sy)
      ..cubicTo(68 * sx, 240 * sy, 72 * sx, 220 * sy, 78 * sx, 200 * sy)
      ..cubicTo(84 * sx, 180 * sy, 88 * sx, 160 * sy, 92 * sx, 140 * sy)
      ..cubicTo(96 * sx, 120 * sy, 100 * sx, 110 * sy, 100 * sx, 105 * sy);

    // ── Right Arm ──
    final rightArm = Path()
      ..moveTo(200 * sx, 105 * sy)
      ..cubicTo(215 * sx, 108 * sy, 222 * sx, 120 * sy, 228 * sx, 140 * sy)
      ..cubicTo(234 * sx, 160 * sy, 240 * sx, 185 * sy, 245 * sx, 210 * sy)
      ..cubicTo(250 * sx, 230 * sy, 252 * sx, 240 * sy, 252 * sx, 250 * sy)
      ..cubicTo(256 * sx, 258 * sy, 258 * sx, 268 * sy, 252 * sx, 270 * sy)
      ..cubicTo(246 * sx, 272 * sy, 240 * sx, 260 * sy, 236 * sx, 250 * sy)
      ..cubicTo(232 * sx, 240 * sy, 228 * sx, 220 * sy, 222 * sx, 200 * sy)
      ..cubicTo(216 * sx, 180 * sy, 212 * sx, 160 * sy, 208 * sx, 140 * sy)
      ..cubicTo(204 * sx, 120 * sy, 200 * sx, 110 * sy, 200 * sx, 105 * sy);

    // ── Left Leg ──
    final leftLeg = Path()
      ..moveTo(115 * sx, 250 * sy)
      ..cubicTo(112 * sx, 270 * sy, 110 * sx, 300 * sy, 112 * sx, 330 * sy)
      ..cubicTo(114 * sx, 350 * sy, 115 * sx, 370 * sy, 115 * sx, 400 * sy)
      ..cubicTo(114 * sx, 420 * sy, 112 * sx, 435 * sy, 110 * sx, 448 * sy)
      ..cubicTo(108 * sx, 455 * sy, 110 * sx, 460 * sy, 118 * sx, 460 * sy)
      ..lineTo(142 * sx, 460 * sy)
      ..cubicTo(148 * sx, 460 * sy, 150 * sx, 455 * sy, 148 * sx, 448 * sy)
      ..cubicTo(146 * sx, 435 * sy, 144 * sx, 420 * sy, 143 * sx, 400 * sy)
      ..cubicTo(143 * sx, 370 * sy, 144 * sx, 350 * sy, 145 * sx, 330 * sy)
      ..cubicTo(146 * sx, 300 * sy, 148 * sx, 270 * sy, 150 * sx, 255 * sy);

    // ── Right Leg ──
    final rightLeg = Path()
      ..moveTo(150 * sx, 255 * sy)
      ..cubicTo(152 * sx, 270 * sy, 154 * sx, 300 * sy, 155 * sx, 330 * sy)
      ..cubicTo(156 * sx, 350 * sy, 157 * sx, 370 * sy, 157 * sx, 400 * sy)
      ..cubicTo(156 * sx, 420 * sy, 154 * sx, 435 * sy, 152 * sx, 448 * sy)
      ..cubicTo(150 * sx, 455 * sy, 152 * sx, 460 * sy, 158 * sx, 460 * sy)
      ..lineTo(190 * sx, 460 * sy)
      ..cubicTo(196 * sx, 460 * sy, 198 * sx, 455 * sy, 196 * sx, 448 * sy)
      ..cubicTo(194 * sx, 435 * sy, 190 * sx, 420 * sy, 188 * sx, 400 * sy)
      ..cubicTo(187 * sx, 370 * sy, 186 * sx, 350 * sy, 188 * sx, 330 * sy)
      ..cubicTo(190 * sx, 300 * sy, 188 * sx, 270 * sy, 185 * sx, 250 * sy);

    // Draw body fill
    canvas.drawPath(path, skinFill); // head
    canvas.drawPath(neckPath, skinFill);
    canvas.drawPath(torsoPath, skinFill);
    canvas.drawPath(leftArm, skinFill);
    canvas.drawPath(rightArm, skinFill);
    canvas.drawPath(leftLeg, skinFill);
    canvas.drawPath(rightLeg, skinFill);

    // Draw outlines
    canvas.drawPath(path, outlinePaint); // head
    canvas.drawPath(neckPath, outlinePaint);
    canvas.drawPath(torsoPath, outlinePaint);
    canvas.drawPath(leftArm, outlinePaint);
    canvas.drawPath(rightArm, outlinePaint);
    canvas.drawPath(leftLeg, outlinePaint);
    canvas.drawPath(rightLeg, outlinePaint);

    // ── Face features (front view) ──
    if (view == BodyPartView.front) {
      final featurePaint = Paint()
        ..color = const Color(0xFF607D8B)
        ..style = PaintingStyle.fill;

      // Eyes
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(139 * sx, 42 * sy),
          width: 6 * sx,
          height: 4 * sy,
        ),
        featurePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(161 * sx, 42 * sy),
          width: 6 * sx,
          height: 4 * sy,
        ),
        featurePaint,
      );

      // Mouth line
      final mouthPaint = Paint()
        ..color = const Color(0xFF607D8B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * sx;
      canvas.drawLine(
        Offset(143 * sx, 58 * sy),
        Offset(157 * sx, 58 * sy),
        mouthPaint,
      );
    }

    // ── View label ──
    final labelSpan = TextSpan(
      text: view == BodyPartView.front ? 'FRONT' : 'BACK',
      style: TextStyle(
        color: const Color(0xFF90A4AE),
        fontSize: 12 * sx,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      ),
    );
    final tp = TextPainter(text: labelSpan, textDirection: ui.TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - 18 * sy));
  }

  // ── Tappable Regions ───────────────────────────────────────
  void _drawRegions(Canvas canvas, Size size) {
    final parts = BodyPartsData.getPartsForView(view);

    for (final part in parts) {
      final path = part.createPath(size);

      final hasObs = observations.containsKey(part.key);
      final isTapped = part.key == tappedKey;

      if (isTapped) {
        // Tapped state: blue highlight
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x33007BFF)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF007BFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      } else if (hasObs) {
        // Has observation: green
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x4D28A745)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF28A745)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
      } else {
        // Default: subtle border
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x30607D8B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant BodyDiagramPainter old) {
    return old.view != view ||
        old.tappedKey != tappedKey ||
        old.observations != observations;
  }
}
