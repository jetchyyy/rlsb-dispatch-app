import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/e_street_form_model.dart';

/// Generates, previews, shares and downloads PDF reports from form data.
///
/// This is for **client-side** PDF generation (offline, share, print).
/// The server also generates its own PDF; see [EStreetApiService].
class EStreetPdfGenerator {
  EStreetPdfGenerator._();

  // ── Public API ──────────────────────────────────────────

  /// Generate a PDF as bytes.
  static Future<Uint8List> generatePdf(
    EStreetFormModel form,
    int incidentId,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        _buildHeader(incidentId),
        pw.SizedBox(height: 16),
        _buildPatientInfo(form),
        pw.SizedBox(height: 12),
        _buildMedicalAssessment(form),
        pw.SizedBox(height: 12),
        _buildTreatment(form),
        pw.SizedBox(height: 12),
        _buildTransport(form),
        pw.SizedBox(height: 12),
        _buildSignatures(form),
        pw.SizedBox(height: 12),
        _buildBodyObservations(form),
        if (form.finalComments != null && form.finalComments!.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _sectionTitle('Final Comments'),
          pw.Text(form.finalComments!),
        ],
      ],
    ));

    return pdf.save();
  }

  /// Save PDF to the device Downloads directory.
  static Future<String> savePdfToDevice(
    EStreetFormModel form,
    int incidentId,
  ) async {
    final bytes = await generatePdf(form, incidentId);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/e_street_form_$incidentId.pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Open the system print dialog.
  static Future<void> printPdf(
    EStreetFormModel form,
    int incidentId,
  ) async {
    final bytes = await generatePdf(form, incidentId);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  /// Share the PDF via OS share sheet.
  static Future<void> sharePdf(
    EStreetFormModel form,
    int incidentId,
  ) async {
    final bytes = await generatePdf(form, incidentId);
    await Printing.sharePdf(bytes: bytes, filename: 'e_street_form_$incidentId.pdf');
  }

  // ── PDF Sections ────────────────────────────────────────

  static pw.Widget _buildHeader(int incidentId) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'E-STREET FORM',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('Incident #$incidentId', style: const pw.TextStyle(fontSize: 12)),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildPatientInfo(EStreetFormModel form) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Patient Information'),
        _buildGrid([
          _field('Name', form.name),
          _field('Age', form.age),
          _field('Sex', form.sex),
          _field('Date of Birth', form.dateOfBirth),
          _field('Address', form.address),
          _field('Emergency Contact', form.emergencyContact),
          _field('Incident Date/Time', form.incidentDatetime),
          _field('Allergies', form.allergies),
          _field('Current Medications', form.currentMedications),
          _field('Medical History', form.medicalHistory),
        ]),
      ],
    );
  }

  static pw.Widget _buildMedicalAssessment(EStreetFormModel form) {
    final gcs = (form.gcsEye != null || form.gcsVerbal != null || form.gcsMotor != null)
        ? 'E${form.gcsEye ?? "-"} V${form.gcsVerbal ?? "-"} M${form.gcsMotor ?? "-"} = ${form.gcsTotal}'
        : null;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Medical Assessment'),
        _buildGrid([
          _field('Chief Complaint', form.chiefComplaint),
          _field('History', form.history),
          _field('Pain Scale', form.painScale?.toString()),
          _field('Consciousness', form.consciousnessLevel),
          _field('GCS', gcs),
          _field('Pupils', form.pupils),
          _field('Blood Pressure', form.bloodPressure),
          _field('Pulse', form.pulse),
          _field('Respiratory', form.respiratory),
          _field('Temperature', form.temperature),
          _field('SpO₂', form.spo2),
          _field('Blood Glucose', form.bloodGlucose),
        ]),
        if (form.skin.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _field('Skin Assessment', form.skin.join(', ')),
        ],
      ],
    );
  }

  static pw.Widget _buildTreatment(EStreetFormModel form) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Treatment & Interventions'),
        if (form.aid.isNotEmpty) _field('Aid Provided', form.aid.join(', ')),
        _buildGrid([
          _field('Medications Given', form.medicationsGiven),
          _field('IV Fluids', form.ivFluids),
          _field('Treatment Response', form.treatmentResponse),
        ]),
        if (form.equipment.isNotEmpty)
          _field('Equipment Used', form.equipment.join(', ')),
        if (form.treatmentNotes != null && form.treatmentNotes!.isNotEmpty)
          _field('Treatment Notes', form.treatmentNotes),
      ],
    );
  }

  static pw.Widget _buildTransport(EStreetFormModel form) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Transport & Outcome'),
        _buildGrid([
          _field('Time Called', form.timeCalled),
          _field('Arrived Scene', form.timeArrivedScene),
          _field('Departed Scene', form.timeDepartedScene),
          _field('Arrived Hospital', form.timeArrivedHospital),
          _field('Transport Method', form.transportMethod),
          _field('Hospital', form.hospital == 'OTHER' ? form.hospitalOther : form.hospital),
          _field('Primary Crew', form.primaryCrew),
          _field('Secondary Crew', form.secondaryCrew),
          _field('Final Outcome', form.finalOutcome),
          _field('Doctor Name', form.doctorName),
          _field('License Number', form.licenseNumber),
        ]),
        if (form.ambulanceType.isNotEmpty)
          _field('Ambulance Type', form.ambulanceType.join(', ')),
        if (form.passenger.isNotEmpty)
          _field('Passengers', form.passenger.join(', ')),
        if (form.physicianReport != null && form.physicianReport!.isNotEmpty)
          _field('Physician Report', form.physicianReport),
      ],
    );
  }

  static pw.Widget _buildSignatures(EStreetFormModel form) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Signatures'),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            _signatureBox('Patient', form.patientSignature),
            _signatureBox('Doctor', form.doctorSignature),
            _signatureBox('Responder', form.responderSignature),
          ],
        ),
      ],
    );
  }

  static pw.Widget _signatureBox(String label, String? base64Data) {
    pw.Widget content;
    if (base64Data != null && base64Data.contains('base64,')) {
      try {
        final b64 = base64Data.split('base64,').last;
        final bytes = base64Decode(b64);
        content = pw.Image(pw.MemoryImage(bytes), width: 120, height: 50, fit: pw.BoxFit.contain);
      } catch (_) {
        content = pw.Text(
          '✓ Signed',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        );
      }
    } else {
      content = pw.Text('Not signed', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey));
    }

    return pw.Container(
      width: 140,
      height: 70,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Center(child: content)),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  static pw.Widget _buildBodyObservations(EStreetFormModel form) {
    if (form.bodyObservations.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Body Observations'),
        // Body diagram image if available.
        if (form.bodyDiagramScreenshot != null &&
            form.bodyDiagramScreenshot!.contains('base64,'))
          _buildBodyDiagramImage(form.bodyDiagramScreenshot!),
        pw.SizedBox(height: 8),
        ...form.bodyObservations.entries.map((e) {
          final label = e.key.replaceAll('_', ' ').split(' ').map(
            (w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}',
          ).join(' ');
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 140,
                  child: pw.Text(label,
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(child: pw.Text(e.value, style: const pw.TextStyle(fontSize: 10))),
              ],
            ),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildBodyDiagramImage(String base64Data) {
    try {
      final b64 = base64Data.split('base64,').last;
      final bytes = base64Decode(b64);
      return pw.Center(
        child: pw.Image(pw.MemoryImage(bytes), height: 250, fit: pw.BoxFit.contain),
      );
    } catch (_) {
      return pw.SizedBox();
    }
  }

  // ── Helpers ─────────────────────────────────────────────

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#1e3a8a')),
      ),
    );
  }

  static pw.Widget _field(String label, String? value) {
    if (value == null || value.trim().isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 10)),
        ]),
      ),
    );
  }

  static pw.Widget _buildGrid(List<pw.Widget> items) {
    // Filter out empty SizedBox widgets
    final nonEmpty = items.where((w) => w is! pw.SizedBox).toList();
    if (nonEmpty.isEmpty) return pw.SizedBox();

    final rows = <pw.TableRow>[];
    for (var i = 0; i < nonEmpty.length; i += 2) {
      rows.add(pw.TableRow(children: [
        pw.Padding(padding: const pw.EdgeInsets.all(2), child: nonEmpty[i]),
        pw.Padding(
          padding: const pw.EdgeInsets.all(2),
          child: i + 1 < nonEmpty.length ? nonEmpty[i + 1] : pw.SizedBox(),
        ),
      ]));
    }
    return pw.Table(children: rows);
  }
}
