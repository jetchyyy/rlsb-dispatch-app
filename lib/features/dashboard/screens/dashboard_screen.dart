import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/incident_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../widgets/map_preview_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        final provider = context.read<IncidentProvider>();
        // Clear any existing filters to show all incidents
        provider.clearFilters();
        provider.fetchIncidents();
        provider.fetchStatistics();
        provider.startAutoRefresh();
      }
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final ip = context.watch<IncidentProvider>();
    final user = authProvider.user;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await Future.wait([
              ip.fetchIncidents(),
              ip.fetchStatistics(),
            ]);
          },
          color: Colors.white,
          backgroundColor: AppColors.primary,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ── Header ─────────────────────────────────
                _buildHeader(user, ip),

                // ── Content ────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 96 + bottomPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Stats row
                        _buildStatsRow(ip),

                        const SizedBox(height: 28),

                        // Quick actions
                        _buildQuickActions(context, ip),

                        // Error banner
                        if (ip.errorMessage != null) ...[
                          const SizedBox(height: 20),
                          _buildErrorBanner(ip),
                        ],

                        const SizedBox(height: 28),

                        // Recent incidents
                        _buildRecentIncidents(context, ip),

                        // Last updated
                        if (ip.lastFetchTime != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Center(
                              child: Text(
                                'Updated ${timeago.format(ip.lastFetchTime!)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: _buildFAB(context),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader(dynamic user, IncidentProvider ip) {
    return SliverAppBar(
      expandedHeight: 150,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primary,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D47A1),
                Color(0xFF1565C0),
                Color(0xFF1976D2),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.name ?? 'Staff',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (user != null)
                    Text(
                      user.position != null
                          ? '${user.position}${user.division != null ? " · ${user.division}" : ""}'
                          : user.roleLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ),
        collapseMode: CollapseMode.pin,
      ),
      title: const Text(
        'PDRRMO Dispatch',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh_rounded,
            color: Colors.white.withOpacity(0.85),
            size: 22,
          ),
          tooltip: 'Refresh',
          onPressed: () {
            HapticFeedback.lightImpact();
            ip.fetchIncidents();
            ip.fetchStatistics();
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATS ROW
  // ═══════════════════════════════════════════════════════════

  Widget _buildStatsRow(IncidentProvider ip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              label: 'Active',
              value: ip.activeCount,
              icon: Icons.radio_button_checked_rounded,
              color: const Color(0xFFEF4444),
              isLoading: ip.isLoading,
              pulse: ip.activeCount > 0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: 'New',
              value: ip.newCount,
              icon: Icons.fiber_new_rounded,
              color: const Color(0xFFF97316),
              isLoading: ip.isLoading,
              pulse: ip.newCount > 0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: 'Critical',
              value: ip.criticalCount,
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFDC2626),
              isLoading: ip.isLoading,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: 'Total',
              value: ip.todayTotal,
              icon: Icons.assessment_outlined,
              color: const Color(0xFF3B82F6),
              isLoading: ip.isLoading,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ═══════════════════════════════════════════════════════════

  Widget _buildQuickActions(BuildContext context, IncidentProvider ip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK ACTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.list_alt_rounded,
                  label: 'Incidents',
                  subtitle: 'View all',
                  color: AppColors.primary,
                  onTap: () => context.push('/incidents'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionCard(
                  icon: Icons.analytics_outlined,
                  label: 'Analytics',
                  subtitle: 'Reports',
                  color: const Color(0xFF8B5CF6),
                  onTap: () => context.push('/analytics'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Map preview (full width)
          MapPreviewCard(
            incidents: ip.incidents,
            onTap: () => context.push('/map'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ERROR BANNER
  // ═══════════════════════════════════════════════════════════

  Widget _buildErrorBanner(IncidentProvider ip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFDC2626), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ip.errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => ip.fetchIncidents(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // RECENT INCIDENTS
  // ═══════════════════════════════════════════════════════════

  Widget _buildRecentIncidents(BuildContext context, IncidentProvider ip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVE INCIDENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.grey.shade500,
                ),
              ),
              if (ip.incidents.isNotEmpty)
                GestureDetector(
                  onTap: () => context.push('/incidents'),
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          if (ip.isLoading && ip.incidents.isEmpty)
            _buildLoadingShimmer()
          else if (ip.incidents.isEmpty)
            _buildEmptyState()
          else
            _buildIncidentList(ip),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i < 2 ? 8 : 0),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No incidents',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pull down to refresh',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentList(IncidentProvider ip) {
    // Filter out resolved/closed/cancelled incidents
    final activeIncidents = ip.incidents
        .where((incident) {
          final status = (incident['status'] ?? '').toString().toLowerCase();
          return !['resolved', 'closed', 'cancelled'].contains(status);
        })
        .take(5)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < activeIncidents.length; i++) ...[
            _IncidentRow(
              incident: activeIncidents[i],
              onTap: () {
                final id = activeIncidents[i]['id'];
                if (id != null) context.push('/incidents/$id');
              },
            ),
            if (i < activeIncidents.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.shade100,
                indent: 54,
              ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FAB
  // ═══════════════════════════════════════════════════════════

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        HapticFeedback.mediumImpact();
        context.push('/incidents/create');
      },
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text(
        'Report',
        style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// STAT TILE
// ═════════════════════════════════════════════════════════════

class _StatTile extends StatefulWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final bool pulse;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.pulse = false,
  });

  @override
  State<_StatTile> createState() => _StatTileState();
}

class _StatTileState extends State<_StatTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.pulse) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatTile old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.pulse && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow = widget.pulse ? _pulse.value * 0.08 : 0.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.pulse
                    ? widget.color.withOpacity(0.08 + glow)
                    : Colors.black.withOpacity(0.03),
                blurRadius: widget.pulse ? 12 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: widget.color, size: 16),
              ),
              const SizedBox(height: 8),

              // Value
              widget.isLoading
                  ? SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: widget.color,
                      ),
                    )
                  : Text(
                      '${widget.value}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                        height: 1,
                      ),
                    ),
              const SizedBox(height: 4),

              // Label
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // Pulse dot
              if (widget.pulse) ...[
                const SizedBox(height: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.5 + glow * 4),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════
// ACTION CARD
// ═════════════════════════════════════════════════════════════

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// INCIDENT ROW
// ═════════════════════════════════════════════════════════════

class _IncidentRow extends StatelessWidget {
  final Map<String, dynamic> incident;
  final VoidCallback onTap;

  const _IncidentRow({required this.incident, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type =
        (incident['incident_type'] ?? incident['type'] ?? 'Unknown').toString();
    final status = (incident['status'] ?? 'unknown').toString();
    final severity = (incident['severity'] ?? '').toString();
    final incNumber =
        incident['incident_number']?.toString() ?? '#${incident['id']}';
    final municipality = incident['municipality']?.toString();
    final barangay = incident['barangay']?.toString();
    final reportedAt = incident['reported_at']?.toString() ??
        incident['created_at']?.toString();

    final sevColor = AppColors.incidentSeverityColor(severity);
    final statColor = AppColors.incidentStatusColor(status);

    String timeStr = '';
    if (reportedAt != null) {
      try {
        timeStr = timeago.format(DateTime.parse(reportedAt));
      } catch (_) {
        timeStr = reportedAt;
      }
    }

    // Build location string
    final location = [barangay, municipality]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Type icon with severity indicator
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: sevColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon(type), color: sevColor, size: 18),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatType(type),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Number + location
                  Row(
                    children: [
                      Text(
                        incNumber,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('·',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade400)),
                        ),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Status + severity chips
                  Row(
                    children: [
                      _chip(
                        status.replaceAll('_', ' '),
                        statColor,
                      ),
                      if (severity.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        _chip(severity, sevColor),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatType(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'medical_emergency':
      case 'medical':
        return Icons.local_hospital_rounded;
      case 'vehicular_accident':
      case 'accident':
        return Icons.car_crash_rounded;
      case 'flood':
        return Icons.flood_rounded;
      case 'natural_disaster':
      case 'earthquake':
      case 'landslide':
      case 'typhoon':
        return Icons.public_rounded;
      case 'rescue':
        return Icons.health_and_safety_rounded;
      case 'crime':
        return Icons.gavel_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }
}
