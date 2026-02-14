import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/incident_provider.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_indicator.dart';

class IncidentDetailScreen extends StatefulWidget {
  final int incidentId;

  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().fetchIncident(widget.incidentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IncidentProvider>();
    final incident = provider.currentIncident;

    return Scaffold(
      appBar: AppBar(
        title: Text(incident?.title ?? 'Incident #${widget.incidentId}'),
      ),
      body: provider.isLoading && incident == null
          ? const LoadingIndicator(message: 'Loading incident…')
          : incident == null
              ? Center(
                  child: Text(
                    provider.errorMessage ?? 'Incident not found',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header Card ──────────────────────────
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber,
                                      color: AppColors.severityColor(
                                          incident.severity ?? ''),
                                      size: 28),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      incident.title ?? incident.type ?? 'Incident',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (incident.severity != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.severityColor(
                                                incident.severity!)
                                            .withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        incident.severity!.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.severityColor(
                                              incident.severity!),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const Divider(height: 24),
                              _detailRow(Icons.category, 'Type',
                                  incident.type ?? 'N/A'),
                              _detailRow(Icons.info_outline, 'Status',
                                  incident.status ?? 'N/A'),
                              _detailRow(Icons.location_on, 'Address',
                                  incident.address ?? 'N/A'),
                              if (incident.latitude != null)
                                _detailRow(Icons.gps_fixed, 'Coordinates',
                                    '${incident.latitude}, ${incident.longitude}'),
                              _detailRow(Icons.person_outline, 'Reported By',
                                  incident.reportedBy ?? 'N/A'),
                              _detailRow(Icons.access_time, 'Reported At',
                                  incident.reportedAt ?? 'N/A'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Patient Info ─────────────────────────
                      if (incident.patientName != null) ...[
                        const Text(
                          'Patient Information',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _detailRow(Icons.person, 'Name',
                                    incident.patientName ?? 'N/A'),
                                _detailRow(Icons.cake, 'Age',
                                    incident.patientAge?.toString() ?? 'N/A'),
                                _detailRow(
                                    Icons.wc,
                                    'Gender',
                                    incident.patientGender ?? 'N/A'),
                                _detailRow(Icons.phone, 'Contact',
                                    incident.patientContact ?? 'N/A'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Description ──────────────────────────
                      if (incident.description != null) ...[
                        const Text(
                          'Description',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              incident.description!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Notes ────────────────────────────────
                      if (incident.notes != null) ...[
                        const Text(
                          'Notes',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              incident.notes!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Action Buttons ───────────────────────
                      const SizedBox(height: 8),
                      CustomButton(
                        text: 'Injury Mapper',
                        icon: Icons.healing,
                        onPressed: () {
                          context.push(
                              '/incident/${widget.incidentId}/injury-mapper');
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'View Assignment Actions',
                        icon: Icons.assignment,
                        backgroundColor: AppColors.secondary,
                        onPressed: () {
                          // Navigate with first assignment ID if available
                          final assignment = provider.assignments.firstWhere(
                            (a) => a.incidentId == widget.incidentId,
                            orElse: () => provider.assignments.isNotEmpty
                                ? provider.assignments.first
                                : throw Exception('No assignments'),
                          );
                          context.push(
                            '/incident/${widget.incidentId}/assignment/${assignment.id}',
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
