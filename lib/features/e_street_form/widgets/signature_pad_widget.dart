import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Custom signature capture widget that draws strokes on a canvas.
///
/// **Key improvement over the previous version:** when [initialData]
/// is provided (a base64 data URI), the existing signature is rendered
/// as a background image so users can see what was previously signed.
///
/// Export via [exportBase64] to get a `data:image/png;base64,...` string.
class SignaturePadWidget extends StatefulWidget {
  final String label;
  final String? initialData;

  const SignaturePadWidget({
    super.key,
    required this.label,
    this.initialData,
  });

  @override
  State<SignaturePadWidget> createState() => SignaturePadWidgetState();
}

class SignaturePadWidgetState extends State<SignaturePadWidget> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;
  bool _isEmpty = true;
  ui.Image? _backgroundImage;
  final _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _loadBackgroundImage(widget.initialData!);
      _isEmpty = false;
    }
  }

  Future<void> _loadBackgroundImage(String dataUri) async {
    try {
      String b64 = dataUri;
      if (b64.contains('base64,')) {
        b64 = b64.split('base64,').last;
      }
      final bytes = base64Decode(b64);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _backgroundImage = frame.image;
        });
      }
    } catch (_) {
      // Silently fail — signature will appear empty
    }
  }

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
      _isEmpty = true;
      _backgroundImage = null;
    });
  }

  /// Export the drawn signature as a `data:image/png;base64,...` string.
  /// Returns `null` if nothing was drawn and no initial data exists.
  Future<String?> exportBase64() async {
    if (_isEmpty && _backgroundImage == null) return null;

    // If only a background image exists with no new strokes,
    // return the original data
    if (_strokes.isEmpty && _backgroundImage != null && widget.initialData != null) {
      return widget.initialData;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 150);

      // White background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white,
      );

      // Draw background image
      if (_backgroundImage != null) {
        final src = Rect.fromLTWH(
          0, 0,
          _backgroundImage!.width.toDouble(),
          _backgroundImage!.height.toDouble(),
        );
        final dst = Rect.fromLTWH(0, 0, size.width, size.height);
        canvas.drawImageRect(_backgroundImage!, src, dst, Paint());
      }

      // Draw strokes
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      for (final stroke in _strokes) {
        if (stroke.length < 2) continue;
        final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
        for (var i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, paint);
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(400, 150);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      return 'data:image/png;base64,${base64Encode(pngBytes)}';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            TextButton.icon(
              onPressed: clear,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          key: _repaintKey,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: GestureDetector(
              onPanStart: (d) {
                setState(() {
                  _currentStroke = [d.localPosition];
                  _isEmpty = false;
                });
              },
              onPanUpdate: (d) {
                setState(() {
                  _currentStroke?.add(d.localPosition);
                });
              },
              onPanEnd: (_) {
                if (_currentStroke != null) {
                  setState(() {
                    _strokes.add(List.from(_currentStroke!));
                    _currentStroke = null;
                  });
                }
              },
              child: CustomPaint(
                size: const Size(double.infinity, 150),
                painter: _SignaturePainter(
                  strokes: _strokes,
                  currentStroke: _currentStroke,
                  backgroundImage: _backgroundImage,
                  isEmpty: _isEmpty && _backgroundImage == null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset>? currentStroke;
  final ui.Image? backgroundImage;
  final bool isEmpty;

  _SignaturePainter({
    required this.strokes,
    this.currentStroke,
    this.backgroundImage,
    required this.isEmpty,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background image (previously signed)
    if (backgroundImage != null) {
      final src = Rect.fromLTWH(
        0, 0,
        backgroundImage!.width.toDouble(),
        backgroundImage!.height.toDouble(),
      );
      final dst = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(backgroundImage!, src, dst, Paint());
    }

    // Baseline
    final baseY = size.height - 30;
    canvas.drawLine(
      Offset(20, baseY),
      Offset(size.width - 20, baseY),
      Paint()
        ..color = Colors.grey.shade300
        ..strokeWidth = 1,
    );

    // Empty state hint
    if (isEmpty && strokes.isEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'Sign here',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, baseY - tp.height - 4));
    }

    // Draw strokes
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}
