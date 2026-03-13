import 'package:flutter/material.dart';

/// Full-screen red flashing overlay that appears when new incidents arrive.
/// Displays incident details and an "Acknowledge" button to dismiss.
class IncidentAlertOverlay extends StatefulWidget {
  final List<Map<String, dynamic>> newIncidents;
  final VoidCallback onDismiss;
  final void Function(int incidentId) onAcknowledgeAndOpen;

  const IncidentAlertOverlay({
    super.key,
    required this.newIncidents,
    required this.onDismiss,
    required this.onAcknowledgeAndOpen,
  });

  @override
  State<IncidentAlertOverlay> createState() => _IncidentAlertOverlayState();
}

class _IncidentAlertOverlayState extends State<IncidentAlertOverlay>
    with TickerProviderStateMixin {
  // Flash animation (red pulse)
  late final AnimationController _flashController;
  late final Animation<double> _flashAnimation;

  // Entrance animation (fade + slide-up)
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // Carousel state (used when there are 2+ incidents)
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // ── Red flash ────────────────────────────────────────────
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);

    _flashAnimation = Tween<double>(begin: 0.0, end: 0.6).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
    );

    // ── Entrance: fast fade + slide-up (150 ms) ──────────────
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.08), // subtle upward slide
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    ));

    // Start entrance animation immediately
    _entranceController.forward();
  }

  @override
  void dispose() {
    _flashController.dispose();
    _entranceController.dispose();
    _pageController.dispose();
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
    final isMultiple = widget.newIncidents.length > 1;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
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
                          isMultiple
                              ? '${widget.newIncidents.length} NEW INCIDENTS'
                              : 'NEW INCIDENT',
                          textAlign: TextAlign.center,
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

                        if (isMultiple) ...[
                          const SizedBox(height: 6),
                          Text(
                            'I-swipe para tan-awon ang matag insidente',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ── Carousel (or single card) ─────────────
                        if (isMultiple)
                          _buildCarousel()
                        else
                          _buildIncidentCard(widget.newIncidents.first),

                        const SizedBox(height: 28),

                        // ── Action buttons ────────────────────────
                        if (isMultiple)
                          _buildMultipleButtons()
                        else
                          _buildSingleButton(widget.newIncidents.first),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Carousel used when there are 2+ incidents.
  Widget _buildCarousel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Page dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.newIncidents.length, (i) {
            final active = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white38,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),

        // Page indicator text (e.g., "2 / 3")
        Text(
          '${_currentPage + 1} / ${widget.newIncidents.length}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),

        // Swipeable pages — fixed height so it works inside a Column(min)
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.newIncidents.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) {
              return _buildIncidentCard(widget.newIncidents[i]);
            },
          ),
        ),
      ],
    );
  }

  /// Single "ACKNOWLEDGE & OPEN" button for a lone incident.
  Widget _buildSingleButton(Map<String, dynamic> inc) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {
          final id = inc['id'];
          if (id != null) widget.onAcknowledgeAndOpen(id as int);
        },
        icon: const Icon(Icons.check_circle, size: 28),
        label: const Text(
          'ACKNOWLEDGE & OPEN',
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
    );
  }

  /// Two buttons shown when there are 2+ incidents:
  ///   1. "OPEN THIS INCIDENT" → opens the currently visible incident.
  ///   2. "ACKNOWLEDGE ALL → VIEW LIST" → dismisses overlay, goes to list.
  Widget _buildMultipleButtons() {
    final current = widget.newIncidents[_currentPage];
    return Column(
      children: [
        // Open the currently visible incident
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              final id = current['id'];
              if (id != null) widget.onAcknowledgeAndOpen(id as int);
            },
            icon: const Icon(Icons.open_in_new, size: 22),
            label: Text(
              'OPEN INCIDENT ${_currentPage + 1} OF ${widget.newIncidents.length}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red.shade800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 8,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Acknowledge all and go to incidents list
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: widget.onDismiss,
            icon: const Icon(Icons.list_alt, size: 20, color: Colors.white),
            label: const Text(
              'ACKNOWLEDGE ALL — VIEW LIST',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white60, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> inc) {
    final type = inc['incident_type']?.toString() ?? inc['type']?.toString();
    final severity = inc['severity']?.toString();
    final title = inc['incident_title']?.toString() ??
        inc['description']?.toString() ??
        'No title';
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
