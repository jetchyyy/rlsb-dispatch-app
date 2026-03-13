import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/location_tracking_provider.dart';

// ── Dark terminal palette ────────────────────────────────────
const _kBg = Color(0xFF080D18);           // near-black navy
const _kSurface = Color(0xFF0E1729);      // panel background
const _kBorder = Color(0xFF253D6E);       // navy border (visible)
const _kGreen = Color(0xFF00FF88);        // terminal green
const _kGreenDim = Color(0xFF00C96A);     // dimmer green
const _kAmber = Color(0xFFFFB300);        // amber accent
const _kCyan = Color(0xFF00D4FF);         // info cyan
const _kRed = Color(0xFFFF4444);          // error red
const _kLabel = Color(0xFF7EB3E8);        // bright blue-grey label
const _kValue = Color(0xFFE8F0FF);        // bright cool white value

/// Hidden admin screen to monitor device location tracking.
/// Accessible by tapping "Roles" 10 times on the profile screen.
class DispatcherTrackerScreen extends StatefulWidget {
  const DispatcherTrackerScreen({super.key});

  @override
  State<DispatcherTrackerScreen> createState() =>
      _DispatcherTrackerScreenState();
}

class _DispatcherTrackerScreenState extends State<DispatcherTrackerScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<LocationTrackingProvider>();
    final position = tracker.lastPosition;
    final mode = tracker.mode;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 72,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            image: DecorationImage(
              image: AssetImage('assets/images/header.jpg'),
              fit: BoxFit.cover,
              opacity: 0.18,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ADMIN CONSOLE',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.6),
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'LOCATION TRACKING MONITOR',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── System boot banner ───────────────────────────────
            _TerminalBanner(
              icon: Icons.admin_panel_settings,
              message: 'PRIVILEGED ACCESS — FOR AUTHORIZED PERSONNEL ONLY',
              color: _kAmber,
            ),
            const SizedBox(height: 14),

            // ── Tracking Status ──────────────────────────────────
            _TerminalCard(
              title: 'TRACKING STATUS',
              prefixChar: '01',
              accentColor: _getTrackingColor(mode),
              icon: _getTrackingIcon(mode),
              children: [
                _TRow('MODE', mode.name.toUpperCase(),
                    valueColor: _getTrackingColor(mode)),
                _TRow('IS TRACKING', tracker.isTracking ? 'YES' : 'NO',
                    valueColor:
                        tracker.isTracking ? _kGreen : _kRed),
                if (tracker.activeIncidentId != null)
                  _TRow('ACTIVE INCIDENT',
                      '#${tracker.activeIncidentId}',
                      valueColor: _kAmber),
                _TRow('PENDING UPLOADS', '${tracker.pendingUpdates}',
                    valueColor: tracker.pendingUpdates > 0
                        ? _kAmber
                        : _kGreenDim),
                if (tracker.errorMessage != null)
                  _TRow('ERROR', tracker.errorMessage!,
                      valueColor: _kRed),
              ],
            ),
            const SizedBox(height: 12),

            // ── GPS Position ─────────────────────────────────────
            _TerminalCard(
              title: 'LAST KNOWN POSITION',
              prefixChar: '02',
              accentColor:
                  position != null ? _kGreen : _kRed,
              icon: Icons.location_on,
              children: position != null
                  ? [
                      _TRow('LATITUDE',
                          position.latitude.toStringAsFixed(6)),
                      _TRow('LONGITUDE',
                          position.longitude.toStringAsFixed(6)),
                      _TRow('ACCURACY',
                          '${position.accuracy.toStringAsFixed(1)} m'),
                      _TRow('ALTITUDE',
                          '${position.altitude.toStringAsFixed(1)} m'),
                      _TRow('SPEED',
                          '${position.speed.toStringAsFixed(2)} m/s'),
                      _TRow('HEADING',
                          '${position.heading.toStringAsFixed(1)}°'),
                      _TRow('TIMESTAMP',
                          _formatTimestamp(position.timestamp),
                          valueColor: _kCyan),
                    ]
                  : [
                      _TRow('STATUS', 'NO POSITION CAPTURED',
                          valueColor: _kRed),
                    ],
            ),
            const SizedBox(height: 12),

            // ── Configuration ────────────────────────────────────
            const _TerminalCard(
              title: 'TRACKING CONFIG',
              prefixChar: '03',
              accentColor: _kCyan,
              icon: Icons.tune,
              children: [
                _TRow('PASSIVE INTERVAL', '10 SECONDS'),
                _TRow('ACTIVE INTERVAL', '5 SECONDS'),
                _TRow('BATCH FLUSH INTERVAL', '30 SECONDS'),
              ],
            ),
            const SizedBox(height: 20),

            // ── Controls header ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    color: _kGreen,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'MANUAL CONTROLS',
                    style: TextStyle(
                      color: _kGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),

            // ── Control buttons ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _TacticalButton(
                    label: 'START PASSIVE',
                    icon: Icons.play_arrow,
                    color: _kGreen,
                    onPressed: mode == TrackingMode.passive
                        ? null
                        : () => tracker.startPassiveTracking(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TacticalButton(
                    label: 'STOP ALL',
                    icon: Icons.stop,
                    color: _kRed,
                    onPressed: mode == TrackingMode.off
                        ? null
                        : () => tracker.stopAllTracking(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TacticalButton(
                    label: 'FLUSH BATCH',
                    icon: Icons.cloud_upload,
                    color: _kCyan,
                    onPressed: tracker.pendingUpdates == 0
                        ? null
                        : () async {
                            await tracker.flushBatch();
                            setState(() {});
                          },
                  ),
                ),
                if (mode == TrackingMode.active) ...
                  [
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TacticalButton(
                        label: 'REVERT PASSIVE',
                        icon: Icons.arrow_back,
                        color: _kAmber,
                        onPressed: () => tracker.stopActiveTracking(),
                      ),
                    ),
                  ],
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  IconData _getTrackingIcon(TrackingMode mode) {
    switch (mode) {
      case TrackingMode.off:
        return Icons.location_off;
      case TrackingMode.passive:
        return Icons.location_searching;
      case TrackingMode.active:
        return Icons.my_location;
    }
  }

  Color _getTrackingColor(TrackingMode mode) {
    switch (mode) {
      case TrackingMode.off:
        return _kRed;
      case TrackingMode.passive:
        return _kCyan;
      case TrackingMode.active:
        return _kGreen;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s AGO';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m AGO';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:'
          '${timestamp.minute.toString().padLeft(2, '0')}:'
          '${timestamp.second.toString().padLeft(2, '0')}';
    }
  }
}

// ── Terminal Banner ──────────────────────────────────────────

class _TerminalBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _TerminalBanner({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          // Blinking cursor indicator (static — actual blink would need AnimationController)
          Text(
            '█',
            style: TextStyle(color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Terminal Card ────────────────────────────────────────────

class _TerminalCard extends StatelessWidget {
  final String title;
  final String prefixChar;
  final Color accentColor;
  final IconData icon;
  final List<Widget> children;

  const _TerminalCard({
    required this.title,
    required this.prefixChar,
    required this.accentColor,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent stripe
              Container(width: 4, color: accentColor),
              // Card body
              Expanded(
                child: Container(
                  color: _kSurface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header bar
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        color: AppColors.primary.withOpacity(0.55),
                        child: Row(
                          children: [
                            Text(
                              '[$prefixChar] ',
                              style: TextStyle(
                                color: accentColor.withOpacity(0.6),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Icon(icon, color: accentColor, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              title,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Divider line
                      Container(height: 1, color: _kBorder),
                      // Content
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Column(children: children),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Terminal Row ─────────────────────────────────────────────

class _TRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _TRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Prompt prefix
          Text(
            '> ',
            style: TextStyle(
              color: _kGreen.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          // Label
          SizedBox(
            width: 148,
            child: Text(
              label,
              style: const TextStyle(
                color: _kLabel,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const Text(
            ':  ',
            style: TextStyle(
              color: _kLabel,
              fontSize: 11,
            ),
          ),
          // Value
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? _kValue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tactical Button ──────────────────────────────────────────

class _TacticalButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _TacticalButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isEnabled
              ? color.withOpacity(0.12)
              : color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isEnabled ? color.withOpacity(0.7) : color.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isEnabled ? color : color.withOpacity(0.3),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isEnabled ? color : color.withOpacity(0.3),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
