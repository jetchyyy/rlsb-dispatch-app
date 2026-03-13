import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/incident_provider.dart';
import '../../../core/widgets/sync_status_banner.dart';

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
    // Immediately update the UI (shows/hides the suffix clear icon)
    setState(() {});

    // Update the provider search filter right away so _FiltersRow sees the
    // current search value if the user applies another filter before the
    // debounce fires (race-condition fix).
    final ip = context.read<IncidentProvider>();
    ip.setFilters(
      status: ip.statusFilter,
      severity: ip.severityFilter,
      type: ip.typeFilter,
      municipality: ip.municipalityFilter,
      search: query.isEmpty ? null : query,
    );

    // Debounce only the API call so the keyboard stays open
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      context.read<IncidentProvider>().fetchIncidents();
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        body: Column(
          children: [
            // ── Gradient Header ────────────────────────────
            _buildHeader(context, ip),

            // ── Stats Row ──────────────────────────────────
            const SizedBox(height: 16),
            _buildStatsRow(ip),

            const SizedBox(height: 16),

            // ── Main Content ───────────────────────────────
            Expanded(
              child: _buildContent(context, ip),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context, IncidentProvider ip) {
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
                      ip.fetchIncidents();
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
                      'INCIDENT MANAGEMENT',
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
                          'ALL INCIDENTS',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${ip.totalCount}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'TOTAL RECORDS',
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

  // ═══════════════════════════════════════════════════════════
  // STATS ROW
  // ═══════════════════════════════════════════════════════════

  Widget _buildStatsRow(IncidentProvider ip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatBox(
              label: 'Active',
              value: ip.activeCount,
              icon: Icons.radio_button_checked_rounded,
              color: const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatBox(
              label: 'Pending',
              value: ip.pendingCount,
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFFF97316),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatBox(
              label: 'Dispatched',
              value: ip.dispatchedCount,
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatBox(
              label: 'Resolved',
              value: ip.resolvedCount,
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF22C55E),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CONTENT
  // ═══════════════════════════════════════════════════════════

  Widget _buildContent(BuildContext context, IncidentProvider ip) {
    return Column(
      children: [
        const SyncStatusBanner(),

        // ── Search & Filters Box ───────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
              // Box header
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  border: Border(
                    bottom: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_list,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'SEARCH & FILTERS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    if (ip.statusFilter != null ||
                        ip.severityFilter != null ||
                        ip.typeFilter != null ||
                        _searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          ip.clearFilters();
                          _searchController.clear();
                          setState(() {});
                          if (_scrollController.hasClients) _scrollController.jumpTo(0);
                          ip.fetchIncidents();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.clear,
                                  size: 12, color: Colors.redAccent),
                              const SizedBox(width: 4),
                              const Text(
                                'CLEAR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.redAccent,
                                  letterSpacing: 0.5,
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
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by title, type, location...',
                    hintStyle:
                        TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search,
                        size: 18, color: AppColors.primary),
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
                    fillColor: Colors.grey.shade50,
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
                          color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
              // Filter buttons
              _FiltersRow(onFilterChanged: () {
                if (_scrollController.hasClients) _scrollController.jumpTo(0);
                ip.fetchIncidents();
              }),
              ],
            ),
          ),

        // ── Active Filter Summary ──────────────────────
        if (ip.statusFilter != null ||
            ip.severityFilter != null ||
            ip.typeFilter != null ||
            (ip.searchQuery != null && ip.searchQuery!.isNotEmpty))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${ip.totalCount} RESULTS FOUND',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
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
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            AppColors.primaryDark,
                                          ],
                                        ),
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
                                          const SizedBox(width: 8),
                                          const Text(
                                            'INCIDENTS',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: 1.0,
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
    );
  }
}

// ═════════════════════════════════════════════════════════════
// STAT BOX
// ═════════════════════════════════════════════════════════════

class _StatBox extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Value
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                // Label
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

// ─── Incident Row (Tactical style) ──────────────────────────

class _IncidentRow extends StatelessWidget {
  final Map<String, dynamic> incident;
  final VoidCallback onTap;

  const _IncidentRow({super.key, required this.incident, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type =
        (incident['incident_type'] ?? incident['type'] ?? 'Unknown').toString();
    final status = (incident['status'] ?? 'unknown').toString();
    final severity = (incident['severity'] ?? '').toString();
    final title = (incident['incident_title'] ??
            incident['title'] ??
            type.replaceAll('_', ' '))
        .toString();
    final description = (incident['description'] ?? '').toString();
    final incNumber =
        incident['incident_number']?.toString() ?? '#${incident['id']}';
    final municipality = incident['municipality']?.toString();
    final barangay = incident['barangay']?.toString();
    final reportedAt = incident['reported_at']?.toString() ??
        incident['created_at']?.toString();

    final sevColor = AppColors.incidentSeverityColor(severity);
    final statColor = AppColors.incidentStatusColor(status);

    final location = [barangay, municipality]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

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
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: sevColor, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon box with severity color
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: sevColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: sevColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(_typeIcon(type), color: sevColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: type label + time
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatType(type).toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: sevColor,
                              letterSpacing: 0.8,
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
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Line 2: title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 6),

                    // Line 3: ID + location + badges
                    Row(
                      children: [
                        // Incident number
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(3),
                            border:
                                Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            incNumber,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),

                        if (location.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Icon(Icons.location_on_rounded,
                              size: 11, color: Colors.grey.shade400),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],

                        const Spacer(),

                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: statColor.withOpacity(0.4),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: statColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                status
                                    .replaceAll('_', ' ')
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: statColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (severity.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: sevColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                  color: sevColor.withOpacity(0.4),
                                  width: 1),
                            ),
                            child: Text(
                              severity.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: sevColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey.shade400,
              ),
            ],
          ),
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
