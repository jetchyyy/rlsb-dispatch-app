import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../providers/debug_overlay_provider.dart';
import '../providers/location_tracking_provider.dart';

// ── Dark terminal palette ───────────────────────────────────────
const _kBg = Color(0xFF080D18);
const _kSurface = Color(0xFF0E1729);
const _kBorder = Color(0xFF253D6E);
const _kGreen = Color(0xFF00FF88);
const _kGreenDim = Color(0xFF00C96A);
const _kAmber = Color(0xFFFFB300);
const _kCyan = Color(0xFF00D4FF);
const _kRed = Color(0xFFFF4444);
const _kLabel = Color(0xFF7EB3E8);
const _kValue = Color(0xFFE8F0FF);

const double _kWidth = 260;

/// System-wide floating debug rectangle.
/// Renders live location tracking data inline — no navigation required.
/// Activated via a 7-tap secret gesture on the dashboard "WELCOME BACK," label.
class DebugFloatingButton extends StatelessWidget {
  const DebugFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    final overlay = context.watch<DebugOverlayProvider>();
    if (!overlay.isEnabled) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;

    return Positioned(
      left: overlay.position.dx.clamp(0.0, size.width - _kWidth),
      top: overlay.position.dy.clamp(topPad + 8, size.height - 260),
      child: GestureDetector(
        onPanUpdate: (details) => overlay.updatePosition(details.delta),
        child: overlay.isMinimized
            ? _MinimizedChip(overlay: overlay)
            : _TrackerRect(overlay: overlay),
      ),
    );
  }
}

// ── Minimized pill ──────────────────────────────────────────────

class _MinimizedChip extends StatelessWidget {
  final DebugOverlayProvider overlay;
  const _MinimizedChip({required this.overlay});

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<LocationTrackingProvider>();
    final modeColor = _modeColor(tracker.mode);

    return GestureDetector(
      onTap: () => overlay.expand(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: modeColor.withOpacity(0.7), width: 1.5),
          boxShadow: [
            BoxShadow(color: modeColor.withOpacity(0.22), blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_modeIcon(tracker.mode), color: modeColor, size: 13),
            const SizedBox(width: 5),
            Text(
              tracker.mode.name.toUpperCase(),
              style: TextStyle(
                color: modeColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 6),
            // Internet status dot
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: tracker.hasNetworkConnection ? _kGreen : _kRed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (tracker.hasNetworkConnection ? _kGreen : _kRed)
                        .withOpacity(0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expanded rectangle with live data ──────────────────────────

class _TrackerRect extends StatelessWidget {
  final DebugOverlayProvider overlay;
  const _TrackerRect({required this.overlay});

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<LocationTrackingProvider>();
    final pos = tracker.lastPosition;
    final modeColor = _modeColor(tracker.mode);

    return Container(
      width: _kWidth,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(color: modeColor.withOpacity(0.10), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title bar ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.65),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal, color: modeColor, size: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'SYS MONITOR  ⠿ drag',
                    style: TextStyle(
                      color: modeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => overlay.minimize(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.remove,
                        color: _kAmber.withOpacity(0.85), size: 15),
                  ),
                ),
                GestureDetector(
                  onTap: () => overlay.deactivate(),
                  child: Icon(Icons.close,
                      color: _kRed.withOpacity(0.85), size: 15),
                ),
              ],
            ),
          ),

          // ── Tracking status section ────────────────────────────
          _SectionHeader(label: 'TRACKING', color: modeColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              children: [
                _Row('MODE', tracker.mode.name.toUpperCase(),
                    valueColor: modeColor),
                _Row('TRACKING',
                    tracker.isTracking ? 'ACTIVE' : 'STOPPED',
                    valueColor:
                        tracker.isTracking ? _kGreenDim : _kRed),
                if (tracker.activeIncidentId != null)
                  _Row('INCIDENT', '#${tracker.activeIncidentId}',
                      valueColor: _kAmber),
                _Row('PENDING',
                    '${tracker.pendingUpdates} upload(s)',
                    valueColor:
                        tracker.pendingUpdates > 0 ? _kAmber : _kGreenDim),
                if (tracker.errorMessage != null)
                  _Row('ERROR', tracker.errorMessage!,
                      valueColor: _kRed),
              ],
            ),
          ),

          // ── Network section ────────────────────────────────────
          _SectionHeader(
              label: 'NETWORK',
              color: tracker.hasNetworkConnection ? _kGreen : _kRed),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              children: [
                _Row(
                  'INTERNET',
                  tracker.hasNetworkConnection ? 'ONLINE' : 'OFFLINE',
                  valueColor:
                      tracker.hasNetworkConnection ? _kGreenDim : _kRed,
                ),
                _Row(
                  'UPLOADS',
                  tracker.hasNetworkConnection
                      ? 'ENABLED'
                      : 'QUEUED (${tracker.pendingUpdates})',
                  valueColor:
                      tracker.hasNetworkConnection ? _kGreenDim : _kAmber,
                ),
              ],
            ),
          ),

          // ── GPS position section ───────────────────────────────
          _SectionHeader(
              label: 'GPS POSITION',
              color: pos != null ? _kCyan : _kRed),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: pos != null
                ? Column(
                    children: [
                      _Row('LAT',
                          pos.latitude.toStringAsFixed(6)),
                      _Row('LNG',
                          pos.longitude.toStringAsFixed(6)),
                      _Row('ACC',
                          '${pos.accuracy.toStringAsFixed(1)} m'),
                      _Row('SPD',
                          '${pos.speed.toStringAsFixed(2)} m/s'),
                      _Row('HDG',
                          '${pos.heading.toStringAsFixed(1)}°'),
                      _Row('AGO', _age(pos.timestamp),
                          valueColor: _kCyan),
                    ],
                  )
                : const _Row('STATUS', 'NO FIX', valueColor: _kRed),
          ),
        ],
      ),
    );
  }

  String _age(DateTime ts) {
    final d = DateTime.now().difference(ts);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}';
  }
}

// ── Shared helpers ──────────────────────────────────────────────

Color _modeColor(TrackingMode mode) {
  switch (mode) {
    case TrackingMode.off:
      return _kRed;
    case TrackingMode.passive:
      return _kCyan;
    case TrackingMode.active:
      return _kGreen;
  }
}

IconData _modeIcon(TrackingMode mode) {
  switch (mode) {
    case TrackingMode.off:
      return Icons.location_off;
    case TrackingMode.passive:
      return Icons.location_searching;
    case TrackingMode.active:
      return Icons.my_location;
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color.withOpacity(0.07),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Text(
        '// $label',
        style: TextStyle(
          color: color.withOpacity(0.7),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Row(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '> ',
            style: TextStyle(
              color: _kGreen.withOpacity(0.4),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                color: _kLabel,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const Text('  ',
              style: TextStyle(color: _kLabel, fontSize: 10)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? _kValue,
                fontSize: 10,
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
