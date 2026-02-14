import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/incident_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        final provider = context.read<IncidentProvider>();
        provider.fetchIncidents();
        provider.fetchStatistics();
        provider.startAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    // Auto-refresh is stopped by provider.dispose or stopAutoRefresh
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final ip = context.watch<IncidentProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDRRMO Dispatch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ip.fetchIncidents();
              ip.fetchStatistics();
            },
          ),
          IconButton(
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, size: 20, color: Colors.white),
            ),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/incidents/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Incident'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ip.fetchIncidents(),
            ip.fetchStatistics(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // ── Welcome Header ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${user?.name ?? 'Staff'}!',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.position != null
                        ? '${user!.position} • ${user.division ?? ""}'
                        : user?.roleLabel ?? 'Staff',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // ── Stat Cards (2x2 Grid) ────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.7,
                children: [
                  _StatCard(
                    title: 'Active',
                    value: ip.activeCount.toString(),
                    icon: Icons.radio_button_checked,
                    color: AppColors.severityCritical,
                    isLoading: ip.isLoading,
                  ),
                  _StatCard(
                    title: 'New',
                    value: ip.newCount.toString(),
                    icon: Icons.fiber_new,
                    color: const Color(0xFFEA580C),
                    isLoading: ip.isLoading,
                    pulse: ip.newCount > 0,
                  ),
                  _StatCard(
                    title: 'Critical',
                    value: ip.criticalCount.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFB91C1C),
                    isLoading: ip.isLoading,
                  ),
                  _StatCard(
                    title: "Today's Total",
                    value: ip.todayTotal.toString(),
                    icon: Icons.info_outline,
                    color: AppColors.info,
                    isLoading: ip.isLoading,
                  ),
                ],
              ),
            ),

            // ── Quick Actions ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _QuickAction(
                    icon: Icons.list_alt,
                    label: 'All Incidents',
                    color: AppColors.primary,
                    onTap: () => context.push('/incidents'),
                  ),
                  _QuickAction(
                    icon: Icons.map_outlined,
                    label: 'Live Map',
                    color: const Color(0xFF06B6D4),
                    onTap: () => context.push('/map'),
                  ),
                  _QuickAction(
                    icon: Icons.analytics_outlined,
                    label: 'Analytics',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => context.push('/analytics'),
                  ),
                  _QuickAction(
                    icon: Icons.add_circle_outline,
                    label: 'Report',
                    color: AppColors.severityCritical,
                    onTap: () => context.push('/incidents/create'),
                  ),
                ],
              ),
            ),

            // ── Error Banner ─────────────────────────────
            if (ip.errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(ip.errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ),
                    TextButton(
                      onPressed: () => ip.fetchIncidents(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],

            // ── Recent Incidents Timeline ─────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Incidents',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (ip.incidents.isNotEmpty)
                    TextButton(
                      onPressed: () => context.push('/incidents'),
                      child: const Text('View All'),
                    ),
                ],
              ),
            ),

            if (ip.isLoading && ip.incidents.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (ip.incidents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('No incidents found', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      const Text('Pull down to refresh', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                    ],
                  ),
                ),
              )
            else
              ...ip.incidents.take(5).map((incident) {
                return _RecentIncidentCard(
                  incident: incident,
                  onTap: () {
                    final id = incident['id'];
                    if (id != null) context.push('/incidents/$id');
                  },
                );
              }),

            // ── Last updated ─────────────────────────────
            if (ip.lastFetchTime != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Center(
                  child: Text(
                    'Last updated ${timeago.format(ip.lastFetchTime!)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────

class _StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final bool pulse;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.pulse = false,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.pulse) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatCard old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.pulse && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder2(
      animation: _pulseController,
      builder: (_, __) {
        final opacity = widget.pulse ? 0.08 + (_pulseController.value * 0.08) : 0.08;
        return Container(
          decoration: BoxDecoration(
            color: widget.color.withOpacity(opacity),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.color.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(widget.icon, color: widget.color, size: 22),
                  if (widget.pulse)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              widget.isLoading
                  ? SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.color,
                      ),
                    )
                  : Text(
                      widget.value,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
                    ),
              const SizedBox(height: 2),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.color.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Quick Action Button ─────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 82,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Recent Incident Card ────────────────────────────────────

class _RecentIncidentCard extends StatelessWidget {
  final Map<String, dynamic> incident;
  final VoidCallback onTap;

  const _RecentIncidentCard({required this.incident, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = (incident['incident_type'] ?? incident['type'] ?? 'Unknown') as String;
    final status = (incident['status'] ?? 'unknown') as String;
    final severity = (incident['severity'] ?? '') as String;
    final incNumber = incident['incident_number'] as String? ?? '#${incident['id']}';
    final description = (incident['description'] ?? '') as String;
    final reportedAt = incident['reported_at'] as String? ?? incident['created_at'] as String?;

    final sevColor = AppColors.incidentSeverityColor(severity);

    String timeStr = '';
    if (reportedAt != null) {
      try {
        timeStr = timeago.format(DateTime.parse(reportedAt));
      } catch (_) {
        timeStr = reportedAt;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Severity color bar
              Container(width: 5, color: sevColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_typeIcon(type), size: 16, color: sevColor),
                          const SizedBox(width: 6),
                          Text(
                            incNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const Spacer(),
                          if (timeStr.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                timeStr,
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _statusChip(status),
                          const SizedBox(width: 6),
                          _severityBadge(severity, sevColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.chevron_right, size: 20, color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = AppColors.incidentStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _severityBadge(String severity, Color color) {
    if (severity.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
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
}

/// Animated widget helper — wraps AnimatedWidget to rebuild on animation ticks.
class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder2({super.key, required Animation<double> animation, required this.builder})
      : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}