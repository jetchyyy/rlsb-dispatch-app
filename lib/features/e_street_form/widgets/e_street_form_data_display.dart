import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../models/e_street_form_model.dart';
import '../screens/pdf_viewer_screen.dart';

/// Read-only display of a submitted E-Street Form.
///
/// Parses the JSON string stored on the incident, renders all
/// sections, and provides PDF action buttons that use the
/// server-generated PDF (same as MIS web version).
class EStreetFormDataDisplay extends StatelessWidget {
  final String? eStreetFormJson;
  final String? eStreetFormPdfPath;
  final int incidentId;

  const EStreetFormDataDisplay({
    super.key,
    required this.eStreetFormJson,
    this.eStreetFormPdfPath,
    required this.incidentId,
  });

  /// Returns the full URL to the server-generated PDF.
  String? get serverPdfUrl {
    if (eStreetFormPdfPath == null || eStreetFormPdfPath!.isEmpty) return null;
    return '${ApiConstants.storageBaseUrl}/$eStreetFormPdfPath';
  }

  @override
  Widget build(BuildContext context) {
    if (eStreetFormJson == null || eStreetFormJson!.isEmpty) {
      return const SizedBox.shrink();
    }

    EStreetFormModel? form;
    try {
      final json = jsonDecode(eStreetFormJson!);
      if (json is Map<String, dynamic>) {
        form = EStreetFormModel.fromJson(json);
      }
    } catch (_) {}

    if (form == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Actions
            Row(
              children: [
                const Icon(Icons.assignment, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'E-Street Form',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _ActionButtons(pdfUrl: serverPdfUrl, incidentId: incidentId),
              ],
            ),
            const Divider(height: 20),

            // Patient Info
            if (_hasPatientInfo(form)) ...[
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
            if (_hasAssessment(form)) ...[
              _sectionTitle('Medical Assessment'),
              _fieldRow('Chief Complaint', form.chiefComplaint),
              _fieldRow('History', form.history),
              _fieldRow('Pain Scale', form.painScale?.toString()),
              _fieldRow('Consciousness', form.consciousnessLevel),
              if (form.gcsEye != null || form.gcsVerbal != null || form.gcsMotor != null)
                _fieldRow(
                  'GCS',
                  'E${form.gcsEye ?? "-"} V${form.gcsVerbal ?? "-"} M${form.gcsMotor ?? "-"} = ${form.gcsTotal}',
                ),
              _fieldRow('Pupils', form.pupils),
              const SizedBox(height: 4),
            ],

            // Vital Signs
            if (_hasVitals(form)) ...[
              _sectionTitle('Vital Signs'),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (form.bloodPressure != null) _vitalChip('BP', form.bloodPressure!),
                  if (form.pulse != null) _vitalChip('Pulse', form.pulse!),
                  if (form.respiratory != null) _vitalChip('Resp', form.respiratory!),
                  if (form.temperature != null) _vitalChip('Temp', form.temperature!),
                  if (form.spo2 != null) _vitalChip('SpO₂', form.spo2!),
                  if (form.bloodGlucose != null) _vitalChip('Glucose', form.bloodGlucose!),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Skin Assessment
            if (form.skin.isNotEmpty) ...[
              _sectionTitle('Skin Assessment'),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: form.skin
                    .map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Treatment
            if (_hasTreatment(form)) ...[
              _sectionTitle('Treatment & Interventions'),
              if (form.aid.isNotEmpty)
                _chipList('Aid Provided', form.aid),
              _fieldRow('Medications Given', form.medicationsGiven),
              _fieldRow('IV Fluids', form.ivFluids),
              if (form.equipment.isNotEmpty)
                _chipList('Equipment Used', form.equipment),
              _fieldRow('Treatment Response', form.treatmentResponse),
              _fieldRow('Treatment Notes', form.treatmentNotes),
              const SizedBox(height: 12),
            ],

            // Transport
            if (_hasTransport(form)) ...[
              _sectionTitle('Transport & Outcome'),
              if (form.timeCalled != null ||
                  form.timeArrivedScene != null ||
                  form.timeDepartedScene != null ||
                  form.timeArrivedHospital != null) ...[
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (form.timeCalled != null)
                      _vitalChip('Called', form.timeCalled!),
                    if (form.timeArrivedScene != null)
                      _vitalChip('On Scene', form.timeArrivedScene!),
                    if (form.timeDepartedScene != null)
                      _vitalChip('Departed', form.timeDepartedScene!),
                    if (form.timeArrivedHospital != null)
                      _vitalChip('At Hospital', form.timeArrivedHospital!),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (form.ambulanceType.isNotEmpty)
                _chipList('Ambulance Type', form.ambulanceType),
              _fieldRow('Transport Method', form.transportMethod),
              _fieldRow('Hospital', form.hospital == 'OTHER' ? form.hospitalOther : form.hospital),
              if (form.passenger.isNotEmpty)
                _chipList('Passengers', form.passenger),
              _fieldRow('Primary Crew', form.primaryCrew),
              _fieldRow('Secondary Crew', form.secondaryCrew),
              _fieldRow('Final Outcome', form.finalOutcome),
              const SizedBox(height: 12),
            ],

            // Doctor / Physician
            if (_hasDoctor(form)) ...[
              _sectionTitle('Receiving Physician'),
              _fieldRow('Doctor Name', form.doctorName),
              _fieldRow('License Number', form.licenseNumber),
              _fieldRow('Hospital', form.hospital == 'OTHER' ? form.hospitalOther : form.hospital),
              _fieldRow('Physician Report', form.physicianReport),
              const SizedBox(height: 12),
            ],

            // Body Observations
            if (form.bodyObservations.isNotEmpty) ...[
              _sectionTitle('Body Observations'),
              ...form.bodyObservations.entries.map((e) {
                final label = e.key.replaceAll('_', ' ').split(' ').map(
                  (w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}',
                ).join(' ');
                return _fieldRow(label, e.value);
              }),
              const SizedBox(height: 12),
            ],

            // Final Comments
            if (form.finalComments != null && form.finalComments!.isNotEmpty) ...[
              _sectionTitle('Final Comments'),
              Text(form.finalComments!, style: const TextStyle(fontSize: 13)),
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
    );
  }

  // ── Section helpers ─────────────────────────────────────

  static Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  static Widget _fieldRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  static Widget _vitalChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static Widget _chipList(String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Wrap(
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

  static Widget _signatureIndicator(String label, String? data) {
    final signed = data != null && data.isNotEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          signed ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: signed ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // ── Has-data checks ─────────────────────────────────────

  bool _hasPatientInfo(EStreetFormModel f) =>
      f.name.isNotEmpty ||
      f.age != null ||
      f.sex != null ||
      f.address != null ||
      f.dateOfBirth != null;

  bool _hasAssessment(EStreetFormModel f) =>
      f.chiefComplaint.isNotEmpty ||
      f.history != null ||
      f.painScale != null ||
      f.consciousnessLevel != null ||
      f.pupils != null;

  bool _hasVitals(EStreetFormModel f) =>
      f.bloodPressure != null ||
      f.pulse != null ||
      f.respiratory != null ||
      f.temperature != null ||
      f.spo2 != null ||
      f.bloodGlucose != null;

  bool _hasTreatment(EStreetFormModel f) =>
      f.aid.isNotEmpty ||
      f.medicationsGiven != null ||
      f.ivFluids != null ||
      f.equipment.isNotEmpty ||
      f.treatmentResponse != null ||
      f.treatmentNotes != null;

  bool _hasTransport(EStreetFormModel f) =>
      f.timeCalled != null ||
      f.timeArrivedScene != null ||
      f.transportMethod != null ||
      f.ambulanceType.isNotEmpty ||
      f.primaryCrew != null ||
      f.finalOutcome != null;

  bool _hasDoctor(EStreetFormModel f) =>
      f.doctorName != null || f.licenseNumber != null || f.physicianReport != null;
}

/// PDF action buttons that use the server-generated PDF.
///
/// - View: Opens in-app PDF viewer
/// - Share: Downloads and shares the PDF file
/// - Download: Downloads to device Downloads folder
/// - Open in Browser: Opens the PDF URL in external browser
class _ActionButtons extends StatefulWidget {
  final String? pdfUrl;
  final int incidentId;

  const _ActionButtons({required this.pdfUrl, required this.incidentId});

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  bool _isLoading = false;
  String? _localPath;

  /// Downloads the PDF to a temp file and returns the local path.
  Future<String?> _downloadPdf() async {
    if (widget.pdfUrl == null) return null;
    if (_localPath != null && File(_localPath!).existsSync()) {
      return _localPath;
    }

    try {
      setState(() => _isLoading = true);
      final dir = await getTemporaryDirectory();
      final fileName = 'e_street_form_${widget.incidentId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$fileName';

      await Dio().download(widget.pdfUrl!, filePath);
      _localPath = filePath;
      return filePath;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.error),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _viewPdf() async {
    if (widget.pdfUrl == null) {
      _showNoPdfError();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfViewerScreen(pdfUrl: widget.pdfUrl!)),
    );
  }

  Future<void> _sharePdf() async {
    if (widget.pdfUrl == null) {
      _showNoPdfError();
      return;
    }
    final path = await _downloadPdf();
    if (path != null) {
      await Share.shareXFiles([XFile(path)], text: 'E-Street Form #${widget.incidentId}');
    }
  }

  Future<void> _savePdf() async {
    if (widget.pdfUrl == null) {
      _showNoPdfError();
      return;
    }
    try {
      setState(() => _isLoading = true);
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }
      final fileName = 'EStreet_Form_${widget.incidentId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final destPath = '${downloadsDir.path}/$fileName';

      await Dio().download(widget.pdfUrl!, destPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to Downloads/$fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openInBrowser() async {
    if (widget.pdfUrl == null) {
      _showNoPdfError();
      return;
    }
    final uri = Uri.parse(widget.pdfUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showNoPdfError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF not available. Submit the form first.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf, size: 18),
          tooltip: 'View PDF',
          onPressed: _viewPdf,
        ),
        IconButton(
          icon: const Icon(Icons.share, size: 18),
          tooltip: 'Share PDF',
          onPressed: _sharePdf,
        ),
        IconButton(
          icon: const Icon(Icons.download, size: 18),
          tooltip: 'Save to Downloads',
          onPressed: _savePdf,
        ),
        IconButton(
          icon: const Icon(Icons.open_in_browser, size: 18),
          tooltip: 'Open in Browser',
          onPressed: _openInBrowser,
        ),
      ],
    );
  }
}
