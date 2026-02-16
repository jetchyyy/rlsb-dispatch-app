import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service that plays an alarm sound and triggers a red-flash callback
/// whenever a new incident is detected.
class IncidentAlarmService {
  IncidentAlarmService();

  final AudioPlayer _player = AudioPlayer();

  /// IDs of incidents we have already alerted on.
  final Set<int> _knownIncidentIds = {};

  /// Whether the very first fetch has completed (avoids alarming on startup).
  bool _initialLoadDone = false;

  /// External callback invoked when new incidents arrive.
  /// The list contains the new incident maps.
  void Function(List<Map<String, dynamic>> newIncidents)? onNewIncidents;

  /// Whether alarm is currently playing
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  // ── Public API ─────────────────────────────────────────────

  /// Call once with the first batch of incidents to seed known IDs
  /// without triggering alarms.
  void seedKnownIncidents(List<Map<String, dynamic>> incidents) {
    for (final inc in incidents) {
      final id = inc['id'] as int?;
      if (id != null) _knownIncidentIds.add(id);
    }
    _initialLoadDone = true;
    debugPrint('🔔 IncidentAlarmService: seeded ${_knownIncidentIds.length} known IDs');
  }

  /// Compare incoming incidents against known IDs.
  /// Triggers alarm + callback for any truly new ones.
  void checkForNewIncidents(List<Map<String, dynamic>> incidents) {
    if (!_initialLoadDone) {
      // First load — just seed, don't alarm
      seedKnownIncidents(incidents);
      return;
    }

    final newOnes = <Map<String, dynamic>>[];
    for (final inc in incidents) {
      final id = inc['id'] as int?;
      if (id != null && !_knownIncidentIds.contains(id)) {
        // Only alarm on active/new incidents, not already resolved ones
        final status = (inc['status'] ?? '').toString().toLowerCase();
        if (!['resolved', 'closed', 'cancelled'].contains(status)) {
          newOnes.add(inc);
        }
        _knownIncidentIds.add(id);
      }
    }

    if (newOnes.isNotEmpty) {
      debugPrint('🚨 IncidentAlarmService: ${newOnes.length} NEW incident(s) detected!');
      for (final inc in newOnes) {
        debugPrint('   → id=${inc['id']} type=${inc['incident_type']} severity=${inc['severity']}');
      }
      _triggerAlarm();
      onNewIncidents?.call(newOnes);
    }
  }

  /// Play the alarm siren.
  Future<void> _triggerAlarm() async {
    try {
      _isPlaying = true;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/alarm.wav'));
      debugPrint('🔊 Alarm started');
    } catch (e) {
      debugPrint('🔇 Alarm playback failed: $e');
      _isPlaying = false;
    }
  }

  /// Stop the alarm – called when the user acknowledges / dismisses.
  Future<void> stopAlarm() async {
    try {
      await _player.stop();
      _isPlaying = false;
      debugPrint('🔇 Alarm stopped');
    } catch (e) {
      debugPrint('🔇 Alarm stop failed: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
