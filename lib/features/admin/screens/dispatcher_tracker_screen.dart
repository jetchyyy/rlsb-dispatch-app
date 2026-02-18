import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/location_tracking_provider.dart';

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
    // Force UI refresh every second to show live updates
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
      appBar: AppBar(
        title: const Text('Dispatcher Tracker'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Admin Mode Banner ────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings,
                      color: AppColors.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Admin Mode — Location Tracking Monitor',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Tracking Status Card ─────────────────────────────
            _StatusCard(
              title: 'Tracking Status',
              icon: _getTrackingIcon(mode),
              iconColor: _getTrackingColor(mode),
              children: [
                _InfoRow('Mode', mode.name.toUpperCase()),
                _InfoRow('Is Tracking', tracker.isTracking ? 'Yes' : 'No'),
                if (tracker.activeIncidentId != null)
                  _InfoRow(
                      'Active Incident', '#${tracker.activeIncidentId}'),
                _InfoRow('Pending Uploads', '${tracker.pendingUpdates}'),
                if (tracker.errorMessage != null)
                  _InfoRow('Error', tracker.errorMessage!,
                      valueColor: AppColors.error),
              ],
            ),
            const SizedBox(height: 16),

            // ── Current Position Card ────────────────────────────
            _StatusCard(
              title: 'Last Known Position',
              icon: Icons.location_on,
              iconColor: position != null ? AppColors.success : AppColors.error,
              children: position != null
                  ? [
                      _InfoRow('Latitude',
                          position.latitude.toStringAsFixed(6)),
                      _InfoRow('Longitude',
                          position.longitude.toStringAsFixed(6)),
                      _InfoRow('Accuracy',
                          '${position.accuracy.toStringAsFixed(1)} m'),
                      _InfoRow(
                          'Altitude', '${position.altitude.toStringAsFixed(1)} m'),
                      _InfoRow(
                          'Speed', '${position.speed.toStringAsFixed(2)} m/s'),
                      _InfoRow('Heading',
                          '${position.heading.toStringAsFixed(1)}°'),
                      _InfoRow(
                          'Timestamp',
                          _formatTimestamp(position.timestamp)),
                    ]
                  : [
                      const _InfoRow('Status', 'No position captured yet'),
                    ],
            ),
            const SizedBox(height: 16),

            // ── Tracking Intervals Card ──────────────────────────
            _StatusCard(
              title: 'Tracking Configuration',
              icon: Icons.timer,
              iconColor: AppColors.info,
              children: const [
                _InfoRow('Passive Interval', '10 seconds'),
                _InfoRow('Active Interval', '5 seconds'),
                _InfoRow('Batch Flush Interval', '30 seconds'),
              ],
            ),
            const SizedBox(height: 24),

            // ── Manual Controls ──────────────────────────────────
            Text(
              'Manual Controls',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ControlButton(
                    label: 'Start Passive',
                    icon: Icons.play_arrow,
                    color: AppColors.success,
                    onPressed: mode == TrackingMode.passive
                        ? null
                        : () => tracker.startPassiveTracking(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ControlButton(
                    label: 'Stop All',
                    icon: Icons.stop,
                    color: AppColors.error,
                    onPressed: mode == TrackingMode.off
                        ? null
                        : () => tracker.stopAllTracking(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ControlButton(
                    label: 'Force Flush Batch',
                    icon: Icons.cloud_upload,
                    color: AppColors.info,
                    onPressed: tracker.pendingUpdates == 0
                        ? null
                        : () async {
                            await tracker.flushBatch();
                            setState(() {});
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (mode == TrackingMode.active)
              _ControlButton(
                label: 'Revert to Passive',
                icon: Icons.arrow_back,
                color: AppColors.warning,
                onPressed: () => tracker.stopActiveTracking(),
              ),
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
        return AppColors.error;
      case TrackingMode.passive:
        return AppColors.info;
      case TrackingMode.active:
        return AppColors.success;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:'
          '${timestamp.minute.toString().padLeft(2, '0')}:'
          '${timestamp.second.toString().padLeft(2, '0')}';
    }
  }
}

// ── Helper Widgets ───────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _StatusCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withOpacity(0.3),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
