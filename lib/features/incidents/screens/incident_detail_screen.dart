import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/incident_provider.dart';
import '../../../core/providers/incident_response_provider.dart';
// import '../../../core/providers/auth_provider.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../e_street_form/screens/e_street_form_screen.dart';
import '../../e_street_form/models/e_street_form_model.dart';
import '../../e_street_form/services/e_street_local_storage.dart';
import '../../e_street_form/services/e_street_pdf_generator.dart';
import '../../e_street_form/widgets/e_street_form_data_display.dart';

class IncidentDetailScreen extends StatefulWidget {
  final int incidentId;

  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  final _notesController = TextEditingController();
  bool _showNotes = false;
  bool _hasShownInjuryMapper =
      false; // Track if we've already opened the injury mapper

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

  void _checkAndOpenInjuryMapper(Map<String, dynamic>? incident) {
    if (incident == null || _hasShownInjuryMapper) return;

    final status = incident['status'] as String?;
    if (status == 'on_scene') {
      _hasShownInjuryMapper = true;

      // Delay to ensure the detail screen is fully built
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EStreetFormScreen(
              incidentId: widget.incidentId,
              incidentData: incident,
            ),
          ),
        );
      });
    }
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

    // Automatically open injury mapper if incident is on_scene
    if (incident != null && !ip.isLoading) {
      _checkAndOpenInjuryMapper(incident);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
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
                      const Icon(Icons.error_outline,
                          size: 56, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(ip.errorMessage!,
                          style: const TextStyle(color: AppColors.error)),
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
      bottomNavigationBar:
          incident != null ? _buildActionBar(context, incident, ip) : null,
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

    // Terminal states — no status action but E-Street Form still available
    if (next == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border:
              Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
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
              Expanded(
                child: Text(
                  status == 'resolved' || status == 'closed'
                      ? 'Incident ${status.replaceAll('_', ' ')}'
                      : 'Status: ${status.replaceAll('_', ' ').toUpperCase()}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.incidentStatusColor(status),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EStreetFormScreen(
                        incidentId: widget.incidentId,
                        incidentData: incident,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.assignment, size: 18),
                label:
                    const Text('E-Street Form', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _generatePdf(incident),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('PDF', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red[700]!),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Check if incident is assigned to someone else
    final assignedUser = incident['assigned_user'] as Map<String, dynamic>?;
    final rp = context.read<IncidentResponseProvider>();
    final auth = context.read<AuthProvider>();

    // Am I the assigned responder?
    // Check both local state (activeIncidentId) AND the actual incident data (assigned_user.id)
    // This handling ensures that if the app is restarted, we don't lock the user out of their own incident.
    final currentUserId = auth.user?.id;
    final assignedUserId = assignedUser?['id'];
    final isMe = (rp.activeIncidentId == incident['id']) ||
        (currentUserId != null &&
            assignedUserId != null &&
            currentUserId.toString() == assignedUserId.toString());

    // Check if another responder is active
    final isOtherResponder = !isMe &&
        assignedUser != null &&
        (status == 'responding' || status == 'on_scene');

    // Locked: If another responder is active, we just show the native status info
    // but the button will be disabled in the UI.
    // No override needed here.

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
            // Warning if another responder is active
            if (isOtherResponder)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Responder ${assignedUser['name'] ?? 'Unknown'} is ${status == 'on_scene' ? 'ON SCENE' : 'EN ROUTE'}',
                        style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

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
                // E-Street Form button
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EStreetFormScreen(
                          incidentId: widget.incidentId,
                          incidentData: incident,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.assignment, color: Color(0xFF1976D2)),
                  tooltip: 'E-Street Form',
                ),
                const SizedBox(width: 4),
                // Main action button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: (ip.isSubmitting || isOtherResponder)
                          ? null
                          : () => _confirmStatusChange(
                                context,
                                ip,
                                widget.incidentId,
                                next, // Use original next, not effectiveNext (no override needed)
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
                          : Icon(isOtherResponder ? Icons.lock : icon),
                      label: Text(
                        ip.isSubmitting
                            ? 'Updating...'
                            : isOtherResponder
                                ? 'LOCKED'
                                : label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOtherResponder ? Colors.grey : color,
                        disabledBackgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: isOtherResponder ? 0 : 2,
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
    String label, {
    Map<String, dynamic>? assignedUser,
  }) async {
    String message =
        'Are you sure you want to update this incident status to "${nextStatus.replaceAll('_', ' ')}"?';

    // Custom warning for shared response
    if (assignedUser != null && nextStatus == 'responding') {
      message =
          'Responder ${assignedUser['name']} is already En Route.\n\nAre you sure you want to respond as well?';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm: $label'),
        content: Text(message),
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

      // If status changed to "on_scene", automatically open E-Street Form
      if (nextStatus == 'on_scene') {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EStreetFormScreen(
                incidentId: incidentId,
                incidentData: ip.currentIncident,
              ),
            ),
          );
        });
      }
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
    final type =
        (incident['incident_type'] ?? incident['type'] ?? 'Unknown') as String;
    final status = (incident['status'] ?? 'unknown') as String;
    final severity = (incident['severity'] ?? '') as String;
    final incNumber =
        incident['incident_number'] as String? ?? '#${incident['id']}';
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
    final title =
        (incident['incident_title'] ?? incident['title']) as String? ??
            type.replaceAll('_', ' ');
    final description = incident['description'] as String? ?? '';
    final peopleAffected = incident['estimated_people_affected'];

    // Parse casualties - might be a JSON string or already a List
    List? casualties;
    if (incident['casualties'] != null) {
      if (incident['casualties'] is String) {
        try {
          casualties = jsonDecode(incident['casualties'] as String) as List?;
        } catch (e) {
          debugPrint('⚠️ Failed to parse casualties JSON: $e');
        }
      } else if (incident['casualties'] is List) {
        casualties = incident['casualties'] as List;
      }
    }

    // Parse property_damage - might be a JSON string or already a List
    List? propertyDamage;
    if (incident['property_damage'] != null) {
      if (incident['property_damage'] is String) {
        try {
          propertyDamage =
              jsonDecode(incident['property_damage'] as String) as List?;
        } catch (e) {
          debugPrint('⚠️ Failed to parse property_damage JSON: $e');
        }
      } else if (incident['property_damage'] is List) {
        propertyDamage = incident['property_damage'] as List;
      }
    }

    // Reporter
    final citizen = incident['citizen'] as Map<String, dynamic>?;
    final source = incident['source'] as String?;

    // Fallback: Parse reporter info from description if citizen object is null
    String? reporterNameFromDesc;
    String? reporterContactFromDesc;
    if (citizen == null && description.isNotEmpty) {
      // Try to extract "Reported by: NAME" and "Contact: PHONE"
      final reportedByMatch =
          RegExp(r'Reported by:\s*([^\n]+)', caseSensitive: false)
              .firstMatch(description);
      final contactMatch = RegExp(r'Contact:\s*([^\n]+)', caseSensitive: false)
          .firstMatch(description);

      if (reportedByMatch != null) {
        reporterNameFromDesc = reportedByMatch.group(1)?.trim();
      }
      if (contactMatch != null) {
        reporterContactFromDesc = contactMatch.group(1)?.trim();
      }
    }

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
        // ── AdminLTE Info Header ─────────────────────────
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              // Header bar
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sevColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(3)),
                ),
                child: Row(
                  children: [
                    Icon(_typeIcon(type), color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      incNumber,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: sevColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_typeIcon(type), color: sevColor, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _chip(status.replaceAll('_', ' ').toUpperCase(),
                                  statColor),
                              _chip(severity.toUpperCase(), sevColor,
                                  icon: Icons.warning_amber_rounded),
                              // Responder Status Badge (New)
                              if ((status == 'responding' ||
                                      status == 'on_scene') &&
                                  incident['assigned_user'] != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: Colors.blue.withOpacity(0.3),
                                        width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.directions_car_filled,
                                          size: 14, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          incident['assigned_user']['name'] !=
                                                  null
                                              ? '${incident['assigned_user']['name']} is ${status == 'on_scene' ? 'ON SCENE' : 'EN ROUTE'}'
                                              : (status == 'on_scene'
                                                  ? 'RESPONDER ON SCENE'
                                                  : 'RESPONDER EN ROUTE'),
                                          style: const TextStyle(
                                            fontSize: 11,
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
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
              value: () {
                final areaStr = [barangay, municipality, province]
                    .where((s) => s != null && s.isNotEmpty)
                    .join(', ');
                return areaStr.isNotEmpty ? areaStr : 'Not specified';
              }(),
            ),
            if (locationDesc != null && locationDesc.isNotEmpty)
              _InfoRow(
                  icon: Icons.description,
                  label: 'Description',
                  value: locationDesc),
            if (lat != null && lng != null) ...[
              _InfoRow(
                  icon: Icons.gps_fixed,
                  label: 'Coordinates',
                  value: '$lat, $lng'),
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
              _InfoRow(
                  icon: Icons.notes, label: 'Description', value: description),
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
                        value: (citizen['phone'] ?? citizen['phone_number'])
                            as String,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.call,
                          color: AppColors.success, size: 20),
                      onPressed: () => _callPhone((citizen['phone'] ??
                          citizen['phone_number']) as String),
                    ),
                  ],
                ),
              if (citizen['email'] != null)
                _InfoRow(
                    icon: Icons.email,
                    label: 'Email',
                    value: citizen['email'] as String),
            ] else if (reporterNameFromDesc != null ||
                reporterContactFromDesc != null) ...[
              // Fallback: Show parsed data from description
              if (reporterNameFromDesc != null)
                _InfoRow(
                  icon: Icons.person,
                  label: 'Name',
                  value: reporterNameFromDesc,
                ),
              if (reporterContactFromDesc != null)
                Row(
                  children: [
                    Expanded(
                      child: _InfoRow(
                        icon: Icons.phone,
                        label: 'Phone',
                        value: reporterContactFromDesc,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.call,
                          color: AppColors.success, size: 20),
                      onPressed: () => _callPhone(reporterContactFromDesc!),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Info extracted from incident description',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              const _InfoRow(
                  icon: Icons.person,
                  label: 'Reporter',
                  value: 'No reporter info'),
            if (source != null)
              _InfoRow(icon: Icons.source, label: 'Source', value: source),
          ],
        ),

        // ── Response Section ──────────────────────────────
        Builder(
          builder: (context) {
            // Parse status_history - might be a JSON string or already a List
            List? statusHistory;
            if (incident['status_history'] is String) {
              try {
                statusHistory =
                    jsonDecode(incident['status_history'] as String) as List?;
              } catch (e) {
                debugPrint('⚠️ Failed to parse status_history JSON: $e');
              }
            } else if (incident['status_history'] is List) {
              statusHistory = incident['status_history'] as List;
            }

            if (statusHistory == null || statusHistory.isEmpty) {
              return const SizedBox.shrink();
            }

            return _SectionCard(
              icon: Icons.history,
              title: 'Status History',
              children: [
                ...statusHistory.map<Widget>((entry) {
                  final e = entry as Map<String, dynamic>;
                  final eStatus = e['status'] as String? ?? '';
                  final eTime = e['timestamp'] as String? ??
                      e['created_at'] as String? ??
                      '';
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
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(eTimeStr,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textHint)),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),

        // ── E-Street Form Data ────────────────────────────
        EStreetFormDataDisplay(
          eStreetFormJson: incident['e_street_form'] as String?,
          eStreetFormPdfPath: incident['e_street_form_pdf'] as String?,
          incidentId: widget.incidentId,
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

    // Get location updates from the current incident data (already loaded)
    final incident = ip.currentIncident;
    final updates = (incident?['location_updates'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    debugPrint('📍 Showing location history: ${updates.length} updates');

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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Location Update History',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${updates.length} points',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: updates.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off,
                              size: 48, color: AppColors.textHint),
                          SizedBox(height: 8),
                          Text('No location updates yet',
                              style: TextStyle(color: AppColors.textHint)),
                          SizedBox(height: 4),
                          Text('Responder location will appear here',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textHint)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: updates.length,
                      itemBuilder: (_, i) {
                        final u = updates[i];
                        String tStr = '';
                        String timestamp = u['timestamp'] as String? ??
                            u['created_at'] as String? ??
                            '';
                        try {
                          tStr = timeago.format(DateTime.parse(timestamp));
                        } catch (_) {
                          tStr = timestamp;
                        }

                        final lat = u['latitude'];
                        final lng = u['longitude'];
                        final accuracy = u['accuracy'];
                        final speed = u['speed'];
                        final heading = u['heading'];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            radius: 20,
                            child: const Icon(Icons.location_on,
                                size: 20, color: AppColors.primary),
                          ),
                          title: Text(
                            '$lat, $lng',
                            style: const TextStyle(
                                fontSize: 13, fontFamily: 'monospace'),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tStr, style: const TextStyle(fontSize: 12)),
                              if (accuracy != null || speed != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      if (accuracy != null)
                                        Text('±${accuracy}m',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textHint)),
                                      if (accuracy != null && speed != null)
                                        const Text(' • ',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textHint)),
                                      if (speed != null)
                                        Text('${speed}m/s',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textHint)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.map, size: 20),
                            onPressed: () {
                              // Open in maps
                              launchUrl(Uri.parse(
                                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng'));
                            },
                          ),
                          isThreeLine: accuracy != null || speed != null,
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
    // Use geo: URI scheme for Android to open in Google Maps app
    // This will open the location and allow navigation
    final url = Uri.parse('geo:0,0?q=$lat,$lng(Incident Location)');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to web URL if geo: scheme not available
      final webUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _callPhone(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _generatePdf(Map<String, dynamic> incident) async {
    try {
      // Check if E-Street form data exists
      final eStreetFormData = incident['e_street_form'];
      if (eStreetFormData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No E-Street form data available. Please fill out the form first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Parse the E-Street form data
      Map<String, dynamic> formJson;
      if (eStreetFormData is String) {
        formJson = jsonDecode(eStreetFormData);
      } else if (eStreetFormData is Map<String, dynamic>) {
        formJson = eStreetFormData;
      } else {
        throw Exception('Invalid E-Street form data format');
      }

      // Create form model and enrich with locally saved images
      final formModel = EStreetFormModel.fromJson(formJson);
      await _enrichWithLocalImages(formModel);

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Generate and open PDF
      await EStreetPdfGenerator.printPdf(formModel, widget.incidentId);

      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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

  /// Enrich form model with locally saved image data.
  /// The API may not store large base64 signatures/body diagram data,
  /// so we load them from local file storage (saved during form submission).
  Future<void> _enrichWithLocalImages(EStreetFormModel formModel) async {
    try {
      final localData =
          await EStreetLocalStorage.loadAllImages(widget.incidentId);

      if (localData.isEmpty) {
        print(
            '⚠️ No locally saved images found for incident ${widget.incidentId}');
        return;
      }

      if (formModel.patientSignature == null &&
          localData['patient_signature'] != null) {
        formModel.patientSignature = localData['patient_signature'] as String;
      }
      if (formModel.doctorSignature == null &&
          localData['doctor_signature'] != null) {
        formModel.doctorSignature = localData['doctor_signature'] as String;
      }
      if (formModel.responderSignature == null &&
          localData['responder_signature'] != null) {
        formModel.responderSignature =
            localData['responder_signature'] as String;
      }
      if (formModel.bodyDiagramScreenshot == null &&
          localData['body_diagram_screenshot'] != null) {
        formModel.bodyDiagramScreenshot =
            localData['body_diagram_screenshot'] as String;
      }
      if (formModel.bodyObservations.isEmpty &&
          localData['body_observations'] != null) {
        try {
          final obsStr = localData['body_observations'] as String;
          final decoded = jsonDecode(obsStr);
          if (decoded is Map) {
            formModel.bodyObservations = decoded.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            );
          }
        } catch (e) {
          print('⚠️ Error parsing body observations from local storage: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error enriching form model with local images: $e');
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          // Panel body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Row ────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

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
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
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
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
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
