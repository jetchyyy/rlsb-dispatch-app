import 'dart:convert';
<<<<<<< Updated upstream
import 'package:flutter/foundation.dart';
=======
>>>>>>> Stashed changes

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

    int totalSize = 0;
    final fieldSizes = <String, int>{};

    rawData.forEach((key, value) {
      if (value is List) {
<<<<<<< Updated upstream
        if (value.isNotEmpty) {
          for (final item in value) {
            formData.fields.add(MapEntry('$key[]', item.toString()));
          }
        }
      } else if (value is Map) {
        if (value.isNotEmpty) {
          // Maps must be JSON-encoded before adding to FormData
          formData.fields.add(MapEntry(key, jsonEncode(value)));
=======
        for (final item in value) {
          final itemStr = item.toString();
          final size = itemStr.length;
          totalSize += size;
          fieldSizes[key] = (fieldSizes[key] ?? 0) + size;
          formData.fields.add(MapEntry('$key[]', itemStr));
>>>>>>> Stashed changes
        }
      } else if (value is Map) {
        // If value is still a Map, JSON encode it
        final jsonStr = jsonEncode(value);
        final size = jsonStr.length;
        totalSize += size;
        fieldSizes[key] = size;
        formData.fields.add(MapEntry(key, jsonStr));
      } else {
        final valueStr = value.toString();
        final size = valueStr.length;
        totalSize += size;
        fieldSizes[key] = size;
        formData.fields.add(MapEntry(key, valueStr));
      }
    });

<<<<<<< Updated upstream
    try {
      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      debugPrint(
          '🚨 EStreetApiService submit error: ${e.response?.statusCode}');
      debugPrint('🚨 Response Data: ${e.response?.data}');
=======
    // Log payload size information
    print('\n═══════════════════════════════════════════════════');
    print('📤 E-STREET FORM SUBMISSION');
    print('═══════════════════════════════════════════════════');
    print('  📍 Incident ID: $incidentId');
    print('  📦 Total Payload Size: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB');
    print('  📊 Field Count: ${rawData.length}');
    print('  🔍 Large Fields (>100KB):');
    fieldSizes.forEach((key, size) {
      if (size > 100000) {
        print('     • $key: ${(size / 1024).toStringAsFixed(2)} KB');
      }
    });
    print('═══════════════════════════════════════════════════\n');

    try {
      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      // Check if response is successful
      if (response.statusCode != 200 && response.statusCode != 201) {
        print('\n❌ Server Error Response:');
        print('   Status: ${response.statusCode}');
        print('   Data: ${response.data}');
        
        // Try to extract error message from response
        String errorMessage = 'Server error (${response.statusCode})';
        if (response.data != null) {
          if (response.data is Map) {
            final data = response.data as Map;
            errorMessage = data['message']?.toString() ?? 
                          data['error']?.toString() ?? 
                          errorMessage;
          } else {
            errorMessage = response.data.toString();
          }
        }
        throw Exception(errorMessage);
      }

      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      print('\n❌ DioException Details:');
      print('   Type: ${e.type}');
      print('   Message: ${e.message}');
      print('   Status Code: ${e.response?.statusCode}');
      print('   Response Data: ${e.response?.data}');
      
      // Try to extract meaningful error from server response
      if (e.response?.data != null) {
        try {
          final data = e.response!.data;
          if (data is Map) {
            final message = data['message']?.toString() ?? 
                          data['error']?.toString();
            if (message != null) {
              throw Exception('Server error: $message');
            }
          }
        } catch (_) {}
      }
      
      // Provide helpful error messages based on status code
      if (e.response?.statusCode == 413) {
        throw Exception('Payload too large. Try reducing signature/image sizes.');
      } else if (e.response?.statusCode == 500) {
        throw Exception('Server error. Please check server logs or contact support.');
      } else if (e.response?.statusCode == 422) {
        throw Exception('Validation error. Please check all required fields.');
      }
      
>>>>>>> Stashed changes
      rethrow;
    }
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
