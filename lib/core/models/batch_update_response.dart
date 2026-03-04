/// Response model for the location batch update API.
/// 
/// Example response:
/// ```json
/// {
///   "success": true,
///   "saved": 45,
///   "message": "45 location points saved successfully (12 duplicates skipped)",
///   "data": {
///     "saved_count": 45,
///     "duplicates_skipped": 12,
///     "latest_timestamp": "2026-03-03T10:30:00Z"
///   },
///   "statistics": {
///     "locations_in_batch": 57,
///     "duplicates_skipped": 12,
///     "active_mode_count": 40,
///     "passive_mode_count": 17
///   }
/// }
/// ```
class BatchUpdateResponse {
  final bool success;
  final int saved;
  final String message;
  final BatchUpdateData data;
  final BatchUpdateStatistics statistics;

  BatchUpdateResponse({
    required this.success,
    required this.saved,
    required this.message,
    required this.data,
    required this.statistics,
  });

  factory BatchUpdateResponse.fromJson(Map<String, dynamic> json) {
    return BatchUpdateResponse(
      success: json['success'] ?? false,
      saved: json['saved'] ?? 0,
      message: json['message'] ?? '',
      data: BatchUpdateData.fromJson(json['data'] ?? {}),
      statistics: BatchUpdateStatistics.fromJson(json['statistics'] ?? {}),
    );
  }

  /// Calculate duplicate rate for monitoring
  double get duplicateRate {
    if (statistics.locationsInBatch == 0) return 0.0;
    return data.duplicatesSkipped / statistics.locationsInBatch;
  }

  /// Returns true if duplicate rate exceeds threshold (30%)
  bool get hasHighDuplicateRate => duplicateRate > 0.3;
}

/// Data portion of the batch update response
class BatchUpdateData {
  final int savedCount;
  final int duplicatesSkipped;
  final String? latestTimestamp;

  BatchUpdateData({
    required this.savedCount,
    required this.duplicatesSkipped,
    this.latestTimestamp,
  });

  factory BatchUpdateData.fromJson(Map<String, dynamic> json) {
    return BatchUpdateData(
      savedCount: json['saved_count'] ?? 0,
      duplicatesSkipped: json['duplicates_skipped'] ?? 0,
      latestTimestamp: json['latest_timestamp'],
    );
  }
}

/// Statistics portion of the batch update response
class BatchUpdateStatistics {
  final int locationsInBatch;
  final int duplicatesSkipped;
  final int activeModeCount;
  final int passiveModeCount;

  BatchUpdateStatistics({
    required this.locationsInBatch,
    required this.duplicatesSkipped,
    required this.activeModeCount,
    required this.passiveModeCount,
  });

  factory BatchUpdateStatistics.fromJson(Map<String, dynamic> json) {
    return BatchUpdateStatistics(
      locationsInBatch: json['locations_in_batch'] ?? 0,
      duplicatesSkipped: json['duplicates_skipped'] ?? 0,
      activeModeCount: json['active_mode_count'] ?? 0,
      passiveModeCount: json['passive_mode_count'] ?? 0,
    );
  }
}
