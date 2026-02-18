import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/incident_response_provider.dart';

/// Persistent banner displayed across all screens when the
/// responder is actively responding to an incident.
///
/// Shows the incident number, current response phase, and a
/// live elapsed-time counter. Includes a popup menu for manual
/// status transitions.
class ResponseStatusBanner extends StatefulWidget {
  const ResponseStatusBanner({super.key});

  @override
  State<ResponseStatusBanner> createState() => _ResponseStatusBannerState();
}

class _ResponseStatusBannerState extends State<ResponseStatusBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Tick every second to update the elapsed time display
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<IncidentResponseProvider>();

    if (!rp.isRespondingToIncident) return const SizedBox.shrink();

    final statusColor = _getStatusColor(rp.responseStatus);
    final elapsed = rp.totalElapsed;
    final responseTime = rp.responseTimeElapsed;

    return Material(
      elevation: 4,
      child: Container(
        color: statusColor,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          left: 12,
          right: 4,
          bottom: 8,
        ),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department,
                color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Responding to Incident #${rp.activeIncidentId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Status: ${rp.responseStatusLabel}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      if (elapsed != null) ...[
                        const SizedBox(width: 12),
                        _buildTimerChip(elapsed, responseTime),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) => _onStatusAction(value, rp),
              itemBuilder: (context) => _buildMenuItems(rp.responseStatus),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerChip(Duration elapsed, Duration? responseTime) {
    // If on_scene or returning, show frozen response time
    final rp = context.read<IncidentResponseProvider>();
    final showResponseTime =
        responseTime != null &&
        (rp.responseStatus == ResponseStatus.onScene ||
            rp.responseStatus == ResponseStatus.returning);

    final displayDuration = showResponseTime ? responseTime : elapsed;
    final label = showResponseTime ? 'Response' : 'Elapsed';
    final minutes = displayDuration.inMinutes;
    final seconds = displayDuration.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            '$label: $minutes:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(String currentStatus) {
    final items = <PopupMenuEntry<String>>[];

    if (currentStatus == ResponseStatus.dispatched) {
      items.add(const PopupMenuItem(
        value: 'en_route',
        child: ListTile(
          leading: Icon(Icons.directions_car, color: Colors.blue),
          title: Text('Mark En Route'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ));
    }

    if (currentStatus == ResponseStatus.dispatched ||
        currentStatus == ResponseStatus.enRoute) {
      items.add(const PopupMenuItem(
        value: 'on_scene',
        child: ListTile(
          leading: Icon(Icons.location_on, color: Colors.red),
          title: Text('Mark On Scene'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ));
    }

    if (currentStatus == ResponseStatus.onScene) {
      items.add(const PopupMenuItem(
        value: 'complete',
        child: ListTile(
          leading: Icon(Icons.check_circle, color: Colors.green),
          title: Text('Complete Incident'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ));
    }

    if (items.isNotEmpty) {
      items.add(const PopupMenuDivider());
    }

    items.add(const PopupMenuItem(
      value: 'cancel',
      child: ListTile(
        leading: Icon(Icons.close, color: Colors.grey),
        title: Text('Cancel Response'),
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    ));

    return items;
  }

  void _onStatusAction(String action, IncidentResponseProvider rp) {
    switch (action) {
      case 'en_route':
        rp.markEnRoute();
        break;
      case 'on_scene':
        rp.markOnScene();
        break;
      case 'complete':
        rp.completeIncident();
        break;
      case 'cancel':
        rp.resetState();
        break;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case ResponseStatus.dispatched:
        return Colors.orange.shade700;
      case ResponseStatus.enRoute:
        return Colors.blue.shade700;
      case ResponseStatus.onScene:
        return Colors.red.shade700;
      case ResponseStatus.returning:
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}
