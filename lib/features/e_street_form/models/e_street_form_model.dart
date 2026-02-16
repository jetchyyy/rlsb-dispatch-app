import 'dart:convert';

/// Data model for the E-Street pre-hospital care form.
/// All fields nullable except [name] and [chiefComplaint].
class EStreetFormModel {
  // Step 1: Patient Information
  String name;
  String? age;
  String? dateOfBirth;
  String? sex;
  String? address;
  String? emergencyContact;
  String? incidentNumber;
  String? incidentDatetime;
  String? allergies;
  String? currentMedications;
  String? medicalHistory;

  // Step 2: Medical Assessment
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

  // Step 3: Treatment & Interventions
  List<String> aid;
  List<String> equipment;
  String? medicationsGiven;
  String? ivFluids;
  String? treatmentResponse;
  String? treatmentNotes;

  // Step 4: Transport & Outcome
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

  // Step 5: Signatures & Documentation
  String? patientSignature;
  String? doctorSignature;
  String? responderSignature;
  String? finalComments;

  // Body Observations
  Map<String, String> bodyObservations;
  String? bodyDiagramScreenshot;

  EStreetFormModel({
    this.name = '',
    this.age,
    this.dateOfBirth,
    this.sex,
    this.address,
    this.emergencyContact,
    this.incidentNumber,
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
    this.skin = const [],
    this.aid = const [],
    this.equipment = const [],
    this.medicationsGiven,
    this.ivFluids,
    this.treatmentResponse,
    this.treatmentNotes,
    this.timeCalled,
    this.timeArrivedScene,
    this.timeDepartedScene,
    this.timeArrivedHospital,
    this.ambulanceType = const [],
    this.transportMethod,
    this.hospital,
    this.hospitalOther,
    this.passenger = const [],
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
    this.bodyObservations = const {},
    this.bodyDiagramScreenshot,
  });

  int get gcsTotal => (gcsEye ?? 0) + (gcsVerbal ?? 0) + (gcsMotor ?? 0);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'chief_complaint': chiefComplaint,
    };

    void addIfNotNull(String key, dynamic value) {
      if (value != null &&
          value != '' &&
          (value is! List || value.isNotEmpty) &&
          (value is! Map || value.isNotEmpty)) {
        map[key] = value;
      }
    }

    addIfNotNull('age', age);
    addIfNotNull('date_of_birth', dateOfBirth);
    addIfNotNull('sex', sex);
    addIfNotNull('address', address);
    addIfNotNull('emergency_contact', emergencyContact);
    addIfNotNull('incident_datetime', incidentDatetime);
    addIfNotNull('allergies', allergies);
    addIfNotNull('current_medications', currentMedications);
    addIfNotNull('medical_history', medicalHistory);
    addIfNotNull('history', history);
    addIfNotNull('pain_scale', painScale);
    addIfNotNull('consciousness_level', consciousnessLevel);
    addIfNotNull('gcs_eye', gcsEye);
    addIfNotNull('gcs_verbal', gcsVerbal);
    addIfNotNull('gcs_motor', gcsMotor);
    addIfNotNull('blood_pressure', bloodPressure);
    addIfNotNull('pulse', pulse);
    addIfNotNull('respiratory', respiratory);
    addIfNotNull('temperature', temperature);
    addIfNotNull('spo2', spo2);
    addIfNotNull('blood_glucose', bloodGlucose);
    addIfNotNull('pupils', pupils);
    addIfNotNull('skin', skin);
    addIfNotNull('aid', aid);
    addIfNotNull('equipment', equipment);
    addIfNotNull('medications_given', medicationsGiven);
    addIfNotNull('iv_fluids', ivFluids);
    addIfNotNull('treatment_response', treatmentResponse);
    addIfNotNull('treatment_notes', treatmentNotes);
    addIfNotNull('time_called', timeCalled);
    addIfNotNull('time_arrived_scene', timeArrivedScene);
    addIfNotNull('time_departed_scene', timeDepartedScene);
    addIfNotNull('time_arrived_hospital', timeArrivedHospital);
    addIfNotNull('ambulance_type', ambulanceType);
    addIfNotNull('transport_method', transportMethod);
    addIfNotNull('hospital', hospital);
    addIfNotNull('hospital_other', hospitalOther);
    addIfNotNull('passenger', passenger);
    addIfNotNull('primary_crew', primaryCrew);
    addIfNotNull('secondary_crew', secondaryCrew);
    addIfNotNull('final_outcome', finalOutcome);
    addIfNotNull('doctor_name', doctorName);
    addIfNotNull('license_number', licenseNumber);
    addIfNotNull('physician_report', physicianReport);
    addIfNotNull('final_comments', finalComments);
    addIfNotNull('patient_signature', patientSignature);
    addIfNotNull('doctor_signature', doctorSignature);
    addIfNotNull('responder_signature', responderSignature);
    addIfNotNull('body_diagram_screenshot', bodyDiagramScreenshot);

    if (bodyObservations.isNotEmpty) {
      map['body_observations'] = jsonEncode(bodyObservations);
    }

    return map;
  }

  /// Populate from existing e_street_form JSON (for editing)
  factory EStreetFormModel.fromJson(Map<String, dynamic> json) {
    List<String> toStringList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    Map<String, String> parseBodyObs(dynamic val) {
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is Map) {
            return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
          }
        } catch (_) {}
      }
      if (val is Map) {
        return val.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return {};
    }

    String? nullSafeString(dynamic val) {
      if (val == null) return null;
      final s = val.toString();
      if (s.isEmpty || s == 'null') return null;
      return s;
    }

    return EStreetFormModel(
      name: json['name']?.toString() ?? '',
      age: nullSafeString(json['age']),
      dateOfBirth: nullSafeString(json['date_of_birth']),
      sex: nullSafeString(json['sex']),
      address: nullSafeString(json['address']),
      emergencyContact: nullSafeString(json['emergency_contact']),
      incidentNumber: nullSafeString(json['incident_number']),
      incidentDatetime: nullSafeString(json['incident_datetime']),
      allergies: nullSafeString(json['allergies']),
      currentMedications: nullSafeString(json['current_medications']),
      medicalHistory: nullSafeString(json['medical_history']),
      chiefComplaint: json['chief_complaint']?.toString() ?? '',
      history: nullSafeString(json['history']),
      painScale: json['pain_scale'] is int
          ? json['pain_scale']
          : int.tryParse(json['pain_scale']?.toString() ?? ''),
      consciousnessLevel: json['consciousness_level']?.toString(),
      gcsEye: json['gcs_eye'] is int
          ? json['gcs_eye']
          : int.tryParse(json['gcs_eye']?.toString() ?? ''),
      gcsVerbal: json['gcs_verbal'] is int
          ? json['gcs_verbal']
          : int.tryParse(json['gcs_verbal']?.toString() ?? ''),
      gcsMotor: json['gcs_motor'] is int
          ? json['gcs_motor']
          : int.tryParse(json['gcs_motor']?.toString() ?? ''),
      bloodPressure: nullSafeString(json['blood_pressure']),
      pulse: nullSafeString(json['pulse']),
      respiratory: nullSafeString(json['respiratory']),
      temperature: nullSafeString(json['temperature']),
      spo2: nullSafeString(json['spo2']),
      bloodGlucose: nullSafeString(json['blood_glucose']),
      pupils: nullSafeString(json['pupils']),
      skin: toStringList(json['skin']),
      aid: toStringList(json['aid']),
      equipment: toStringList(json['equipment']),
      medicationsGiven: nullSafeString(json['medications_given']),
      ivFluids: nullSafeString(json['iv_fluids']),
      treatmentResponse: nullSafeString(json['treatment_response']),
      treatmentNotes: nullSafeString(json['treatment_notes']),
      timeCalled: nullSafeString(json['time_called']),
      timeArrivedScene: nullSafeString(json['time_arrived_scene']),
      timeDepartedScene: nullSafeString(json['time_departed_scene']),
      timeArrivedHospital: nullSafeString(json['time_arrived_hospital']),
      ambulanceType: toStringList(json['ambulance_type']),
      transportMethod: nullSafeString(json['transport_method']),
      hospital: nullSafeString(json['hospital']),
      hospitalOther: nullSafeString(json['hospital_other']),
      passenger: toStringList(json['passenger']),
      primaryCrew: nullSafeString(json['primary_crew']),
      secondaryCrew: nullSafeString(json['secondary_crew']),
      finalOutcome: nullSafeString(json['final_outcome']),
      doctorName: nullSafeString(json['doctor_name']),
      licenseNumber: nullSafeString(json['license_number']),
      physicianReport: nullSafeString(json['physician_report']),
      finalComments: nullSafeString(json['final_comments']),
      patientSignature: nullSafeString(json['patient_signature']),
      doctorSignature: nullSafeString(json['doctor_signature']),
      responderSignature: nullSafeString(json['responder_signature']),
      bodyDiagramScreenshot: nullSafeString(json['body_diagram_screenshot']),
      bodyObservations: parseBodyObs(json['body_observations']),
    );
  }
}
