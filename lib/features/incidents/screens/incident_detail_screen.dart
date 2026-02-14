import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/incident_provider.dart';

class IncidentDetailScreen extends StatefulWidget {
  final int incidentId;

  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  final _notesController = TextEditingController();
  bool _showNotes = false;

  // Status workflow: current status → next status
  static const _nextStatus = {
    'reported': 'acknowledged',
    'acknowledged': 'responding',
    'responding': 'on_scene',
    'on_scene': 'resolved',
  };

  static const _actionLabels = {
    'acknowledged': 'Acknowledge',
    'responding': 'Respond',
    'on_scene': 'On Scene',
    'resolved': 'Mark Resolved',
  };

  static const _actionIcons = {
    'acknowledged': Icons.check,
    'responding': Icons.directions_car,
    'on_scene': Icons.location_on,
    'resolved': Icons.check_circle,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().fetchIncident(widget.incidentId);
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    // Clear current incident when leaving
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<IncidentProvider>().clearCurrentIncident();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ip = context.watch<IncidentProvider>();
    final incident = ip.currentIncident;

    return Scaffold(
      appBar: AppBar(
        title: Text(incident?['incident_number'] ?? 'Incident Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ip.fetchIncident(widget.incidentId),
          ),
        ],
      ),
      body: ip.isLoading && incident == null
          ? const Center(child: CircularProgressIndicator())
          : ip.errorMessage != null && incident == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 56, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(ip.errorMessage!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ip.fetchIncident(widget.incidentId),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : incident == null
                  ? const Center(child: Text('Incident not found'))
                  : RefreshIndicator(
                      onRefresh: () => ip.fetchIncident(widget.incidentId),
                      child: _buildContent(context, incident, ip),
                    ),
      bottomNavigationBar: incident != null
          ? _buildActionBar(context, incident, ip)
          : null,
    );
  }

  // ── Action Bar ───────────────────────────────────────────
  Widget _buildActionBar(
    BuildContext context,
    Map<String, dynamic> incident,
    IncidentProvider ip,
  ) {
    final status = (incident['status'] ?? 'unknown').toString().toLowerCase();
    final next = _nextStatus[status];

    // Terminal states — no action available
    if (next == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Icon(
                status == 'resolved' || status == 'closed'
                    ? Icons.check_circle
                    : Icons.info_outline,
                size: 18,
                color: AppColors.incidentStatusColor(status),
              ),
              const SizedBox(width: 8),
              Text(
                status == 'resolved' || status == 'closed'
                    ? 'This incident has been ${status.replaceAll('_', ' ')}'
                    : 'Status: ${status.replaceAll('_', ' ').toUpperCase()}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.incidentStatusColor(status),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final label = _actionLabels[next] ?? next.toUpperCase();
    final icon = _actionIcons[next] ?? Icons.arrow_forward;
    final color = AppColors.incidentStatusColor(next);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Optional notes toggle
            if (_showNotes) ...[
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Add notes (optional)...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                // Notes toggle button
                IconButton(
                  onPressed: () => setState(() => _showNotes = !_showNotes),
                  icon: Icon(
                    _showNotes ? Icons.notes : Icons.note_add_outlined,
                    color: _showNotes ? AppColors.primary : Colors.grey,
                  ),
                  tooltip: 'Add notes',
                ),
                const SizedBox(width: 8),
                // Main action button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: ip.isSubmitting
                          ? null
                          : () => _confirmStatusChange(
                                context,
                                ip,
                                widget.incidentId,
                                next,
                                label,
                              ),
                      icon: ip.isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(icon),
                      label: Text(
                        ip.isSubmitting ? 'Updating...' : label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Confirmation Dialog ──────────────────────────────────
  Future<void> _confirmStatusChange(
    BuildContext context,
    IncidentProvider ip,
    int incidentId,
    String nextStatus,
    String label,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm: $label'),
        content: Text(
          'Are you sure you want to update this incident status to "${nextStatus.replaceAll('_', ' ')}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.incidentStatusColor(nextStatus),
              foregroundColor: Colors.white,
            ),
            child: Text(label),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final notes = _notesController.text.trim();
    
    // Call the appropriate action method based on next status
    bool success;
    switch (nextStatus) {
      case 'acknowledged':
        success = await ip.acknowledgeIncident(
          incidentId,
          notes: notes.isNotEmpty ? notes : null,
        );
        break;
      case 'responding':
        success = await ip.respondToIncident(
          incidentId,
          notes: notes.isNotEmpty ? notes : null,
        );
        break;
      case 'on_scene':
        success = await ip.markOnScene(
          incidentId,
          notes: notes.isNotEmpty ? notes : null,
        );
        break;
      case 'resolved':
        success = await ip.resolveIncident(
          incidentId,
          notes: notes.isNotEmpty ? notes : null,
        );
        break;
      case 'closed':
        success = await ip.closeIncident(
          incidentId,
          notes: notes.isNotEmpty ? notes : null,
        );
        break;
      case 'cancelled':
        success = await ip.cancelIncident(
          incidentId,
          notes: notes.isNotEmpty ? notes : null,
        );
        break;
      default:
        success = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unknown action: $nextStatus'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
    }

    if (!mounted) return;

    if (success) {
      _notesController.clear();
      setState(() => _showNotes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${nextStatus.replaceAll('_', ' ')}'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ip.errorMessage ?? 'Failed to update status'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildContent(
    BuildContext context,
    Map<String, dynamic> incident,
    IncidentProvider ip,
  ) {
    final type = (incident['incident_type'] ?? incident['type'] ?? 'Unknown') as String;
    final status = (incident['status'] ?? 'unknown') as String;
    final severity = (incident['severity'] ?? '') as String;
    final incNumber = incident['incident_number'] as String? ?? '#${incident['id']}';
    final createdAt = incident['created_at'] as String?;
    final sevColor = AppColors.incidentSeverityColor(severity);
    final statColor = AppColors.incidentStatusColor(status);

    // Location
    final lat = incident['latitude'];
    final lng = incident['longitude'];
    final address = incident['location_address'] as String?;
    final barangay = incident['barangay'] as String?;
    final municipality = incident['municipality'] as String?;
    final province = incident['province'] as String?;
    final locationDesc = incident['location_description'] as String?;

    // Details
    final title = incident['title'] as String? ?? type.replaceAll('_', ' ');
    final description = incident['description'] as String? ?? '';
    final peopleAffected = incident['estimated_people_affected'];
    final casualties = incident['casualties'] as List?;
    final propertyDamage = incident['property_damage'] as List?;

    // Reporter
    final citizen = incident['citizen'] as Map<String, dynamic>?;
    final source = incident['source'] as String?;

    // Response
    final assignedUser = incident['assigned_user'] as Map<String, dynamic>?;
    final internalNotes = incident['internal_notes'] as String?;
    final resolutionDetails = incident['resolution_details'] as String?;

    String timeStr = '';
    if (createdAt != null) {
      try {
        timeStr = timeago.format(DateTime.parse(createdAt));
      } catch (_) {
        timeStr = createdAt;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // ── Hero Section ─────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [sevColor.withOpacity(0.08), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: sevColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_typeIcon(type), color: sevColor, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                incNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _chip(status.replaceAll('_', ' ').toUpperCase(), statColor),
                  const SizedBox(width: 8),
                  _chip(severity.toUpperCase(), sevColor, icon: Icons.warning_amber_rounded),
                ],
              ),
              const SizedBox(height: 6),
              if (timeStr.isNotEmpty)
                Text('Created $timeStr',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),

        // ── Location Section ─────────────────────────────
        _SectionCard(
          icon: Icons.location_on,
          title: 'Location',
          children: [
            if (address != null && address.isNotEmpty)
              _InfoRow(icon: Icons.place, label: 'Address', value: address),
            _InfoRow(
              icon: Icons.map_outlined,
              label: 'Area',
              value: [barangay, municipality, province]
                  .where((s) => s != null && s.isNotEmpty)
                  .join(', '),
            ),
            if (locationDesc != null && locationDesc.isNotEmpty)
              _InfoRow(icon: Icons.description, label: 'Description', value: locationDesc),
            if (lat != null && lng != null) ...[
              _InfoRow(icon: Icons.gps_fixed, label: 'Coordinates', value: '$lat, $lng'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openInMaps(lat, lng),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open in Google Maps'),
                ),
              ),
            ],
          ],
        ),

        // ── Incident Info ────────────────────────────────
        _SectionCard(
          icon: Icons.info_outline,
          title: 'Incident Information',
          children: [
            _InfoRow(icon: Icons.title, label: 'Title', value: title),
            if (description.isNotEmpty)
              _InfoRow(icon: Icons.notes, label: 'Description', value: description),
            _InfoRow(
              icon: Icons.category,
              label: 'Type',
              value: type.replaceAll('_', ' ').toUpperCase(),
            ),
            if (peopleAffected != null)
              _InfoRow(
                icon: Icons.people,
                label: 'People Affected',
                value: '$peopleAffected persons',
              ),
            if (casualties != null && casualties.isNotEmpty)
              _ExpandableInfo(
                title: 'Casualties (${casualties.length})',
                icon: Icons.personal_injury,
                children: casualties.map<Widget>((c) {
                  final cas = c as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${cas['type'] ?? 'Unknown'}: ${cas['count'] ?? 0} - ${cas['details'] ?? 'No details'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
              ),
            if (propertyDamage != null && propertyDamage.isNotEmpty)
              _ExpandableInfo(
                title: 'Property Damage (${propertyDamage.length})',
                icon: Icons.house,
                children: propertyDamage.map<Widget>((p) {
                  final prop = p as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${prop['type'] ?? 'Unknown'}: ${prop['description'] ?? ''} (Est: ${prop['estimated_value'] ?? 'N/A'})',
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),

        // ── Reporter Info ────────────────────────────────
        _SectionCard(
          icon: Icons.person_outline,
          title: 'Reporter Information',
          children: [
            if (citizen != null) ...[
              _InfoRow(
                icon: Icons.person,
                label: 'Name',
                value: citizen['name'] as String? ?? 'Unknown',
              ),
              if (citizen['phone'] != null || citizen['phone_number'] != null)
                Row(
                  children: [
                    Expanded(
                      child: _InfoRow(
                        icon: Icons.phone,
                        label: 'Phone',
                        value: (citizen['phone'] ?? citizen['phone_number']) as String,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.call, color: AppColors.success, size: 20),
                      onPressed: () => _callPhone(
                          (citizen['phone'] ?? citizen['phone_number']) as String),
                    ),
                  ],
                ),
              if (citizen['email'] != null)
                _InfoRow(icon: Icons.email, label: 'Email', value: citizen['email'] as String),
            ] else
              const _InfoRow(icon: Icons.person, label: 'Reporter', value: 'No reporter info'),
            if (source != null)
              _InfoRow(icon: Icons.source, label: 'Source', value: source),
          ],
        ),

        // ── Response Section ─────────────────────────────
        _SectionCard(
          icon: Icons.emergency,
          title: 'Response',
          children: [
            _InfoRow(
              icon: Icons.assignment_ind,
              label: 'Assigned To',
              value: assignedUser?['name'] as String? ?? 'Unassigned',
            ),
            if (internalNotes != null && internalNotes.isNotEmpty)
              _ExpandableInfo(
                title: 'Internal Notes',
                icon: Icons.note,
                children: [Text(internalNotes, style: const TextStyle(fontSize: 13))],
              ),
            if (resolutionDetails != null && resolutionDetails.isNotEmpty)
              _ExpandableInfo(
                title: 'Resolution Details',
                icon: Icons.check_circle_outline,
                children: [Text(resolutionDetails, style: const TextStyle(fontSize: 13))],
              ),
          ],
        ),

        // ── Status History ───────────────────────────────
        if (incident['status_history'] != null &&
            (incident['status_history'] as List).isNotEmpty)
          _SectionCard(
            icon: Icons.history,
            title: 'Status History',
            children: [
              ...(incident['status_history'] as List).map<Widget>((entry) {
                final e = entry as Map<String, dynamic>;
                final eStatus = e['status'] as String? ?? '';
                final eTime = e['created_at'] as String? ?? '';
                String eTimeStr = eTime;
                try {
                  eTimeStr = timeago.format(DateTime.parse(eTime));
                } catch (_) {}
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.incidentStatusColor(eStatus),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          eStatus.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(eTimeStr,
                          style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),
                );
              }),
            ],
          ),

        // ── Location Updates Button ──────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => _showLocationHistory(context),
            icon: const Icon(Icons.timeline),
            label: const Text('Show Location Update History'),
          ),
        ),
      ],
    );
  }

  void _showLocationHistory(BuildContext context) async {
    final ip = context.read<IncidentProvider>();
    final updates = await ip.fetchLocationUpdates(widget.incidentId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Location Updates',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Expanded(
              child: updates.isEmpty
                  ? const Center(child: Text('No location updates'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: updates.length,
                      itemBuilder: (_, i) {
                        final u = updates[i];
                        String tStr = '';
                        try {
                          tStr = timeago.format(
                              DateTime.parse(u['created_at'] as String));
                        } catch (_) {}
                        return ListTile(
                          leading: const Icon(Icons.location_on, size: 20),
                          title: Text(
                            '${u['latitude']}, ${u['longitude']}',
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                          ),
                          subtitle: Text(tStr),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _openInMaps(dynamic lat, dynamic lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _callPhone(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department;
      case 'medical_emergency':
      case 'medical':
        return Icons.local_hospital;
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

// ─── Section Card ────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ─── Info Row ────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Expandable Info ─────────────────────────────────────────

class _ExpandableInfo extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _ExpandableInfo({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  State<_ExpandableInfo> createState() => _ExpandableInfoState();
}

class _ExpandableInfoState extends State<_ExpandableInfo> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(widget.icon, size: 16, color: AppColors.textHint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 4, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}
