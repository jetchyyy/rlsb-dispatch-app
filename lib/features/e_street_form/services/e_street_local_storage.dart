import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Local file storage for e-street form images (signatures & body diagram).
///
/// These are stored as files on the device because the API may not persist
/// large base64 image data. Each image is stored under:
///   `<app_dir>/e_street_images/<incidentId>/<type>.png`
class EStreetLocalStorage {
  static const _rootFolder = 'e_street_images';

  /// Get the storage directory for a given incident
  static Future<Directory> _getDir(int incidentId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_rootFolder/$incidentId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Save a base64 data-url image to local storage.
  /// [type] can be: patient_signature, doctor_signature,
  /// responder_signature, body_diagram_screenshot
  static Future<void> saveImage(
    int incidentId,
    String type,
    String base64DataUrl,
  ) async {
    try {
      final dir = await _getDir(incidentId);
      final file = File('${dir.path}/$type.txt');
      await file.writeAsString(base64DataUrl);
      print('💾 Saved $type for incident $incidentId (${base64DataUrl.length} chars)');
    } catch (e) {
      print('❌ Error saving $type for incident $incidentId: $e');
    }
  }

  /// Load a base64 data-url image from local storage.
  /// Returns null if not found.
  static Future<String?> loadImage(int incidentId, String type) async {
    try {
      final dir = await _getDir(incidentId);
      final file = File('${dir.path}/$type.txt');
      if (await file.exists()) {
        final data = await file.readAsString();
        if (data.isNotEmpty && data != 'null') {
          print('📂 Loaded $type for incident $incidentId (${data.length} chars)');
          return data;
        }
      }
    } catch (e) {
      print('⚠️ Error loading $type for incident $incidentId: $e');
    }
    return null;
  }

  /// Save all signatures and body diagram for an incident.
  static Future<void> saveAllImages({
    required int incidentId,
    String? patientSignature,
    String? doctorSignature,
    String? responderSignature,
    String? bodyDiagramScreenshot,
    Map<String, String>? bodyObservations,
  }) async {
    final futures = <Future>[];

    if (patientSignature != null && patientSignature.isNotEmpty) {
      futures.add(saveImage(incidentId, 'patient_signature', patientSignature));
    }
    if (doctorSignature != null && doctorSignature.isNotEmpty) {
      futures.add(saveImage(incidentId, 'doctor_signature', doctorSignature));
    }
    if (responderSignature != null && responderSignature.isNotEmpty) {
      futures
          .add(saveImage(incidentId, 'responder_signature', responderSignature));
    }
    if (bodyDiagramScreenshot != null && bodyDiagramScreenshot.isNotEmpty) {
      futures.add(
          saveImage(incidentId, 'body_diagram_screenshot', bodyDiagramScreenshot));
    }
    if (bodyObservations != null && bodyObservations.isNotEmpty) {
      futures.add(saveImage(
          incidentId, 'body_observations', jsonEncode(bodyObservations)));
    }

    await Future.wait(futures);
    print('✅ All e-street images saved for incident $incidentId');
  }

  /// Load all stored images and merge them into an EStreetFormModel's fields.
  /// Returns a map of the loaded data.
  static Future<Map<String, dynamic>> loadAllImages(int incidentId) async {
    final results = await Future.wait([
      loadImage(incidentId, 'patient_signature'),
      loadImage(incidentId, 'doctor_signature'),
      loadImage(incidentId, 'responder_signature'),
      loadImage(incidentId, 'body_diagram_screenshot'),
      loadImage(incidentId, 'body_observations'),
    ]);

    final data = <String, dynamic>{};
    if (results[0] != null) data['patient_signature'] = results[0];
    if (results[1] != null) data['doctor_signature'] = results[1];
    if (results[2] != null) data['responder_signature'] = results[2];
    if (results[3] != null) data['body_diagram_screenshot'] = results[3];
    if (results[4] != null) {
      try {
        data['body_observations'] = results[4]; // Keep as JSON string
      } catch (_) {}
    }

    print('📂 Loaded ${data.length} images for incident $incidentId');
    return data;
  }

  /// Delete all stored images for an incident.
  static Future<void> deleteAll(int incidentId) async {
    try {
      final dir = await _getDir(incidentId);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        print('🗑️ Deleted all e-street images for incident $incidentId');
      }
    } catch (e) {
      print('⚠️ Error deleting images for incident $incidentId: $e');
    }
  }
}
