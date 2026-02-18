import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/incident_provider.dart';
import '../../../core/providers/location_tracking_provider.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _showList = true;
  bool _mapReady = false;
  double _currentZoom = _defaultZoom;
  List<Marker>? _cachedMarkers; // Cache markers to avoid rebuilding
  int _lastIncidentHash = 0; // Track if incidents changed

  // Animation controller for smooth transitions
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Animation controller for flashing incident markers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Default center: Surigao City (city proper)
  static const _defaultCenter = LatLng(9.7894, 125.4953);
  static const _defaultZoom = 12.0;

  // Province boundaries
  static const _minLat = 9.4;
  static const _maxLat = 10.5;
  static const _minLng = 125.0;
  static const _maxLng = 126.2;

  static final _provinceBounds = LatLngBounds(
    const LatLng(_minLat, _minLng),
    const LatLng(_maxLat, _maxLng),
  );

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

    // Setup fade animation for smooth entry
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Setup pulse animation for incident markers
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Delay map readiness to prevent jitter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().fetchIncidents(silent: true);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() => _mapReady = true);
          _fadeController.forward();
        }
      });
    });

    // Listen to zoom changes to optimize animations
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove || event is MapEventMoveEnd) {
        final newZoom = _mapController.camera.zoom;
        if ((newZoom - _currentZoom).abs() > 0.5) {
          setState(() {
            _currentZoom = newZoom;
            _cachedMarkers = null; // Clear cache on zoom change
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  List<Marker> _buildMarkers(List<Map<String, dynamic>> incidents) {
    // Check if we can use cached markers
    final incidentHash = incidents.length; // Simple hash based on count
    if (_cachedMarkers != null && _lastIncidentHash == incidentHash) {
      return _cachedMarkers!;
    }

    final markers = <Marker>[];
    final isZoomedIn = _currentZoom >= 13; // Only animate when zoomed in
    final showIcons = _currentZoom >= 12; // Only show icons when zoomed in

    for (final inc in incidents) {
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
          width: isZoomedIn ? 48 : 24,
          height: isZoomedIn ? 48 : 24,
          child: RepaintBoundary(
            child: GestureDetector(
              onTap: () => _showIncidentPopup(inc, color),
              child: isZoomedIn
                  ? _buildAnimatedMarker(color, type, showIcons)
                  : _buildSimpleMarker(color),
            ),
          ),
        ),
      );
    }

    // Cache the markers
    _lastIncidentHash = incidentHash;
    _cachedMarkers = markers;
    return markers;
  }

  /// Build animated marker for zoomed-in view (zoom >= 13)
  Widget _buildAnimatedMarker(Color color, String type, bool showIcons) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing outer ring
            Container(
              width: 48 * _pulseAnimation.value,
              height: 48 * _pulseAnimation.value,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.3 * _pulseAnimation.value),
                shape: BoxShape.circle,
              ),
            ),
            // Main marker (pre-built, not animated)
            child!,
          ],
        );
      },
      // Pre-build the static marker child to avoid rebuilding it every frame
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: showIcons
            ? Icon(
                _typeIcon(type),
                color: Colors.white,
                size: 16,
              )
            : null,
      ),
    );
  }

  /// Build simple marker for zoomed-out view (zoom < 13)
  Widget _buildSimpleMarker(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }

  /// Build user location marker (blue dot with accuracy circle)
  Marker? _buildUserLocationMarker() {
    final locationProvider = context.watch<LocationTrackingProvider>();
    final position = locationProvider.lastPosition;

    if (position == null) return null;

    final lat = position.latitude;
    final lng = position.longitude;

    // Only show if within Surigao del Norte bounds
    if (lat < _minLat || lat > _maxLat || lng < _minLng || lng > _maxLng) {
      return null;
    }

    final isZoomedIn = _currentZoom >= 13;

    return Marker(
      point: LatLng(lat, lng),
      width: isZoomedIn ? 60 : 30,
      height: isZoomedIn ? 60 : 30,
      child: RepaintBoundary(
        child: isZoomedIn
            ? Stack(
                alignment: Alignment.center,
                children: [
                  // Accuracy circle
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  // User location dot with pulsing animation
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 16 + (4 * _pulseAnimation.value),
                        height: 16 + (4 * _pulseAnimation.value),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.5 * _pulseAnimation.value),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              )
            : Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
      ),
    );
  }

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  void _showIncidentPopup(Map<String, dynamic> inc, Color color) {
    final id = inc['id'];
    final incNumber = inc['incident_number']?.toString() ?? '#$id';
    final type = (inc['incident_type'] ?? inc['type'] ?? 'unknown').toString();
    final status = (inc['status'] ?? '').toString();
    final severity = (inc['severity'] ?? '').toString();
    final title = inc['incident_title']?.toString() ??
        inc['title']?.toString() ??
        type.replaceAll('_', ' ');
    final municipality = inc['municipality']?.toString() ?? 'Unknown';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_typeIcon(type), color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(incNumber,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _chip(status.replaceAll('_', ' ').toUpperCase(),
                    AppColors.incidentStatusColor(status)),
                const SizedBox(width: 8),
                _chip(severity.toUpperCase(), color),
                const Spacer(),
                Icon(Icons.place, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(municipality,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (id != null) context.push('/incidents/$id');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  void _fitBounds(List<Map<String, dynamic>> incidents) {
    final points = <LatLng>[];
    for (final inc in incidents) {
      final lat = _parseDouble(inc['latitude']);
      final lng = _parseDouble(inc['longitude']);
      if (lat != null && lng != null) {
        // Only include points within Surigao del Norte bounds
        if (lat >= _minLat &&
            lat <= _maxLat &&
            lng >= _minLng &&
            lng <= _maxLng) {
          points.add(LatLng(lat, lng));
        }
      }
    }
    if (points.length >= 2) {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    } else if (points.length == 1) {
      _animatedMove(points.first, 14.0);
    } else {
      // If no points, fit to province bounds
      _mapController.fitCamera(
        CameraFit.bounds(
            bounds: _provinceBounds, padding: const EdgeInsets.all(20)),
      );
    }
  }

  /// Smoothly animate the map camera to a new position
  void _animatedMove(LatLng destLocation, double destZoom) {
    final camera = _mapController.camera;
    final latTween = Tween<double>(
        begin: camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);

    final controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    final animation =
        CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final ip = context.watch<IncidentProvider>();
    // Filter to only show active incidents
    final incidents = ip.incidents.where((inc) {
      final status = (inc['status'] ?? '').toString().toLowerCase();
      return _activeStatuses.contains(status);
    }).toList();
    
    // Build markers (uses caching)
    final markers = _buildMarkers(incidents);
    final userMarker = _buildUserLocationMarker();

    // Combine incident markers with user location marker
    final allMarkers = [...markers];
    if (userMarker != null) {
      allMarkers.add(userMarker);
    }

    // Pause animations when zoomed out for better performance
    if (_currentZoom < 13) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    } else {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Surigao del Norte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Fit all markers',
            onPressed: () => _fitBounds(incidents),
          ),
          IconButton(
            icon: Icon(_showList ? Icons.map : Icons.list),
            tooltip: _showList ? 'Full map' : 'Show list',
            onPressed: () => setState(() => _showList = !_showList),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ip.fetchIncidents(silent: true),
          ),
        ],
      ),
      body: Hero(
        tag: 'map_hero_transition',
        child: Material(
          child: Column(
            children: [
              // ── OpenStreetMap ────────────────────────────────
              Expanded(
                child: _mapReady
                    ? FadeTransition(
                        opacity: _fadeAnimation,
                        child: RepaintBoundary(
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _defaultCenter,
                              initialZoom: _defaultZoom,
                              minZoom: 8,
                              maxZoom: 18,
                              backgroundColor: const Color(0xFFE8E8E8),
                              // Constrain center to Surigao del Norte bounds
                              cameraConstraint: CameraConstraint.containCenter(
                                bounds: _provinceBounds,
                              ),
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all,
                                // Smooth zoom with scroll wheel velocity
                                scrollWheelVelocity: 0.002,
                                // Enable pinch move for smoother gestures
                                enableMultiFingerGestureRace: true,
                              ),
                              onMapReady: () {
                                // Fit to province bounds on first load
                                Future.delayed(
                                    const Duration(milliseconds: 200), () {
                                  if (mounted && markers.isNotEmpty) {
                                    _fitBounds(incidents);
                                  }
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'ph.inno.sdnpdrrmo.dispatch',
                                maxZoom: 19,
                                // Optimize buffer sizes for better performance
                                keepBuffer: 4, // Reduced from 8
                                panBuffer: 2, // Reduced from 3
                                // Smooth fade-in for tiles instead of instant pop
                                tileDisplay: const TileDisplay.fadeIn(
                                  duration: Duration(milliseconds: 100), // Faster
                                ),
                                evictErrorTileStrategy: EvictErrorTileStrategy
                                    .notVisibleRespectMargin,
                              ),
                              MarkerLayer(markers: allMarkers),
                            ],
                          ),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(),
                      ),
              ),

              // ── Severity Legend & Incident List Panel ────────
              if (_showList)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, -2)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Legend
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _legendDot('Critical', AppColors.severityCritical),
                            _legendDot('High', AppColors.severityHigh),
                            _legendDot('Medium', AppColors.severityMedium),
                            _legendDot('Low', AppColors.severityLow),
                            Text('${markers.length} pins',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // Incident list
                      SizedBox(
                        height: 160,
                        child: incidents.isEmpty
                            ? const Center(
                                child: Text('No incidents',
                                    style:
                                        TextStyle(color: AppColors.textHint)),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                cacheExtent: 300,
                                itemCount: incidents.length > 30
                                    ? 30
                                    : incidents.length,
                                itemBuilder: (_, i) {
                                  final inc = incidents[i];
                                  final severity = (inc['severity'] ?? 'medium')
                                      .toString()
                                      .toLowerCase();
                                  final status = (inc['status'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final lat = _parseDouble(inc['latitude']);
                                  final lng = _parseDouble(inc['longitude']);
                                  final hasCoords = lat != null && lng != null;

                                  // Only show incidents within bounds
                                  final inBounds = hasCoords &&
                                      lat >= _minLat &&
                                      lat <= _maxLat &&
                                      lng >= _minLng &&
                                      lng <= _maxLng;

                                  return ListTile(
                                    dense: true,
                                    visualDensity:
                                        const VisualDensity(vertical: -3),
                                    leading: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: AppColors.incidentSeverityColor(
                                            severity),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    title: Text(
                                      inc['incident_title']?.toString() ??
                                          inc['title']?.toString() ??
                                          'Incident #${inc['incident_number'] ?? inc['id']}',
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${inc['municipality'] ?? 'Unknown'} • ${status.replaceAll('_', ' ')}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    trailing: inBounds
                                        ? const Icon(Icons.place,
                                            size: 14, color: AppColors.primary)
                                        : const Icon(Icons.place_outlined,
                                            size: 14,
                                            color: AppColors.textHint),
                                    onTap: () {
                                      if (inBounds) {
                                        _animatedMove(LatLng(lat, lng), 15.0);
                                        setState(() => _showList = false);
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
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
        return Icons.public;
      case 'landslide':
        return Icons.landscape;
      case 'typhoon':
        return Icons.cyclone;
      case 'rescue':
        return Icons.health_and_safety;
      case 'crime':
        return Icons.gavel;
      default:
        return Icons.warning_amber;
    }
  }
}
