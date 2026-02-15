import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/body_region.dart';
import '../../../core/models/injury_entry.dart';
import '../../../core/providers/injury_provider.dart';

/// Bottom sheet modal for recording an injury on a specific body region.
class InjuryInputModal extends StatefulWidget {
  final BodyRegion region;

  const InjuryInputModal({super.key, required this.region});

  /// Convenience method to show the modal.
  static void show(BuildContext context, BodyRegion region) {
    final injuryProvider = Provider.of<InjuryProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: injuryProvider,
        child: InjuryInputModal(region: region),
      ),
    );
  }

  @override
  State<InjuryInputModal> createState() => _InjuryInputModalState();
}

class _InjuryInputModalState extends State<InjuryInputModal> {
  String? _selectedType;
  String _selectedSeverity = 'Minor';
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an injury type'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final entry = InjuryEntry(
      type: _selectedType!,
      severity: _selectedSeverity,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    context.read<InjuryProvider>().addInjury(widget.region.regionId, entry);
    Navigator.of(context).pop();
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'Minor':
        return AppColors.severityMinor;
      case 'Moderate':
        return AppColors.severityModerate;
      case 'Severe':
        return AppColors.severitySevere;
      case 'Critical':
        return AppColors.severityCritical;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag Handle ────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Region Name Header ─────────────────────────
            Text(
              widget.region.regionName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Record injury for this region',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),

            // ── Injury Type Chips ──────────────────────────
            const Text(
              'Injury Type',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: InjuryEntry.injuryTypes.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? type : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Severity Radio Group ───────────────────────
            const Text(
              'Severity',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...InjuryEntry.severityLevels.map((level) {
              return RadioListTile<String>(
                title: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _severityColor(level),
                        shape: BoxShape.circle,
                        border: level == 'Moderate'
                            ? Border.all(color: Colors.grey)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(level),
                  ],
                ),
                value: level,
                groupValue: _selectedSeverity,
                onChanged: (value) {
                  setState(() => _selectedSeverity = value!);
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
            const SizedBox(height: 16),

            // ── Description ────────────────────────────────
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Brief description of the injury…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Notes ──────────────────────────────────────
            const Text(
              'Notes',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Additional notes…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Save Button ────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text(
                  'Save Injury',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
