import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/e_street_form_model.dart';
import 'e_street_local_storage.dart';

class PendingEStreetForm {
  final int incidentId;
  final EStreetFormModel form;
  final String recordedAt;
  
  // GPS coordinates at moment of form submission (for accurate resolved marker)
  final double? latitude;
  final double? longitude;

  PendingEStreetForm({
    required this.incidentId,
    required this.form,
    required this.recordedAt,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'incidentId': incidentId,
        'form': form.toJson(),
        'recordedAt': recordedAt,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  factory PendingEStreetForm.fromJson(Map<String, dynamic> json) =>
      PendingEStreetForm(
        incidentId: json['incidentId'] as int,
        form: EStreetFormModel.fromJson(json['form'] as Map<String, dynamic>),
        recordedAt: json['recordedAt'] as String,
        latitude: json['latitude'] as double?,
        longitude: json['longitude'] as double?,
      );
}

/// Persists and retrieves pending E-Street forms using a Hive box.
class OfflineEStreetQueue {
  static const String _boxName = 'offline_estreet_queue';

  Box<String>? _box;

  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox<String>(_boxName);
      } else {
        _box = Hive.box<String>(_boxName);
      }
      debugPrint(
          '📦 OfflineEStreetQueue: initialized with ${_box!.length} pending form(s)');
    } catch (e) {
      debugPrint('🚨 OfflineEStreetQueue: Hive init error: $e');
    }
  }

  Future<void> _ensureInit() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
  }

  List<PendingEStreetForm> getAll() {
    if (_box == null) return [];
    final result = <PendingEStreetForm>[];
    for (final key in _box!.keys) {
      try {
        final json =
            jsonDecode(_box!.get(key as String)!) as Map<String, dynamic>;
        result.add(PendingEStreetForm.fromJson(json));
      } catch (e) {
        debugPrint('⚠️ OfflineEStreetQueue: failed to parse key=$key: $e');
      }
    }
    // Sort by oldest first
    result.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return result;
  }

  bool get hasPending => (_box?.isNotEmpty) ?? false;

  bool hasPendingFor(int incidentId) =>
      getAll().any((a) => a.incidentId == incidentId);

  Future<void> enqueue(PendingEStreetForm pendingForm) async {
    await _ensureInit();
    if (_box == null) return;

    try {
      final key = 'estreet_${pendingForm.incidentId}'; // One per incident
      final jsonStr = jsonEncode(pendingForm.toJson());
      await _box!.put(key, jsonStr);
      debugPrint(
          '📝 OfflineEStreetQueue: enqueued form for incident #${pendingForm.incidentId}');
    } catch (e, st) {
      debugPrint('🚨 OfflineEStreetQueue enqueue error: $e\n$st');
      rethrow;
    }
  }

  Future<void> remove(int incidentId) async {
    await _ensureInit();
    if (_box == null) return;
    final key = 'estreet_$incidentId';
    await _box!.delete(key);

    // Also delete local images when successfully synced to avoid clutter
    await EStreetLocalStorage.deleteAll(incidentId);

    debugPrint('✅ OfflineEStreetQueue: removed form entry for #$incidentId');
  }

  Future<void> clear() async {
    await _ensureInit();
    await _box?.clear();
    debugPrint('🗑️ OfflineEStreetQueue: cleared all pending forms');
  }
}
