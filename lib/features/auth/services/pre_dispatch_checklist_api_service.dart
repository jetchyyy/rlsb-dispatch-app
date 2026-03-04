import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';

class PreDispatchChecklistApiService {
  final Dio _dio;

  PreDispatchChecklistApiService._(this._dio);

  static Future<PreDispatchChecklistApiService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConstants.tokenKey);

    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout:
            const Duration(milliseconds: ApiConstants.connectTimeout),
        receiveTimeout:
            const Duration(milliseconds: ApiConstants.receiveTimeout),
        sendTimeout: const Duration(milliseconds: ApiConstants.sendTimeout),
        headers: {
          ApiConstants.accept: ApiConstants.applicationJson,
          if (token != null && token.isNotEmpty)
            ApiConstants.authorization: '${ApiConstants.bearer} $token',
        },
      ),
    );

    return PreDispatchChecklistApiService._(dio);
  }

  Future<Map<String, dynamic>> submit({
    required int? userId,
    required DateTime checklistDate,
    required String? shift,
    required String? unit,
    required List<String> teamMembers,
    required File selfiePhoto,
    required List<File> ambulancePhotos,
    required List<File> traumaBagPhotos,
    required DateTime deviceTime,
  }) async {
    final formData = FormData();
    formData.fields.add(
      MapEntry(
          'checklist_date', checklistDate.toIso8601String().split('T').first),
    );
    formData.fields.add(MapEntry('team_members', jsonEncode(teamMembers)));
    formData.fields.add(MapEntry('device_time', deviceTime.toIso8601String()));

    if (shift != null && shift.trim().isNotEmpty) {
      formData.fields.add(MapEntry('shift', shift.trim()));
    }
    if (unit != null && unit.trim().isNotEmpty) {
      formData.fields.add(MapEntry('unit', unit.trim()));
    }
    if (userId != null) {
      formData.fields.add(MapEntry('user_id', userId.toString()));
    }

    formData.files.add(MapEntry(
      'selfie_photo',
      await MultipartFile.fromFile(selfiePhoto.path),
    ));

    for (final file in ambulancePhotos) {
      formData.files.add(MapEntry(
        'ambulance_photos[]',
        await MultipartFile.fromFile(file.path),
      ));
    }

    for (final file in traumaBagPhotos) {
      formData.files.add(MapEntry(
        'trauma_bag_photos[]',
        await MultipartFile.fromFile(file.path),
      ));
    }

    try {
      final response = await _dio.post(
        ApiConstants.preDispatchChecklistsEndpoint,
        data: formData,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      debugPrint('PreDispatch submit failed');
      debugPrint('URL: ${_dio.options.baseUrl}${ApiConstants.preDispatchChecklistsEndpoint}');
      debugPrint('Status: ${e.response?.statusCode}');
      debugPrint('Response: ${e.response?.data}');
      rethrow;
    }
  }
}
