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
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
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
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      ip.clearFilters();
                      ip.fetchIncidents();
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear filters',
                        style: TextStyle(fontSize: 12)),
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
                              child: ListView.builder(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.only(bottom: 16, top: 8),
                                itemCount: ip.incidents.length,
                                itemBuilder: (context, index) {
                                  final incident = ip.incidents[index];
                                  return _AnimatedIncidentCard(
                                    key: ValueKey(incident['id']),
                                    index: index,
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

// ─── Animated Incident Card Wrapper ──────────────────────────

class _AnimatedIncidentCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> incident;
  final VoidCallback onTap;

  const _AnimatedIncidentCard({
    super.key,
    required this.index,
    required this.incident,
    required this.onTap,
  });

  @override
  State<_AnimatedIncidentCard> createState() => _AnimatedIncidentCardState();
}

class _AnimatedIncidentCardState extends State<_AnimatedIncidentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + (widget.index * 50).clamp(0, 300)),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Start animation
    Future.delayed(Duration(milliseconds: widget.index * 30), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _IncidentListCard(
          incident: widget.incident,
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

// ─── Incident List Card ──────────────────────────────────────

class _IncidentListCard extends StatefulWidget {
  final Map<String, dynamic> incident;
  final VoidCallback onTap;

  const _IncidentListCard({required this.incident, required this.onTap});

  @override
  State<_IncidentListCard> createState() => _IncidentListCardState();
}

class _IncidentListCardState extends State<_IncidentListCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final type = (widget.incident['incident_type'] ??
        widget.incident['type'] ??
        'Unknown') as String;
    final status = (widget.incident['status'] ?? 'unknown') as String;
    final severity = (widget.incident['severity'] ?? '') as String;
    final title = (widget.incident['incident_title'] ??
        widget.incident['title'] ??
        type.replaceAll('_', ' ')) as String;
    final description = (widget.incident['description'] ?? '') as String;
    final incNumber = widget.incident['incident_number'] as String? ??
        '#${widget.incident['id']}';
    final municipality = widget.incident['municipality'] as String?;
    final reportedAt = widget.incident['reported_at'] as String? ??
        widget.incident['created_at'] as String?;

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

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: (details) {
          _handleTapUp(details);
          widget.onTap();
        },
        onTapCancel: _handleTapCancel,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? Colors.black.withOpacity(0.08)
                    : Colors.black.withOpacity(0.04),
                blurRadius: _isPressed ? 8 : 12,
                offset: Offset(0, _isPressed ? 2 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Severity accent bar with gradient
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          sevColor,
                          sevColor.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Icon, number, and time
                          Row(
                            children: [
                              // Type icon with animated background
                              Hero(
                                tag: 'incident_${widget.incident['id']}_icon',
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        sevColor.withOpacity(0.15),
                                        sevColor.withOpacity(0.08),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _typeIcon(type),
                                    size: 20,
                                    color: sevColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      incNumber,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                        color: Colors.grey.shade700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatType(type),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (timeStr.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Title with better typography
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Bottom row: Location and status badges
                          Row(
                            children: [
                              if (municipality != null &&
                                  municipality.isNotEmpty) ...[
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    municipality,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      statColor.withOpacity(0.15),
                                      statColor.withOpacity(0.08),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: statColor.withOpacity(0.3),
                                    width: 1,
                                  ),
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
                                    const SizedBox(width: 6),
                                    Text(
                                      status.replaceAll('_', ' ').toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: statColor,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (severity.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sevColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    severity.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: sevColor,
                                      letterSpacing: 0.5,
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
                  // Chevron indicator
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          _PaginationButton(
            icon: Icons.chevron_left_rounded,
            label: 'Previous',
            onPressed: currentPage > 1 && !isLoading
                ? () => onPageChanged(currentPage - 1)
                : null,
          ),

          // Page numbers
          Expanded(
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
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

    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: isEnabled ? AppColors.primary : Colors.grey.shade400,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(80, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: isNext ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isNext) ...[
            const SizedBox(width: 4),
            Icon(icon, size: 18),
          ],
        ],
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            '$pageNumber',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
