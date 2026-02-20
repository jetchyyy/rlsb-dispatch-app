import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../models/e_street_form_model.dart';

/// Service for submitting / fetching E-Street Form data via the API.
///
/// Uses multipart/form-data encoding so PHP-style array fields
/// (`skin[]`, `aid[]`, etc.) are handled correctly by the Laravel backend.
class EStreetApiService {
  final Dio _dio;

  EStreetApiService._(this._dio);

  /// Factory that reads the auth token from SharedPreferences and
  /// creates a configured Dio client.
  static Future<EStreetApiService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConstants.tokenKey);

    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ));

    return EStreetApiService._(dio);
  }

  /// Submit a completed (or partial) E-Street Form.
  ///
  /// Returns the API response map containing:
  /// - `success` (bool)
  /// - `pdf_url` (String) — full URL to the generated PDF
  /// - `patient_signature_path`, `doctor_signature_path`, `responder_signature_path`
  ///
  /// Throws [DioException] on network / validation errors.
  Future<Map<String, dynamic>> submitForm({
    required int incidentId,
    required EStreetFormModel form,
  }) async {
    final endpoint = ApiConstants.eStreetForm(incidentId);
    final rawData = form.toFormData();

    // Build FormData with proper array handling.
    // Dio FormData handles List values as repeated keys with [] suffix.
    final formData = FormData();

    rawData.forEach((key, value) {
      if (value is List) {
        for (final item in value) {
          formData.fields.add(MapEntry('$key[]', item.toString()));
        }
      } else if (value is Map) {
        // Maps must be JSON-encoded before adding to FormData
        formData.fields.add(MapEntry(key, jsonEncode(value)));
      } else {
        formData.fields.add(MapEntry(key, value.toString()));
      }
    });

    final response = await _dio.post(
      endpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Fetch an existing E-Street Form for the given incident.
  ///
  /// Returns `null` if no form exists (404) or the server endpoint
  /// is not available (500 for missing controller method).
  Future<EStreetFormModel?> fetchForm(int incidentId) async {
    try {
      final endpoint = ApiConstants.eStreetForm(incidentId);
      final response = await _dio.get(endpoint);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          // The server may nest under 'e_street_form', 'data', or return flat
          final formJson = data['e_street_form'] ?? data['data'] ?? data;
          if (formJson is Map<String, dynamic>) {
            return EStreetFormModel.fromJson(formJson);
          }
        }
      }
      return null;
    } on DioException catch (e) {
      // 404 = no form exists yet; 500 = `show` method not implemented
      if (e.response?.statusCode == 404 || e.response?.statusCode == 500) {
        return null;
      }
      rethrow;
    }
  }
}
