import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/incident_provider.dart';

class IncidentsListScreen extends StatefulWidget {
  const IncidentsListScreen({super.key});

  @override
  State<IncidentsListScreen> createState() => _IncidentsListScreenState();
}

class _IncidentsListScreenState extends State<IncidentsListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().fetchIncidents();
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<IncidentProvider>().loadMore();
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final ip = context.read<IncidentProvider>();
      ip.setFilters(
        status: ip.statusFilter,
        severity: ip.severityFilter,
        type: ip.typeFilter,
        municipality: ip.municipalityFilter,
        search: query.isEmpty ? null : query,
      );
      ip.fetchIncidents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ip = context.watch<IncidentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Incidents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ip.fetchIncidents(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/incidents/create'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ── Search Bar ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search incidents...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
            ),
          ),

          // ── Filters ────────────────────────────────────
          _FiltersRow(
            onFilterChanged: () => ip.fetchIncidents(),
          ),

          // ── Active Filter Summary ──────────────────────
          if (ip.statusFilter != null ||
              ip.severityFilter != null ||
              ip.typeFilter != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${ip.totalCount} results',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      ip.clearFilters();
                      ip.fetchIncidents();
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear filters', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          // ── Incident List ──────────────────────────────
          Expanded(
            child: ip.isLoading && ip.incidents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ip.incidents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('No incidents match your criteria',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ip.fetchIncidents(),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: ip.incidents.length + (ip.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == ip.incidents.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            }

                            final incident = ip.incidents[index];
                            return _IncidentListCard(
                              incident: incident,
                              onTap: () {
                                final id = incident['id'];
                                if (id != null) context.push('/incidents/$id');
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Chips Row ────────────────────────────────────────

class _FiltersRow extends StatelessWidget {
  final VoidCallback onFilterChanged;

  const _FiltersRow({required this.onFilterChanged});

  static const _statuses = [
    'reported', 'acknowledged', 'responding', 'on_scene', 'resolved', 'closed',
  ];
  static const _severities = ['critical', 'high', 'medium', 'low'];
  static const _types = [
    'medical_emergency', 'fire', 'natural_disaster', 'accident',
    'crime', 'flood', 'earthquake', 'landslide', 'typhoon', 'other',
  ];

  @override
  Widget build(BuildContext context) {
    final ip = context.watch<IncidentProvider>();

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _filterChip(
            context: context,
            label: ip.statusFilter != null
                ? ip.statusFilter!.replaceAll('_', ' ')
                : 'Status',
            isActive: ip.statusFilter != null,
            options: _statuses,
            current: ip.statusFilter,
            onSelected: (value) {
              ip.setFilters(
                status: value,
                severity: ip.severityFilter,
                type: ip.typeFilter,
                municipality: ip.municipalityFilter,
                search: ip.searchQuery,
              );
              onFilterChanged();
            },
          ),
          const SizedBox(width: 8),
          _filterChip(
            context: context,
            label: ip.severityFilter ?? 'Severity',
            isActive: ip.severityFilter != null,
            options: _severities,
            current: ip.severityFilter,
            onSelected: (value) {
              ip.setFilters(
                status: ip.statusFilter,
                severity: value,
                type: ip.typeFilter,
                municipality: ip.municipalityFilter,
                search: ip.searchQuery,
              );
              onFilterChanged();
            },
          ),
          const SizedBox(width: 8),
          _filterChip(
            context: context,
            label: ip.typeFilter != null
                ? ip.typeFilter!.replaceAll('_', ' ')
                : 'Type',
            isActive: ip.typeFilter != null,
            options: _types,
            current: ip.typeFilter,
            onSelected: (value) {
              ip.setFilters(
                status: ip.statusFilter,
                severity: ip.severityFilter,
                type: value,
                municipality: ip.municipalityFilter,
                search: ip.searchQuery,
              );
              onFilterChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required BuildContext context,
    required String label,
    required bool isActive,
    required List<String> options,
    required String? current,
    required ValueChanged<String?> onSelected,
  }) {
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            size: 16,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ],
      ),
      backgroundColor: isActive ? AppColors.primary : Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => _FilterBottomSheet(
            title: label,
            options: options,
            current: current,
            onSelected: onSelected,
          ),
        );
      },
    );
  }
}

// ─── Filter Bottom Sheet ─────────────────────────────────────

class _FilterBottomSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? current;
  final ValueChanged<String?> onSelected;

  const _FilterBottomSheet({
    required this.title,
    required this.options,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.toUpperCase(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              if (current != null)
                TextButton(
                  onPressed: () {
                    onSelected(null);
                    Navigator.pop(context);
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
          const Divider(),
          ...options.map((option) {
            final isSelected = current == option;
            return ListTile(
              dense: true,
              title: Text(
                option.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : null,
                ),
              ),
              leading: isSelected
                  ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                  : const Icon(Icons.radio_button_unchecked, size: 20),
              onTap: () {
                onSelected(option);
                Navigator.pop(context);
              },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Incident List Card ──────────────────────────────────────

class _IncidentListCard extends StatelessWidget {
  final Map<String, dynamic> incident;
  final VoidCallback onTap;

  const _IncidentListCard({required this.incident, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = (incident['incident_type'] ?? incident['type'] ?? 'Unknown') as String;
    final status = (incident['status'] ?? 'unknown') as String;
    final severity = (incident['severity'] ?? '') as String;
    final title = (incident['incident_title'] ?? incident['title'] ?? type.replaceAll('_', ' ')) as String;
    final description = (incident['description'] ?? '') as String;
    final incNumber = incident['incident_number'] as String? ?? '#${incident['id']}';
    final municipality = incident['municipality'] as String?;
    final reportedAt = incident['reported_at'] as String? ?? incident['created_at'] as String?;

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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top: number + type icon + time
                      Row(
                        children: [
                          Icon(_typeIcon(type), size: 16, color: sevColor),
                          const SizedBox(width: 6),
                          Text(
                            incNumber,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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
                              child: Text(timeStr,
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Middle: Title + description
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Bottom: Location + Status chip
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (municipality != null && municipality.isNotEmpty) ...[
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: AppColors.textHint),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                municipality,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textHint),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statColor,
                              ),
                            ),
                          ),
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
      case 'crime':
        return Icons.gavel;
      default:
        return Icons.warning_amber;
    }
  }
}
