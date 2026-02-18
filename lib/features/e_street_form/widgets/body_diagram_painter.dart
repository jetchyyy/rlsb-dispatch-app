import 'package:flutter/material.dart';

import '../models/body_part.dart';
import '../models/body_parts_data.dart';

/// Custom painter that renders the body silhouette and tappable regions.
///
/// - Default region: light grey outline
/// - Has observation: green fill
/// - Currently tapped: blue fill
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
    _drawBodySilhouette(canvas, size);
    _drawRegions(canvas, size);
    _drawViewLabel(canvas, size);
  }

  void _drawBodySilhouette(Canvas canvas, Size size) {
    final sx = size.width / 300;
    final sy = size.height / 500;
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Head
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(150 * sx, 42 * sy),
        width: 60 * sx,
        height: 70 * sy,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(150 * sx, 42 * sy),
        width: 60 * sx,
        height: 70 * sy,
      ),
      outlinePaint,
    );

    // Neck
    canvas.drawRect(
      Rect.fromLTWH(138 * sx, 74 * sy, 24 * sx, 24 * sy),
      paint,
    );

    // Torso
    final torso = Path()
      ..moveTo(110 * sx, 95 * sy)
      ..cubicTo(100 * sx, 95 * sy, 85 * sx, 105 * sy, 85 * sx, 115 * sy)
      ..lineTo(90 * sx, 195 * sy)
      ..cubicTo(90 * sx, 215 * sy, 110 * sx, 230 * sy, 120 * sx, 230 * sy)
      ..lineTo(180 * sx, 230 * sy)
      ..cubicTo(190 * sx, 230 * sy, 210 * sx, 215 * sy, 210 * sx, 195 * sy)
      ..lineTo(215 * sx, 115 * sy)
      ..cubicTo(215 * sx, 105 * sy, 200 * sx, 95 * sy, 190 * sx, 95 * sy)
      ..close();
    canvas.drawPath(torso, paint);
    canvas.drawPath(torso, outlinePaint);

    // Left arm
    final leftArm = Path()
      ..moveTo(85 * sx, 110 * sy)
      ..cubicTo(72 * sx, 110 * sy, 65 * sx, 120 * sy, 62 * sx, 135 * sy)
      ..lineTo(52 * sx, 225 * sy)
      ..cubicTo(48 * sx, 240 * sy, 47 * sx, 248 * sy, 50 * sx, 258 * sy)
      ..lineTo(72 * sx, 258 * sy)
      ..cubicTo(72 * sx, 248 * sy, 76 * sx, 235 * sy, 78 * sx, 225 * sy)
      ..lineTo(88 * sx, 145 * sy)
      ..close();
    canvas.drawPath(leftArm, paint);
    canvas.drawPath(leftArm, outlinePaint);

    // Right arm
    final rightArm = Path()
      ..moveTo(215 * sx, 110 * sy)
      ..cubicTo(228 * sx, 110 * sy, 235 * sx, 120 * sy, 238 * sx, 135 * sy)
      ..lineTo(248 * sx, 225 * sy)
      ..cubicTo(252 * sx, 240 * sy, 253 * sx, 248 * sy, 250 * sx, 258 * sy)
      ..lineTo(228 * sx, 258 * sy)
      ..cubicTo(228 * sx, 248 * sy, 224 * sx, 235 * sy, 222 * sx, 225 * sy)
      ..lineTo(212 * sx, 145 * sy)
      ..close();
    canvas.drawPath(rightArm, paint);
    canvas.drawPath(rightArm, outlinePaint);

    // Left leg
    final leftLeg = Path()
      ..moveTo(120 * sx, 225 * sy)
      ..cubicTo(115 * sx, 240 * sy, 112 * sx, 280 * sy, 114 * sx, 320 * sy)
      ..lineTo(112 * sx, 420 * sy)
      ..cubicTo(110 * sx, 440 * sy, 112 * sx, 450 * sy, 120 * sx, 452 * sy)
      ..lineTo(148 * sx, 452 * sy)
      ..cubicTo(148 * sx, 445 * sy, 144 * sx, 435 * sy, 142 * sx, 420 * sy)
      ..lineTo(148 * sx, 320 * sy)
      ..cubicTo(150 * sx, 280 * sy, 150 * sx, 240 * sy, 150 * sx, 225 * sy)
      ..close();
    canvas.drawPath(leftLeg, paint);
    canvas.drawPath(leftLeg, outlinePaint);

    // Right leg
    final rightLeg = Path()
      ..moveTo(150 * sx, 225 * sy)
      ..cubicTo(150 * sx, 240 * sy, 150 * sx, 280 * sy, 152 * sx, 320 * sy)
      ..lineTo(158 * sx, 420 * sy)
      ..cubicTo(156 * sx, 435 * sy, 152 * sx, 445 * sy, 152 * sx, 452 * sy)
      ..lineTo(180 * sx, 452 * sy)
      ..cubicTo(188 * sx, 450 * sy, 190 * sx, 440 * sy, 188 * sx, 420 * sy)
      ..lineTo(186 * sx, 320 * sy)
      ..cubicTo(188 * sx, 280 * sy, 185 * sx, 240 * sy, 180 * sx, 225 * sy)
      ..close();
    canvas.drawPath(rightLeg, paint);
    canvas.drawPath(rightLeg, outlinePaint);

    // Face features (front view only)
    if (view == BodyPartView.front) {
      final eyePaint = Paint()..color = Colors.grey.shade500;
      // Left eye
      canvas.drawOval(
        Rect.fromCenter(center: Offset(140 * sx, 38 * sy), width: 8 * sx, height: 5 * sy),
        eyePaint,
      );
      // Right eye
      canvas.drawOval(
        Rect.fromCenter(center: Offset(160 * sx, 38 * sy), width: 8 * sx, height: 5 * sy),
        eyePaint,
      );
      // Mouth
      final mouthPath = Path()
        ..moveTo(143 * sx, 52 * sy)
        ..quadraticBezierTo(150 * sx, 58 * sy, 157 * sx, 52 * sy);
      canvas.drawPath(
        mouthPath,
        Paint()
          ..color = Colors.grey.shade500
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawRegions(Canvas canvas, Size size) {
    final parts = BodyPartsData.getPartsForView(view);

    for (final part in parts) {
      final path = part.createPath(size);
      final hasObs = observations.containsKey(part.key);
      final isTapped = part.key == tappedKey;

      if (isTapped) {
        canvas.drawPath(
          path,
          Paint()..color = Colors.blue.withOpacity(0.35),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.blue
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else if (hasObs) {
        canvas.drawPath(
          path,
          Paint()..color = Colors.green.withOpacity(0.3),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.grey.withOpacity(0.15)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.grey.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }
  }

  void _drawViewLabel(Canvas canvas, Size size) {
    final label = view == BodyPartView.front ? 'FRONT' : 'BACK';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - tp.height - 4));
  }

  @override
  bool shouldRepaint(covariant BodyDiagramPainter old) {
    return old.tappedKey != tappedKey ||
        old.observations.length != observations.length ||
        old.view != view;
  }
}
