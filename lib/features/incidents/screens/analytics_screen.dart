import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/incident_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = '7d';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final ip = context.read<IncidentProvider>();
    ip.fetchStatistics(period: _selectedPeriod);
    ip.fetchIncidents(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final ip = context.watch<IncidentProvider>();
    final incidents = ip.incidents;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        body: Column(
          children: [
            // ── Gradient Header ──────────────────────────
            _buildHeader(context),

            // ── Content ──────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Period Selector ─────────────────────────
                    _periodSelector(),
                    const SizedBox(height: 16),

                    // ── Summary Small Boxes ────────────────────
                    _summaryBoxes(ip),
                    const SizedBox(height: 16),

                    // ── Severity Distribution ────────────────────
                    _boxPanel(
                      title: 'SEVERITY DISTRIBUTION',
                      icon: Icons.pie_chart_outline,
                      child: SizedBox(
                        height: 220,
                        child: _severityPieChart(incidents),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Incident Types ──────────────────────────
                    _boxPanel(
                      title: 'INCIDENTS BY TYPE',
                      icon: Icons.bar_chart,
                      child: _typeBarChart(incidents),
                    ),
                    const SizedBox(height: 12),

                    // ── Status Breakdown ────────────────────────
                    _boxPanel(
                      title: 'STATUS BREAKDOWN',
                      icon: Icons.donut_small_outlined,
                      child: _statusList(incidents),
                    ),
                    const SizedBox(height: 12),

                    // ── Top Municipalities ──────────────────────
                    _boxPanel(
                      title: 'TOP MUNICIPALITIES',
                      icon: Icons.location_city,
                      child: _municipalityList(incidents),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        image: const DecorationImage(
          image: AssetImage('assets/images/header.jpg'),
          fit: BoxFit.cover,
          opacity: 0.18,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row with back button and refresh
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go('/dashboard');
                      }
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _refresh();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Title section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INCIDENT ANALYTICS',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'REPORTS & STATS',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Icon(
                          Icons.analytics_rounded,
                          size: 32,
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'DATA INSIGHTS',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
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

  Widget _periodSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.primaryDark.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('PERIOD:',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontSize: 12,
                  letterSpacing: 1.0)),
          const SizedBox(width: 12),
          ...['24h', '7d', '30d', '90d'].map((period) {
            final isSelected = _selectedPeriod == period;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedPeriod = period);
                  _refresh();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: [
                            AppColors.primary,
                            AppColors.primaryDark,
                          ])
                        : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryDark
                          : Colors.grey.shade400,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    period.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ══ AdminLTE-style Small Boxes ═══════════════════════════

  Widget _summaryBoxes(IncidentProvider ip) {
    final avgResponse = ip.statistics?['average_response_time'] ?? 'N/A';

    return Column(
      children: [
        Row(
          children: [
            _smallBox('ACTIVE', '${ip.activeCount}',
                const Color(0xFFEF4444), Icons.notifications_active),
            const SizedBox(width: 8),
            _smallBox('PENDING', '${ip.pendingCount}',
                const Color(0xFFF97316), Icons.hourglass_top),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _smallBox('DISPATCHED', '${ip.dispatchedCount}',
                const Color(0xFF3B82F6), Icons.local_shipping),
            const SizedBox(width: 8),
            _smallBox('RESOLVED', '${ip.resolvedCount}',
                const Color(0xFF22C55E), Icons.check_circle_outline),
          ],
        ),
        const SizedBox(height: 8),
        // Average Response Time Box (Full Width)
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Watermark Icon
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(
                  Icons.timer,
                  size: 80,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(avgResponse,
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1)),
                          const SizedBox(height: 4),
                          Text('AVG RESPONSE TIME',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _smallBox(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Watermark Icon
            Positioned(
              right: -8,
              bottom: -8,
              child: Icon(
                icon,
                size: 56,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1)),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══ AdminLTE Box Panel ═══════════════════════════════════

  Widget _boxPanel(
      {required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Panel header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.08),
                  AppColors.primaryDark.withOpacity(0.08),
                ],
              ),
              border: Border(
                  bottom: BorderSide(color: AppColors.primary.withOpacity(0.2))),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          // Panel body
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }

  // ─── Severity Pie Chart ───────────────────────────────────

  Widget _severityPieChart(List<Map<String, dynamic>> incidents) {
    final counts = <String, int>{};
    for (final inc in incidents) {
      final s = (inc['severity'] ?? 'unknown').toString().toLowerCase();
      counts[s] = (counts[s] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      return const Center(
          child: Text('No data', style: TextStyle(color: AppColors.textHint)));
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: entries.map((e) {
                final pct = (e.value / total * 100).round();
                return PieChartSectionData(
                  color: AppColors.incidentSeverityColor(e.key),
                  value: e.value.toDouble(),
                  title: '$pct%',
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                  radius: 50,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.incidentSeverityColor(e.key),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${e.key[0].toUpperCase()}${e.key.substring(1)} (${e.value})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── Type Bar Chart ───────────────────────────────────────

  Widget _typeBarChart(List<Map<String, dynamic>> incidents) {
    final counts = <String, int>{};
    for (final inc in incidents) {
      final t = (inc['incident_type'] ?? inc['type'] ?? 'other').toString();
      final label = t.replaceAll('_', ' ');
      counts[label] = (counts[label] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No data', style: TextStyle(color: AppColors.textHint)),
      );
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();

    return Column(
      children: top.asMap().entries.map((entry) {
        final label = entry.value.key;
        final count = entry.value.value;
        final maxVal = top.first.value;
        final ratio = maxVal > 0 ? count / maxVal : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label.length > 14 ? '${label.substring(0, 12)}…' : label,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 6),
                        child: Text('$count',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Status List ──────────────────────────────────────────

  Widget _statusList(List<Map<String, dynamic>> incidents) {
    final counts = <String, int>{};
    for (final inc in incidents) {
      final s = (inc['status'] ?? 'unknown').toString().toLowerCase();
      counts[s] = (counts[s] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<int>(0, (sum, e) => sum + e.value);

    return Column(
      children: sorted.map((e) {
        final pct = total > 0 ? (e.value / total * 100).round() : 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.incidentStatusColor(e.key),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.key.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              Text('${e.value}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 4),
              SizedBox(
                width: 36,
                child: Text('$pct%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Municipality List ────────────────────────────────────

  Widget _municipalityList(List<Map<String, dynamic>> incidents) {
    final counts = <String, int>{};
    for (final inc in incidents) {
      final m = (inc['municipality'] ?? 'Unknown').toString();
      counts[m] = (counts[m] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(10).toList();

    if (top.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No data', style: TextStyle(color: AppColors.textHint)),
      );
    }

    return Column(
      children: List.generate(top.length, (i) {
        final e = top[i];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.key, style: const TextStyle(fontSize: 13)),
                  ),
                  Text('${e.value}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (i < top.length - 1)
              Divider(height: 1, color: Colors.grey.shade200),
          ],
        );
      }),
    );
  }
}
