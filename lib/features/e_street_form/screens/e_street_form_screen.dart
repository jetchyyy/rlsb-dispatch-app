import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/e_street_form_model.dart';
import '../services/e_street_form_service.dart';
import '../services/e_street_local_storage.dart';
import '../widgets/body_diagram_widget.dart';
import '../widgets/body_observations_list.dart';
import '../widgets/gcs_selector.dart';
import '../widgets/multi_select_chips.dart';
import '../widgets/signature_pad_widget.dart';
import '../widgets/vital_signs_section.dart';

/// 5-step wizard for the E-Street pre-hospital care form.
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
  bool _isSubmitting = false;
  bool _isLoading = true;
  late EStreetFormModel _form;
  EStreetFormService? _service;

  // ── Step 1 Controllers ──
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyContactCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _medicalHistoryCtrl = TextEditingController();
  String? _selectedSex;
  DateTime? _dob;
  DateTime? _incidentDateTime;

  // ── Step 2 Controllers ──
  final _chiefComplaintCtrl = TextEditingController();
  final _historyCtrl = TextEditingController();
  int? _painScale;
  String? _consciousnessLevel;
  int? _gcsEye, _gcsVerbal, _gcsMotor;
  final _bpCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _respCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _glucoseCtrl = TextEditingController();
  String? _pupils;
  List<String> _skin = [];

  // ── Step 3 Controllers ──
  List<String> _aid = [];
  List<String> _equipment = [];
  final _medicationsGivenCtrl = TextEditingController();
  final _ivFluidsCtrl = TextEditingController();
  String? _treatmentResponse;
  final _treatmentNotesCtrl = TextEditingController();

  // ── Step 4 Controllers ──
  TimeOfDay? _timeCalled;
  TimeOfDay? _timeArrivedScene;
  TimeOfDay? _timeDepartedScene;
  TimeOfDay? _timeArrivedHospital;
  List<String> _ambulanceType = [];
  String? _transportMethod;
  String? _hospital;
  final _hospitalOtherCtrl = TextEditingController();
  List<String> _passenger = [];
  final _primaryCrewCtrl = TextEditingController();
  final _secondaryCrewCtrl = TextEditingController();
  String? _finalOutcome;
  final _doctorNameCtrl = TextEditingController();
  final _licenseNumberCtrl = TextEditingController();
  final _physicianReportCtrl = TextEditingController();

  // ── Step 5 Controllers ──
  final _finalCommentsCtrl = TextEditingController();
  final _patientSigKey = GlobalKey<SignaturePadWidgetState>();
  final _doctorSigKey = GlobalKey<SignaturePadWidgetState>();
  final _responderSigKey = GlobalKey<SignaturePadWidgetState>();
  final _bodyDiagramKey = GlobalKey<EStreetBodyDiagramWidgetState>();

  // ── Body observations ──
  Map<String, String> _bodyObservations = {};

  // ── Form key ──
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _form = EStreetFormModel();
    _initForm();
  }

  Future<void> _initForm() async {
    try {
      _service = await EStreetFormService.create();

      // Pre-fill from incident data
      _prefillFromIncident();

      // Try to load existing form
      final existing = await _service!.fetchForm(widget.incidentId);
      if (existing != null) {
        _form = existing;
        _loadFormToControllers();
      }
    } catch (_) {
      // Ignore — we just start with a blank form
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prefillFromIncident() {
    final data = widget.incidentData;
    if (data == null) return;

    _form.incidentNumber = data['incident_number']?.toString();

    // Incident datetime
    final datetime = data['incident_datetime'] ?? data['created_at'];
    if (datetime != null) {
      _form.incidentDatetime = datetime.toString();
      try {
        _incidentDateTime = DateTime.parse(datetime.toString());
      } catch (_) {}
    }

    // Citizen info
    final citizen = data['citizen'];
    if (citizen is Map<String, dynamic>) {
      final fname = citizen['first_name']?.toString() ?? '';
      final lname = citizen['last_name']?.toString() ?? '';
      if (fname.isNotEmpty || lname.isNotEmpty) {
        _nameCtrl.text = '$fname $lname'.trim();
      }
      _addressCtrl.text = citizen['address']?.toString() ?? '';
      _emergencyContactCtrl.text = citizen['emergency_contact']?.toString() ?? '';
      if (citizen['date_of_birth'] != null) {
        try {
          _dob = DateTime.parse(citizen['date_of_birth'].toString());
          _ageCtrl.text = _calcAge(_dob!);
        } catch (_) {}
      }
      if (citizen['sex'] != null) {
        _selectedSex = citizen['sex'].toString();
      }
    }

    // E-Street form data already on incident?
    final eStreetRaw = data['e_street_form'];
    if (eStreetRaw != null) {
      Map<String, dynamic>? eStreet;
      if (eStreetRaw is String) {
        try {
          eStreet = jsonDecode(eStreetRaw) as Map<String, dynamic>;
        } catch (_) {}
      } else if (eStreetRaw is Map<String, dynamic>) {
        eStreet = eStreetRaw;
      }
      if (eStreet != null && eStreet.isNotEmpty) {
        _form = EStreetFormModel.fromJson(eStreet);
        _loadFormToControllers();
      }
    }
  }

  void _loadFormToControllers() {
    _nameCtrl.text = _form.name;
    _ageCtrl.text = _form.age ?? '';
    _selectedSex = _form.sex;
    _addressCtrl.text = _form.address ?? '';
    _emergencyContactCtrl.text = _form.emergencyContact ?? '';
    _allergiesCtrl.text = _form.allergies ?? '';
    _medicationsCtrl.text = _form.currentMedications ?? '';
    _medicalHistoryCtrl.text = _form.medicalHistory ?? '';
    if (_form.dateOfBirth != null) {
      try {
        _dob = DateTime.parse(_form.dateOfBirth!);
      } catch (_) {}
    }
    if (_form.incidentDatetime != null) {
      try {
        _incidentDateTime = DateTime.parse(_form.incidentDatetime!);
      } catch (_) {}
    }

    _chiefComplaintCtrl.text = _form.chiefComplaint;
    _historyCtrl.text = _form.history ?? '';
    _painScale = _form.painScale;
    _consciousnessLevel = _form.consciousnessLevel;
    _gcsEye = _form.gcsEye;
    _gcsVerbal = _form.gcsVerbal;
    _gcsMotor = _form.gcsMotor;
    _bpCtrl.text = _form.bloodPressure ?? '';
    _pulseCtrl.text = _form.pulse ?? '';
    _respCtrl.text = _form.respiratory ?? '';
    _tempCtrl.text = _form.temperature ?? '';
    _spo2Ctrl.text = _form.spo2 ?? '';
    _glucoseCtrl.text = _form.bloodGlucose ?? '';
    _pupils = _form.pupils;
    _skin = List<String>.from(_form.skin);

    _aid = List<String>.from(_form.aid);
    _equipment = List<String>.from(_form.equipment);
    _medicationsGivenCtrl.text = _form.medicationsGiven ?? '';
    _ivFluidsCtrl.text = _form.ivFluids ?? '';
    _treatmentResponse = _form.treatmentResponse;
    _treatmentNotesCtrl.text = _form.treatmentNotes ?? '';

    _timeCalled = _parseTime(_form.timeCalled);
    _timeArrivedScene = _parseTime(_form.timeArrivedScene);
    _timeDepartedScene = _parseTime(_form.timeDepartedScene);
    _timeArrivedHospital = _parseTime(_form.timeArrivedHospital);
    _ambulanceType = List<String>.from(_form.ambulanceType);
    _transportMethod = _form.transportMethod;
    _hospital = _form.hospital;
    _hospitalOtherCtrl.text = _form.hospitalOther ?? '';
    _passenger = List<String>.from(_form.passenger);
    _primaryCrewCtrl.text = _form.primaryCrew ?? '';
    _secondaryCrewCtrl.text = _form.secondaryCrew ?? '';
    _finalOutcome = _form.finalOutcome;
    _doctorNameCtrl.text = _form.doctorName ?? '';
    _licenseNumberCtrl.text = _form.licenseNumber ?? '';
    _physicianReportCtrl.text = _form.physicianReport ?? '';

    _finalCommentsCtrl.text = _form.finalComments ?? '';
    _bodyObservations = Map<String, String>.from(_form.bodyObservations);
  }

  String _calcAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age.toString();
  }

  /// Capture body diagram screenshot and store in form
  Future<void> _captureBodyDiagramScreenshot() async {
    try {
      // Wait a bit for the UI to update
      await Future.delayed(const Duration(milliseconds: 300));
      
      final screenshot = await _bodyDiagramKey.currentState?.exportAsBase64();
      if (screenshot != null) {
        _form.bodyDiagramScreenshot = screenshot;
        print('📸 Body diagram screenshot captured: ${screenshot.length} chars');
        
        // Show brief feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Body diagram captured'),
                ],
              ),
              backgroundColor: Color(0xFF28A745),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        print('⚠️ Failed to capture body diagram screenshot');
      }
    } catch (e) {
      print('❌ Error capturing body diagram: $e');
    }
  }

  TimeOfDay? _parseTime(String? val) {
    if (val == null || val.isEmpty) return null;
    final parts = val.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return null;
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _collectFormData() {
    _form.name = _nameCtrl.text.trim();
    _form.age = _ageCtrl.text.trim().isEmpty ? null : _ageCtrl.text.trim();
    _form.sex = _selectedSex;
    _form.address =
        _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim();
    _form.emergencyContact = _emergencyContactCtrl.text.trim().isEmpty
        ? null
        : _emergencyContactCtrl.text.trim();
    _form.dateOfBirth = _dob != null
        ? DateFormat('yyyy-MM-dd').format(_dob!)
        : null;
    _form.incidentDatetime = _incidentDateTime != null
        ? DateFormat("yyyy-MM-dd'T'HH:mm").format(_incidentDateTime!)
        : null;
    _form.allergies =
        _allergiesCtrl.text.trim().isEmpty ? null : _allergiesCtrl.text.trim();
    _form.currentMedications = _medicationsCtrl.text.trim().isEmpty
        ? null
        : _medicationsCtrl.text.trim();
    _form.medicalHistory = _medicalHistoryCtrl.text.trim().isEmpty
        ? null
        : _medicalHistoryCtrl.text.trim();

    _form.chiefComplaint = _chiefComplaintCtrl.text.trim();
    _form.history =
        _historyCtrl.text.trim().isEmpty ? null : _historyCtrl.text.trim();
    _form.painScale = _painScale;
    _form.consciousnessLevel = _consciousnessLevel;
    _form.gcsEye = _gcsEye;
    _form.gcsVerbal = _gcsVerbal;
    _form.gcsMotor = _gcsMotor;
    _form.bloodPressure =
        _bpCtrl.text.trim().isEmpty ? null : _bpCtrl.text.trim();
    _form.pulse =
        _pulseCtrl.text.trim().isEmpty ? null : _pulseCtrl.text.trim();
    _form.respiratory =
        _respCtrl.text.trim().isEmpty ? null : _respCtrl.text.trim();
    _form.temperature =
        _tempCtrl.text.trim().isEmpty ? null : _tempCtrl.text.trim();
    _form.spo2 =
        _spo2Ctrl.text.trim().isEmpty ? null : _spo2Ctrl.text.trim();
    _form.bloodGlucose =
        _glucoseCtrl.text.trim().isEmpty ? null : _glucoseCtrl.text.trim();
    _form.pupils = _pupils;
    _form.skin = _skin;

    _form.aid = _aid;
    _form.equipment = _equipment;
    _form.medicationsGiven = _medicationsGivenCtrl.text.trim().isEmpty
        ? null
        : _medicationsGivenCtrl.text.trim();
    _form.ivFluids =
        _ivFluidsCtrl.text.trim().isEmpty ? null : _ivFluidsCtrl.text.trim();
    _form.treatmentResponse = _treatmentResponse;
    _form.treatmentNotes = _treatmentNotesCtrl.text.trim().isEmpty
        ? null
        : _treatmentNotesCtrl.text.trim();

    _form.timeCalled = _formatTime(_timeCalled);
    _form.timeArrivedScene = _formatTime(_timeArrivedScene);
    _form.timeDepartedScene = _formatTime(_timeDepartedScene);
    _form.timeArrivedHospital = _formatTime(_timeArrivedHospital);
    _form.ambulanceType = _ambulanceType;
    _form.transportMethod = _transportMethod;
    _form.hospital = _hospital == 'OTHER' ? null : _hospital;
    _form.hospitalOther = _hospital == 'OTHER'
        ? _hospitalOtherCtrl.text.trim()
        : null;
    _form.passenger = _passenger;
    _form.primaryCrew = _primaryCrewCtrl.text.trim().isEmpty
        ? null
        : _primaryCrewCtrl.text.trim();
    _form.secondaryCrew = _secondaryCrewCtrl.text.trim().isEmpty
        ? null
        : _secondaryCrewCtrl.text.trim();
    _form.finalOutcome = _finalOutcome;
    _form.doctorName = _doctorNameCtrl.text.trim().isEmpty
        ? null
        : _doctorNameCtrl.text.trim();
    _form.licenseNumber = _licenseNumberCtrl.text.trim().isEmpty
        ? null
        : _licenseNumberCtrl.text.trim();
    _form.physicianReport = _physicianReportCtrl.text.trim().isEmpty
        ? null
        : _physicianReportCtrl.text.trim();

    _form.finalComments = _finalCommentsCtrl.text.trim().isEmpty
        ? null
        : _finalCommentsCtrl.text.trim();
    _form.bodyObservations = _bodyObservations;
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nameCtrl.text.trim().isEmpty) {
          _showError('Patient name is required');
          return false;
        }
        return true;
      case 1:
        if (_chiefComplaintCtrl.text.trim().isEmpty) {
          _showError('Chief complaint is required');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 4) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitForm() async {
    if (!_validateCurrentStep()) return;

    _collectFormData();

    if (_form.name.isEmpty) {
      _showError('Patient name is required (Step 1)');
      return;
    }
    if (_form.chiefComplaint.isEmpty) {
      _showError('Chief complaint is required (Step 2)');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Export signatures
      _form.patientSignature = await _patientSigKey.currentState?.exportBase64();
      _form.doctorSignature = await _doctorSigKey.currentState?.exportBase64();
      _form.responderSignature =
          await _responderSigKey.currentState?.exportBase64();

      // Ensure body diagram screenshot is captured (should already be done on changes)
      if (_form.bodyDiagramScreenshot == null && _bodyObservations.isNotEmpty) {
        print('📸 Capturing body diagram screenshot before submit...');
        await _captureBodyDiagramScreenshot();
      }
      
      print('📋 Form submission - Body diagram: ${_form.bodyDiagramScreenshot != null ? "${_form.bodyDiagramScreenshot!.length} chars" : "NULL"}');

      // Save signatures & body diagram locally before submitting
      // (API may not store large base64 data)
      await EStreetLocalStorage.saveAllImages(
        incidentId: widget.incidentId,
        patientSignature: _form.patientSignature,
        doctorSignature: _form.doctorSignature,
        responderSignature: _form.responderSignature,
        bodyDiagramScreenshot: _form.bodyDiagramScreenshot,
        bodyObservations: _form.bodyObservations,
      );

      final result = await _service!.submitForm(
        incidentId: widget.incidentId,
        form: _form,
      );

      if (!mounted) return;

      final pdfUrl = result['pdf_url'] as String?;
      final msg = pdfUrl != null
          ? 'E-Street Form submitted! PDF generated.'
          : 'E-Street Form submitted successfully!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF28A745),
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final errMsg = e.response?.data?['message']?.toString() ??
          'Failed to submit form. Please try again.';
      _showError(errMsg);
    } catch (e) {
      if (!mounted) return;
      _showError('An error occurred: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyContactCtrl.dispose();
    _allergiesCtrl.dispose();
    _medicationsCtrl.dispose();
    _medicalHistoryCtrl.dispose();
    _chiefComplaintCtrl.dispose();
    _historyCtrl.dispose();
    _bpCtrl.dispose();
    _pulseCtrl.dispose();
    _respCtrl.dispose();
    _tempCtrl.dispose();
    _spo2Ctrl.dispose();
    _glucoseCtrl.dispose();
    _medicationsGivenCtrl.dispose();
    _ivFluidsCtrl.dispose();
    _treatmentNotesCtrl.dispose();
    _hospitalOtherCtrl.dispose();
    _primaryCrewCtrl.dispose();
    _secondaryCrewCtrl.dispose();
    _doctorNameCtrl.dispose();
    _licenseNumberCtrl.dispose();
    _physicianReportCtrl.dispose();
    _finalCommentsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Street Form'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_currentStep == 4)
            TextButton.icon(
              onPressed: _isSubmitting ? null : _submitForm,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 18),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Submit',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Progress bar ──
                _buildProgressBar(),
                // ── Form content ──
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: _buildStepContent(),
                  ),
                ),
                // ── Bottom navigation ──
                _buildBottomNav(),
              ],
            ),
    );
  }

  Widget _buildProgressBar() {
    const stepLabels = [
      'Patient',
      'Assessment',
      'Treatment',
      'Transport',
      'Signatures',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress indicator
          Row(
            children: List.generate(5, (i) {
              final isActive = i == _currentStep;
              final isDone = i < _currentStep;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (i < _currentStep || _validateCurrentStep()) {
                      setState(() => _currentStep = i);
                    }
                  },
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isDone
                              ? const Color(0xFF28A745)
                              : isActive
                                  ? const Color(0xFF1976D2)
                                  : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stepLabels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
                          color: isActive
                              ? const Color(0xFF1976D2)
                              : isDone
                                  ? const Color(0xFF28A745)
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: _prevStep,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
            ),
          const Spacer(),
          Text(
            'Step ${_currentStep + 1} of 5',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const Spacer(),
          if (_currentStep < 4)
            FilledButton.icon(
              onPressed: _nextStep,
              icon: const Text('Next'),
              label: const Icon(Icons.arrow_forward, size: 18),
            )
          else
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitForm,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 18),
              label: Text(_isSubmitting ? 'Submitting...' : 'Submit Form'),
            ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      case 4:
        return _buildStep5();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 1: Patient Information
  // ═══════════════════════════════════════════════════════════
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('Patient Information', Icons.person),
          const SizedBox(height: 12),

          // Recall & Clear buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _recallCitizenInfo,
                  icon: const Icon(Icons.person_search, size: 18),
                  label: const Text('Recall Citizen Info',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _clearStep1,
                icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                label: const Text('Clear',
                    style: TextStyle(fontSize: 12, color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name (required)
          TextFormField(
            controller: _nameCtrl,
            decoration: _inputDeco('Full Name *', Icons.person_outline),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),

          // DOB + Age
          Row(
            children: [
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _dob ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _dob = picked;
                        _ageCtrl.text = _calcAge(picked);
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: _inputDeco('Date of Birth', Icons.cake),
                    child: Text(
                      _dob != null
                          ? DateFormat('MMM dd, yyyy').format(_dob!)
                          : 'Select',
                      style: TextStyle(
                          color: _dob != null ? null : Colors.grey,
                          fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ageCtrl,
                  decoration: _inputDeco('Age', Icons.numbers),
                  keyboardType: TextInputType.number,
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sex
          DropdownButtonFormField<String>(
            value: _selectedSex,
            decoration: _inputDeco('Sex', Icons.wc),
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _selectedSex = v),
          ),
          const SizedBox(height: 12),

          // Address
          TextField(
            controller: _addressCtrl,
            decoration: _inputDeco('Address', Icons.home),
            maxLines: 2,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),

          // Emergency Contact
          TextField(
            controller: _emergencyContactCtrl,
            decoration:
                _inputDeco('Emergency Contact (Name & Phone)', Icons.phone),
          ),
          const SizedBox(height: 12),

          // Incident number (read-only)
          if (_form.incidentNumber != null)
            TextField(
              controller: TextEditingController(text: _form.incidentNumber),
              decoration: _inputDeco('Incident Number', Icons.tag),
              readOnly: true,
              enabled: false,
            ),
          const SizedBox(height: 12),

          // Incident DateTime
          InkWell(
            onTap: _pickIncidentDateTime,
            child: InputDecorator(
              decoration:
                  _inputDeco('Incident Date/Time', Icons.calendar_today),
              child: Text(
                _incidentDateTime != null
                    ? DateFormat('MMM dd, yyyy  HH:mm')
                        .format(_incidentDateTime!)
                    : 'Select',
                style: TextStyle(
                    color: _incidentDateTime != null ? null : Colors.grey,
                    fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          _sectionHeader('Medical Background', Icons.medical_information),
          const SizedBox(height: 12),

          TextField(
            controller: _allergiesCtrl,
            decoration: _inputDeco('Allergies', Icons.warning_amber),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _medicationsCtrl,
            decoration: _inputDeco('Current Medications', Icons.medication),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _medicalHistoryCtrl,
            decoration: _inputDeco('Medical History', Icons.history),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  void _recallCitizenInfo() {
    final data = widget.incidentData;
    if (data == null) return;
    final citizen = data['citizen'];
    if (citizen is Map<String, dynamic>) {
      setState(() {
        final fname = citizen['first_name']?.toString() ?? '';
        final lname = citizen['last_name']?.toString() ?? '';
        _nameCtrl.text = '$fname $lname'.trim();
        _addressCtrl.text = citizen['address']?.toString() ?? '';
        _emergencyContactCtrl.text =
            citizen['emergency_contact']?.toString() ?? '';
        if (citizen['sex'] != null) _selectedSex = citizen['sex'].toString();
        if (citizen['date_of_birth'] != null) {
          try {
            _dob = DateTime.parse(citizen['date_of_birth'].toString());
            _ageCtrl.text = _calcAge(_dob!);
          } catch (_) {}
        }
      });
    } else {
      _showError('No citizen info linked to this incident');
    }
  }

  void _clearStep1() {
    setState(() {
      _nameCtrl.clear();
      _ageCtrl.clear();
      _selectedSex = null;
      _dob = null;
      _addressCtrl.clear();
      _emergencyContactCtrl.clear();
      _allergiesCtrl.clear();
      _medicationsCtrl.clear();
      _medicalHistoryCtrl.clear();
    });
  }

  Future<void> _pickIncidentDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _incidentDateTime ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _incidentDateTime != null
          ? TimeOfDay.fromDateTime(_incidentDateTime!)
          : TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _incidentDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 2: Medical Assessment
  // ═══════════════════════════════════════════════════════════
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('Chief Complaint', Icons.report_problem),
          const SizedBox(height: 8),
          TextFormField(
            controller: _chiefComplaintCtrl,
            decoration: _inputDeco(
                'Primary reason for EMS call *', Icons.medical_services),
            maxLines: 3,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _historyCtrl,
            decoration:
                _inputDeco('History of Present Illness', Icons.description),
            maxLines: 3,
          ),

          const SizedBox(height: 20),
          _sectionHeader('Pain & Consciousness', Icons.psychology),
          const SizedBox(height: 8),

          // Pain Scale
          DropdownButtonFormField<int>(
            value: _painScale,
            decoration: _inputDeco('Pain Scale (0-10)', Icons.healing),
            items: List.generate(11, (i) {
              String label = '$i';
              if (i == 0) label = '0 - No Pain';
              else if (i <= 3) label = '$i - Mild';
              else if (i <= 6) label = '$i - Moderate';
              else label = '$i - Severe';
              return DropdownMenuItem(value: i, child: Text(label, style: const TextStyle(fontSize: 13)));
            }),
            onChanged: (v) => setState(() => _painScale = v),
          ),
          const SizedBox(height: 12),

          // AVPU
          DropdownButtonFormField<String>(
            value: _consciousnessLevel,
            decoration:
                _inputDeco('Consciousness Level (AVPU)', Icons.visibility),
            items: const [
              DropdownMenuItem(value: 'Alert', child: Text('Alert')),
              DropdownMenuItem(value: 'Verbal', child: Text('Verbal')),
              DropdownMenuItem(value: 'Pain', child: Text('Pain')),
              DropdownMenuItem(
                  value: 'Unresponsive', child: Text('Unresponsive')),
            ],
            onChanged: (v) => setState(() => _consciousnessLevel = v),
          ),

          const SizedBox(height: 20),
          GcsSelector(
            eye: _gcsEye,
            verbal: _gcsVerbal,
            motor: _gcsMotor,
            onEyeChanged: (v) => setState(() => _gcsEye = v),
            onVerbalChanged: (v) => setState(() => _gcsVerbal = v),
            onMotorChanged: (v) => setState(() => _gcsMotor = v),
          ),

          const SizedBox(height: 20),
          VitalSignsSection(
            bpController: _bpCtrl,
            pulseController: _pulseCtrl,
            respController: _respCtrl,
            tempController: _tempCtrl,
            spo2Controller: _spo2Ctrl,
            glucoseController: _glucoseCtrl,
          ),

          const SizedBox(height: 20),
          MultiSelectChips(
            label: 'Skin Assessment',
            options: const [
              'Normal', 'Pale', 'Cyanotic', 'Flushed',
              'Warm/Dry', 'Cold/Clammy', 'Warm/Moist', 'Cold/Dry',
            ],
            selected: _skin,
            onChanged: (v) => setState(() => _skin = v),
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _pupils,
            decoration: _inputDeco('Pupils', Icons.remove_red_eye),
            items: const [
              DropdownMenuItem(value: 'PEARL', child: Text('PEARL')),
              DropdownMenuItem(value: 'Dilated', child: Text('Dilated')),
              DropdownMenuItem(
                  value: 'Constricted', child: Text('Constricted')),
              DropdownMenuItem(value: 'Unequal', child: Text('Unequal')),
              DropdownMenuItem(
                  value: 'Non-reactive', child: Text('Non-reactive')),
            ],
            onChanged: (v) => setState(() => _pupils = v),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Body Injury Map', Icons.accessibility_new),
          const SizedBox(height: 8),
          EStreetBodyDiagramWidget(
            key: _bodyDiagramKey,
            observations: _bodyObservations,
            onObservationsChanged: (obs) async {
              setState(() => _bodyObservations = obs);
              // Auto-capture screenshot after changes
              await _captureBodyDiagramScreenshot();
            },
          ),
          const SizedBox(height: 12),
          BodyObservationsList(
            observations: _bodyObservations,
            onObservationsChanged: (obs) async {
              setState(() => _bodyObservations = obs);
              // Auto-capture screenshot after changes
              await _captureBodyDiagramScreenshot();
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 3: Treatment & Interventions
  // ═══════════════════════════════════════════════════════════
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('Aid Provided', Icons.healing),
          const SizedBox(height: 8),
          MultiSelectChips(
            label: 'Select all that apply',
            options: const [
              'Oxygen Therapy', 'Bandaging', 'Splinting', 'Spine Board',
              'C-Spine Immobilization', 'IV Access', 'CPR (Successful)',
              'CPR (Unsuccessful)', 'Airway Suction', 'OPA/NPA',
              'Bleeding Control', 'Patient Restrained', 'OB Delivery',
              'Traction Splint', 'AED Used', 'Patient Refused',
            ],
            selected: _aid,
            onChanged: (v) => setState(() => _aid = v),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Medications & Fluids', Icons.medication),
          const SizedBox(height: 8),
          TextField(
            controller: _medicationsGivenCtrl,
            decoration: _inputDeco(
                'Medications Given (drug, dose, time)', Icons.medication),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ivFluidsCtrl,
            decoration:
                _inputDeco('IV Fluids (type & amount)', Icons.water_drop),
            maxLines: 2,
          ),

          const SizedBox(height: 20),
          _sectionHeader('Equipment Used', Icons.build),
          const SizedBox(height: 8),
          MultiSelectChips(
            label: 'Select all that apply',
            options: const [
              'Stretcher', 'Stair Chair', 'Backboard', 'Cervical Collar',
              'KED Board', 'Cardiac Monitor', 'Ventilator', 'Defibrillator',
              'Suction Unit', 'Other',
            ],
            selected: _equipment,
            onChanged: (v) => setState(() => _equipment = v),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Treatment Response', Icons.trending_up),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _treatmentResponse,
            decoration:
                _inputDeco('Patient Response', Icons.swap_vert),
            items: const [
              DropdownMenuItem(value: 'Improved', child: Text('Improved')),
              DropdownMenuItem(value: 'No Change', child: Text('No Change')),
              DropdownMenuItem(
                  value: 'Deteriorated', child: Text('Deteriorated')),
              DropdownMenuItem(
                  value: 'Stabilized', child: Text('Stabilized')),
            ],
            onChanged: (v) => setState(() => _treatmentResponse = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _treatmentNotesCtrl,
            decoration:
                _inputDeco('Treatment Notes', Icons.notes),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 4: Transport & Outcome
  // ═══════════════════════════════════════════════════════════
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('Response Times', Icons.timer),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _timeField('Time Called', _timeCalled, (t) {
                setState(() => _timeCalled = t);
              })),
              const SizedBox(width: 12),
              Expanded(
                  child: _timeField('Arrived Scene', _timeArrivedScene, (t) {
                setState(() => _timeArrivedScene = t);
              })),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _timeField('Departed Scene', _timeDepartedScene, (t) {
                setState(() => _timeDepartedScene = t);
              })),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      _timeField('Arrived Hospital', _timeArrivedHospital, (t) {
                setState(() => _timeArrivedHospital = t);
              })),
            ],
          ),

          const SizedBox(height: 20),
          _sectionHeader('Ambulance & Transport', Icons.local_hospital),
          const SizedBox(height: 8),
          MultiSelectChips(
            label: 'Ambulance Type',
            options: const [
              'Emergency Response Call',
              'Hospital Transfer',
              'Inter-Hospital',
              'Procedural',
            ],
            selected: _ambulanceType,
            onChanged: (v) => setState(() => _ambulanceType = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _transportMethod,
            decoration: _inputDeco('Transport Method', Icons.directions_walk),
            items: const [
              DropdownMenuItem(value: 'Stretcher', child: Text('Stretcher')),
              DropdownMenuItem(value: 'Walking', child: Text('Walking')),
              DropdownMenuItem(
                  value: 'Wheelchair', child: Text('Wheelchair')),
              DropdownMenuItem(value: 'Carried', child: Text('Carried')),
            ],
            onChanged: (v) => setState(() => _transportMethod = v),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Destination Hospital', Icons.local_hospital),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _hospital,
            isExpanded: true,
            decoration: _inputDeco('Hospital', Icons.business),
            items: const [
              DropdownMenuItem(
                value: 'Surigao del Norte Provincial Hospital (SDNPH)',
                child: Text('SDNPH', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'Gigaquit Municipal Hospital',
                child: Text('Gigaquit Municipal Hospital',
                    style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'Mainit Medicare Community Hospital',
                child: Text('Mainit Medicare', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'Malimono District Hospital',
                child:
                    Text('Malimono District', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'Del Carmen District Hospital',
                child: Text('Del Carmen District',
                    style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'Pilar District Hospital',
                child: Text('Pilar District', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'Socorro District Hospital',
                child:
                    Text('Socorro District', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'Sta. Monica District Hospital',
                child: Text('Sta. Monica District',
                    style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'Surigao Doctors\' Hospital',
                child: Text('Surigao Doctors\'',
                    style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'Saint Paul University Hospital',
                child:
                    Text('Saint Paul University', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'Surigao Medical Center',
                child: Text('Surigao Medical Center',
                    style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'CARAGA Regional Hospital',
                child: Text('CARAGA Regional', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'OTHER',
                child: Text('OTHER', style: TextStyle(fontSize: 13)),
              ),
            ],
            onChanged: (v) => setState(() => _hospital = v),
          ),
          if (_hospital == 'OTHER') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _hospitalOtherCtrl,
              decoration:
                  _inputDeco('Specify Hospital', Icons.edit),
            ),
          ],

          const SizedBox(height: 20),
          _sectionHeader('Transport Crew', Icons.groups),
          const SizedBox(height: 8),
          MultiSelectChips(
            label: 'Passengers',
            options: const [
              'EMT/MFR',
              'MD/Nurse',
              'Ambulance Crew',
              'Relatives',
            ],
            selected: _passenger,
            onChanged: (v) => setState(() => _passenger = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _primaryCrewCtrl,
            decoration: _inputDeco('Primary Crew', Icons.person),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _secondaryCrewCtrl,
            decoration: _inputDeco('Secondary Crew', Icons.person_outline),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Final Outcome', Icons.check_circle),
          const SizedBox(height: 8),
          ..._buildOutcomeRadios(),

          const SizedBox(height: 20),
          _sectionHeader('Receiving Physician', Icons.medical_information),
          const SizedBox(height: 8),
          TextField(
            controller: _doctorNameCtrl,
            decoration: _inputDeco('Doctor Name', Icons.person),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _licenseNumberCtrl,
            decoration: _inputDeco('License Number', Icons.badge),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _physicianReportCtrl,
            decoration: _inputDeco('Physician Report', Icons.description),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOutcomeRadios() {
    const options = [
      'Admitted to Emergency Room',
      'Admitted to Hospital',
      'Transferred',
      'Released',
      'Died',
      'Refused Treatment',
    ];
    return options
        .map((opt) => RadioListTile<String>(
              title: Text(opt, style: const TextStyle(fontSize: 13)),
              value: opt,
              groupValue: _finalOutcome,
              onChanged: (v) => setState(() => _finalOutcome = v),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ))
        .toList();
  }

  Widget _timeField(String label, TimeOfDay? value, ValueChanged<TimeOfDay> onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? TimeOfDay.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: _inputDeco(label, Icons.access_time),
        child: Text(
          value != null ? _formatTime(value) : '--:--',
          style: TextStyle(
              color: value != null ? null : Colors.grey, fontSize: 14),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 5: Signatures & Documentation
  // ═══════════════════════════════════════════════════════════
  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('Signatures', Icons.draw),
          const SizedBox(height: 12),

          SignaturePadWidget(
            key: _patientSigKey,
            label: 'Patient / Guardian Signature',
            onChanged: (_) {},
          ),
          const SizedBox(height: 20),

          SignaturePadWidget(
            key: _doctorSigKey,
            label: 'Attending Physician Signature',
            onChanged: (_) {},
          ),
          const SizedBox(height: 20),

          SignaturePadWidget(
            key: _responderSigKey,
            label: 'EMT / First Responder Signature',
            onChanged: (_) {},
          ),

          const SizedBox(height: 24),
          _sectionHeader('Final Comments', Icons.comment),
          const SizedBox(height: 8),
          TextField(
            controller: _finalCommentsCtrl,
            decoration:
                _inputDeco('Additional comments or notes', Icons.note_add),
            maxLines: 4,
          ),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitForm,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(
                _isSubmitting
                    ? 'Submitting...'
                    : 'Submit E-Street Form',
                style: const TextStyle(fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF28A745),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────
  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13),
      prefixIcon: Icon(icon, size: 20),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1976D2)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1976D2),
          ),
        ),
      ],
    );
  }
}
