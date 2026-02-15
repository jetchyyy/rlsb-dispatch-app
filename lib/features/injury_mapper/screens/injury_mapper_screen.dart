import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/incident_provider.dart';
import '../../../core/providers/injury_provider.dart';
import '../../../core/services/api_service.dart';
import '../widgets/body_diagram_widget.dart';
import '../widgets/injury_summary_list.dart';

class InjuryMapperScreen extends StatefulWidget {
  final int incidentId;

  const InjuryMapperScreen({super.key, required this.incidentId});

  @override
  State<InjuryMapperScreen> createState() => _InjuryMapperScreenState();
}

class _InjuryMapperScreenState extends State<InjuryMapperScreen> {
  bool _isSubmitting = false;

  Future<void> _submitReport() async {
    final injuryProvider = context.read<InjuryProvider>();

    if (injuryProvider.totalInjuryCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please record at least one injury before submitting'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ApiService();
      await api.post(
        ApiConstants.injuryReport(widget.incidentId),
        data: injuryProvider.toJson(),
      );

      if (!mounted) return;

      injuryProvider.clearAll();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Injury report submitted successfully'),
          backgroundColor: AppColors.success,
        ),
      );

      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['message']?.toString() ??
                'Failed to submit injury report',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final injuryProvider = context.watch<InjuryProvider>();
    final incident = incidentProvider.currentIncident;
    
    // Extract patient name from incident data
    String patientName = 'Patient';
    if (incident != null) {
      // Try to get name from citizen object first
      final citizen = incident['citizen'] as Map<String, dynamic>?;
      if (citizen != null) {
        final firstName = citizen['first_name'] as String? ?? '';
        final lastName = citizen['last_name'] as String? ?? '';
        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          patientName = '$firstName $lastName'.trim();
        }
      }
      // Fallback to incident title or description
      if (patientName == 'Patient') {
        patientName = incident['incident_title'] as String? ?? 'Patient';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(patientName),
        actions: [
          if (injuryProvider.totalInjuryCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${injuryProvider.totalInjuryCount} injuries',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Body Diagram ─────────────────────────────────
          const Expanded(
            flex: 3,
            child: BodyDiagramWidget(),
          ),

          // ── Triage Category Selector ─────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surface,
            child: Row(
              children: [
                const Text(
                  'Triage: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                ..._triageOptions(injuryProvider),
              ],
            ),
          ),

          // ── Injury Summary ───────────────────────────────
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        const Text(
                          'Injury Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (injuryProvider.totalInjuryCount > 0)
                          TextButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Clear All'),
                                  content: const Text(
                                      'Remove all recorded injuries?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        injuryProvider.clearAll();
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('Clear',
                                          style:
                                              TextStyle(color: AppColors.error)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('Clear All',
                                style: TextStyle(
                                    color: AppColors.error, fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                  const InjurySummaryList(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSubmitting ? null : _submitReport,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send),
        label: Text(_isSubmitting ? 'Submitting…' : 'Submit Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  List<Widget> _triageOptions(InjuryProvider provider) {
    const categories = [
      ('Green', AppColors.triageGreen),
      ('Yellow', AppColors.triageYellow),
      ('Red', AppColors.triageRed),
      ('Black', AppColors.triageBlack),
    ];

    return categories.map((cat) {
      final isSelected = provider.triageCategory == cat.$1;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(
            cat.$1,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          selected: isSelected,
          selectedColor: cat.$2,
          backgroundColor: cat.$2.withOpacity(0.15),
          onSelected: (_) => provider.setTriageCategory(cat.$1),
          visualDensity: VisualDensity.compact,
        ),
      );
    }).toList();
  }
}
