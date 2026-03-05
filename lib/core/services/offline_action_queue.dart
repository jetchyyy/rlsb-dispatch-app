import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// A queued incident action that could not be sent due to no connectivity.
class PendingAction {
  final int incidentId;

  /// The target status (e.g. "on_scene", "responding", "resolved").
  final String action;

  /// ISO-8601 timestamp of when the responder pressed the button — used as
  /// the authoritative "arrived_at" / "responded_at" time on the server.
  final String recordedAt;

  final String? notes;

  // GPS coordinates at moment of action (for accurate marker placement)
  final double? latitude;
  final double? longitude;

  PendingAction({
    required this.incidentId,
    required this.action,
    required this.recordedAt,
    this.notes,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'incidentId': incidentId,
        'action': action,
        'recordedAt': recordedAt,
        if (notes != null) 'notes': notes,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
        incidentId: json['incidentId'] as int,
        action: json['action'] as String,
        recordedAt: json['recordedAt'] as String,
        notes: json['notes'] as String?,
        latitude: json['latitude'] as double?,
        longitude: json['longitude'] as double?,
      );
}

/// Persists and retrieves pending incident actions using a Hive box.
///
/// Uses Hive with JSON-encoded strings — no need for a generated adapter.
/// Box name: `offline_action_queue`
class OfflineActionQueue {
  static const String _boxName = 'offline_action_queue';

  Box<String>? _box;

  /// Call once on startup (after Hive.initFlutter()).
  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox<String>(_boxName);
      } else {
        _box = Hive.box<String>(_boxName);
      }
      debugPrint(
          '📦 OfflineActionQueue: initialized with ${_box!.length} pending action(s)');
    } catch (e) {
      debugPrint('🚨 OfflineActionQueue: Hive init error: $e');
    }
  }

  Future<void> _ensureInit() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
  }

  /// Returns all pending actions in insertion order.
  List<PendingAction> getAll() {
    if (_box == null) return [];
    final result = <PendingAction>[];
    for (final key in _box!.keys) {
      try {
        final json =
            jsonDecode(_box!.get(key as String)!) as Map<String, dynamic>;
        result.add(PendingAction.fromJson(json));
      } catch (e) {
        debugPrint('⚠️ OfflineActionQueue: failed to parse key=$key: $e');
      }
    }
    return result;
  }

  /// Returns `true` if there are pending actions for any incident.
  bool get hasPending => (_box?.isNotEmpty) ?? false;

  /// Returns `true` if there is at least one pending action for [incidentId].
  bool hasPendingFor(int incidentId) =>
      getAll().any((a) => a.incidentId == incidentId);

  /// Returns the latest pending action for [incidentId], or null.
  PendingAction? latestFor(int incidentId) {
    final matching = getAll().where((a) => a.incidentId == incidentId).toList();
    return matching.isEmpty ? null : matching.last;
  }

  /// Enqueue a new pending action. Uses a unique key so multiple actions for
  /// the same incident can coexist (e.g. acknowledge then respond offline).
  Future<void> enqueue(PendingAction action) async {
    await _ensureInit();
    if (_box == null) return;

    try {
      final key =
          '${action.incidentId}_${action.action}_${DateTime.now().millisecondsSinceEpoch}';
      await _box!.put(key, jsonEncode(action.toJson()));
      debugPrint(
          '📝 OfflineActionQueue: enqueued ${action.action} for incident #${action.incidentId}');
    } catch (e, st) {
      debugPrint('🚨 OfflineActionQueue enqueue error: $e\n$st');
      rethrow;
    }
  }

  /// Remove all actions for a given [incidentId] + [action] pair.
  /// Called after a successful sync.
  Future<void> remove(int incidentId, String action) async {
    await _ensureInit();
    if (_box == null) return;
    final toDelete = _box!.keys
        .where((k) {
          try {
            final json =
                jsonDecode(_box!.get(k as String)!) as Map<String, dynamic>;
            return json['incidentId'] == incidentId && json['action'] == action;
          } catch (_) {
            return false;
          }
        })
        .cast<String>()
        .toList();
    await _box!.deleteAll(toDelete);
    debugPrint(
        '✅ OfflineActionQueue: removed ${toDelete.length} entry/entries for ${action} #$incidentId');
  }

  /// Remove ALL pending actions (e.g. after a full sync or logout).
  Future<void> clear() async {
    await _ensureInit();
    await _box?.clear();
    debugPrint('🗑️ OfflineActionQueue: cleared all pending actions');
  }
}
