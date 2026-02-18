import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/body_part.dart';
import '../models/body_parts_data.dart';
import 'body_diagram_painter.dart';
import 'body_observation_dialog.dart';

/// Interactive body diagram with front and back views.
///
/// Supports tapping body regions to add observations, tracks
/// which parts have been documented, and can export a screenshot
/// as a base64 data URI via [exportAsBase64].
class EStreetBodyDiagramWidget extends StatefulWidget {
  final Map<String, String> observations;
  final ValueChanged<Map<String, String>> onObservationsChanged;

  const EStreetBodyDiagramWidget({
    super.key,
    required this.observations,
    required this.onObservationsChanged,
  });

  @override
  State<EStreetBodyDiagramWidget> createState() =>
      EStreetBodyDiagramWidgetState();
}

class EStreetBodyDiagramWidgetState extends State<EStreetBodyDiagramWidget> {
  String? _tappedKey;
  final _repaintBoundaryKey = GlobalKey();

  /// Capture the entire diagram (front + back) as a base64 data URI.
  Future<String?> exportAsBase64() async {
    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      return 'data:image/png;base64,${base64Encode(pngBytes)}';
    } catch (_) {
      return null;
    }
  }

  void _onTap(Offset localPosition, Size size, BodyPartView view) {
    final parts = BodyPartsData.getPartsForView(view);

    // Hit-test in reverse order (topmost first)
    for (final part in parts.reversed) {
      final path = part.createPath(size);
      if (path.contains(localPosition)) {
        _showObservationDialog(part);
        return;
      }
    }

    // Clear tapped state on background tap
    setState(() => _tappedKey = null);
  }

  Future<void> _showObservationDialog(BodyPart part) async {
    setState(() => _tappedKey = part.key);

    final result = await BodyObservationDialog.show(
      context,
      partLabel: part.label,
      currentObservation: widget.observations[part.key],
    );

    if (!mounted) return;

    if (result != null) {
      final updated = Map<String, String>.from(widget.observations);
      if (result.isEmpty) {
        updated.remove(part.key);
      } else {
        updated[part.key] = result;
      }
      widget.onObservationsChanged(updated);
    }

    setState(() => _tappedKey = null);
  }

  @override
  Widget build(BuildContext context) {
    final obsCount = widget.observations.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Text(
              'Body Diagram',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            if (obsCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$obsCount',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            const Spacer(),
            const Text(
              'Tap a region to add notes',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Diagrams (front + back side by side)
        RepaintBoundary(
          key: _repaintBoundaryKey,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: _buildDiagram(BodyPartView.front)),
                Container(width: 1, height: 380, color: Colors.grey.shade200),
                Expanded(child: _buildDiagram(BodyPartView.back)),
              ],
            ),
          ),
        ),

        // Legend
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendItem(Colors.grey.withOpacity(0.3), 'No Observation'),
            const SizedBox(width: 16),
            _legendItem(Colors.green.withOpacity(0.3), 'Has Observation'),
            const SizedBox(width: 16),
            _legendItem(Colors.blue.withOpacity(0.35), 'Selected'),
          ],
        ),
      ],
    );
  }

  Widget _buildDiagram(BodyPartView view) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            final size = Size(constraints.maxWidth, 380);
            _onTap(details.localPosition, size, view);
          },
          child: SizedBox(
            height: 380,
            child: CustomPaint(
              size: Size(constraints.maxWidth, 380),
              painter: BodyDiagramPainter(
                view: view,
                observations: widget.observations,
                tappedKey: _tappedKey,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
