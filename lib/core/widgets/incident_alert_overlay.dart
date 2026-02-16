import 'package:flutter/material.dart';

/// Full-screen red flashing overlay that appears when new incidents arrive.
/// Displays incident details and an "Acknowledge" button to dismiss.
class IncidentAlertOverlay extends StatefulWidget {
  final List<Map<String, dynamic>> newIncidents;
  final VoidCallback onDismiss;

  const IncidentAlertOverlay({
    super.key,
    required this.newIncidents,
    required this.onDismiss,
  });

  @override
  State<IncidentAlertOverlay> createState() => _IncidentAlertOverlayState();
}

class _IncidentAlertOverlayState extends State<IncidentAlertOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  late final Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _flashAnimation = Tween<double>(begin: 0.15, end: 0.55).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  String _incidentTypeLabel(String? type) {
    switch (type) {
      case 'medical_emergency':
        return 'MEDICAL EMERGENCY';
      case 'fire':
        return 'FIRE';
      case 'vehicular_accident':
        return 'VEHICULAR ACCIDENT';
      case 'natural_disaster':
        return 'NATURAL DISASTER';
      case 'crime':
        return 'CRIME';
      case 'rescue':
        return 'RESCUE';
      default:
        return (type ?? 'UNKNOWN').toUpperCase().replaceAll('_', ' ');
    }
  }

  String _severityLabel(String? severity) {
    return (severity ?? 'unknown').toUpperCase();
  }

  IconData _incidentIcon(String? type) {
    switch (type) {
      case 'medical_emergency':
        return Icons.local_hospital;
      case 'fire':
        return Icons.local_fire_department;
      case 'vehicular_accident':
        return Icons.car_crash;
      case 'natural_disaster':
        return Icons.storm;
      case 'crime':
        return Icons.gavel;
      case 'rescue':
        return Icons.health_and_safety;
      default:
        return Icons.warning_amber;
    }
  }

  Color _severityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return const Color(0xFFFF1744);
      case 'high':
        return const Color(0xFFFF5722);
      case 'medium':
        return const Color(0xFFFFA726);
      case 'low':
        return const Color(0xFFFDD835);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Red flash background ──────────────────────────
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              return Container(
                color: Colors.red.withValues(alpha: _flashAnimation.value),
              );
            },
          ),

          // ── Content ───────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Alert icon
                    const Icon(
                      Icons.notification_important,
                      size: 72,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      widget.newIncidents.length == 1
                          ? 'NEW INCIDENT'
                          : '${widget.newIncidents.length} NEW INCIDENTS',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(blurRadius: 12, color: Colors.black54),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Incident cards
                    ...widget.newIncidents.take(5).map((inc) => _buildIncidentCard(inc)),

                    if (widget.newIncidents.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '+${widget.newIncidents.length - 5} more',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Acknowledge button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: widget.onDismiss,
                        icon: const Icon(Icons.check_circle, size: 28),
                        label: const Text(
                          'ACKNOWLEDGE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> inc) {
    final type = inc['incident_type']?.toString() ?? inc['type']?.toString();
    final severity = inc['severity']?.toString();
    final title = inc['incident_title']?.toString() ?? inc['description']?.toString() ?? 'No title';
    final number = inc['incident_number']?.toString() ?? '#${inc['id']}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _incidentIcon(type),
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _incidentTypeLabel(type),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Severity badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _severityColor(severity).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _severityColor(severity).withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              _severityLabel(severity),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _severityColor(severity),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
