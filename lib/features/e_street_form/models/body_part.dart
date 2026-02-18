import 'dart:ui';
import 'dart:typed_data';

/// Shape types supported by body region hit areas.
enum BodyPartShape { ellipse, circle, rect, roundedRect }

/// Which body view the part belongs to.
enum BodyPartView { front, back }

/// Describes a tappable body region with its geometry.
///
/// All coordinates are defined in a 300×500 reference space and scaled
/// to the rendered size at draw time.
class BodyPart {
  final String key;
  final String label;
  final BodyPartShape shape;
  final BodyPartView view;

  // Ellipse / circle params
  final double? cx, cy, rx, ry, r;

  // Rect / roundedRect params
  final double? x, y, w, h, cornerRadius;

  // Optional rotation in degrees
  final double? rotation;

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
    this.rotation,
  });

  /// Creates a [Path] scaled to [size] from the 300×500 coordinate space.
  Path createPath(Size size) {
    final sx = size.width / 300;
    final sy = size.height / 500;
    final path = Path();

    switch (shape) {
      case BodyPartShape.ellipse:
        final center = Offset(cx! * sx, cy! * sy);
        final radii = Radius.elliptical(rx! * sx, ry! * sy);
        if (rotation != null && rotation != 0) {
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: rx! * 2 * sx,
            height: ry! * 2 * sy,
          );
          final matrix = Float64List(16)
            ..[0] = 1
            ..[5] = 1
            ..[10] = 1
            ..[15] = 1;
          // Apply rotation around center
          final rad = rotation! * 3.14159265 / 180;
          final cos = _cos(rad);
          final sin = _sin(rad);
          matrix[0] = cos;
          matrix[1] = sin;
          matrix[4] = -sin;
          matrix[5] = cos;
          matrix[12] = center.dx;
          matrix[13] = center.dy;
          path.addOval(rect);
          return path.transform(matrix);
        }
        path.addOval(Rect.fromCenter(
          center: center,
          width: radii.x * 2,
          height: radii.y * 2,
        ));
        break;

      case BodyPartShape.circle:
        path.addOval(Rect.fromCircle(
          center: Offset(cx! * sx, cy! * sy),
          radius: r! * sx,
        ));
        break;

      case BodyPartShape.rect:
        path.addRect(Rect.fromLTWH(
          x! * sx,
          y! * sy,
          w! * sx,
          h! * sy,
        ));
        break;

      case BodyPartShape.roundedRect:
        final rect = Rect.fromLTWH(x! * sx, y! * sy, w! * sx, h! * sy);
        final cr = (cornerRadius ?? 4) * sx;
        if (rotation != null && rotation != 0) {
          final centeredRect = Rect.fromCenter(
            center: Offset.zero,
            width: w! * sx,
            height: h! * sy,
          );
          path.addRRect(RRect.fromRectAndRadius(centeredRect, Radius.circular(cr)));
          final rad = rotation! * 3.14159265 / 180;
          final cos = _cos(rad);
          final sin = _sin(rad);
          final matrix = Float64List(16)
            ..[0] = cos
            ..[1] = sin
            ..[4] = -sin
            ..[5] = cos
            ..[10] = 1
            ..[15] = 1
            ..[12] = (x! + w! / 2) * sx
            ..[13] = (y! + h! / 2) * sy;
          return path.transform(matrix);
        }
        path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(cr)));
        break;
    }

    return path;
  }

  static double _cos(double rad) {
    // Use dart:math in practice; inline to avoid import
    return _taylorCos(rad);
  }

  static double _sin(double rad) {
    return _taylorSin(rad);
  }

  static double _taylorCos(double x) {
    // Normalize to [-pi, pi]
    while (x > 3.14159265) x -= 6.28318530;
    while (x < -3.14159265) x += 6.28318530;
    final x2 = x * x;
    return 1 - x2 / 2 + x2 * x2 / 24 - x2 * x2 * x2 / 720;
  }

  static double _taylorSin(double x) {
    while (x > 3.14159265) x -= 6.28318530;
    while (x < -3.14159265) x += 6.28318530;
    final x2 = x * x;
    return x - x * x2 / 6 + x * x2 * x2 / 120 - x * x2 * x2 * x2 / 5040;
  }
}
