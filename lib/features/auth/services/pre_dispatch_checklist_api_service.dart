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
    // HH:mm:ss local time of submission
    final h = checklistDate.hour.toString().padLeft(2, '0');
    final m = checklistDate.minute.toString().padLeft(2, '0');
    final s = checklistDate.second.toString().padLeft(2, '0');
    formData.fields.add(MapEntry('checklist_time', '$h:$m:$s'));
    formData.fields.add(MapEntry('team_members', jsonEncode(teamMembers)));
    formData.fields
        .add(MapEntry('device_time', deviceTime.toUtc().toIso8601String()));

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
      debugPrint(
          'URL: ${_dio.options.baseUrl}${ApiConstants.preDispatchChecklistsEndpoint}');
      debugPrint('Status: ${e.response?.statusCode}');
      debugPrint('Response: ${e.response?.data}');
      rethrow;
    }
  }

  /// Fetch active team members / partners from the MIS backend
  Future<List<Map<String, dynamic>>> getAvailablePartners() async {
    try {
      final response = await _dio.get(ApiConstants.teamMembersEndpoint);
      final data = response.data;

      if (data != null && data['success'] == true && data['data'] != null) {
        final List<dynamic> users = data['data'];

        // Derive the host from baseUrl (strips /api suffix)
        final host = ApiConstants.baseUrl.replaceFirst(RegExp(r'/api$'), '');

        return users.map((u) {
          final rawPhoto = u['profile_photo_url']?.toString();
          String? resolvedPhoto;
          if (rawPhoto != null && rawPhoto.isNotEmpty) {
            if (rawPhoto.startsWith('http://') ||
                rawPhoto.startsWith('https://')) {
              resolvedPhoto = rawPhoto; // already absolute
            } else {
              resolvedPhoto = '$host$rawPhoto'; // prepend host
            }
          }

          return {
            'id': u['id'].toString(),
            'name': u['name'] ?? 'Unknown',
            'position': u['position'] ?? '',
            'unit': u['unit'] ?? '',
            'photo_url': resolvedPhoto, // null when no photo
            'isSelected': false,
          };
        }).toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Error fetching partners: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Unexpected error fetching partners: $e');
      return [];
    }
  }
}
