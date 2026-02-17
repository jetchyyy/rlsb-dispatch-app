import 'package:flutter/material.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
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
              title: 'Severity Distribution',
              icon: Icons.pie_chart_outline,
              child: SizedBox(
                height: 220,
                child: _severityPieChart(incidents),
              ),
            ),
            const SizedBox(height: 12),

            // ── Incident Types ──────────────────────────
            _boxPanel(
              title: 'Incidents by Type',
              icon: Icons.bar_chart,
              child: _typeBarChart(incidents),
            ),
            const SizedBox(height: 12),

            // ── Status Breakdown ────────────────────────
            _boxPanel(
              title: 'Status Breakdown',
              icon: Icons.donut_small_outlined,
              child: _statusList(incidents),
            ),
            const SizedBox(height: 12),

            // ── Top Municipalities ──────────────────────
            _boxPanel(
              title: 'Top Municipalities',
              icon: Icons.location_city,
              child: _municipalityList(incidents),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _periodSelector() {
    return Row(
      children: [
        Text('Period:',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 13)),
        const SizedBox(width: 8),
        ...['24h', '7d', '30d', '90d'].map((period) {
          final isSelected = _selectedPeriod == period;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: InkWell(
              onTap: () {
                setState(() => _selectedPeriod = period);
                _refresh();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color:
                        isSelected ? AppColors.primary : Colors.grey.shade400,
                  ),
                ),
                child: Text(
                  period,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── AdminLTE-style Small Boxes ────────────────────────────

  Widget _summaryBoxes(IncidentProvider ip) {
    return Row(
      children: [
        _smallBox('Active', '${ip.activeCount}', AppColors.severityCritical,
            Icons.notifications_active),
        const SizedBox(width: 8),
        _smallBox('Critical', '${ip.criticalCount}', AppColors.severityHigh,
            Icons.warning_amber),
        const SizedBox(width: 8),
        _smallBox(
            'New', '${ip.newCount}', AppColors.statusReported, Icons.fiber_new),
        const SizedBox(width: 8),
        _smallBox(
            'Total', '${ip.totalCount}', AppColors.primary, Icons.list_alt),
      ],
    );
  }

  Widget _smallBox(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            // Color accent bar on left
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(3)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    Text(label,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(icon, size: 24, color: color.withOpacity(0.3)),
            ),
          ],
        ),
      ),
    );
  }

  // ── AdminLTE Box Panel ────────────────────────────────────

  Widget _boxPanel(
      {required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Panel header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
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
