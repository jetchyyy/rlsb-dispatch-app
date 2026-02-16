import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/body_part.dart';
import '../models/body_parts_data.dart';
import 'body_diagram_painter.dart';
import 'body_observation_dialog.dart';

/// Interactive body diagram widget showing front + back views side-by-side.
/// Tapping a region opens an observation dialog. Observed parts turn green.
class EStreetBodyDiagramWidget extends StatefulWidget {
  final Map<String, String> observations;
  final Future<void> Function(Map<String, String>) onObservationsChanged;

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
  final GlobalKey _repaintKey = GlobalKey();

  /// Capture the body diagram as a base64-encoded PNG image
  Future<String?> exportAsBase64() async {
    try {
      // Get the RenderRepaintBoundary
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Capture as image
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      // Convert to base64
      final bytes = byteData.buffer.asUint8List();
      return 'data:image/png;base64,${base64Encode(bytes)}';
    } catch (e) {
      print('❌ Error capturing body diagram: $e');
      return null;
    }
  }

  void _onTap(TapUpDetails details, Size size, BodyPartView view) {
    final parts = BodyPartsData.getPartsForView(view);

    // Test in reverse so smaller/top regions take priority
    for (final part in parts.reversed) {
      final path = part.createPath(size);
      if (path.contains(details.localPosition)) {
        setState(() => _tappedKey = part.key);
        _showObservationDialog(part);
        // Clear tap highlight after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _tappedKey = null);
        });
        return;
      }
    }
  }

  Future<void> _showObservationDialog(BodyPart part) async {
    final result = await BodyObservationDialog.show(
      context,
      partLabel: part.label,
      currentObservation: widget.observations[part.key],
    );

    if (result == null) return; // dismissed

    final updated = Map<String, String>.from(widget.observations);
    if (result.isEmpty) {
      updated.remove(part.key);
    } else {
      updated[part.key] = result;
    }
    widget.onObservationsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final obsCount = widget.observations.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.accessibility_new, size: 20, color: Color(0xFF1976D2)),
              const SizedBox(width: 8),
              const Text(
                'Body Injury Map',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (obsCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF28A745),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$obsCount region${obsCount > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),

        // Side-by-side body diagrams
        RepaintBoundary(
          key: _repaintKey,
          child: SizedBox(
            height: 380,
            child: Row(
              children: [
                Expanded(child: _buildDiagram(BodyPartView.front)),
                const SizedBox(width: 8),
                Expanded(child: _buildDiagram(BodyPartView.back)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0x30607D8B), 'No Observation'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFF28A745), 'Has Observation'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFF007BFF), 'Selected'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiagram(BodyPartView view) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onTapUp: (details) => _onTap(details, size, view),
            child: CustomPaint(
              size: size,
              painter: BodyDiagramPainter(
                view: view,
                observations: widget.observations,
                tappedKey: _tappedKey,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color, width: 1.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
