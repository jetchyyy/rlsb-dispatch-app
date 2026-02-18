import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/e_street_form_model.dart';
import '../services/e_street_local_storage.dart';
import '../services/e_street_pdf_generator.dart';

/// Widget to display completed e-street form data in a readable format
class EStreetFormDataDisplay extends StatelessWidget {
  final String? eStreetFormJson;
  final int incidentId;

  const EStreetFormDataDisplay({
    super.key,
    this.eStreetFormJson,
    required this.incidentId,
  });

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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error parsing e-street form data',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Check if there's any meaningful data  
    if (!_hasAnyData(formData)) {
      return const SizedBox.shrink();
    }

    // At this point, formData is confirmed non-null
    final data = formData;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.medical_information, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'E-Street Form Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Information Section
                if (_hasPatientInfo(data)) ...[
                  _sectionHeader('Patient Information', Icons.person),
                  const SizedBox(height: 8),
                  if (data['name'] != null)
                    _detailRow('Name', data['name']),
                  if (data['age'] != null)
                    _detailRow('Age', data['age'].toString()),
                  if (data['sex'] != null)
                    _detailRow('Sex', data['sex']),
                  if (data['address'] != null)
                    _detailRow('Address', data['address']),
                  if (data['date_of_birth'] != null)
                    _detailRow('Date of Birth', data['date_of_birth']),
                  if (data['emergency_contact'] != null)
                    _detailRow('Emergency Contact', data['emergency_contact']),
                  const Divider(height: 24),
                ],

                // Incident Details Section
                if (_hasIncidentDetails(data)) ...[
                  _sectionHeader('Incident Details', Icons.event_note),
                  const SizedBox(height: 8),
                  if (data['incident_datetime'] != null)
                    _detailRow('Incident Date/Time', data['incident_datetime']),
                  if (data['chief_complaint'] != null)
                    _detailRow('Chief Complaint', data['chief_complaint']),
                  if (data['history'] != null)
                    _detailRow('History', data['history']),
                  const Divider(height: 24),
                ],

                // Medical History Section
                if (_hasMedicalHistory(data)) ...[
                  _sectionHeader('Medical History', Icons.history_edu),
                  const SizedBox(height: 8),
                  if (data['allergies'] != null)
                    _detailRow('Allergies', data['allergies']),
                  if (data['current_medications'] != null)
                    _detailRow('Current Medications', data['current_medications']),
                  if (data['medical_history'] != null)
                    _detailRow('Medical History', data['medical_history']),
                  const Divider(height: 24),
                ],

                // Assessment Section
                if (_hasAssessment(data)) ...[
                  _sectionHeader('Assessment', Icons.assessment),
                  const SizedBox(height: 8),
                  if (data['pain_scale'] != null)
                    _detailRow('Pain Scale', data['pain_scale'].toString()),
                  if (data['consciousness_level'] != null)
                    _detailRow('Consciousness Level', data['consciousness_level']),
                  if (_hasGCS(data)) ...[
                    const SizedBox(height: 8),
                    _detailRow('GCS Eye', data['gcs_eye']?.toString() ?? 'N/A'),
                    _detailRow('GCS Verbal', data['gcs_verbal']?.toString() ?? 'N/A'),
                    _detailRow('GCS Motor', data['gcs_motor']?.toString() ?? 'N/A'),
                    _detailRow('GCS Total', data['gcs_total']?.toString() ?? 'N/A'),
                  ],
                  const Divider(height: 24),
                ],

                // Vital Signs Section
                if (_hasVitalSigns(data)) ...[
                  _sectionHeader('Vital Signs', Icons.favorite),
                  const SizedBox(height: 8),
                  if (data['blood_pressure'] != null)
                    _detailRow('Blood Pressure', data['blood_pressure']),
                  if (data['pulse'] != null)
                    _detailRow('Pulse', data['pulse']),
                  if (data['respiratory'] != null)
                    _detailRow('Respiratory Rate', data['respiratory']),
                  if (data['temperature'] != null)
                    _detailRow('Temperature', data['temperature']),
                  if (data['spo2'] != null)
                    _detailRow('SpO₂', data['spo2']),
                  if (data['blood_glucose'] != null)
                    _detailRow('Blood Glucose', data['blood_glucose']),
                  if (data['pupils'] != null)
                    _detailRow('Pupils', data['pupils']),
                  const Divider(height: 24),
                ],

                // Treatment Section
                if (_hasTreatment(data)) ...[
                  _sectionHeader('Treatment', Icons.medication),
                  const SizedBox(height: 8),
                  if (data['medications_given'] != null)
                    _detailRow('Medications Given', data['medications_given']),
                  if (data['iv_fluids'] != null)
                    _detailRow('IV Fluids', data['iv_fluids']),
                  if (data['treatment_response'] != null)
                    _detailRow('Treatment Response', data['treatment_response']),
                  if (data['treatment_notes'] != null)
                    _detailRow('Treatment Notes', data['treatment_notes']),
                  const Divider(height: 24),
                ],

                // Transport Section
                if (_hasTransportInfo(data)) ...[
                  _sectionHeader('Transport Information', Icons.local_shipping),
                  const SizedBox(height: 8),
                  if (data['time_called'] != null)
                    _detailRow('Time Called', data['time_called']),
                  if (data['time_arrived_scene'] != null)
                    _detailRow('Time Arrived Scene', data['time_arrived_scene']),
                  if (data['time_departed_scene'] != null)
                    _detailRow('Time Departed Scene', data['time_departed_scene']),
                  if (data['time_arrived_hospital'] != null)
                    _detailRow('Time Arrived Hospital', data['time_arrived_hospital']),
                  if (data['transport_method'] != null)
                    _detailRow('Transport Method', data['transport_method']),
                  const Divider(height: 24),
                ],

                // Crew Section
                if (_hasCrewInfo(data)) ...[
                  _sectionHeader('Crew Information', Icons.groups),
                  const SizedBox(height: 8),
                  if (data['primary_crew'] != null)
                    _detailRow('Primary Crew', data['primary_crew']),
                  if (data['secondary_crew'] != null)
                    _detailRow('Secondary Crew', data['secondary_crew']),
                ],

                // Action Buttons
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleShare(context, data),
                        icon: const Icon(Icons.share, size: 20),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handlePreviewPdf(context, data),
                        icon: const Icon(Icons.preview, size: 20),
                        label: const Text('Preview'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleSavePdf(context, data),
                        icon: const Icon(Icons.download, size: 20),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShare(BuildContext context, Map<String, dynamic> formData) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Create form model and enrich with locally saved images
      final formModel = EStreetFormModel.fromJson(formData);
      await _enrichWithLocalImages(formModel);
      
      print('📝 Form model created for sharing...');
      print('   Body diagram screenshot: ${formModel.bodyDiagramScreenshot != null ? "EXISTS (${formModel.bodyDiagramScreenshot!.length} chars)" : "NULL"}');
      print('   Patient signature: ${formModel.patientSignature != null ? "EXISTS" : "NULL"}');
      print('   Body observations: ${formModel.bodyObservations.length} entries');
      
      await EStreetPdfGenerator.sharePdf(formModel, incidentId);

      // Close loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Close loading if open
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSavePdf(BuildContext context, Map<String, dynamic> formData) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Create form model and enrich with locally saved images
      final formModel = EStreetFormModel.fromJson(formData);
      await _enrichWithLocalImages(formModel);
      
      print('📝 Form model created for PDF, checking body diagram...');
      print('   Body diagram screenshot: ${formModel.bodyDiagramScreenshot != null ? "EXISTS (${formModel.bodyDiagramScreenshot!.length} chars)" : "NULL"}');
      print('   Patient signature: ${formModel.patientSignature != null ? "EXISTS" : "NULL"}');
      print('   Body observations: ${formModel.bodyObservations.length} entries');
      
      final filePath = await EStreetPdfGenerator.downloadPdf(formModel, incidentId);

      // Close loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show success with action to view
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PDF saved successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(filePath, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                const Text('📁 Check your Downloads folder or Files app', style: TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error saving PDF: $e');
      // Close loading if open
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving PDF: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handlePreviewPdf(BuildContext context, Map<String, dynamic> formData) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Create form model and enrich with locally saved images
      final formModel = EStreetFormModel.fromJson(formData);
      await _enrichWithLocalImages(formModel);
      
      print('📝 Form model created for PDF preview...');
      print('   Body diagram screenshot: ${formModel.bodyDiagramScreenshot != null ? "EXISTS (${formModel.bodyDiagramScreenshot!.length} chars)" : "NULL"}');
      print('   Patient signature: ${formModel.patientSignature != null ? "EXISTS" : "NULL"}');
      print('   Body observations: ${formModel.bodyObservations.length} entries');

      // Close loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Show PDF preview
      await EStreetPdfGenerator.printPdf(formModel, incidentId);
    } catch (e) {
      print('❌ Error previewing PDF: $e');
      // Close loading if open
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error previewing PDF: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.isEmpty || value == 'null') return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods to check if sections have data
  bool _hasAnyData(Map<String, dynamic> data) {
    return _hasPatientInfo(data) ||
        _hasIncidentDetails(data) ||
        _hasMedicalHistory(data) ||
        _hasAssessment(data) ||
        _hasVitalSigns(data) ||
        _hasTreatment(data) ||
        _hasTransportInfo(data) ||
        _hasCrewInfo(data);
  }

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

  /// Enrich form model with locally saved image data.
  /// The API may not store large base64 signatures/body diagram data,
  /// so we load them from local file storage (saved during form submission).
  Future<void> _enrichWithLocalImages(EStreetFormModel formModel) async {
    try {
      final localData = await EStreetLocalStorage.loadAllImages(incidentId);
      
      if (localData.isEmpty) {
        print('⚠️ No locally saved images found for incident $incidentId');
        return;
      }

      // Only fill in fields that are missing from the API data
      if (formModel.patientSignature == null && localData['patient_signature'] != null) {
        formModel.patientSignature = localData['patient_signature'] as String;
        print('   📎 Loaded patient signature from local storage');
      }
      if (formModel.doctorSignature == null && localData['doctor_signature'] != null) {
        formModel.doctorSignature = localData['doctor_signature'] as String;
        print('   📎 Loaded doctor signature from local storage');
      }
      if (formModel.responderSignature == null && localData['responder_signature'] != null) {
        formModel.responderSignature = localData['responder_signature'] as String;
        print('   📎 Loaded responder signature from local storage');
      }
      if (formModel.bodyDiagramScreenshot == null && localData['body_diagram_screenshot'] != null) {
        formModel.bodyDiagramScreenshot = localData['body_diagram_screenshot'] as String;
        print('   📎 Loaded body diagram from local storage');
      }
      if (formModel.bodyObservations.isEmpty && localData['body_observations'] != null) {
        try {
          final obsStr = localData['body_observations'] as String;
          final decoded = json.decode(obsStr);
          if (decoded is Map) {
            formModel.bodyObservations = decoded.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            );
            print('   📎 Loaded ${formModel.bodyObservations.length} body observations from local storage');
          }
        } catch (e) {
          print('   ⚠️ Error parsing body observations from local storage: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error enriching form model with local images: $e');
    }
  }
}
