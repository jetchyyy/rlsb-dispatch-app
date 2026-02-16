import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../models/e_street_form_model.dart';

/// Service for generating PDF from E-Street Form data
class EStreetPdfGenerator {
  /// Generate a PDF document from the E-Street form
  static Future<Uint8List> generatePdf(
    EStreetFormModel form,
    int incidentId,
  ) async {
    final pdf = pw.Document();

    // Page theme
    final theme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.robotoRegular(),
      bold: await PdfGoogleFonts.robotoBold(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (pw.Context context) => [
          _buildHeader(incidentId),
          pw.SizedBox(height: 20),
          _buildPatientInfo(form),
          pw.SizedBox(height:15),
          _buildMedicalAssessment(form),
          pw.SizedBox(height: 15),
          _buildTreatment(form),
          pw.SizedBox(height: 15),
          _buildTransport(form),
          pw.SizedBox(height: 15),
          _buildSignatures(form),
          // Always show body observations section (shows "no data" message if empty)
          pw.SizedBox(height: 15),
          _buildBodyObservations(form),
        ],
      ),
    );

    return pdf.save();
  }

  /// Save PDF to device and return the file path
  static Future<String> savePdfToDevice(
    EStreetFormModel form,
    int incidentId,
  ) async {
    final pdfData = await generatePdf(form, incidentId);
    
    // Try to get Downloads directory, fallback to Documents
    Directory? directory;
    if (Platform.isAndroid) {
      // On Android, save to Downloads folder
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${directory!.path}/e_street_form_${incidentId}_$timestamp.pdf');
    
    await file.writeAsBytes(pdfData);
    print('✅ PDF saved to: ${file.path}');
    return file.path;
  }

  /// Print or preview the PDF
  static Future<void> printPdf(
    EStreetFormModel form,
    int incidentId,
  ) async {
    final pdfData = await generatePdf(form, incidentId);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
    );
  }

  /// Share the PDF via system share dialog
  static Future<void> sharePdf(
    EStreetFormModel form,
    int incidentId,
  ) async {
    final pdfData = await generatePdf(form, incidentId);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    await Printing.sharePdf(
      bytes: pdfData,
      filename: 'e_street_form_${incidentId}_$timestamp.pdf',
    );
  }

  /// Download/Save the PDF to device
  static Future<String> downloadPdf(
    EStreetFormModel form,
    int incidentId,
  ) async {
    return await savePdfToDevice(form, incidentId);
  }

  /// Header section
  static pw.Widget _buildHeader(int incidentId) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue700, width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'E-STREET FORM',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Pre-Hospital Emergency Care Report',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.Divider(thickness: 1, color: PdfColors.blue700),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Incident ID: $incidentId',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(
                'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Patient Information section
  static pw.Widget _buildPatientInfo(EStreetFormModel form) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('PATIENT INFORMATION'),
          pw.SizedBox(height: 8),
          _buildGrid([
            _field('Name', form.name),
            _field('Age', form.age ?? 'N/A'),
            _field('Sex', form.sex ?? 'N/A'),
            _field('Date of Birth', form.dateOfBirth ?? 'N/A'),
            _field('Address', form.address ?? 'N/A'),
            _field('Emergency Contact', form.emergencyContact ?? 'N/A'),
            _field('Incident Date/Time', form.incidentDatetime ?? 'N/A'),
            _field('Allergies', form.allergies ?? 'None'),
            _field('Current Medications', form.currentMedications ?? 'None'),
            _field('Medical History', form.medicalHistory ?? 'None'),
          ]),
        ],
      ),
    );
  }

  /// Medical Assessment section
  static pw.Widget _buildMedicalAssessment(EStreetFormModel form) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('MEDICAL ASSESSMENT'),
          pw.SizedBox(height: 8),
          _buildGrid([
            _field('Chief Complaint', form.chiefComplaint),
            _field('History', form.history ?? 'N/A'),
            _field('Pain Scale', form.painScale?.toString() ?? 'N/A'),
            _field('Consciousness Level', form.consciousnessLevel ?? 'N/A'),
            _field('GCS Total', '${form.gcsTotal} (E${form.gcsEye ?? 0} V${form.gcsVerbal ?? 0} M${form.gcsMotor ?? 0})'),
            _field('Blood Pressure', form.bloodPressure ?? 'N/A'),
            _field('Pulse', form.pulse ?? 'N/A'),
            _field('Respiratory Rate', form.respiratory ?? 'N/A'),
            _field('Temperature', form.temperature ?? 'N/A'),
            _field('SpO2', form.spo2 ?? 'N/A'),
            _field('Blood Glucose', form.bloodGlucose ?? 'N/A'),
            _field('Pupils', form.pupils ?? 'N/A'),
            _field('Skin Condition', form.skin.join(', ').isEmpty ? 'N/A' : form.skin.join(', ')),
          ]),
        ],
      ),
    );
  }

  /// Treatment section
  static pw.Widget _buildTreatment(EStreetFormModel form) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('TREATMENT & INTERVENTIONS'),
          pw.SizedBox(height: 8),
          _buildGrid([
            _field('First Aid', form.aid.join(', ').isEmpty ? 'N/A' : form.aid.join(', ')),
            _field('Equipment Used', form.equipment.join(', ').isEmpty ? 'N/A' : form.equipment.join(', ')),
            _field('Medications Given', form.medicationsGiven ?? 'N/A'),
            _field('IV Fluids', form.ivFluids ?? 'N/A'),
            _field('Treatment Response', form.treatmentResponse ?? 'N/A'),
            _field('Treatment Notes', form.treatmentNotes ?? 'N/A'),
          ]),
        ],
      ),
    );
  }

  /// Transport section
  static pw.Widget _buildTransport(EStreetFormModel form) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('TRANSPORT & OUTCOME'),
          pw.SizedBox(height: 8),
          _buildGrid([
            _field('Time Called', form.timeCalled ?? 'N/A'),
            _field('Time Arrived Scene', form.timeArrivedScene ?? 'N/A'),
            _field('Time Departed Scene', form.timeDepartedScene ?? 'N/A'),
            _field('Time Arrived Hospital', form.timeArrivedHospital ?? 'N/A'),
            _field('Ambulance Type', form.ambulanceType.join(', ').isEmpty ? 'N/A' : form.ambulanceType.join(', ')),
            _field('Transport Method', form.transportMethod ?? 'N/A'),
            _field('Hospital', form.hospital ?? form.hospitalOther ?? 'N/A'),
            _field('Passengers', form.passenger.join(', ').isEmpty ? 'N/A' : form.passenger.join(', ')),
            _field('Primary Crew', form.primaryCrew ?? 'N/A'),
            _field('Secondary Crew', form.secondaryCrew ?? 'N/A'),
            _field('Final Outcome', form.finalOutcome ?? 'N/A'),
            _field('Doctor Name', form.doctorName ?? 'N/A'),
            _field('License Number', form.licenseNumber ?? 'N/A'),
            _field('Physician Report', form.physicianReport ?? 'N/A'),
          ]),
        ],
      ),
    );
  }

  /// Signatures section
  static pw.Widget _buildSignatures(EStreetFormModel form) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('SIGNATURES & DOCUMENTATION'),
          pw.SizedBox(height: 8),
          _field('Final Comments', form.finalComments ?? 'None'),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _signatureBoxWithImage('Patient Signature', form.patientSignature),
              _signatureBoxWithImage('Doctor Signature', form.doctorSignature),
              _signatureBoxWithImage('Responder Signature', form.responderSignature),
            ],
          ),
        ],
      ),
    );
  }

  /// Body observations section
  static pw.Widget _buildBodyObservations(EStreetFormModel form) {
    // Debug: Check if body diagram data exists
    print('🔍 Body Diagram Debug:');
    print('   - Screenshot exists: ${form.bodyDiagramScreenshot != null}');
    if (form.bodyDiagramScreenshot != null) {
      print('   - Screenshot length: ${form.bodyDiagramScreenshot!.length} chars');
      print('   - First 100 chars: ${form.bodyDiagramScreenshot!.substring(0, form.bodyDiagramScreenshot!.length > 100 ? 100 : form.bodyDiagramScreenshot!.length)}');
    }
    print('   - Observations count: ${form.bodyObservations.length}');
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('BODY INJURY MAPPER'),
          pw.SizedBox(height: 8),
          
          // Show body diagram screenshot if available
          if (form.bodyDiagramScreenshot != null && 
              form.bodyDiagramScreenshot!.isNotEmpty &&
              form.bodyDiagramScreenshot != 'null') ...[
            pw.Text(
              'Injury Diagram:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
            pw.SizedBox(height: 8),
            _buildBodyDiagramImage(form.bodyDiagramScreenshot!),
            pw.SizedBox(height: 12),
          ],
          
          // Show text observations
          if (form.bodyObservations.isNotEmpty) ...[
            pw.Text(
              'Injury Details:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
            pw.SizedBox(height: 8),
            ...form.bodyObservations.entries.map(
              (entry) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 100,
                      child: pw.Text(
                        entry.key,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        entry.value,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // If no data at all
          if (form.bodyObservations.isEmpty && 
              (form.bodyDiagramScreenshot == null || 
               form.bodyDiagramScreenshot!.isEmpty ||
               form.bodyDiagramScreenshot == 'null'))
            pw.Text(
              'No injury observations recorded',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
            ),
        ],
      ),
    );
  }

  /// Helper: Section title
  static pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900,
      ),
    );
  }

  /// Helper: Field row
  static pw.Widget _field(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 140,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper: Build grid layout for fields
  static pw.Widget _buildGrid(List<pw.Widget> fields) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: fields,
    );
  }

  /// Helper: Signature box with actual image rendering
  static pw.Widget _signatureBoxWithImage(String label, String? signatureData) {
    // Try to render the actual signature image
    if (signatureData != null && signatureData.isNotEmpty) {
      try {
        final imageBytes = _decodeBase64Image(signatureData);
        if (imageBytes != null && imageBytes.length > 100) {
          final image = pw.MemoryImage(imageBytes);
          return pw.Column(
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                width: 150,
                height: 55,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
            ],
          );
        }
      } catch (e) {
        print('⚠️ Error rendering signature for $label: $e');
      }
    }

    // Fallback: show empty signature box
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: 150,
          height: 55,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Center(
            child: pw.Text(
              signatureData != null ? '✓ Signed' : 'Not signed',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: signatureData != null ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: signatureData != null ? PdfColors.green700 : PdfColors.grey600,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  /// Helper: Build body diagram image widget
  static pw.Widget _buildBodyDiagramImage(String base64String) {
    try {
      print('🖼️  Attempting to decode body diagram image...');
      final imageBytes = _decodeBase64Image(base64String);
      if (imageBytes != null && imageBytes.length > 100) {
        print('   ✅ Image decoded successfully: ${imageBytes.length} bytes');
        final image = pw.MemoryImage(imageBytes);
        return pw.Container(
          height: 300,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            color: PdfColors.grey50,
          ),
          child: pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        );
      } else {
        print('   ❌ Image decoding returned null or too small');
        return pw.Container(
          height: 60,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Center(
            child: pw.Text(
              'Injury diagram data could not be decoded',
              style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10, fontStyle: pw.FontStyle.italic),
            ),
          ),
        );
      }
    } catch (e) {
      // If image fails to load, show error message
      print('   ❌ Error decoding image: $e');
      return pw.Container(
        height: 60,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.orange),
          color: PdfColors.orange50,
        ),
        child: pw.Center(
          child: pw.Text(
            'Error loading injury diagram image: ${e.toString()}',
            style: pw.TextStyle(color: PdfColors.orange900, fontSize: 9),
          ),
        ),
      );
    }
  }
  
  /// Helper: Decode base64 image string
  static Uint8List? _decodeBase64Image(String base64String) {
    try {
      print('   🔄 Decoding base64 string...');
      // Remove data:image prefix if present
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        print('   📌 Found comma, splitting...');
        cleanBase64 = base64String.split(',').last;
      }
      print('   📏 Clean base64 length: ${cleanBase64.length}');
      final decoded = base64Decode(cleanBase64);
      print('   ✅ Decoded to ${decoded.length} bytes');
      return decoded;
    } catch (e) {
      print('   ❌ Decode error: $e');
      return null;
    }
  }
}
