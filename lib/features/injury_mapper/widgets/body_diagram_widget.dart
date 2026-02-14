import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/body_region.dart';
import '../../../../core/providers/injury_provider.dart';
import '../data/body_regions_data.dart';
import 'body_region_painter.dart';
import 'injury_input_modal.dart';

/// Interactive body diagram with front/back views via PageView.
/// Taps on body regions open the injury input modal.
class BodyDiagramWidget extends StatefulWidget {
  const BodyDiagramWidget({super.key});

  @override
  State<BodyDiagramWidget> createState() => _BodyDiagramWidgetState();
}

class _BodyDiagramWidgetState extends State<BodyDiagramWidget> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _hoveredRegionId;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Checks which region was tapped using normalized coordinates.
  BodyRegion? _hitTestRegion(
      Offset localPosition, Size size, BodyView view) {
    final normalizedPoint = Offset(
      localPosition.dx / size.width,
      localPosition.dy / size.height,
    );

    final regions = BodyRegionsData.getRegionsForView(view);

    // Iterate in reverse so smaller/top regions take priority.
    for (final region in regions.reversed) {
      final path = ui.Path();
      if (region.polygonPoints.isEmpty) continue;
      path.moveTo(
        region.polygonPoints.first.dx,
        region.polygonPoints.first.dy,
      );
      for (int i = 1; i < region.polygonPoints.length; i++) {
        path.lineTo(
          region.polygonPoints[i].dx,
          region.polygonPoints[i].dy,
        );
      }
      path.close();

      if (path.contains(normalizedPoint)) {
        return region;
      }
    }
    return null;
  }

  void _onTapUp(TapUpDetails details, Size size, BodyView view) {
    final region = _hitTestRegion(details.localPosition, size, view);
    if (region != null) {
      InjuryInputModal.show(context, region);
    }
  }

  @override
  Widget build(BuildContext context) {
    final injuryProvider = context.watch<InjuryProvider>();

    return Column(
      children: [
        // ── View Label ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _currentPage == 0 ? 'Front View' : 'Back View',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Body Diagram ─────────────────────────────────────
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            children: [
              _buildBodyPage(BodyView.front, injuryProvider),
              _buildBodyPage(BodyView.back, injuryProvider),
            ],
          ),
        ),

        // ── Page Indicator Dots ──────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildBodyPage(BodyView view, InjuryProvider injuryProvider) {
    final assetPath = view == BodyView.front
        ? 'assets/images/body_front.png'
        : 'assets/images/body_back.png';

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onTapUp: (details) => _onTapUp(details, size, view),
          child: Stack(
            children: [
              // (a) Body silhouette
              Positioned.fill(
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      view == BodyView.front
                          ? Icons.accessibility_new
                          : Icons.accessibility,
                      size: 200,
                      color: Colors.grey[300],
                    ),
                  ),
                ),
              ),

              // (b) Region overlay painter
              Positioned.fill(
                child: CustomPaint(
                  painter: BodyRegionPainter(
                    view: view,
                    injuryProvider: injuryProvider,
                    selectedRegionId: _hoveredRegionId,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
