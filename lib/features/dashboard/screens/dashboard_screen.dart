import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'dart:async';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/debug_overlay_provider.dart';
import '../../../core/providers/incident_provider.dart';
import '../../../core/providers/theme_provider.dart';
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

  // Secret tap to activate debug overlay (7 taps within 3 seconds)
  int _secretTapCount = 0;
  Timer? _secretTapTimer;

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        final provider = context.read<IncidentProvider>();

        // Clear filters and fetch all incidents, then filter for today + active
        provider.clearFilters();
        await provider.fetchIncidents();
        provider.filterTodayAndActive();
        provider.fetchStatistics();
        provider.startAutoRefresh();
      }
      _fadeController.forward();
    });
  }

  void _handleSecretTap() {
    _secretTapTimer?.cancel();
    _secretTapCount++;
    if (_secretTapCount >= 7) {
      _secretTapCount = 0;
      context.read<DebugOverlayProvider>().activate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '🖥  SYS MONITOR ACTIVATED',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFF00FF88),
            ),
          ),
          backgroundColor: const Color(0xFF0E1729),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _secretTapTimer = Timer(const Duration(seconds: 3), () {
      _secretTapCount = 0;
    });
  }

  @override
  void dispose() {
    _secretTapTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final ip = context.watch<IncidentProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final user = authProvider.user;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF020617) : AppColors.background,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: isDark
              ? BoxDecoration(
                  color: Color.lerp(AppColors.primary, Colors.black, 0.8)!,
                  image: const DecorationImage(
                    image: AssetImage('assets/images/pdrrmosplash.png'),
                    fit: BoxFit.cover,
                    opacity: 0.35,
                  ),
                )
              : BoxDecoration(color: AppColors.background),
          child: isDark
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    child:
                        _buildBodyContent(context, user, ip, bottomPad, isDark),
                  ),
                )
              : _buildBodyContent(context, user, ip, bottomPad, isDark),
        ),
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context, dynamic user,
      IncidentProvider ip, double bottomPad, bool isDark) {
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        await ip.fetchIncidents();
        ip.filterTodayAndActive();
        await ip.fetchStatistics();
      },
      color: isDark ? AppColors.secondary : AppColors.primary,
      backgroundColor: isDark ? AppColors.primaryDark : Colors.white,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Header ─────────────────────────────────
            _buildHeader(user, ip, isDark),

            // ── Content ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 96 + bottomPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Stats row
                    _buildStatsRow(ip, isDark),

                    const SizedBox(height: 28),

                    // Quick actions
                    _buildQuickActions(context, isDark),

                    const SizedBox(height: 20),

                    // Map preview (full width)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: MapPreviewCard(
                        incidents: ip.incidents,
                        onTap: () => context.push('/map'),
                      ),
                    ),

                    // Error banner
                    if (ip.errorMessage != null) ...[
                      const SizedBox(height: 20),
                      _buildErrorBanner(ip),
                    ],

                    const SizedBox(height: 28),

                    // Recent incidents
                    _buildRecentIncidents(context, ip, isDark),

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
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader(dynamic user, IncidentProvider ip, bool isDark) {
    return SliverAppBar(
      expandedHeight: 260,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? Colors.transparent : AppColors.primary,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.6),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                  ),
            image: isDark
                ? null
                : const DecorationImage(
                    image: AssetImage('assets/images/header.jpg'),
                    fit: BoxFit.cover,
                    opacity: 0.18,
                  ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Secret 7-tap zone to activate debug overlay
                  GestureDetector(
                    onTap: _handleSecretTap,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'WELCOME BACK,',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          (user?.name ?? 'STAFF').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StreamBuilder<DateTime>(
                        stream: Stream.periodic(
                            const Duration(seconds: 1), (_) => DateTime.now()),
                        initialData: DateTime.now(),
                        builder: (context, snapshot) {
                          final time = snapshot.data!;
                          final hour = time.hour > 12
                              ? time.hour - 12
                              : (time.hour == 0 ? 12 : time.hour);
                          final minute = time.minute.toString().padLeft(2, '0');
                          final second = time.second.toString().padLeft(2, '0');
                          final period = time.hour >= 12 ? 'PM' : 'AM';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$hour:$minute:$second $period',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.secondary,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                DateFormat('EEEE, MMM d, yyyy')
                                    .format(time)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white70,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (user != null)
                    Text(
                      (user.position != null
                              ? '${user.position}${user.division != null ? " · ${user.division}" : ""}'
                              : user.roleLabel)
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.secondary : Colors.white70,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
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
      title: Text(
        (user?.unit ?? 'PDRRMO DISPATCH').toUpperCase(),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.5,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode : Icons.dark_mode,
            color: Colors.white.withOpacity(0.85),
            size: 22,
          ),
          tooltip: 'Toggle Theme',
          onPressed: () {
            HapticFeedback.lightImpact();
            context.read<ThemeProvider>().toggleTheme();
          },
        ),
        IconButton(
          icon: Icon(
            Icons.refresh_rounded,
            color: Colors.white.withOpacity(0.85),
            size: 22,
          ),
          tooltip: 'Refresh',
          onPressed: () async {
            HapticFeedback.lightImpact();
            await ip.fetchIncidents();
            ip.filterTodayAndActive();
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

  Widget _buildStatsRow(IncidentProvider ip, bool isDark) {
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
              onTap: () => _showFilteredIncidentsModal(
                context,
                title: 'Active Incidents',
                color: const Color(0xFFEF4444),
                icon: Icons.radio_button_checked_rounded,
                incidents: ip.incidents
                    .where((i) => !['resolved', 'closed', 'cancelled']
                        .contains((i['status'] ?? '').toString().toLowerCase()))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: 'Pending',
              value: ip.pendingCount,
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFFF97316),
              isLoading: ip.isLoading,
              pulse: ip.pendingCount > 0,
              onTap: () => _showFilteredIncidentsModal(
                context,
                title: 'Pending Incidents',
                color: const Color(0xFFF97316),
                icon: Icons.hourglass_top_rounded,
                incidents: ip.incidents
                    .where((i) =>
                        (i['status'] ?? '').toString().toLowerCase() ==
                        'reported')
                    .toList(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: 'Dispatched',
              value: ip.dispatchedCount,
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFF3B82F6),
              isLoading: ip.isLoading,
              onTap: () => _showFilteredIncidentsModal(
                context,
                title: 'Dispatched Incidents',
                color: const Color(0xFF3B82F6),
                icon: Icons.local_shipping_rounded,
                incidents: ip.incidents
                    .where((i) => [
                          'acknowledged',
                          'responding',
                          'on_scene',
                          'on-scene'
                        ].contains(
                            (i['status'] ?? '').toString().toLowerCase()))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: 'Resolved',
              value: ip.resolvedCount,
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF22C55E),
              isLoading: ip.isLoading,
              onTap: () => _showFilteredIncidentsModal(
                context,
                title: 'Resolved Incidents',
                color: const Color(0xFF22C55E),
                icon: Icons.check_circle_outline_rounded,
                incidents: ip.incidents
                    .where((i) => ['resolved', 'closed']
                        .contains((i['status'] ?? '').toString().toLowerCase()))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FILTERED INCIDENTS MODAL
  // ═══════════════════════════════════════════════════════════

  void _showFilteredIncidentsModal(
    BuildContext context, {
    required String title,
    required Color color,
    required IconData icon,
    required List<Map<String, dynamic>> incidents,
  }) {
    HapticFeedback.lightImpact();
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF070B14) : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white10 : AppColors.border,
              ),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${incidents.length} incident${incidents.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: isDark
                              ? Colors.white.withOpacity(0.5)
                              : AppColors.textSecondary,
                          size: 22),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? Colors.white.withOpacity(0.1) : AppColors.border,
              ),
              // Incident list
              Expanded(
                child: incidents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_rounded,
                                size: 48,
                                color: isDark
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.2)),
                            const SizedBox(height: 8),
                            Text(
                              'No incidents',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white.withOpacity(0.5)
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: incidents.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : AppColors.border,
                        ),
                        itemBuilder: (_, i) => Container(
                          color: Colors.transparent,
                          child: _IncidentRow(
                            incident: incidents[i],
                            onTap: () {
                              Navigator.of(ctx).pop();
                              final id = incidents[i]['id'];
                              if (id != null) context.push('/incidents/$id');
                            },
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

  // ═══════════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ═══════════════════════════════════════════════════════════

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _boxSectionHeader('QUICK ACTIONS', Icons.flash_on, isDark),
          const SizedBox(height: 10),
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
              const SizedBox(width: 8),
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
          borderRadius: BorderRadius.circular(4),
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
              onTap: () async {
                await ip.fetchIncidents();
                ip.filterTodayAndActive();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
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

  // Helper for section headers
  Widget _boxSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon,
            size: 14,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentIncidents(
      BuildContext context, IncidentProvider ip, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content inside a bordered panel
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withOpacity(0.5)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.15)
                      : AppColors.border),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            child: Column(
              children: [
                // Panel header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : AppColors.primary.withOpacity(0.05),
                    border: Border(
                        bottom: BorderSide(
                            color: isDark
                                ? Colors.white.withOpacity(0.15)
                                : AppColors.border)),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 14,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Recent Incidents',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (ip.incidents.isNotEmpty)
                        GestureDetector(
                          onTap: () => context.push('/incidents'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Body
                if (ip.isLoading && ip.incidents.isEmpty)
                  _buildLoadingShimmer(isDark)
                else if (ip.incidents
                    .where((i) => !['resolved', 'closed', 'cancelled']
                        .contains((i['status'] ?? '').toString().toLowerCase()))
                    .isEmpty)
                  _buildEmptyState(isDark)
                else
                  _buildIncidentList(ip),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          3,
          (i) => Padding(
            padding: EdgeInsets.only(bottom: i < 2 ? 8 : 0),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      width: double.infinity,
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 40,
              color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 10),
          Text(
            'No active incidents',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pull down to refresh',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentList(IncidentProvider ip) {
    // Filter to show only active incidents (exclude resolved, closed, cancelled)
    final activeIncidents = ip.incidents
        .where((incident) {
          final status = (incident['status'] ?? '').toString().toLowerCase();
          return !['resolved', 'closed', 'cancelled'].contains(status);
        })
        .take(5)
        .toList();

    return Column(
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
              color: Colors.white.withOpacity(0.1),
            ),
        ],
      ],
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
  final VoidCallback? onTap;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.pulse = false,
    this.onTap,
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        // AdminLTE Small-Box Style
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? widget.color : widget.color.withOpacity(0.9),
              borderRadius: BorderRadius.circular(4),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: widget.color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
            ),
            child: Stack(
              children: [
                // Watermark Icon
                Positioned(
                  right: -8,
                  bottom: -8,
                  child: Icon(
                    widget.icon,
                    size: 64,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Value
                      widget.isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              '${widget.value}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                      const SizedBox(height: 4),
                      // Label
                      Text(
                        widget.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F172A).withOpacity(0.5)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color:
                    isDark ? Colors.white.withOpacity(0.15) : AppColors.border),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Row(
            children: [
              // Left color accent bar
              Container(
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark ? Colors.white70 : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: isDark ? Colors.white54 : Colors.black26),
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;

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
                borderRadius: BorderRadius.circular(4),
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : AppColors.textPrimary,
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
                            color: isDark
                                ? Colors.white54
                                : AppColors.textSecondary,
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
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white70 : AppColors.textPrimary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('·',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.white54
                                      : AppColors.textHint)),
                        ),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textSecondary,
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
                      // Responder Status Badge (New for Dashboard)
                      if ((status == 'responding' || status == 'on_scene') &&
                          incident['assigned_user'] != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.directions_car_filled,
                              size: 12, color: Colors.blue),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: isDark ? Colors.white24 : Colors.black26),
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
