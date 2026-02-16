import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Represents a single tappable body region on the body diagram.
class BodyPart {
  final String key;
  final String label;
  final BodyPartShape shape;
  final BodyPartView view;

  // Shape parameters (in 300x500 coordinate space)
  final double? cx, cy, rx, ry, r;
  final double? x, y, w, h, cornerRadius;
  final double rotation; // degrees

  const BodyPart({
    required this.key,
    required this.label,
    required this.shape,
    required this.view,
    this.cx,
    this.cy,
    this.rx,
    this.ry,
    this.r,
    this.x,
    this.y,
    this.w,
    this.h,
    this.cornerRadius,
    this.rotation = 0,
  });

  /// Create the Path for this body part, scaled to [size].
  Path createPath(Size size) {
    final sx = size.width / 300.0;
    final sy = size.height / 500.0;

    switch (shape) {
      case BodyPartShape.ellipse:
        return Path()
          ..addOval(Rect.fromCenter(
            center: Offset(cx! * sx, cy! * sy),
            width: rx! * 2 * sx,
            height: ry! * 2 * sy,
          ));
      case BodyPartShape.circle:
        return Path()
          ..addOval(Rect.fromCircle(
            center: Offset(cx! * sx, cy! * sy),
            radius: r! * math.min(sx, sy),
          ));
      case BodyPartShape.rect:
        return Path()
          ..addRect(Rect.fromLTWH(
            x! * sx,
            y! * sy,
            w! * sx,
            h! * sy,
          ));
      case BodyPartShape.roundedRect:
        final rect = Rect.fromLTWH(x! * sx, y! * sy, w! * sx, h! * sy);
        final cr = (cornerRadius ?? 5) * math.min(sx, sy);
        if (rotation != 0) {
          final center = rect.center;
          final rad = rotation * math.pi / 180.0;
          final cosA = math.cos(rad);
          final sinA = math.sin(rad);

          // Build unrotated RRect centered at origin, then transform
          final halfW = rect.width / 2;
          final halfH = rect.height / 2;
          final p = Path()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(-halfW, -halfH, rect.width, rect.height),
              Radius.circular(cr),
            ));

          // Rotation + translation matrix
          final matrix = Float64List(16);
          matrix[0] = cosA;
          matrix[1] = sinA;
          matrix[4] = -sinA;
          matrix[5] = cosA;
          matrix[10] = 1;
          matrix[12] = center.dx;
          matrix[13] = center.dy;
          matrix[15] = 1;

          return p.transform(matrix);
        } else {
          return Path()
            ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(cr)));
        }
    }
  }
}

enum BodyPartShape { ellipse, circle, rect, roundedRect }

enum BodyPartView { front, back }
