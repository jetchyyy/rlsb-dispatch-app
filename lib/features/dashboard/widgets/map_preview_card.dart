import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';

/// A small, interactive map preview card for the dashboard quick actions.
/// Shows recent incident locations as markers on OpenStreetMap.
/// Optimized for Surigao del Norte province with smooth animations.
class MapPreviewCard extends StatefulWidget {
  final List<Map<String, dynamic>> incidents;
  final VoidCallback onTap;

  const MapPreviewCard({
    super.key,
    required this.incidents,
    required this.onTap,
  });

  @override
  State<MapPreviewCard> createState() => _MapPreviewCardState();
}

class _MapPreviewCardState extends State<MapPreviewCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  // Surigao del Norte bounds - optimized center
  static const _defaultCenter = LatLng(9.8500, 125.5500);
  static const _defaultZoom = 9.5;

  // Province boundaries for clamping
  static const _minLat = 9.4;
  static const _maxLat = 10.5;
  static const _minLng = 125.0;
  static const _maxLng = 126.2;

  // Active statuses to display on map
  static const _activeStatuses = {
    'reported',
    'acknowledged',
    'dispatched',
    'en_route',
    'on_scene',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Only show up to 10 markers to avoid clutter
    final limitedIncidents = widget.incidents.take(10);

    for (final inc in limitedIncidents) {
      // Only show active incidents (filter out resolved, closed, cancelled)
      final status = (inc['status'] ?? '').toString().toLowerCase();
      if (!_activeStatuses.contains(status)) continue;

      final lat = _parseDouble(inc['latitude']);
      final lng = _parseDouble(inc['longitude']);
      if (lat == null || lng == null) continue;

      // Only show markers within Surigao del Norte bounds
      if (lat < _minLat || lat > _maxLat || lng < _minLng || lng > _maxLng) {
        continue;
      }

      final severity = (inc['severity'] ?? 'medium').toString().toLowerCase();
      final color = AppColors.incidentSeverityColor(severity);
      final type =
          (inc['incident_type'] ?? inc['type'] ?? 'unknown').toString();

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 24,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Icon(
              _typeIcon(type),
              color: Colors.white,
              size: 10,
            ),
          ),
        ),
      );
    }
    return markers;
  }

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department;
      case 'medical_emergency':
      case 'medical':
        return Icons.local_hospital;
      case 'vehicular_accident':
      case 'accident':
        return Icons.car_crash;
      case 'flood':
        return Icons.flood;
      case 'natural_disaster':
      case 'earthquake':
      case 'landslide':
      case 'typhoon':
        return Icons.public;
      case 'rescue':
        return Icons.health_and_safety;
      case 'crime':
        return Icons.gavel;
      default:
        return Icons.warning_amber;
    }
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: (details) {
          _handleTapUp(details);
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        onTapCancel: _handleTapCancel,
        child: Hero(
          tag: 'map_hero_transition',
          flightShuttleBuilder: (
            BuildContext flightContext,
            Animation<double> animation,
            HeroFlightDirection flightDirection,
            BuildContext fromHeroContext,
            BuildContext toHeroContext,
          ) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(12 * (1 - animation.value)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(0.2 * (1 - animation.value)),
                        blurRadius: 20 * animation.value,
                        spreadRadius: 5 * animation.value,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(12 * (1 - animation.value)),
                    child: child,
                  ),
                );
              },
              child: Material(
                color: Colors.white,
                child: _buildMapContent(markers),
              ),
            );
          },
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            elevation: _isPressed ? 2 : 4,
            shadowColor: Colors.black.withOpacity(0.15),
            child: _buildMapContent(markers),
          ),
        ),
      ),
    );
  }

  Widget _buildMapContent(List<Marker> markers) {
    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          // ── Map Layer ──────────────────────────────────
          Positioned.fill(
            child: RepaintBoundary(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: _defaultZoom,
                  minZoom: 8,
                  maxZoom: 12,
                  backgroundColor: const Color(0xFFE8E8E8),
                  // Constrain center to Surigao del Norte bounds
                  cameraConstraint: CameraConstraint.containCenter(
                    bounds: LatLngBounds(
                      const LatLng(_minLat, _minLng),
                      const LatLng(_maxLat, _maxLng),
                    ),
                  ),
                  interactionOptions: const InteractionOptions(
                    flags:
                        InteractiveFlag.none, // Disable interactions in preview
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ph.inno.sdnpdrrmo.dispatch',
                    maxZoom: 19,
                    keepBuffer: 8,
                    panBuffer: 3,
                    evictErrorTileStrategy:
                        EvictErrorTileStrategy.notVisibleRespectMargin,
                  ),
                  if (markers.isNotEmpty) MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),

          // ── Gradient Overlay ───────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.25),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Label & Count ──────────────────────────────
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Surigao del Norte',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (markers.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      '${markers.length} active',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Tap indicator ──────────────────────────────
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
