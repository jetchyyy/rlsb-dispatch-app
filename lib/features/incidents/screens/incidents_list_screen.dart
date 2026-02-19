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

    // _scrollController.addListener(_onScroll); // Removed for manual pagination
  }

  // void _onScroll() { ... } // Removed for manual pagination

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
        title: const Text('All Incidents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ip.fetchIncidents(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Content Header ──────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFECF0F5),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.list_alt,
                    size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text(
                  'Incident Management',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${ip.totalCount} total',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Search & Filters Box ───────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                // Box header
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Search & Filters',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Spacer(),
                      if (ip.statusFilter != null ||
                          ip.severityFilter != null ||
                          ip.typeFilter != null)
                        GestureDetector(
                          onTap: () {
                            ip.clearFilters();
                            ip.fetchIncidents();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                  color: AppColors.error.withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.clear_all,
                                    size: 14, color: AppColors.error),
                                SizedBox(width: 4),
                                Text(
                                  'Clear All',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Search input
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search incidents...',
                      hintStyle:
                          TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search,
                          size: 18, color: Colors.grey.shade500),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                // Filter buttons
                _FiltersRow(onFilterChanged: () => ip.fetchIncidents()),
              ],
            ),
          ),

          // ── Active Filter Summary ──────────────────────
          if (ip.statusFilter != null ||
              ip.severityFilter != null ||
              ip.typeFilter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    '${ip.totalCount} results found',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // ── Incident List ──────────────────────────────
          Expanded(
            child: ip.isLoading && ip.incidents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ip.incidents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off,
                                size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('No incidents match your criteria',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: () => ip.fetchIncidents(),
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  children: [
                                    // Table header
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                              Icons.warning_amber_rounded,
                                              size: 16,
                                              color: Colors.white),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Incidents',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (ip.isLoading)
                                            const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // List items
                                    Expanded(
                                      child: ListView.separated(
                                        controller: _scrollController,
                                        padding: EdgeInsets.zero,
                                        itemCount: ip.incidents.length,
                                        separatorBuilder: (_, __) => Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: Colors.grey.shade200,
                                        ),
                                        itemBuilder: (context, index) {
                                          final incident = ip.incidents[index];
                                          return _IncidentRow(
                                            key: ValueKey(incident['id']),
                                            incident: incident,
                                            onTap: () {
                                              final id = incident['id'];
                                              if (id != null)
                                                context.push('/incidents/$id');
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Modern Pagination Controls
                          if (ip.totalCount > 20)
                            _ModernPagination(
                              currentPage: ip.currentPage,
                              totalPages: ip.lastPage,
                              onPageChanged: (page) {
                                ip.goToPage(page);
                              },
                              isLoading: ip.isLoading,
                            ),
                        ],
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
    'reported',
    'acknowledged',
    'responding',
    'on_scene',
    'resolved',
    'closed',
  ];
  static const _severities = ['critical', 'high', 'medium', 'low'];
  static const _types = [
    'medical_emergency',
    'fire',
    'natural_disaster',
    'accident',
    'crime',
    'flood',
    'earthquake',
    'landslide',
    'typhoon',
    'other',
  ];

  @override
  Widget build(BuildContext context) {
    final ip = context.watch<IncidentProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: _filterButton(
              context: context,
              label: ip.statusFilter != null
                  ? ip.statusFilter!.replaceAll('_', ' ')
                  : 'Status',
              isActive: ip.statusFilter != null,
              icon: Icons.flag_outlined,
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
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _filterButton(
              context: context,
              label: ip.severityFilter ?? 'Severity',
              isActive: ip.severityFilter != null,
              icon: Icons.warning_amber_rounded,
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
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _filterButton(
              context: context,
              label: ip.typeFilter != null
                  ? ip.typeFilter!.replaceAll('_', ' ')
                  : 'Type',
              isActive: ip.typeFilter != null,
              icon: Icons.category_outlined,
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
          ),
        ],
      ),
    );
  }

  Widget _filterButton({
    required BuildContext context,
    required String label,
    required bool isActive,
    required IconData icon,
    required List<String> options,
    required String? current,
    required ValueChanged<String?> onSelected,
  }) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          builder: (_) => _FilterBottomSheet(
            title: label,
            options: options,
            current: current,
            onSelected: onSelected,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.shade400,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : Colors.grey.shade700,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
          ],
        ),
      ),
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
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
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
                  ? const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 20)
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

// ─── Incident Row (AdminLTE flat style) ──────────────────────

class _IncidentRow extends StatelessWidget {
  final Map<String, dynamic> incident;
  final VoidCallback onTap;

  const _IncidentRow({super.key, required this.incident, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type =
        (incident['incident_type'] ?? incident['type'] ?? 'Unknown') as String;
    final status = (incident['status'] ?? 'unknown') as String;
    final severity = (incident['severity'] ?? '') as String;
    final title = (incident['incident_title'] ??
        incident['title'] ??
        type.replaceAll('_', ' ')) as String;
    final description = (incident['description'] ?? '') as String;
    final incNumber =
        incident['incident_number'] as String? ?? '#${incident['id']}';
    final municipality = incident['municipality'] as String?;
    final reportedAt =
        incident['reported_at'] as String? ?? incident['created_at'] as String?;

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

    return InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Severity accent bar
            Container(
              width: 4,
              color: sevColor,
            ),
            // Content
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: number, type, time
                    Row(
                      children: [
                        Icon(_typeIcon(type), size: 16, color: sevColor),
                        const SizedBox(width: 6),
                        Text(
                          incNumber,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatType(type),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 6),

                    // Bottom row: location, status, severity badges
                    Row(
                      children: [
                        if (municipality != null &&
                            municipality.isNotEmpty) ...[
                          Icon(Icons.location_on_rounded,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              municipality,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: statColor.withOpacity(0.4), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                status.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Responder Status Badge (New)
                        if ((status == 'responding' || status == 'on_scene') &&
                            incident['assigned_user'] != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                  width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_car_filled,
                                    size: 10, color: Colors.blue),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    status == 'on_scene'
                                        ? 'ON SCENE'
                                        : 'EN ROUTE',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (severity.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: sevColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              severity.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: sevColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Chevron
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey.shade400,
              ),
            ),
          ],
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

// ─── Modern Pagination Widget ────────────────────────────────

class _ModernPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final bool isLoading;

  const _ModernPagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          _PaginationButton(
            icon: Icons.chevron_left_rounded,
            label: 'Prev',
            onPressed: currentPage > 1 && !isLoading
                ? () => onPageChanged(currentPage - 1)
                : null,
          ),

          // Page numbers
          Expanded(
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _buildPageNumbers(),
            ),
          ),

          // Next button
          _PaginationButton(
            icon: Icons.chevron_right_rounded,
            label: 'Next',
            isNext: true,
            onPressed: currentPage < totalPages && !isLoading
                ? () => onPageChanged(currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPageNumbers() {
    final List<Widget> children = [];
    final maxVisible = 5;

    int start = currentPage - 2;
    int end = currentPage + 2;

    if (start < 1) {
      start = 1;
      end = start + maxVisible - 1;
    }
    if (end > totalPages) {
      end = totalPages;
      start = end - maxVisible + 1;
      if (start < 1) start = 1;
    }

    // First page
    if (start > 1) {
      children.add(_PageNumber(
        pageNumber: 1,
        isActive: false,
        onPressed: () => onPageChanged(1),
      ));
      if (start > 2) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('...', style: TextStyle(color: Colors.grey.shade400)),
          ),
        );
      }
    }

    // Main page numbers
    for (int i = start; i <= end; i++) {
      if (i > 0 && i <= totalPages) {
        children.add(_PageNumber(
          pageNumber: i,
          isActive: i == currentPage,
          onPressed: () => onPageChanged(i),
        ));
      }
    }

    // Last page
    if (end < totalPages) {
      if (end < totalPages - 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('...', style: TextStyle(color: Colors.grey.shade400)),
          ),
        );
      }
      children.add(_PageNumber(
        pageNumber: totalPages,
        isActive: false,
        onPressed: () => onPageChanged(totalPages),
      ));
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: children,
    );
  }
}

// ─── Pagination Button ───────────────────────────────────────

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isNext;

  const _PaginationButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isNext = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isEnabled ? Colors.grey.shade400 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isNext)
              Icon(icon,
                  size: 16,
                  color: isEnabled ? AppColors.primary : Colors.grey.shade400),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isEnabled ? AppColors.primary : Colors.grey.shade400,
              ),
            ),
            if (isNext)
              Icon(icon,
                  size: 16,
                  color: isEnabled ? AppColors.primary : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ─── Page Number Chip ────────────────────────────────────────

class _PageNumber extends StatelessWidget {
  final int pageNumber;
  final bool isActive;
  final VoidCallback onPressed;

  const _PageNumber({
    required this.pageNumber,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isActive ? null : onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            '$pageNumber',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
