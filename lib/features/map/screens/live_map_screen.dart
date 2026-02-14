import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/incident_provider.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController _mapController = MapController();
  bool _showList = true;

  // Default center: Surigao del Norte area
  static const _defaultCenter = LatLng(9.7500, 125.5000);
  static const _defaultZoom = 10.0;

  @override
  void initState() {
    super.initState();
    context.read<IncidentProvider>().fetchIncidents(silent: true);
  }

  List<Marker> _buildMarkers(List<Map<String, dynamic>> incidents) {
    final markers = <Marker>[];
    for (final inc in incidents) {
      final lat = _parseDouble(inc['latitude']);
      final lng = _parseDouble(inc['longitude']);
      if (lat == null || lng == null) continue;

      final severity = (inc['severity'] ?? 'medium').toString().toLowerCase();
      final color = AppColors.incidentSeverityColor(severity);
      final type =
          (inc['incident_type'] ?? inc['type'] ?? 'unknown').toString();

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _showIncidentPopup(inc, color),
            child: Container(
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
              child: Icon(
                _typeIcon(type),
                color: Colors.white,
                size: 16,
              ),
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

  void _showIncidentPopup(Map<String, dynamic> inc, Color color) {
    final id = inc['id'];
    final incNumber = inc['incident_number']?.toString() ?? '#$id';
    final type =
        (inc['incident_type'] ?? inc['type'] ?? 'unknown').toString();
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
                _chip(
                    status.replaceAll('_', ' ').toUpperCase(),
                    AppColors.incidentStatusColor(status)),
                const SizedBox(width: 8),
                _chip(severity.toUpperCase(), color),
                const Spacer(),
                Icon(Icons.place, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(municipality,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
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
      if (lat != null && lng != null) points.add(LatLng(lat, lng));
    }
    if (points.length >= 2) {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
            bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    } else if (points.length == 1) {
      _mapController.move(points.first, 14.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ip = context.watch<IncidentProvider>();
    final incidents = ip.incidents;
    final markers = _buildMarkers(incidents);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking Map'),
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
      body: Column(
        children: [
          // ── OpenStreetMap ────────────────────────────────
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: _defaultZoom,
                minZoom: 5,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'ph.inno.sdnpdrrmo.dispatch',
                  maxZoom: 19,
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),

          // ── Severity Legend & Incident List Panel ────────
          if (_showList)
            Container(
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
                              final lat =
                                  _parseDouble(inc['latitude']);
                              final lng =
                                  _parseDouble(inc['longitude']);
                              final hasCoords =
                                  lat != null && lng != null;

                              return ListTile(
                                dense: true,
                                visualDensity:
                                    const VisualDensity(vertical: -3),
                                leading: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: AppColors
                                        .incidentSeverityColor(severity),
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
                                trailing: hasCoords
                                    ? const Icon(Icons.place,
                                        size: 14,
                                        color: AppColors.primary)
                                    : const Icon(Icons.place_outlined,
                                        size: 14,
                                        color: AppColors.textHint),
                                onTap: () {
                                  if (hasCoords) {
                                    _mapController.move(
                                        LatLng(lat!, lng!), 15.0);
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
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
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
