import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../models/e_street_form_model.dart';

/// Service for submitting E-Street forms to the API.
class EStreetFormService {
  final Dio _dio;

  EStreetFormService._(this._dio);

  /// Create a service backed by [SharedPreferences] for the auth token.
  static Future<EStreetFormService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConstants.tokenKey) ?? '';

    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ));

    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    return EStreetFormService._(dio);
  }

  /// Submit the E-Street form for the given [incidentId].
  /// Returns the response data including `pdf_url` and signature paths.
  Future<Map<String, dynamic>> submitForm({
    required int incidentId,
    required EStreetFormModel form,
  }) async {
    final response = await _dio.post(
      '/incidents/$incidentId/e-street-form',
      data: form.toJson(),
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    return {'success': true};
  }

  /// Fetch an existing E-Street form for editing.
  Future<EStreetFormModel?> fetchForm(int incidentId) async {
    try {
      final response = await _dio.get(
        '/incidents/$incidentId/e-street-form',
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final formData = data['e_street_form'] ?? data['data'] ?? data;
        if (formData is Map<String, dynamic> && formData.isNotEmpty) {
          return EStreetFormModel.fromJson(formData);
        }
      }
    } on DioException catch (e) {
      // 404 means no existing form — that's fine
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
    return null;
  }
}
