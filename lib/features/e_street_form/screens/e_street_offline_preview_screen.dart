import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/e_street_form_model.dart';

/// Read-only preview screen displayed after submitting an E-Street Form
/// while offline. Shows all user inputs so they can verify what was saved.
class EStreetOfflinePreviewScreen extends StatelessWidget {
  final EStreetFormModel form;
  final int incidentId;

  const EStreetOfflinePreviewScreen({
    super.key,
    required this.form,
    required this.incidentId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Form Preview'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Offline banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saved Offline',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This form will be automatically submitted when you reconnect to the internet.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form data card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.assignment,
                            color: AppColors.primary, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'E-Street Form #$incidentId',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Patient Info
                    ...[
                      _sectionTitle('Patient Information'),
                      _fieldRow('Name', form.name),
                      _fieldRow('Age', form.age),
                      _fieldRow('Sex', form.sex),
                      _fieldRow('Date of Birth', form.dateOfBirth),
                      _fieldRow('Address', form.address),
                      _fieldRow('Emergency Contact', form.emergencyContact),
                      _fieldRow('Incident Date/Time', form.incidentDatetime),
                      _fieldRow('Allergies', form.allergies),
                      _fieldRow('Current Medications', form.currentMedications),
                      _fieldRow('Medical History', form.medicalHistory),
                      const SizedBox(height: 12),
                    ],

                    // Medical Assessment
                    ...[
                      _sectionTitle('Medical Assessment'),
                      _fieldRow('Chief Complaint', form.chiefComplaint),
                      _fieldRow('History', form.history),
                      _fieldRow('Pain Scale', form.painScale?.toString()),
                      _fieldRow('Consciousness', form.consciousnessLevel),
                      if (form.gcsEye != null ||
                          form.gcsVerbal != null ||
                          form.gcsMotor != null)
                        _fieldRow(
                          'GCS',
                          'E${form.gcsEye ?? "-"} V${form.gcsVerbal ?? "-"} M${form.gcsMotor ?? "-"} = ${form.gcsTotal}',
                        ),
                      _fieldRow('Pupils', form.pupils),
                      const SizedBox(height: 12),
                    ],

                    // Vital Signs
                    ...[
                      _sectionTitle('Vital Signs'),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _vitalChip('BP', form.bloodPressure),
                          _vitalChip('Pulse', form.pulse),
                          _vitalChip('Resp', form.respiratory),
                          _vitalChip('Temp', form.temperature),
                          _vitalChip('SpO₂', form.spo2),
                          _vitalChip('Glucose', form.bloodGlucose),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Skin Assessment
                    ...[
                      _sectionTitle('Skin Assessment'),
                      _chipList('Skin Condition', form.skin),
                      const SizedBox(height: 12),
                    ],

                    // Treatment
                    ...[
                      _sectionTitle('Treatment & Interventions'),
                      _chipList('Aid Provided', form.aid),
                      _fieldRow('Medications Given', form.medicationsGiven),
                      _fieldRow('IV Fluids', form.ivFluids),
                      _chipList('Equipment Used', form.equipment),
                      _fieldRow('Treatment Response', form.treatmentResponse),
                      _fieldRow('Treatment Notes', form.treatmentNotes),
                      const SizedBox(height: 12),
                    ],

                    // Transport
                    ...[
                      _sectionTitle('Transport & Outcome'),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _vitalChip('Called', form.timeCalled),
                          _vitalChip('On Scene', form.timeArrivedScene),
                          _vitalChip('Departed', form.timeDepartedScene),
                          _vitalChip('At Hospital', form.timeArrivedHospital),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _chipList('Ambulance Type', form.ambulanceType),
                      _fieldRow('Transport Method', form.transportMethod),
                      _fieldRow(
                          'Hospital',
                          form.hospital == 'OTHER'
                              ? form.hospitalOther
                              : form.hospital),
                      _chipList('Passengers', form.passenger),
                      _fieldRow('Primary Crew', form.primaryCrew),
                      _fieldRow('Secondary Crew', form.secondaryCrew),
                      _fieldRow('Final Outcome', form.finalOutcome),
                      const SizedBox(height: 12),
                    ],

                    // Doctor / Physician
                    ...[
                      _sectionTitle('Receiving Physician'),
                      _fieldRow('Doctor Name', form.doctorName),
                      _fieldRow('License Number', form.licenseNumber),
                      _fieldRow(
                          'Hospital',
                          form.hospital == 'OTHER'
                              ? form.hospitalOther
                              : form.hospital),
                      _fieldRow('Physician Report', form.physicianReport),
                      const SizedBox(height: 12),
                    ],

                    // Body Observations
                    ...[
                      _sectionTitle('Body Observations'),
                      form.bodyObservations.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '—',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: form.bodyObservations.entries.map((e) {
                                final label =
                                    e.key.replaceAll('_', ' ').split(' ').map(
                                  (w) => w.isEmpty
                                      ? ''
                                      : '${w[0].toUpperCase()}${w.substring(1)}',
                                ).join(' ');
                                return _fieldRow(label, e.value);
                              }).toList(),
                            ),
                      const SizedBox(height: 12),
                    ],

                    // Final Comments
                    ...[
                      _sectionTitle('Final Comments'),
                      Text(
                        (form.finalComments != null &&
                                form.finalComments!.isNotEmpty)
                            ? form.finalComments!
                            : '—',
                        style: TextStyle(
                          fontSize: 13,
                          color: (form.finalComments == null ||
                                  form.finalComments!.isEmpty)
                              ? Colors.grey.shade400
                              : null,
                          fontStyle: (form.finalComments == null ||
                                  form.finalComments!.isEmpty)
                              ? FontStyle.italic
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Signatures indicator
                    _sectionTitle('Signatures'),
                    Row(
                      children: [
                        _signatureIndicator('Patient', form.patientSignature),
                        const SizedBox(width: 12),
                        _signatureIndicator('Doctor', form.doctorSignature),
                        const SizedBox(width: 12),
                        _signatureIndicator('Responder', form.responderSignature),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Done button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text('Done'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Section helpers ─────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _fieldRow(String label, String? value) {
    final displayValue = (value == null || value.trim().isEmpty) ? '—' : value;
    final isBlank = (value == null || value.trim().isEmpty);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: 13,
                color: isBlank ? Colors.grey.shade400 : null,
                fontStyle: isBlank ? FontStyle.italic : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalChip(String label, String? value) {
    final displayValue = (value == null || value.trim().isEmpty) ? '—' : value;
    final isBlank = (value == null || value.trim().isEmpty);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isBlank 
            ? Colors.grey.shade100 
            : AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          Text(displayValue,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isBlank ? Colors.grey.shade400 : null,
                fontStyle: isBlank ? FontStyle.italic : null,
              )),
        ],
      ),
    );
  }

  Widget _chipList(String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          items.isEmpty
              ? Text(
                  '—',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: items
                      .map((s) => Chip(
                            label: Text(s, style: const TextStyle(fontSize: 11)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _signatureIndicator(String label, String? data) {
    final signed = data != null && data.isNotEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          signed ? Icons.check_circle : Icons.cancel,
          size: 18,
          color: signed ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
