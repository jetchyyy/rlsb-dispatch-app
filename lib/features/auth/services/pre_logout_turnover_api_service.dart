import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';

class PreLogoutTurnoverApiService {
  final Dio _dio;

  PreLogoutTurnoverApiService._(this._dio);

  static Future<PreLogoutTurnoverApiService> create() async {
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

    return PreLogoutTurnoverApiService._(dio);
  }

  Future<Map<String, dynamic>> submit({
    required int? userId,
    required DateTime turnoverDate,
    required String? unit,
    required String notes,
    required List<File> itemPhotos,
    required List<File> ambulancePhotos,
    required File odometerPhoto,
    required DateTime deviceTime,
  }) async {
    final formData = FormData();
    formData.fields.add(
      MapEntry('turnover_date', turnoverDate.toIso8601String().split('T').first),
    );
    formData.fields.add(MapEntry('notes', notes));
    formData.fields.add(MapEntry('device_time', deviceTime.toIso8601String()));

    if (userId != null) {
      formData.fields.add(MapEntry('user_id', userId.toString()));
    }
    if (unit != null && unit.trim().isNotEmpty) {
      formData.fields.add(MapEntry('unit', unit.trim()));
    }

    for (final file in itemPhotos) {
      formData.files.add(MapEntry(
        'item_photos[]',
        await MultipartFile.fromFile(file.path),
      ));
    }

    for (final file in ambulancePhotos) {
      formData.files.add(MapEntry(
        'ambulance_photos[]',
        await MultipartFile.fromFile(file.path),
      ));
    }

    formData.files.add(MapEntry(
      'odometer_photo',
      await MultipartFile.fromFile(odometerPhoto.path),
    ));

    try {
      final response = await _dio.post(
        ApiConstants.preLogoutTurnoversEndpoint,
        data: formData,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      debugPrint('PreLogout turnover submit failed');
      debugPrint(
          'URL: ${_dio.options.baseUrl}${ApiConstants.preLogoutTurnoversEndpoint}');
      debugPrint('Status: ${e.response?.statusCode}');
      debugPrint('Response: ${e.response?.data}');
      rethrow;
    }
  }
}
