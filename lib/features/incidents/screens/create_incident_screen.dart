import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/incident_provider.dart';

class CreateIncidentScreen extends StatefulWidget {
  const CreateIncidentScreen({super.key});

  @override
  State<CreateIncidentScreen> createState() => _CreateIncidentScreenState();
}

class _CreateIncidentScreenState extends State<CreateIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Step 1: Type & Severity
  String? _selectedType;
  String _selectedSeverity = 'medium';

  // Step 2: Location
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _addressController = TextEditingController();
  final _barangayController = TextEditingController();
  final _municipalityController = TextEditingController();
  final _provinceController = TextEditingController(text: 'Surigao del Norte');

  // Step 3: Details
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationDescController = TextEditingController();
  final _peopleAffectedController = TextEditingController();

  // Casualties
  final List<Map<String, dynamic>> _casualties = [];

  // Step 4: Property Damage
  final List<Map<String, dynamic>> _propertyDamage = [];

  // Step 5: Notes
  final _notesController = TextEditingController();

  static const _incidentTypes = [
    {'value': 'medical_emergency', 'label': 'Medical Emergency', 'icon': Icons.local_hospital},
    {'value': 'fire', 'label': 'Fire', 'icon': Icons.local_fire_department},
    {'value': 'natural_disaster', 'label': 'Natural Disaster', 'icon': Icons.public},
    {'value': 'accident', 'label': 'Accident', 'icon': Icons.car_crash},
    {'value': 'crime', 'label': 'Crime', 'icon': Icons.gavel},
    {'value': 'flood', 'label': 'Flood', 'icon': Icons.flood},
    {'value': 'earthquake', 'label': 'Earthquake', 'icon': Icons.vibration},
    {'value': 'landslide', 'label': 'Landslide', 'icon': Icons.landscape},
    {'value': 'typhoon', 'label': 'Typhoon', 'icon': Icons.cyclone},
    {'value': 'other', 'label': 'Other', 'icon': Icons.warning_amber},
  ];

  static const _severityLevels = ['low', 'medium', 'high', 'critical'];

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _addressController.dispose();
    _barangayController.dispose();
    _municipalityController.dispose();
    _provinceController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationDescController.dispose();
    _peopleAffectedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ip = context.watch<IncidentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Incident'),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: ip.isSubmitting ? null : _submit,
              child: Text(
                'Submit',
                style: TextStyle(
                  color: ip.isSubmitting ? Colors.white38 : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          onStepTapped: (step) => setState(() => _currentStep = step),
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_currentStep == 4 ? 'Submit' : 'Continue'),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back'),
                    ),
                ],
              ),
            );
          },
          steps: [
            // ── Step 1: Type & Severity ──────────────────
            Step(
              title: const Text('Type & Severity'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Incident Type',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _incidentTypes.length,
                    itemBuilder: (context, index) {
                      final type = _incidentTypes[index];
                      final isSelected = _selectedType == type['value'];
                      return InkWell(
                        onTap: () => setState(() => _selectedType = type['value'] as String),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.1)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                type['icon'] as IconData,
                                size: 28,
                                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                type['label'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Severity',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: _severityLevels.map((level) {
                      final isSelected = _selectedSeverity == level;
                      final color = AppColors.incidentSeverityColor(level);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            label: Text(
                              level.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : color,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: color,
                            backgroundColor: color.withOpacity(0.1),
                            onSelected: (_) => setState(() => _selectedSeverity = level),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // ── Step 2: Location ─────────────────────────
            Step(
              title: const Text('Location'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lngController,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Street Address (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _barangayController,
                    decoration: const InputDecoration(
                      labelText: 'Barangay',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _municipalityController,
                    decoration: const InputDecoration(
                      labelText: 'Municipality',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _provinceController,
                    decoration: const InputDecoration(
                      labelText: 'Province',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),

            // ── Step 3: Details ──────────────────────────
            Step(
              title: const Text('Details'),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 4,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Description is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationDescController,
                    decoration: const InputDecoration(
                      labelText: 'Location Description (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _peopleAffectedController,
                    decoration: const InputDecoration(
                      labelText: 'Est. People Affected',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  // Casualties
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Casualties',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      TextButton.icon(
                        onPressed: _addCasualty,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  ..._casualties.asMap().entries.map((entry) {
                    final i = entry.key;
                    final c = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text('${c['type']}: ${c['count']}',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: c['details'] != null
                            ? Text(c['details'] as String, style: const TextStyle(fontSize: 12))
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: AppColors.error, size: 20),
                          onPressed: () => setState(() => _casualties.removeAt(i)),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // ── Step 4: Property Damage ──────────────────
            Step(
              title: const Text('Property Damage'),
              subtitle: const Text('Optional'),
              isActive: _currentStep >= 3,
              state: _currentStep > 3 ? StepState.complete : StepState.indexed,
              content: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Property Damage Entries',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      TextButton.icon(
                        onPressed: _addPropertyDamage,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  ..._propertyDamage.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text('${p['type']}: ${p['description']}',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text('Est. Value: ${p['estimated_value'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: AppColors.error, size: 20),
                          onPressed: () => setState(() => _propertyDamage.removeAt(i)),
                        ),
                      ),
                    );
                  }),
                  if (_propertyDamage.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No property damage entries',
                          style: TextStyle(color: AppColors.textHint)),
                    ),
                ],
              ),
            ),

            // ── Step 5: Additional Notes ─────────────────
            Step(
              title: const Text('Additional Notes'),
              isActive: _currentStep >= 4,
              content: Column(
                children: [
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Internal Notes (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 5,
                  ),
                  if (ip.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(ip.errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ),
                  ],
                  if (ip.isSubmitting) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onStepContinue() {
    if (_currentStep == 0 && _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an incident type')),
      );
      return;
    }
    if (_currentStep == 2 && !_formKey.currentState!.validate()) return;

    if (_currentStep == 4) {
      _submit();
    } else {
      setState(() => _currentStep++);
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _addCasualty() {
    showDialog(
      context: context,
      builder: (_) => _AddCasualtyDialog(onAdd: (casualty) {
        setState(() => _casualties.add(casualty));
      }),
    );
  }

  void _addPropertyDamage() {
    showDialog(
      context: context,
      builder: (_) => _AddPropertyDamageDialog(onAdd: (damage) {
        setState(() => _propertyDamage.add(damage));
      }),
    );
  }

  Future<void> _submit() async {
    // Display notification that incident creation is not supported
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Feature Not Available'),
          ],
        ),
        content: const Text(
          'Creating new incidents is not supported by the server. '
          'This is a read-only view of the dispatch system.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ─── Add Casualty Dialog ─────────────────────────────────────

class _AddCasualtyDialog extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onAdd;

  const _AddCasualtyDialog({required this.onAdd});

  @override
  State<_AddCasualtyDialog> createState() => _AddCasualtyDialogState();
}

class _AddCasualtyDialogState extends State<_AddCasualtyDialog> {
  String _type = 'injured';
  final _countController = TextEditingController(text: '1');
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _countController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Casualty'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _type,
            items: ['injured', 'deceased', 'missing'].map((t) {
              return DropdownMenuItem(value: t, child: Text(t.toUpperCase()));
            }).toList(),
            onChanged: (v) => setState(() => _type = v!),
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _countController,
            decoration: const InputDecoration(
              labelText: 'Count',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _detailsController,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onAdd({
              'type': _type,
              'count': int.tryParse(_countController.text) ?? 1,
              if (_detailsController.text.isNotEmpty) 'details': _detailsController.text,
            });
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ─── Add Property Damage Dialog ──────────────────────────────

class _AddPropertyDamageDialog extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onAdd;

  const _AddPropertyDamageDialog({required this.onAdd});

  @override
  State<_AddPropertyDamageDialog> createState() => _AddPropertyDamageDialogState();
}

class _AddPropertyDamageDialogState extends State<_AddPropertyDamageDialog> {
  String _type = 'residential';
  final _descController = TextEditingController();
  final _valueController = TextEditingController();

  @override
  void dispose() {
    _descController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Property Damage'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _type,
            items: ['residential', 'commercial', 'agricultural', 'infrastructure', 'vehicle', 'other']
                .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                .toList(),
            onChanged: (v) => setState(() => _type = v!),
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _valueController,
            decoration: const InputDecoration(
              labelText: 'Estimated Value (PHP)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onAdd({
              'type': _type,
              'description': _descController.text,
              if (_valueController.text.isNotEmpty)
                'estimated_value': double.tryParse(_valueController.text),
            });
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
