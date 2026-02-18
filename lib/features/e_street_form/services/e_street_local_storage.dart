import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Local file-based storage for E-Street Form images (signatures,
/// body diagram screenshots) that are too large for SharedPreferences.
///
/// Files are stored at: `<appDir>/e_street_images/<incidentId>/<type>.txt`
class EStreetLocalStorage {
  EStreetLocalStorage._();

  static Future<Directory> _dir(int incidentId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/e_street_images/$incidentId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Save a single base64 data URI to disk.
  static Future<void> saveImage(
    int incidentId,
    String type,
    String base64DataUri,
  ) async {
    final dir = await _dir(incidentId);
    final file = File('${dir.path}/$type.txt');
    await file.writeAsString(base64DataUri);
  }

  /// Load a single image from disk. Returns `null` if not found.
  static Future<String?> loadImage(int incidentId, String type) async {
    try {
      final dir = await _dir(incidentId);
      final file = File('${dir.path}/$type.txt');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }

  /// Save all image fields at once.
  static Future<void> saveAllImages({
    required int incidentId,
    String? patientSignature,
    String? doctorSignature,
    String? responderSignature,
    String? bodyDiagramScreenshot,
  }) async {
    final futures = <Future>[];
    if (patientSignature != null && patientSignature.isNotEmpty) {
      futures.add(saveImage(incidentId, 'patient_signature', patientSignature));
    }
    if (doctorSignature != null && doctorSignature.isNotEmpty) {
      futures.add(saveImage(incidentId, 'doctor_signature', doctorSignature));
    }
    if (responderSignature != null && responderSignature.isNotEmpty) {
      futures.add(saveImage(incidentId, 'responder_signature', responderSignature));
    }
    if (bodyDiagramScreenshot != null && bodyDiagramScreenshot.isNotEmpty) {
      futures.add(saveImage(incidentId, 'body_diagram_screenshot', bodyDiagramScreenshot));
    }
    await Future.wait(futures);
  }

  /// Load all stored images for an incident.
  static Future<Map<String, String?>> loadAllImages(int incidentId) async {
    final results = await Future.wait([
      loadImage(incidentId, 'patient_signature'),
      loadImage(incidentId, 'doctor_signature'),
      loadImage(incidentId, 'responder_signature'),
      loadImage(incidentId, 'body_diagram_screenshot'),
    ]);
    return {
      'patient_signature': results[0],
      'doctor_signature': results[1],
      'responder_signature': results[2],
      'body_diagram_screenshot': results[3],
    };
  }

  /// Delete all stored images for an incident.
  static Future<void> deleteAll(int incidentId) async {
    try {
      final dir = await _dir(incidentId);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
