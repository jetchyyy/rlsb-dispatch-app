import 'dart:convert';

/// Complete data model for the E-Street Form.
///
/// All fields are nullable (the backend accepts partial submissions).
/// Use [toFormData] to serialize for multipart/form-data submission,
/// and [fromJson] to deserialize from the API response.
class EStreetFormModel {
  // ── Step 1: Patient Information ─────────────────────────
  String name;
  String? age;
  String? sex;
  String? address;
  String? dateOfBirth;
  String? emergencyContact;
  String? incidentDatetime;
  String? allergies;
  String? currentMedications;
  String? medicalHistory;

  // ── Step 2: Medical Assessment ──────────────────────────
  String chiefComplaint;
  String? history;
  int? painScale;
  String? consciousnessLevel;
  int? gcsEye;
  int? gcsVerbal;
  int? gcsMotor;
  String? bloodPressure;
  String? pulse;
  String? respiratory;
  String? temperature;
  String? spo2;
  String? bloodGlucose;
  String? pupils;
  List<String> skin;

  // ── Body Assessment ─────────────────────────────────────
  Map<String, String> bodyObservations;
  String? bodyDiagramScreenshot;

  // ── Step 3: Treatment & Interventions ───────────────────
  List<String> aid;
  String? medicationsGiven;
  String? ivFluids;
  List<String> equipment;
  String? treatmentResponse;
  String? treatmentNotes;

  // ── Step 4: Transport & Outcome ─────────────────────────
  String? timeCalled;
  String? timeArrivedScene;
  String? timeDepartedScene;
  String? timeArrivedHospital;
  List<String> ambulanceType;
  String? transportMethod;
  String? hospital;
  String? hospitalOther;
  List<String> passenger;
  String? primaryCrew;
  String? secondaryCrew;
  String? finalOutcome;
  String? doctorName;
  String? licenseNumber;
  String? physicianReport;

  // ── Step 5: Signatures & Final ──────────────────────────
  String? patientSignature;
  String? doctorSignature;
  String? responderSignature;
  String? finalComments;

  // ── Computed ────────────────────────────────────────────
  int get gcsTotal => (gcsEye ?? 0) + (gcsVerbal ?? 0) + (gcsMotor ?? 0);

  EStreetFormModel({
    this.name = '',
    this.age,
    this.sex,
    this.address,
    this.dateOfBirth,
    this.emergencyContact,
    this.incidentDatetime,
    this.allergies,
    this.currentMedications,
    this.medicalHistory,
    this.chiefComplaint = '',
    this.history,
    this.painScale,
    this.consciousnessLevel,
    this.gcsEye,
    this.gcsVerbal,
    this.gcsMotor,
    this.bloodPressure,
    this.pulse,
    this.respiratory,
    this.temperature,
    this.spo2,
    this.bloodGlucose,
    this.pupils,
    List<String>? skin,
    Map<String, String>? bodyObservations,
    this.bodyDiagramScreenshot,
    List<String>? aid,
    this.medicationsGiven,
    this.ivFluids,
    List<String>? equipment,
    this.treatmentResponse,
    this.treatmentNotes,
    this.timeCalled,
    this.timeArrivedScene,
    this.timeDepartedScene,
    this.timeArrivedHospital,
    List<String>? ambulanceType,
    this.transportMethod,
    this.hospital,
    this.hospitalOther,
    List<String>? passenger,
    this.primaryCrew,
    this.secondaryCrew,
    this.finalOutcome,
    this.doctorName,
    this.licenseNumber,
    this.physicianReport,
    this.patientSignature,
    this.doctorSignature,
    this.responderSignature,
    this.finalComments,
  })  : skin = skin ?? [],
        bodyObservations = bodyObservations ?? {},
        aid = aid ?? [],
        equipment = equipment ?? [],
        ambulanceType = ambulanceType ?? [],
        passenger = passenger ?? [];

  // ── Serialization for multipart/form-data ───────────────

  /// Converts to a Map suitable for Dio [FormData.fromMap].
  ///
  /// Array fields use `[]` suffix keys for PHP-style encoding.
  /// Null/empty values are omitted so the backend receives only
  /// the fields the responder actually filled.
  Map<String, dynamic> toFormData() {
    final map = <String, dynamic>{};

    void addIfNotEmpty(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        map[key] = value.trim();
      }
    }

    void addIntIfNotNull(String key, int? value) {
      if (value != null) map[key] = value.toString();
    }

    // Step 1 — Patient Info
    addIfNotEmpty('name', name);
    addIfNotEmpty('age', age);
    addIfNotEmpty('sex', sex);
    addIfNotEmpty('address', address);
    addIfNotEmpty('date_of_birth', dateOfBirth);
    addIfNotEmpty('emergency_contact', emergencyContact);
    addIfNotEmpty('incident_datetime', incidentDatetime);
    addIfNotEmpty('allergies', allergies);
    addIfNotEmpty('current_medications', currentMedications);
    addIfNotEmpty('medical_history', medicalHistory);

    // Step 2 — Medical Assessment
    addIfNotEmpty('chief_complaint', chiefComplaint);
    addIfNotEmpty('history', history);
    addIntIfNotNull('pain_scale', painScale);
    addIfNotEmpty('consciousness_level', consciousnessLevel);
    addIntIfNotNull('gcs_eye', gcsEye);
    addIntIfNotNull('gcs_verbal', gcsVerbal);
    addIntIfNotNull('gcs_motor', gcsMotor);
    addIfNotEmpty('blood_pressure', bloodPressure);
    addIfNotEmpty('pulse', pulse);
    addIfNotEmpty('respiratory', respiratory);
    addIfNotEmpty('temperature', temperature);
    addIfNotEmpty('spo2', spo2);
    addIfNotEmpty('blood_glucose', bloodGlucose);
    addIfNotEmpty('pupils', pupils);

    // Skin — array
    if (skin.isNotEmpty) {
      map['skin'] = skin;
    }

    // Body observations — JSON string
    if (bodyObservations.isNotEmpty) {
      map['body_observations'] = jsonEncode(bodyObservations);
    }

    // Body diagram screenshot
    addIfNotEmpty('body_diagram_screenshot', bodyDiagramScreenshot);

    // Step 3 — Treatment
    if (aid.isNotEmpty) {
      map['aid'] = aid;
    }
    addIfNotEmpty('medications_given', medicationsGiven);
    addIfNotEmpty('iv_fluids', ivFluids);
    if (equipment.isNotEmpty) {
      map['equipment'] = equipment;
    }
    addIfNotEmpty('treatment_response', treatmentResponse);
    addIfNotEmpty('treatment_notes', treatmentNotes);

    // Step 4 — Transport
    addIfNotEmpty('time_called', timeCalled);
    addIfNotEmpty('time_arrived_scene', timeArrivedScene);
    addIfNotEmpty('time_departed_scene', timeDepartedScene);
    addIfNotEmpty('time_arrived_hospital', timeArrivedHospital);
    if (ambulanceType.isNotEmpty) {
      map['ambulance_type'] = ambulanceType;
    }
    addIfNotEmpty('transport_method', transportMethod);

    // Hospital: if OTHER was chosen, use the custom text
    final hospitalValue = hospital == 'OTHER' ? hospitalOther : hospital;
    addIfNotEmpty('hospital', hospitalValue);

    if (passenger.isNotEmpty) {
      map['passenger'] = passenger;
    }
    addIfNotEmpty('primary_crew', primaryCrew);
    addIfNotEmpty('secondary_crew', secondaryCrew);
    addIfNotEmpty('final_outcome', finalOutcome);
    addIfNotEmpty('doctor_name', doctorName);
    addIfNotEmpty('license_number', licenseNumber);
    addIfNotEmpty('physician_report', physicianReport);

    // Step 5 — Signatures & Final
    addIfNotEmpty('patient_signature', patientSignature);
    addIfNotEmpty('doctor_signature', doctorSignature);
    addIfNotEmpty('responder_signature', responderSignature);
    addIfNotEmpty('final_comments', finalComments);

    return map;
  }

  /// Converts to a simple JSON map (used for local PDF generation / display).
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    void add(String key, dynamic value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is List && value.isEmpty) return;
      map[key] = value;
    }

    add('name', name);
    add('age', age);
    add('sex', sex);
    add('address', address);
    add('date_of_birth', dateOfBirth);
    add('emergency_contact', emergencyContact);
    add('incident_datetime', incidentDatetime);
    add('allergies', allergies);
    add('current_medications', currentMedications);
    add('medical_history', medicalHistory);
    add('chief_complaint', chiefComplaint);
    add('history', history);
    add('pain_scale', painScale);
    add('consciousness_level', consciousnessLevel);
    add('gcs_eye', gcsEye);
    add('gcs_verbal', gcsVerbal);
    add('gcs_motor', gcsMotor);
    if (gcsEye != null || gcsVerbal != null || gcsMotor != null) {
      map['gcs_total'] = gcsTotal;
    }
    add('blood_pressure', bloodPressure);
    add('pulse', pulse);
    add('respiratory', respiratory);
    add('temperature', temperature);
    add('spo2', spo2);
    add('blood_glucose', bloodGlucose);
    add('pupils', pupils);
    add('skin', skin);
    if (bodyObservations.isNotEmpty) {
      map['body_observations'] = jsonEncode(bodyObservations);
    }
    add('body_diagram_screenshot', bodyDiagramScreenshot);
    add('aid', aid);
    add('medications_given', medicationsGiven);
    add('iv_fluids', ivFluids);
    add('equipment', equipment);
    add('treatment_response', treatmentResponse);
    add('treatment_notes', treatmentNotes);
    add('time_called', timeCalled);
    add('time_arrived_scene', timeArrivedScene);
    add('time_departed_scene', timeDepartedScene);
    add('time_arrived_hospital', timeArrivedHospital);
    add('ambulance_type', ambulanceType);
    add('transport_method', transportMethod);
    final hospitalValue = hospital == 'OTHER' ? hospitalOther : hospital;
    add('hospital', hospitalValue);
    add('passenger', passenger);
    add('primary_crew', primaryCrew);
    add('secondary_crew', secondaryCrew);
    add('final_outcome', finalOutcome);
    add('doctor_name', doctorName);
    add('license_number', licenseNumber);
    add('physician_report', physicianReport);
    add('patient_signature', patientSignature);
    add('doctor_signature', doctorSignature);
    add('responder_signature', responderSignature);
    add('final_comments', finalComments);

    return map;
  }

  // ── Deserialization ─────────────────────────────────────

  factory EStreetFormModel.fromJson(Map<String, dynamic> json) {
    return EStreetFormModel(
      name: _str(json['name']) ?? '',
      age: _str(json['age']),
      sex: _str(json['sex']),
      address: _str(json['address']),
      dateOfBirth: _str(json['date_of_birth']),
      emergencyContact: _str(json['emergency_contact']),
      incidentDatetime: _str(json['incident_datetime']),
      allergies: _str(json['allergies']),
      currentMedications: _str(json['current_medications']),
      medicalHistory: _str(json['medical_history']),
      chiefComplaint: _str(json['chief_complaint']) ?? '',
      history: _str(json['history']),
      painScale: _parseInt(json['pain_scale']),
      consciousnessLevel: _str(json['consciousness_level']),
      gcsEye: _parseInt(json['gcs_eye']),
      gcsVerbal: _parseInt(json['gcs_verbal']),
      gcsMotor: _parseInt(json['gcs_motor']),
      bloodPressure: _str(json['blood_pressure']),
      pulse: _str(json['pulse']),
      respiratory: _str(json['respiratory']),
      temperature: _str(json['temperature']),
      spo2: _str(json['spo2']),
      bloodGlucose: _str(json['blood_glucose']),
      pupils: _str(json['pupils']),
      skin: _toStringList(json['skin']),
      bodyObservations: _parseBodyObs(json['body_observations']),
      bodyDiagramScreenshot: _str(json['body_diagram_screenshot']),
      aid: _toStringList(json['aid']),
      medicationsGiven: _str(json['medications_given']),
      ivFluids: _str(json['iv_fluids']),
      equipment: _toStringList(json['equipment']),
      treatmentResponse: _str(json['treatment_response']),
      treatmentNotes: _str(json['treatment_notes']),
      timeCalled: _str(json['time_called']),
      timeArrivedScene: _str(json['time_arrived_scene']),
      timeDepartedScene: _str(json['time_departed_scene']),
      timeArrivedHospital: _str(json['time_arrived_hospital']),
      ambulanceType: _toStringList(json['ambulance_type']),
      transportMethod: _str(json['transport_method']),
      hospital: _str(json['hospital']),
      passenger: _toStringList(json['passenger']),
      primaryCrew: _str(json['primary_crew']),
      secondaryCrew: _str(json['secondary_crew']),
      finalOutcome: _str(json['final_outcome']),
      doctorName: _str(json['doctor_name']),
      licenseNumber: _str(json['license_number']),
      physicianReport: _str(json['physician_report']),
      patientSignature: _str(json['patient_signature']),
      doctorSignature: _str(json['doctor_signature']),
      responderSignature: _str(json['responder_signature']),
      finalComments: _str(json['final_comments']),
    );
  }

  // ── Static option lists ─────────────────────────────────

  static const List<String> sexOptions = ['Male', 'Female', 'Other'];

  static const List<String> consciousnessLevels = [
    'Alert', 'Verbal', 'Pain', 'Unresponsive',
  ];

  static const List<String> pupilOptions = [
    'PEARL', 'Dilated', 'Constricted', 'Unequal', 'Non-reactive',
  ];

  static const List<String> skinOptions = [
    'Normal', 'Pale', 'Cyanotic', 'Flushed',
    'Warm/Dry', 'Cold/Clammy', 'Warm/Moist', 'Cold/Dry',
  ];

  static const List<String> aidOptions = [
    'Oxygen', 'Bandaging', 'Splinting', 'Spine board',
    'Neck Immobilized', 'IV Access', 'Cpr Successful', 'Cpr Unsuccessful',
    'Suction', 'Oropharyngeal Airway', 'Cont. Bleeding', 'Restrained',
    'Ob Delivery', 'Traction Splints', 'AED', 'Patient Refuse Services',
  ];

  static const List<String> equipmentOptions = [
    'Stretcher', 'Stair Chair', 'Backboard', 'C-Collar', 'KED',
    'Monitor', 'Ventilator', 'Defibrillator', 'Suction Unit', 'Other',
  ];

  static const List<String> ambulanceTypeOptions = [
    'Emergency Response Call', 'Hospital Transfer',
    'Inter-Hospital', 'Procedural',
  ];

  static const List<String> transportMethodOptions = [
    'Stretcher', 'Walking', 'Wheelchair', 'Carried',
  ];

  static const List<String> passengerOptions = [
    'EMT/MFR', 'MD/Nurse', 'Ambulance Crew', 'Relatives',
  ];

  static const List<String> finalOutcomeOptions = [
    'Admitted to Emergency Room', 'Admitted to Hospital',
    'Transferred', 'Released', 'Died', 'Refused Treatment',
  ];

  static const List<String> treatmentResponseOptions = [
    'Improved', 'No Change', 'Deteriorated', 'Stabilized',
  ];

  static const List<String> hospitalOptions = [
    'Surigao del Norte Provincial Hospital (SDNPH)',
    'Gigaquit Municipal Hospital',
    'Mainit Medicare Community Hospital',
    'Malimono District Hospital',
    'Del Carmen District Hospital',
    'Pilar District Hospital',
    'Socorro District Hospital',
    'Sta. Monica District Hospital',
    'Surigao Doctors\' Hospital',
    'Saint Paul University Hospital',
    'Surigao Medical Center',
    'CARAGA Regional Hospital',
  ];

  // ── Private helpers ─────────────────────────────────────

  static String? _str(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      // Could be a JSON-encoded array
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  static Map<String, String> _parseBodyObs(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    }
    return {};
  }
}
