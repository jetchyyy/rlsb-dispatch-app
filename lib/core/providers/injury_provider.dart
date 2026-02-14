import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/injury_entry.dart';

/// Manages injury data keyed by body region ID.
class InjuryProvider extends ChangeNotifier {
  /// Map of regionId → list of [InjuryEntry].
  final Map<String, List<InjuryEntry>> _selectedRegions = {};

  /// Currently selected triage category.
  String _triageCategory = 'Green';

  // ── Getters ────────────────────────────────────────────────

  Map<String, List<InjuryEntry>> get selectedRegions =>
      Map.unmodifiable(_selectedRegions);

  String get triageCategory => _triageCategory;

  // ── Injury Management ──────────────────────────────────────

  /// Adds an injury to the specified region.
  void addInjury(String regionId, InjuryEntry entry) {
    _selectedRegions.putIfAbsent(regionId, () => []);
    _selectedRegions[regionId]!.add(entry);
    notifyListeners();
  }

  /// Removes an injury by index from the specified region.
  void removeInjury(String regionId, int index) {
    final list = _selectedRegions[regionId];
    if (list != null && index >= 0 && index < list.length) {
      list.removeAt(index);
      if (list.isEmpty) _selectedRegions.remove(regionId);
      notifyListeners();
    }
  }

  /// Updates an injury at [index] in the specified region.
  void updateInjury(String regionId, int index, InjuryEntry entry) {
    final list = _selectedRegions[regionId];
    if (list != null && index >= 0 && index < list.length) {
      list[index] = entry;
      notifyListeners();
    }
  }

  /// Returns injuries for the given region, or empty list.
  List<InjuryEntry> getInjuriesForRegion(String regionId) {
    return _selectedRegions[regionId] ?? [];
  }

  /// Whether the region has at least one injury recorded.
  bool hasInjury(String regionId) {
    return _selectedRegions.containsKey(regionId) &&
        _selectedRegions[regionId]!.isNotEmpty;
  }

  /// Returns the highest severity color for a region.
  /// Priority: Critical > Severe > Moderate > Minor.
  Color getSeverityColor(String regionId) {
    final injuries = _selectedRegions[regionId];
    if (injuries == null || injuries.isEmpty) return Colors.transparent;

    const priority = ['Critical', 'Severe', 'Moderate', 'Minor'];
    for (final level in priority) {
      if (injuries.any((i) => i.severity == level)) {
        return AppColors.severityColor(level);
      }
    }
    return Colors.grey;
  }

  /// Sets the overall triage category for this report.
  void setTriageCategory(String category) {
    _triageCategory = category;
    notifyListeners();
  }

  /// Clears all recorded injuries.
  void clearAll() {
    _selectedRegions.clear();
    _triageCategory = 'Green';
    notifyListeners();
  }

  /// Total number of recorded injuries across all regions.
  int get totalInjuryCount =>
      _selectedRegions.values.fold(0, (sum, list) => sum + list.length);

  /// Serializes all injury data for API submission.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> injuriesJson = {};
    _selectedRegions.forEach((regionId, entries) {
      injuriesJson[regionId] = entries.map((e) => e.toJson()).toList();
    });
    return {
      'triage_category': _triageCategory,
      'injuries': injuriesJson,
    };
  }
}
