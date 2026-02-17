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
    {
      'value': 'medical_emergency',
      'label': 'Medical Emergency',
      'icon': Icons.local_hospital
    },
    {'value': 'fire', 'label': 'Fire', 'icon': Icons.local_fire_department},
    {
      'value': 'natural_disaster',
      'label': 'Natural Disaster',
      'icon': Icons.public
    },
    {'value': 'accident', 'label': 'Accident', 'icon': Icons.car_crash},
    {'value': 'crime', 'label': 'Crime', 'icon': Icons.gavel},
    {'value': 'flood', 'label': 'Flood', 'icon': Icons.flood},
    {'value': 'earthquake', 'label': 'Earthquake', 'icon': Icons.vibration},
    {'value': 'landslide', 'label': 'Landslide', 'icon': Icons.landscape},
    {'value': 'typhoon', 'label': 'Typhoon', 'icon': Icons.cyclone},
    {'value': 'other', 'label': 'Other', 'icon': Icons.warning_amber},
  ];

  static const _severityLevels = ['low', 'medium', 'high', 'critical'];

  static const _stepLabels = [
    'Type & Severity',
    'Location',
    'Details',
    'Property Damage',
    'Additional Notes',
  ];

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
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Content Header ───────────────────────────
            Row(
              children: [
                Icon(Icons.report, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'New Incident Report',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Fill in the details to create a new incident report',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),

            // ── Step Indicator ───────────────────────────
            _buildStepIndicator(),
            const SizedBox(height: 16),

            // ── Step Content (box panel) ─────────────────
            _boxPanel(
              title: _stepLabels[_currentStep],
              icon: _stepIcon(_currentStep),
              headerColor: AppColors.primary,
              child: _buildStepContent(ip),
            ),
            const SizedBox(height: 16),

            // ── Navigation Buttons ───────────────────────
            _buildNavButtons(ip),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Step Indicator (AdminLTE progress bar style) ───────────

  Widget _buildStepIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: List.generate(_stepLabels.length, (i) {
          final isCompleted = i < _currentStep;
          final isCurrent = i == _currentStep;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentStep = i),
              child: Row(
                children: [
                  // Step circle
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? AppColors.success
                          : isCurrent
                              ? AppColors.primary
                              : Colors.grey.shade300,
                    ),
                    alignment: Alignment.center,
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                  ),
                  // Connector line
                  if (i < _stepLabels.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: isCompleted
                            ? AppColors.success
                            : Colors.grey.shade200,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  IconData _stepIcon(int step) {
    switch (step) {
      case 0:
        return Icons.category;
      case 1:
        return Icons.location_on;
      case 2:
        return Icons.description;
      case 3:
        return Icons.house_siding;
      case 4:
        return Icons.notes;
      default:
        return Icons.circle;
    }
  }

  // ── Box Panel ─────────────────────────────────────────────

  Widget _boxPanel({
    required String title,
    required IconData icon,
    required Widget child,
    Color headerColor = const Color(0xFFF8F9FA),
  }) {
    final isColored = headerColor != const Color(0xFFF8F9FA);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Panel header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 16,
                    color: isColored ? Colors.white : Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isColored ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          // Panel body
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  // ── Step Content Builder ──────────────────────────────────

  Widget _buildStepContent(IncidentProvider ip) {
    switch (_currentStep) {
      case 0:
        return _step1TypeSeverity();
      case 1:
        return _step2Location();
      case 2:
        return _step3Details();
      case 3:
        return _step4PropertyDamage();
      case 4:
        return _step5Notes(ip);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 1: Type & Severity ───────────────────────────────

  Widget _step1TypeSeverity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Incident Type'),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 1.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _incidentTypes.length,
          itemBuilder: (context, index) {
            final type = _incidentTypes[index];
            final isSelected = _selectedType == type['value'];
            return InkWell(
              onTap: () =>
                  setState(() => _selectedType = type['value'] as String),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color:
                        isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      size: 24,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type['label'] as String,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
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
        _fieldLabel('Severity Level'),
        const SizedBox(height: 8),
        Row(
          children: _severityLevels.map((level) {
            final isSelected = _selectedSeverity == level;
            final color = AppColors.incidentSeverityColor(level);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () => setState(() => _selectedSeverity = level),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey.shade300,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      level.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Step 2: Location ──────────────────────────────────────

  Widget _step2Location() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: _adminInput('Latitude', _latController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 12),
            Expanded(
                child: _adminInput('Longitude', _lngController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true))),
          ],
        ),
        const SizedBox(height: 12),
        _adminInput('Street Address (optional)', _addressController),
        const SizedBox(height: 12),
        _adminInput('Barangay', _barangayController),
        const SizedBox(height: 12),
        _adminInput('Municipality', _municipalityController),
        const SizedBox(height: 12),
        _adminInput('Province', _provinceController),
      ],
    );
  }

  // ── Step 3: Details ───────────────────────────────────────

  Widget _step3Details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _adminInput('Title *', _titleController,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Title is required' : null),
        const SizedBox(height: 12),
        _adminInput('Description *', _descriptionController,
            maxLines: 4,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Description is required' : null),
        const SizedBox(height: 12),
        _adminInput('Location Description (optional)', _locationDescController,
            maxLines: 2),
        const SizedBox(height: 12),
        _adminInput('Est. People Affected', _peopleAffectedController,
            keyboardType: TextInputType.number),
        const SizedBox(height: 16),

        // ── Casualties sub-section ──────────────────
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              // Sub-header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border:
                      Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.personal_injury,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('Casualties',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey.shade700)),
                      ],
                    ),
                    InkWell(
                      onTap: _addCasualty,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Add',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Casualty rows
              if (_casualties.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No casualties added',
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                )
              else
                ..._casualties.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c['type'] == 'deceased'
                                ? AppColors.error
                                : c['type'] == 'missing'
                                    ? AppColors.warning
                                    : AppColors.info,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${c['type']}: ${c['count']}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              if (c['details'] != null)
                                Text(c['details'] as String,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _casualties.removeAt(i)),
                          child: const Icon(Icons.close,
                              size: 16, color: AppColors.error),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 4: Property Damage ───────────────────────────────

  Widget _step4PropertyDamage() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Sub-header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.house_siding,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text('Property Damage Entries',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.grey.shade700)),
                  ],
                ),
                InkWell(
                  onTap: _addPropertyDamage,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Add',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Damage rows
          if (_propertyDamage.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No property damage entries',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            )
          else
            ..._propertyDamage.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.domain_disabled,
                        size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p['type']}: ${p['description']}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                          Text('Est. Value: ${p['estimated_value'] ?? 'N/A'}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _propertyDamage.removeAt(i)),
                      child: const Icon(Icons.close,
                          size: 16, color: AppColors.error),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Step 5: Additional Notes ──────────────────────────────

  Widget _step5Notes(IncidentProvider ip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _adminInput('Internal Notes (optional)', _notesController, maxLines: 5),
        if (ip.errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(ip.errorMessage!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
        if (ip.isSubmitting) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  // ── Navigation Buttons ────────────────────────────────────

  Widget _buildNavButtons(IncidentProvider ip) {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _onStepCancel,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: ip.isSubmitting ? null : _onStepContinue,
            icon: Icon(
              _currentStep == 4 ? Icons.send : Icons.arrow_forward,
              size: 16,
            ),
            label: Text(_currentStep == 4 ? 'Submit Report' : 'Continue'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _currentStep == 4 ? AppColors.success : AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // ── Reusable AdminLTE Input ───────────────────────────────

  Widget _adminInput(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700));
  }

  // ── Logic (unchanged) ─────────────────────────────────────

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              elevation: 0,
            ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      title: Row(
        children: [
          Icon(Icons.personal_injury, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          const Text('Add Casualty', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _type,
            items: ['injured', 'deceased', 'missing'].map((t) {
              return DropdownMenuItem(value: t, child: Text(t.toUpperCase()));
            }).toList(),
            onChanged: (v) => setState(() => _type = v!),
            decoration: InputDecoration(
              labelText: 'Type',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _countController,
            decoration: InputDecoration(
              labelText: 'Count',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _detailsController,
            decoration: InputDecoration(
              labelText: 'Details (optional)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: BorderSide(color: Colors.grey.shade400),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onAdd({
              'type': _type,
              'count': int.tryParse(_countController.text) ?? 1,
              if (_detailsController.text.isNotEmpty)
                'details': _detailsController.text,
            });
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            elevation: 0,
          ),
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
  State<_AddPropertyDamageDialog> createState() =>
      _AddPropertyDamageDialogState();
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      title: Row(
        children: [
          Icon(Icons.house_siding, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          const Text('Add Property Damage', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _type,
            items: [
              'residential',
              'commercial',
              'agricultural',
              'infrastructure',
              'vehicle',
              'other'
            ]
                .map((t) =>
                    DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                .toList(),
            onChanged: (v) => setState(() => _type = v!),
            decoration: InputDecoration(
              labelText: 'Type',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descController,
            decoration: InputDecoration(
              labelText: 'Description',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _valueController,
            decoration: InputDecoration(
              labelText: 'Estimated Value (PHP)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: BorderSide(color: Colors.grey.shade400),
          ),
          child: const Text('Cancel'),
        ),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            elevation: 0,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
