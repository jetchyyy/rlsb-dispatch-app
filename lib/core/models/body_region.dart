import 'dart:ui';

/// Represents a selectable body region on the diagram.
class BodyRegion {
  /// Unique region ID (matches [BodyRegionConstants]).
  final String regionId;

  /// Human-readable name.
  final String regionName;

  /// Which body view this region belongs to.
  final BodyView view;

  /// Normalized polygon coordinates (0.0–1.0).
  /// Scaled to actual widget size at paint time.
  final List<Offset> polygonPoints;

  const BodyRegion({
    required this.regionId,
    required this.regionName,
    required this.view,
    required this.polygonPoints,
  });
}

/// Whether the region appears on the front or back body diagram.
enum BodyView { front, back }
