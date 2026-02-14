import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/incident_provider.dart';
import '../../../core/widgets/custom_button.dart';

class AssignmentActionScreen extends StatefulWidget {
  final int incidentId;
  final int assignmentId;

  const AssignmentActionScreen({
    super.key,
    required this.incidentId,
    required this.assignmentId,
  });

  @override
  State<AssignmentActionScreen> createState() => _AssignmentActionScreenState();
}

class _AssignmentActionScreenState extends State<AssignmentActionScreen> {
  final _rejectionController = TextEditingController();

  @override
  void dispose() {
    _rejectionController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final provider = context.read<IncidentProvider>();
    final success = await provider.acceptAssignment(widget.assignmentId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment accepted'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to accept'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _reject() async {
    final reason = _rejectionController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for rejection'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final provider = context.read<IncidentProvider>();
    final success =
        await provider.rejectAssignment(widget.assignmentId, reason);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment rejected'),
          backgroundColor: AppColors.info,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to reject'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _updateStatus(String status) async {
    final provider = context.read<IncidentProvider>();
    final success = await provider.updateAssignmentStatus(
        widget.assignmentId, status);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${status.replaceAll('_', ' ')}'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to update'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IncidentProvider>();
    final assignment = provider.getAssignment(widget.assignmentId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment Actions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Current Status ─────────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Current Status: ',
                      style: TextStyle(fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.assignmentStatusColor(
                                assignment?.status ?? 'pending')
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        assignment?.statusLabel ?? 'Pending',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.assignmentStatusColor(
                              assignment?.status ?? 'pending'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Accept / Reject (only if pending) ──────────
            if (assignment?.status == 'pending') ...[
              const Text(
                'Respond to Dispatch',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Accept Assignment',
                icon: Icons.check_circle,
                backgroundColor: AppColors.success,
                isLoading: provider.isLoading,
                onPressed: _accept,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rejectionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Rejection Reason',
                  hintText: 'Provide a reason if rejecting…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Reject Assignment',
                icon: Icons.cancel,
                backgroundColor: AppColors.error,
                isLoading: provider.isLoading,
                onPressed: _reject,
              ),
            ],

            // ── Status Transitions (if accepted) ───────────
            if (assignment?.status == 'accepted' ||
                assignment?.status == 'en_route' ||
                assignment?.status == 'on_scene') ...[
              const Text(
                'Update Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (assignment?.status == 'accepted')
                CustomButton(
                  text: 'En Route',
                  icon: Icons.directions_car,
                  backgroundColor: AppColors.statusEnRoute,
                  isLoading: provider.isLoading,
                  onPressed: () => _updateStatus('en_route'),
                ),
              if (assignment?.status == 'en_route') ...[
                CustomButton(
                  text: 'On Scene',
                  icon: Icons.location_on,
                  backgroundColor: AppColors.statusOnScene,
                  isLoading: provider.isLoading,
                  onPressed: () => _updateStatus('on_scene'),
                ),
              ],
              if (assignment?.status == 'on_scene') ...[
                CustomButton(
                  text: 'Completed',
                  icon: Icons.check,
                  backgroundColor: AppColors.statusCompleted,
                  isLoading: provider.isLoading,
                  onPressed: () => _updateStatus('completed'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
