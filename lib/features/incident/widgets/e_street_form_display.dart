import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class EStreetFormDisplay extends StatelessWidget {
  final String? eStreetFormJson;

  const EStreetFormDisplay({super.key, this.eStreetFormJson});

  @override
  Widget build(BuildContext context) {
    if (eStreetFormJson == null || eStreetFormJson!.isEmpty) {
      return const SizedBox.shrink();
    }

    Map<String, dynamic>? formData;
    try {
      formData = json.decode(eStreetFormJson!) as Map<String, dynamic>;
    } catch (e) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error parsing e-street form data',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'E-Street Form',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Information Section
                if (_hasPatientInfo(formData)) ...[
                  _sectionHeader('Patient Information'),
                  const SizedBox(height: 8),
                  if (formData['name'] != null)
                    _detailRow(Icons.person, 'Name', formData['name']),
                  if (formData['age'] != null)
                    _detailRow(Icons.cake, 'Age', formData['age'].toString()),
                  if (formData['sex'] != null)
                    _detailRow(Icons.wc, 'Sex', formData['sex']),
                  if (formData['address'] != null)
                    _detailRow(Icons.home, 'Address', formData['address']),
                  if (formData['date_of_birth'] != null)
                    _detailRow(Icons.calendar_today, 'Date of Birth',
                        formData['date_of_birth']),
                  if (formData['emergency_contact'] != null)
                    _detailRow(Icons.phone, 'Emergency Contact',
                        formData['emergency_contact']),
                  const Divider(height: 24),
                ],

                // Incident Details Section
                if (_hasIncidentDetails(formData)) ...[
                  _sectionHeader('Incident Details'),
                  const SizedBox(height: 8),
                  if (formData['incident_datetime'] != null)
                    _detailRow(Icons.access_time, 'Incident Date/Time',
                        formData['incident_datetime']),
                  if (formData['chief_complaint'] != null)
                    _detailRow(Icons.medical_services, 'Chief Complaint',
                        formData['chief_complaint']),
                  if (formData['history'] != null)
                    _detailRow(
                        Icons.history, 'History', formData['history']),
                  const Divider(height: 24),
                ],

                // Medical History Section
                if (_hasMedicalHistory(formData)) ...[
                  _sectionHeader('Medical History'),
                  const SizedBox(height: 8),
                  if (formData['allergies'] != null)
                    _detailRow(Icons.warning_amber, 'Allergies',
                        formData['allergies']),
                  if (formData['current_medications'] != null)
                    _detailRow(Icons.medication, 'Current Medications',
                        formData['current_medications']),
                  if (formData['medical_history'] != null)
                    _detailRow(Icons.history_edu, 'Medical History',
                        formData['medical_history']),
                  const Divider(height: 24),
                ],

                // Assessment Section
                if (_hasAssessment(formData)) ...[
                  _sectionHeader('Assessment'),
                  const SizedBox(height: 8),
                  if (formData['pain_scale'] != null)
                    _detailRow(Icons.healing, 'Pain Scale',
                        formData['pain_scale'].toString()),
                  if (formData['consciousness_level'] != null)
                    _detailRow(Icons.psychology, 'Consciousness Level',
                        formData['consciousness_level']),
                  if (_hasGCS(formData)) ...[
                    const SizedBox(height: 4),
                    _detailRow(Icons.visibility, 'GCS Eye',
                        formData['gcs_eye']?.toString() ?? 'N/A'),
                    _detailRow(Icons.record_voice_over, 'GCS Verbal',
                        formData['gcs_verbal']?.toString() ?? 'N/A'),
                    _detailRow(Icons.back_hand, 'GCS Motor',
                        formData['gcs_motor']?.toString() ?? 'N/A'),
                    _detailRow(Icons.calculate, 'GCS Total',
                        formData['gcs_total']?.toString() ?? 'N/A'),
                  ],
                  const Divider(height: 24),
                ],

                // Vital Signs Section
                if (_hasVitalSigns(formData)) ...[
                  _sectionHeader('Vital Signs'),
                  const SizedBox(height: 8),
                  if (formData['blood_pressure'] != null)
                    _detailRow(Icons.favorite, 'Blood Pressure',
                        formData['blood_pressure']),
                  if (formData['pulse'] != null)
                    _detailRow(
                        Icons.monitor_heart, 'Pulse', formData['pulse']),
                  if (formData['respiratory'] != null)
                    _detailRow(Icons.air, 'Respiratory Rate',
                        formData['respiratory']),
                  if (formData['temperature'] != null)
                    _detailRow(Icons.thermostat, 'Temperature',
                        formData['temperature']),
                  if (formData['spo2'] != null)
                    _detailRow(
                        Icons.bluetooth_audio, 'SpO2', formData['spo2']),
                  if (formData['blood_glucose'] != null)
                    _detailRow(Icons.water_drop, 'Blood Glucose',
                        formData['blood_glucose']),
                  if (formData['pupils'] != null)
                    _detailRow(Icons.remove_red_eye, 'Pupils',
                        formData['pupils']),
                  const Divider(height: 24),
                ],

                // Treatment Section
                if (_hasTreatment(formData)) ...[
                  _sectionHeader('Treatment'),
                  const SizedBox(height: 8),
                  if (formData['medications_given'] != null)
                    _detailRow(Icons.medication_liquid, 'Medications Given',
                        formData['medications_given']),
                  if (formData['iv_fluids'] != null)
                    _detailRow(
                        Icons.opacity, 'IV Fluids', formData['iv_fluids']),
                  if (formData['treatment_response'] != null)
                    _detailRow(Icons.trending_up, 'Treatment Response',
                        formData['treatment_response']),
                  if (formData['treatment_notes'] != null)
                    _detailRow(Icons.note_alt, 'Treatment Notes',
                        formData['treatment_notes']),
                  const Divider(height: 24),
                ],

                // Transport Section
                if (_hasTransportInfo(formData)) ...[
                  _sectionHeader('Transport Information'),
                  const SizedBox(height: 8),
                  if (formData['time_called'] != null)
                    _detailRow(Icons.call, 'Time Called',
                        formData['time_called']),
                  if (formData['time_arrived_scene'] != null)
                    _detailRow(Icons.location_on, 'Time Arrived Scene',
                        formData['time_arrived_scene']),
                  if (formData['time_departed_scene'] != null)
                    _detailRow(Icons.directions_car, 'Time Departed Scene',
                        formData['time_departed_scene']),
                  if (formData['time_arrived_hospital'] != null)
                    _detailRow(Icons.local_hospital, 'Time Arrived Hospital',
                        formData['time_arrived_hospital']),
                  if (formData['transport_method'] != null)
                    _detailRow(Icons.directions_car_filled,
                        'Transport Method', formData['transport_method']),
                  const Divider(height: 24),
                ],

                // Crew Section
                if (_hasCrewInfo(formData)) ...[
                  _sectionHeader('Crew Information'),
                  const SizedBox(height: 8),
                  if (formData['primary_crew'] != null)
                    _detailRow(Icons.person_pin, 'Primary Crew',
                        formData['primary_crew']),
                  if (formData['secondary_crew'] != null)
                    _detailRow(Icons.people, 'Secondary Crew',
                        formData['secondary_crew']),
                  const Divider(height: 24),
                ],

                // Additional Information
                if (_hasAdditionalInfo(formData)) ...[
                  _sectionHeader('Additional Information'),
                  const SizedBox(height: 8),
                  if (formData['additional_info'] != null)
                    _detailRow(Icons.info_outline, 'Additional Info',
                        formData['additional_info']),
                  if (formData['signature'] != null)
                    _detailRow(
                        Icons.draw, 'Signature', formData['signature']),
                  if (formData['responder_id'] != null)
                    _detailRow(Icons.badge, 'Responder ID',
                        formData['responder_id']),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
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
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods to check if sections have data
  bool _hasPatientInfo(Map<String, dynamic> data) {
    return data['name'] != null ||
        data['age'] != null ||
        data['sex'] != null ||
        data['address'] != null ||
        data['date_of_birth'] != null ||
        data['emergency_contact'] != null;
  }

  bool _hasIncidentDetails(Map<String, dynamic> data) {
    return data['incident_datetime'] != null ||
        data['chief_complaint'] != null ||
        data['history'] != null;
  }

  bool _hasMedicalHistory(Map<String, dynamic> data) {
    return data['allergies'] != null ||
        data['current_medications'] != null ||
        data['medical_history'] != null;
  }

  bool _hasAssessment(Map<String, dynamic> data) {
    return data['pain_scale'] != null ||
        data['consciousness_level'] != null ||
        _hasGCS(data);
  }

  bool _hasGCS(Map<String, dynamic> data) {
    return data['gcs_eye'] != null ||
        data['gcs_verbal'] != null ||
        data['gcs_motor'] != null ||
        data['gcs_total'] != null;
  }

  bool _hasVitalSigns(Map<String, dynamic> data) {
    return data['blood_pressure'] != null ||
        data['pulse'] != null ||
        data['respiratory'] != null ||
        data['temperature'] != null ||
        data['spo2'] != null ||
        data['blood_glucose'] != null ||
        data['pupils'] != null;
  }

  bool _hasTreatment(Map<String, dynamic> data) {
    return data['medications_given'] != null ||
        data['iv_fluids'] != null ||
        data['treatment_response'] != null ||
        data['treatment_notes'] != null;
  }

  bool _hasTransportInfo(Map<String, dynamic> data) {
    return data['time_called'] != null ||
        data['time_arrived_scene'] != null ||
        data['time_departed_scene'] != null ||
        data['time_arrived_hospital'] != null ||
        data['transport_method'] != null;
  }

  bool _hasCrewInfo(Map<String, dynamic> data) {
    return data['primary_crew'] != null || data['secondary_crew'] != null;
  }

  bool _hasAdditionalInfo(Map<String, dynamic> data) {
    return data['additional_info'] != null ||
        data['signature'] != null ||
        data['responder_id'] != null;
  }
}
