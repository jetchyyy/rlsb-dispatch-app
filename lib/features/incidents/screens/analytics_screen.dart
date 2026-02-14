import 'package:flutter/material.dart';
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
      appBar: AppBar(
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
            const SizedBox(height: 20),

            // ── Summary Cards ───────────────────────────
            _summaryCards(ip),
            const SizedBox(height: 24),

            // ── Severity Distribution ────────────────────
            _sectionTitle('Severity Distribution'),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: _severityPieChart(incidents),
            ),
            const SizedBox(height: 24),

            // ── Incident Types ──────────────────────────
            _sectionTitle('Incidents by Type'),
            const SizedBox(height: 12),
            _typeBarChart(incidents),
            const SizedBox(height: 24),

            // ── Status Breakdown ────────────────────────
            _sectionTitle('Status Breakdown'),
            const SizedBox(height: 12),
            _statusList(incidents),
            const SizedBox(height: 24),

            // ── Top Municipalities ──────────────────────
            _sectionTitle('Top Municipalities'),
            const SizedBox(height: 12),
            _municipalityList(incidents),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _periodSelector() {
    return Row(
      children: [
        const Text('Period:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        ...['24h', '7d', '30d', '90d'].map((period) {
          final isSelected = _selectedPeriod == period;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(period, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                setState(() => _selectedPeriod = period);
                _refresh();
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _summaryCards(IncidentProvider ip) {
    return Row(
      children: [
        _miniCard('Active', '${ip.activeCount}', AppColors.severityCritical),
        const SizedBox(width: 8),
        _miniCard('Critical', '${ip.criticalCount}', AppColors.severityHigh),
        const SizedBox(width: 8),
        _miniCard('New', '${ip.newCount}', AppColors.statusReported),
        const SizedBox(width: 8),
        _miniCard('Total', '${ip.totalCount}', AppColors.primary),
      ],
    );
  }

  Widget _miniCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  // ─── Severity Pie Chart ───────────────────────────────────

  Widget _severityPieChart(List<Map<String, dynamic>> incidents) {
    final counts = <String, int>{};
    for (final inc in incidents) {
      final s = (inc['severity'] ?? 'unknown').toString().toLowerCase();
      counts[s] = (counts[s] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: AppColors.textHint)));
    }

    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
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
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.incidentSeverityColor(e.key),
                        borderRadius: BorderRadius.circular(3),
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

    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
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
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 6),
                        child: Text('$count',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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

    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<int>(0, (sum, e) => sum + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: sorted.map((e) {
            final pct = total > 0 ? (e.value / total * 100).round() : 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.incidentStatusColor(e.key),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.key.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text('${e.value}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
        ),
      ),
    );
  }

  // ─── Municipality List ────────────────────────────────────

  Widget _municipalityList(List<Map<String, dynamic>> incidents) {
    final counts = <String, int>{};
    for (final inc in incidents) {
      final m = (inc['municipality'] ?? 'Unknown').toString();
      counts[m] = (counts[m] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(10).toList();

    if (top.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No data', style: TextStyle(color: AppColors.textHint)),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: top.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final e = top[i];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text('${i + 1}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ),
            title: Text(e.key, style: const TextStyle(fontSize: 13)),
            trailing: Text('${e.value}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        },
      ),
    );
  }
}
