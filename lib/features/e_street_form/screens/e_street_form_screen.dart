import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/e_street_form_model.dart';
import '../services/e_street_api_service.dart';
import '../services/e_street_local_storage.dart';
import '../widgets/body_diagram_widget.dart';
import '../widgets/body_observations_list.dart';
import '../widgets/gcs_selector.dart';
import '../widgets/multi_select_chips.dart';
import '../widgets/signature_pad_widget.dart';
import '../widgets/vital_signs_section.dart';
import 'pdf_viewer_screen.dart';

/// 5-step E-Street Form wizard.
///
/// Steps: Patient Info → Medical Assessment → Treatment →
///        Transport & Outcome → Signatures & Submit
class EStreetFormScreen extends StatefulWidget {
  final int incidentId;
  final Map<String, dynamic>? incidentData;

  const EStreetFormScreen({
    super.key,
    required this.incidentId,
    this.incidentData,
  });

  @override
  State<EStreetFormScreen> createState() => _EStreetFormScreenState();
}

class _EStreetFormScreenState extends State<EStreetFormScreen> {
  int _currentStep = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;

  late EStreetFormModel _form;
  EStreetApiService? _apiService;

  // ── Controllers ─────────────────────────────────────────
  // Step 1 — Patient
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyContactCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _currentMedsCtrl = TextEditingController();
  final _medicalHistoryCtrl = TextEditingController();

  // Step 2 — Assessment
  final _chiefComplaintCtrl = TextEditingController();
  final _historyCtrl = TextEditingController();
  final _bpCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _respiratoryCtrl = TextEditingController();
  final _temperatureCtrl = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _bloodGlucoseCtrl = TextEditingController();

  // Step 3 — Treatment
  final _medicationsGivenCtrl = TextEditingController();
  final _ivFluidsCtrl = TextEditingController();
  final _treatmentNotesCtrl = TextEditingController();

  // Step 4 — Transport
  final _primaryCrewCtrl = TextEditingController();
  final _secondaryCrewCtrl = TextEditingController();
  final _doctorNameCtrl = TextEditingController();
  final _licenseNumberCtrl = TextEditingController();
  final _physicianReportCtrl = TextEditingController();
  final _hospitalOtherCtrl = TextEditingController();

  // Step 5 — Signatures
  final _finalCommentsCtrl = TextEditingController();

  // Signature pad keys
  final _patientSigKey = GlobalKey<SignaturePadWidgetState>();
  final _doctorSigKey = GlobalKey<SignaturePadWidgetState>();
  final _responderSigKey = GlobalKey<SignaturePadWidgetState>();

  // Body diagram key
  final _bodyDiagramKey = GlobalKey<EStreetBodyDiagramWidgetState>();

  // Step labels
  static const _stepLabels = [
    'Patient Info',
    'Assessment',
    'Treatment',
    'Transport',
    'Signatures',
  ];

  @override
  void initState() {
    super.initState();
    _form = EStreetFormModel();
    _initForm();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _ageCtrl, _addressCtrl, _emergencyContactCtrl,
      _allergiesCtrl, _currentMedsCtrl, _medicalHistoryCtrl,
      _chiefComplaintCtrl, _historyCtrl,
      _bpCtrl, _pulseCtrl, _respiratoryCtrl, _temperatureCtrl,
      _spo2Ctrl, _bloodGlucoseCtrl,
      _medicationsGivenCtrl, _ivFluidsCtrl, _treatmentNotesCtrl,
      _primaryCrewCtrl, _secondaryCrewCtrl,
      _doctorNameCtrl, _licenseNumberCtrl, _physicianReportCtrl,
      _hospitalOtherCtrl, _finalCommentsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Init / Prefill ──────────────────────────────────────

  Future<void> _initForm() async {
    try {
      _apiService = await EStreetApiService.create();

      // Prefill from incident citizen data
      _prefillFromIncident();

      // Try to load existing form from API
      final existing = await _apiService?.fetchForm(widget.incidentId);
      if (existing != null) {
        _form = existing;
      }

      // Merge local images
      final localImages = await EStreetLocalStorage.loadAllImages(widget.incidentId);
      _form.patientSignature ??= localImages['patient_signature'];
      _form.doctorSignature ??= localImages['doctor_signature'];
      _form.responderSignature ??= localImages['responder_signature'];
      _form.bodyDiagramScreenshot ??= localImages['body_diagram_screenshot'];

      _loadFormToControllers();
    } catch (_) {
      // Service creation failure is non-fatal — user can still fill out form
      _prefillFromIncident();
      _loadFormToControllers();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _prefillFromIncident() {
    final data = widget.incidentData;
    if (data == null) return;

    // Try to extract citizen data
    final citizen = data['citizen'] as Map<String, dynamic>?;
    if (citizen != null) {
      _form.name = _str(citizen['first_name'], citizen['middle_name'], citizen['last_name']) ?? _form.name;
      _form.age = citizen['age']?.toString() ?? _form.age;
      _form.sex = citizen['sex']?.toString() ?? _form.sex;
      _form.address = citizen['address']?.toString() ?? _form.address;
    }

    // Incident datetime from created_at
    final createdAt = data['created_at']?.toString();
    if (createdAt != null && _form.incidentDatetime == null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        _form.incidentDatetime = '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}T${_pad(dt.hour)}:${_pad(dt.minute)}';
      } catch (_) {}
    }

    // Try to load existing e_street_form JSON from the incident
    final eStreetJson = data['e_street_form'];
    if (eStreetJson != null && eStreetJson is String && eStreetJson.isNotEmpty) {
      try {
        final parsed = jsonDecode(eStreetJson);
        if (parsed is Map<String, dynamic>) {
          _form = EStreetFormModel.fromJson(parsed);
        }
      } catch (_) {}
    }
  }

  String? _str(dynamic first, dynamic middle, dynamic last) {
    final parts = [first, middle, last]
        .where((p) => p != null && p.toString().trim().isNotEmpty)
        .map((p) => p.toString().trim())
        .toList();
    return parts.isEmpty ? null : parts.join(' ');
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  void _loadFormToControllers() {
    _nameCtrl.text = _form.name;
    _ageCtrl.text = _form.age ?? '';
    _addressCtrl.text = _form.address ?? '';
    _emergencyContactCtrl.text = _form.emergencyContact ?? '';
    _allergiesCtrl.text = _form.allergies ?? '';
    _currentMedsCtrl.text = _form.currentMedications ?? '';
    _medicalHistoryCtrl.text = _form.medicalHistory ?? '';

    _chiefComplaintCtrl.text = _form.chiefComplaint;
    _historyCtrl.text = _form.history ?? '';
    _bpCtrl.text = _form.bloodPressure ?? '';
    _pulseCtrl.text = _form.pulse ?? '';
    _respiratoryCtrl.text = _form.respiratory ?? '';
    _temperatureCtrl.text = _form.temperature ?? '';
    _spo2Ctrl.text = _form.spo2 ?? '';
    _bloodGlucoseCtrl.text = _form.bloodGlucose ?? '';

    _medicationsGivenCtrl.text = _form.medicationsGiven ?? '';
    _ivFluidsCtrl.text = _form.ivFluids ?? '';
    _treatmentNotesCtrl.text = _form.treatmentNotes ?? '';

    _primaryCrewCtrl.text = _form.primaryCrew ?? '';
    _secondaryCrewCtrl.text = _form.secondaryCrew ?? '';
    _doctorNameCtrl.text = _form.doctorName ?? '';
    _licenseNumberCtrl.text = _form.licenseNumber ?? '';
    _physicianReportCtrl.text = _form.physicianReport ?? '';
    _hospitalOtherCtrl.text = _form.hospitalOther ?? '';

    _finalCommentsCtrl.text = _form.finalComments ?? '';
  }

  void _collectFormData() {
    _form.name = _nameCtrl.text.trim();
    _form.age = _emptyNull(_ageCtrl.text);
    _form.address = _emptyNull(_addressCtrl.text);
    _form.emergencyContact = _emptyNull(_emergencyContactCtrl.text);
    _form.allergies = _emptyNull(_allergiesCtrl.text);
    _form.currentMedications = _emptyNull(_currentMedsCtrl.text);
    _form.medicalHistory = _emptyNull(_medicalHistoryCtrl.text);

    _form.chiefComplaint = _chiefComplaintCtrl.text.trim();
    _form.history = _emptyNull(_historyCtrl.text);
    _form.bloodPressure = _emptyNull(_bpCtrl.text);
    _form.pulse = _emptyNull(_pulseCtrl.text);
    _form.respiratory = _emptyNull(_respiratoryCtrl.text);
    _form.temperature = _emptyNull(_temperatureCtrl.text);
    _form.spo2 = _emptyNull(_spo2Ctrl.text);
    _form.bloodGlucose = _emptyNull(_bloodGlucoseCtrl.text);

    _form.medicationsGiven = _emptyNull(_medicationsGivenCtrl.text);
    _form.ivFluids = _emptyNull(_ivFluidsCtrl.text);
    _form.treatmentNotes = _emptyNull(_treatmentNotesCtrl.text);

    _form.primaryCrew = _emptyNull(_primaryCrewCtrl.text);
    _form.secondaryCrew = _emptyNull(_secondaryCrewCtrl.text);
    _form.doctorName = _emptyNull(_doctorNameCtrl.text);
    _form.licenseNumber = _emptyNull(_licenseNumberCtrl.text);
    _form.physicianReport = _emptyNull(_physicianReportCtrl.text);
    _form.hospitalOther = _emptyNull(_hospitalOtherCtrl.text);

    _form.finalComments = _emptyNull(_finalCommentsCtrl.text);
  }

  String? _emptyNull(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  // ── Validation ──────────────────────────────────────────

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Patient Info — name required
        if (_nameCtrl.text.trim().isEmpty) {
          _showError('Please enter the patient name');
          return false;
        }
        return true;
      case 1: // Assessment — chief complaint required
        if (_chiefComplaintCtrl.text.trim().isEmpty) {
          _showError('Please enter the chief complaint');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  // ── Navigation ──────────────────────────────────────────

  void _next() {
    if (!_validateCurrentStep()) return;
    _collectFormData();
    if (_currentStep < 4) {
      setState(() => _currentStep++);
    }
  }

  void _previous() {
    _collectFormData();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // ── Submit ──────────────────────────────────────────────

  Future<void> _submitForm() async {
    if (!_validateCurrentStep()) return;
    _collectFormData();

    setState(() => _isSubmitting = true);

    try {
      // Export signatures
      _form.patientSignature =
          await _patientSigKey.currentState?.exportBase64() ?? _form.patientSignature;
      _form.doctorSignature =
          await _doctorSigKey.currentState?.exportBase64() ?? _form.doctorSignature;
      _form.responderSignature =
          await _responderSigKey.currentState?.exportBase64() ?? _form.responderSignature;

      // Capture body diagram screenshot
      _form.bodyDiagramScreenshot =
          await _bodyDiagramKey.currentState?.exportAsBase64() ?? _form.bodyDiagramScreenshot;

      // Save images locally
      await EStreetLocalStorage.saveAllImages(
        incidentId: widget.incidentId,
        patientSignature: _form.patientSignature,
        doctorSignature: _form.doctorSignature,
        responderSignature: _form.responderSignature,
        bodyDiagramScreenshot: _form.bodyDiagramScreenshot,
      );

      // Submit to API
      if (_apiService == null) {
        _apiService = await EStreetApiService.create();
      }

      final result = await _apiService!.submitForm(
        incidentId: widget.incidentId,
        form: _form,
      );

      if (!mounted) return;

      final pdfUrl = result['pdf_url'] as String?;

      // Show success
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Form Submitted'),
          content: Text(
            pdfUrl != null
                ? 'E-Street Form submitted successfully.\nPDF has been generated.'
                : 'E-Street Form submitted successfully.',
          ),
          actions: [
            if (pdfUrl != null)
              TextButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('View PDF'),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewerScreen(pdfUrl: pdfUrl),
                    ),
                  );
                },
              ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Submission failed: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Time / Date Pickers ─────────────────────────────────

  Future<void> _pickDate({
    required String label,
    String? initialValue,
    required ValueChanged<String> onPicked,
  }) async {
    DateTime initial = DateTime.now();
    if (initialValue != null && initialValue.isNotEmpty) {
      try { initial = DateTime.parse(initialValue); } catch (_) {}
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      onPicked('${date.year}-${_pad(date.month)}-${_pad(date.day)}');
    }
  }

  Future<void> _pickDateTime({
    String? initialValue,
    required ValueChanged<String> onPicked,
  }) async {
    DateTime initial = DateTime.now();
    if (initialValue != null && initialValue.isNotEmpty) {
      try { initial = DateTime.parse(initialValue); } catch (_) {}
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    onPicked('${date.year}-${_pad(date.month)}-${_pad(date.day)}T${_pad(time.hour)}:${_pad(time.minute)}');
  }

  Future<void> _pickTime({
    String? initialValue,
    required ValueChanged<String> onPicked,
  }) async {
    TimeOfDay initial = TimeOfDay.now();
    if (initialValue != null && initialValue.isNotEmpty) {
      try {
        final parts = initialValue.split(':');
        initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }

    final time = await showTimePicker(context: context, initialTime: initial);
    if (time != null) {
      onPicked('${_pad(time.hour)}:${_pad(time.minute)}');
    }
  }

  // ── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Street Form'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildCurrentStep(),
                  ),
                ),
                _buildNavButtons(),
              ],
            ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: AppColors.primary.withOpacity(0.06),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: List.generate(_stepLabels.length, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (i < _currentStep) {
                  _collectFormData();
                  setState(() => _currentStep = i);
                }
              },
              child: Column(
                children: [
                  Row(
                    children: [
                      if (i > 0)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isDone || isActive
                                ? AppColors.primary
                                : Colors.grey.shade300,
                          ),
                        ),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isActive
                            ? AppColors.primary
                            : isDone
                                ? AppColors.success
                                : Colors.grey.shade300,
                        child: isDone
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isActive ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      if (i < _stepLabels.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isDone
                                ? AppColors.primary
                                : Colors.grey.shade300,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stepLabels[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? AppColors.primary : Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previous,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _currentStep < 4
                ? FilledButton.icon(
                    onPressed: _next,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text('Next: ${_stepLabels[_currentStep + 1]}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitForm,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(_isSubmitting ? 'Submitting…' : 'Submit Form'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildStep0PatientInfo();
      case 1: return _buildStep1Assessment();
      case 2: return _buildStep2Treatment();
      case 3: return _buildStep3Transport();
      case 4: return _buildStep4Signatures();
      default: return const SizedBox.shrink();
    }
  }

  // ══════════════════════════════════════════════════════════
  // STEP 0 — PATIENT INFORMATION
  // ══════════════════════════════════════════════════════════

  Widget _buildStep0PatientInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('Patient Information', Icons.person),

        // Recall citizen info button
        if (widget.incidentData?['citizen'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () {
                final citizen = widget.incidentData!['citizen'] as Map<String, dynamic>;
                setState(() {
                  _nameCtrl.text = _str(citizen['first_name'], citizen['middle_name'], citizen['last_name']) ?? '';
                  _ageCtrl.text = citizen['age']?.toString() ?? '';
                  _form.sex = citizen['sex']?.toString();
                  _addressCtrl.text = citizen['address']?.toString() ?? '';
                });
              },
              icon: const Icon(Icons.person_pin, size: 16),
              label: const Text('Recall Citizen Info', style: TextStyle(fontSize: 12)),
            ),
          ),

        _textField(_nameCtrl, 'Full Name *', icon: Icons.person),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(child: _textField(_ageCtrl, 'Age', icon: Icons.cake, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _form.sex,
                decoration: _inputDeco('Sex', icon: Icons.wc),
                items: EStreetFormModel.sexOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _form.sex = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _textField(_addressCtrl, 'Address', icon: Icons.location_on, maxLines: 2),
        const SizedBox(height: 12),

        // Date of Birth
        _dateTile(
          label: 'Date of Birth',
          value: _form.dateOfBirth,
          icon: Icons.calendar_today,
          onTap: () => _pickDate(
            label: 'Date of Birth',
            initialValue: _form.dateOfBirth,
            onPicked: (v) => setState(() => _form.dateOfBirth = v),
          ),
        ),
        const SizedBox(height: 12),

        // Incident DateTime
        _dateTile(
          label: 'Incident Date/Time',
          value: _form.incidentDatetime,
          icon: Icons.access_time,
          onTap: () => _pickDateTime(
            initialValue: _form.incidentDatetime,
            onPicked: (v) => setState(() => _form.incidentDatetime = v),
          ),
        ),
        const SizedBox(height: 12),

        _textField(_emergencyContactCtrl, 'Emergency Contact', icon: Icons.phone),
        const SizedBox(height: 12),
        _textField(_allergiesCtrl, 'Allergies', icon: Icons.warning_amber, maxLines: 2),
        const SizedBox(height: 12),
        _textField(_currentMedsCtrl, 'Current Medications', icon: Icons.medication, maxLines: 2),
        const SizedBox(height: 12),
        _textField(_medicalHistoryCtrl, 'Medical History', icon: Icons.history, maxLines: 2),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 1 — MEDICAL ASSESSMENT
  // ══════════════════════════════════════════════════════════

  Widget _buildStep1Assessment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('Medical Assessment', Icons.medical_services),

        _textField(_chiefComplaintCtrl, 'Chief Complaint *', icon: Icons.report_problem, maxLines: 2),
        const SizedBox(height: 12),
        _textField(_historyCtrl, 'History of Present Illness', icon: Icons.description, maxLines: 2),
        const SizedBox(height: 16),

        // Pain Scale
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _form.painScale,
                decoration: _inputDeco('Pain Scale (0-10)', icon: Icons.sentiment_very_dissatisfied),
                items: List.generate(11, (i) => DropdownMenuItem(value: i, child: Text('$i'))),
                onChanged: (v) => setState(() => _form.painScale = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _form.consciousnessLevel,
                decoration: _inputDeco('AVPU', icon: Icons.psychology),
                items: EStreetFormModel.consciousnessLevels
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _form.consciousnessLevel = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // GCS
        GcsSelector(
          eye: _form.gcsEye,
          verbal: _form.gcsVerbal,
          motor: _form.gcsMotor,
          onEyeChanged: (v) => setState(() => _form.gcsEye = v),
          onVerbalChanged: (v) => setState(() => _form.gcsVerbal = v),
          onMotorChanged: (v) => setState(() => _form.gcsMotor = v),
        ),
        const SizedBox(height: 16),

        // Vital Signs
        VitalSignsSection(
          bpController: _bpCtrl,
          pulseController: _pulseCtrl,
          respiratoryController: _respiratoryCtrl,
          temperatureController: _temperatureCtrl,
          spo2Controller: _spo2Ctrl,
          bloodGlucoseController: _bloodGlucoseCtrl,
        ),
        const SizedBox(height: 16),

        // Pupils
        DropdownButtonFormField<String>(
          value: _form.pupils,
          decoration: _inputDeco('Pupils', icon: Icons.visibility),
          items: EStreetFormModel.pupilOptions
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _form.pupils = v),
        ),
        const SizedBox(height: 16),

        // Skin Assessment
        MultiSelectChips(
          label: 'Skin Assessment',
          options: EStreetFormModel.skinOptions,
          selected: _form.skin,
          onChanged: (v) => setState(() => _form.skin = v),
        ),
        const SizedBox(height: 20),

        // Body Diagram
        EStreetBodyDiagramWidget(
          key: _bodyDiagramKey,
          observations: _form.bodyObservations,
          onObservationsChanged: (obs) {
            setState(() => _form.bodyObservations = obs);
          },
        ),
        const SizedBox(height: 12),

        // Observations List
        BodyObservationsList(
          observations: _form.bodyObservations,
          onChanged: (obs) => setState(() => _form.bodyObservations = obs),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 2 — TREATMENT
  // ══════════════════════════════════════════════════════════

  Widget _buildStep2Treatment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('Treatment & Interventions', Icons.healing),

        MultiSelectChips(
          label: 'Aid Provided',
          options: EStreetFormModel.aidOptions,
          selected: _form.aid,
          onChanged: (v) => setState(() => _form.aid = v),
        ),
        const SizedBox(height: 16),

        _textField(_medicationsGivenCtrl, 'Medications Given', icon: Icons.medication, maxLines: 2),
        const SizedBox(height: 12),
        _textField(_ivFluidsCtrl, 'IV Fluids', icon: Icons.water_drop),
        const SizedBox(height: 16),

        MultiSelectChips(
          label: 'Equipment Used',
          options: EStreetFormModel.equipmentOptions,
          selected: _form.equipment,
          onChanged: (v) => setState(() => _form.equipment = v),
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: _form.treatmentResponse,
          decoration: _inputDeco('Treatment Response', icon: Icons.trending_up),
          items: EStreetFormModel.treatmentResponseOptions
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _form.treatmentResponse = v),
        ),
        const SizedBox(height: 12),

        _textField(_treatmentNotesCtrl, 'Treatment Notes', icon: Icons.notes, maxLines: 3),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 3 — TRANSPORT & OUTCOME
  // ══════════════════════════════════════════════════════════

  Widget _buildStep3Transport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('Transport & Outcome', Icons.local_shipping),

        // Time pickers
        const Text('Response Times', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _timeTile('Time Called', _form.timeCalled, (v) => setState(() => _form.timeCalled = v)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _timeTile('Arrived Scene', _form.timeArrivedScene, (v) => setState(() => _form.timeArrivedScene = v)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _timeTile('Departed Scene', _form.timeDepartedScene, (v) => setState(() => _form.timeDepartedScene = v)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _timeTile('At Hospital', _form.timeArrivedHospital, (v) => setState(() => _form.timeArrivedHospital = v)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        MultiSelectChips(
          label: 'Ambulance Type',
          options: EStreetFormModel.ambulanceTypeOptions,
          selected: _form.ambulanceType,
          onChanged: (v) => setState(() => _form.ambulanceType = v),
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: _form.transportMethod,
          decoration: _inputDeco('Transport Method', icon: Icons.transfer_within_a_station),
          items: EStreetFormModel.transportMethodOptions
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _form.transportMethod = v),
        ),
        const SizedBox(height: 16),

        // Hospital Dropdown
        DropdownButtonFormField<String>(
          value: _form.hospital,
          decoration: _inputDeco('Hospital', icon: Icons.local_hospital),
          isExpanded: true,
          items: [
            ...EStreetFormModel.hospitalOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))),
            const DropdownMenuItem(value: 'OTHER', child: Text('OTHER (specify below)')),
          ],
          onChanged: (v) => setState(() => _form.hospital = v),
        ),
        if (_form.hospital == 'OTHER') ...[
          const SizedBox(height: 8),
          _textField(_hospitalOtherCtrl, 'Specify Hospital', icon: Icons.edit),
        ],
        const SizedBox(height: 16),

        MultiSelectChips(
          label: 'Passengers',
          options: EStreetFormModel.passengerOptions,
          selected: _form.passenger,
          onChanged: (v) => setState(() => _form.passenger = v),
        ),
        const SizedBox(height: 16),

        _textField(_primaryCrewCtrl, 'Primary Crew', icon: Icons.person),
        const SizedBox(height: 12),
        _textField(_secondaryCrewCtrl, 'Secondary Crew', icon: Icons.person_outline),
        const SizedBox(height: 16),

        // Final Outcome — radio
        const Text('Final Outcome', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ...EStreetFormModel.finalOutcomeOptions.map((option) {
          return RadioListTile<String>(
            title: Text(option, style: const TextStyle(fontSize: 14)),
            value: option,
            groupValue: _form.finalOutcome,
            onChanged: (v) => setState(() => _form.finalOutcome = v),
            contentPadding: EdgeInsets.zero,
            dense: true,
          );
        }),
        const SizedBox(height: 16),

        // Receiving Physician
        _sectionDivider('Receiving Physician'),
        _textField(_doctorNameCtrl, 'Doctor Name', icon: Icons.medical_information),
        const SizedBox(height: 12),
        _textField(_licenseNumberCtrl, 'License Number', icon: Icons.badge),
        const SizedBox(height: 12),
        _textField(_physicianReportCtrl, 'Physician Report', icon: Icons.description, maxLines: 3),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 4 — SIGNATURES & SUBMIT
  // ══════════════════════════════════════════════════════════

  Widget _buildStep4Signatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('Signatures & Final', Icons.draw),

        SignaturePadWidget(
          key: _patientSigKey,
          label: 'Patient Signature',
          initialData: _form.patientSignature,
        ),
        const SizedBox(height: 20),

        SignaturePadWidget(
          key: _doctorSigKey,
          label: 'Doctor Signature',
          initialData: _form.doctorSignature,
        ),
        const SizedBox(height: 20),

        SignaturePadWidget(
          key: _responderSigKey,
          label: 'Responder Signature',
          initialData: _form.responderSignature,
        ),
        const SizedBox(height: 20),

        _textField(_finalCommentsCtrl, 'Final Comments', icon: Icons.comment, maxLines: 3),
        const SizedBox(height: 24),

        // Summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'All fields are optional. Submit what you have — '
                  'the form can be updated later.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared UI Helpers ───────────────────────────────────

  Widget _stepHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _sectionDivider(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(title,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _inputDeco(label, icon: icon),
    );
  }

  InputDecoration _inputDeco(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 18) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      isDense: true,
    );
  }

  Widget _dateTile({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _inputDeco(label, icon: icon),
        child: Text(
          value ?? 'Tap to select',
          style: TextStyle(
            color: value != null ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _timeTile(String label, String? value, ValueChanged<String> onPicked) {
    return InkWell(
      onTap: () => _pickTime(initialValue: value, onPicked: onPicked),
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time, size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
        ),
        child: Text(
          value ?? '—',
          style: TextStyle(color: value != null ? Colors.black : Colors.grey),
        ),
      ),
    );
  }
}
