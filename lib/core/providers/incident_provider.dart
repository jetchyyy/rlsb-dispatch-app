import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../services/incident_alarm_service.dart';
import '../services/offline_action_queue.dart';
import '../../features/e_street_form/models/e_street_form_model.dart';
import '../../features/e_street_form/services/offline_estreet_queue.dart';
import '../../features/e_street_form/services/e_street_api_service.dart';
import '../../features/e_street_form/services/e_street_local_storage.dart';

/// Manages incident list, detail, statistics, and CRUD state
/// with detailed debug logging.
class IncidentProvider extends ChangeNotifier {
  final ApiClient _api;
  final IncidentAlarmService alarmService;
  final OfflineActionQueue _actionQueue = OfflineActionQueue();
  final OfflineEStreetQueue _estreetQueue = OfflineEStreetQueue();

  IncidentProvider(this._api, {IncidentAlarmService? alarmService})
      : alarmService = alarmService ?? IncidentAlarmService() {
    // Initialize the offline queue asynchronously — safe because usage is
    // always after the first frame (buttons are only visible post-login).
    _actionQueue.init();
    _estreetQueue.init();
  }

  // ── State ──────────────────────────────────────────────────

  List<Map<String, dynamic>> _incidents = [];
  Map<String, dynamic>? _currentIncident;
  Map<String, dynamic>? _statistics;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSubmitting = false;
  bool _isSyncing = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;

  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;

  // Active filters
  String? _statusFilter;
  String? _severityFilter;
  String? _typeFilter;
  String? _municipalityFilter;
  String? _searchQuery;

  // ── Unit-based filtering ────────────────────────────────────
  /// The current user's unit (e.g. "BFP", "PNP", "PDRRMO-ASSERT").
  /// When set, only incidents dispatched to this unit are shown & alarmed.
  /// This uses the `unit` field from the users table, NOT `division`.
  String? _userUnit;

  /// When true the unit filter is bypassed (admin / super-admin users).
  bool _isAdmin = false;

  /// Tracks the current activeOnly preference so auto-refresh uses the same mode.
  /// When true, hide resolved/closed/cancelled incidents.
  bool _activeOnly = false;

  String? get userUnit => _userUnit;
  bool get isAdmin => _isAdmin;

  /// Call after login to configure unit-based incident filtering.
  /// Pass [unit] from user.unit (e.g., "BFP", "PNP", "PDRRMO-ASSERT").
  /// Pass [isAdmin] = true so admins/super-admins see ALL incidents.
  void setUserUnit(String? unit, {bool isAdmin = false}) {
    _userUnit = unit;
    _isAdmin = isAdmin;
    // Propagate to the alarm service so alarm filtering stays in sync
    alarmService.userUnit = unit;
    alarmService.isAdmin = isAdmin;
    debugPrint('🏷️ IncidentProvider: userUnit=$_userUnit, isAdmin=$_isAdmin');
    notifyListeners();
  }

  // Auto-refresh
  Timer? _refreshTimer;

  // ── Location Tracking Callbacks ─────────────────────────────
  /// Called when the responder taps "Respond" on an incident.
  /// Passes the incident ID to start active GPS tracking.
  void Function(int incidentId)? onRespondStarted;

  /// Called when the incident is resolved.
  /// Signals the tracking system to revert to passive mode.
  void Function(int incidentId)? onRespondEnded;

  /// Called when the responder marks arrival on scene.
  /// Passes the incident ID so the response provider can record arrival.
  void Function(int incidentId)? onOnSceneReached;

  // ── Getters ────────────────────────────────────────────────

  List<Map<String, dynamic>> get incidents => _incidents;
  Map<String, dynamic>? get currentIncident => _currentIncident;
  Map<String, dynamic>? get statistics => _statistics;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isSubmitting => _isSubmitting;
  bool get isSyncing => _isSyncing;
  bool get hasPendingActions => _actionQueue.hasPending;
  bool get hasPendingEStreetForms => _estreetQueue.hasPending;
  String? get errorMessage => _errorMessage;
  DateTime? get lastFetchTime => _lastFetchTime;
  int get incidentCount => _incidents.length;
  int get totalCount => _total;
  bool get hasMore => _currentPage < _lastPage;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;

  /// Whether there is a pending (offline-queued) action for [incidentId].
  bool hasPendingFor(int incidentId) => _actionQueue.hasPendingFor(incidentId);

  /// Whether there is a pending (offline-queued) E-Street form for [incidentId].
  bool hasPendingEStreetFormFor(int incidentId) =>
      _estreetQueue.hasPendingFor(incidentId);

  /// Returns the action string of the latest pending action for [incidentId],
  /// or null if there is none.
  String? latestPendingActionFor(int incidentId) =>
      _actionQueue.latestFor(incidentId)?.action;

  String? get statusFilter => _statusFilter;
  String? get severityFilter => _severityFilter;
  String? get typeFilter => _typeFilter;
  String? get municipalityFilter => _municipalityFilter;
  String? get searchQuery => _searchQuery;

  // ── Computed Stats ─────────────────────────────────────────

  /// All non-terminal incidents (not resolved, closed, or cancelled)
  int get activeCount =>
      _statistics?['active_incidents'] ??
      _incidents
          .where((i) => !['resolved', 'closed', 'cancelled']
              .contains((i['status'] ?? '').toString().toLowerCase()))
          .length;

  /// Reported but not yet acted on — needs dispatcher attention
  int get pendingCount =>
      _statistics?['pending_incidents'] ??
      _incidents
          .where(
              (i) => (i['status'] ?? '').toString().toLowerCase() == 'reported')
          .length;

  /// Acknowledged, responding, or on-scene — being handled
  int get dispatchedCount =>
      _statistics?['dispatched_incidents'] ??
      _incidents
          .where((i) => ['acknowledged', 'responding', 'on_scene', 'on-scene']
              .contains((i['status'] ?? '').toString().toLowerCase()))
          .length;

  /// Resolved or closed — completed
  int get resolvedCount =>
      _statistics?['resolved_incidents'] ??
      _incidents
          .where((i) => ['resolved', 'closed']
              .contains((i['status'] ?? '').toString().toLowerCase()))
          .length;

  // ── Auto-refresh ───────────────────────────────────────────

  void startAutoRefresh({Duration interval = const Duration(seconds: 3)}) {
    stopAutoRefresh();
    debugPrint('⏱️ Auto-refresh started (every ${interval.inSeconds}s)');
    _refreshTimer = Timer.periodic(interval, (_) {
      if (kDebugMode) debugPrint('⏱️ Auto-refresh tick');
      fetchIncidents(silent: true, activeOnly: _activeOnly);

      // Also refresh the currently viewed incident detail if active
      if (_currentIncident?['id'] != null) {
        fetchIncident(_currentIncident!['id'], silent: true);
      }

      // Try to flush any offline-queued actions
      _flushOfflineQueue();
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    alarmService.dispose();
    super.dispose();
  }

  // ── Offline Queue ───────────────────────────────────────────

  /// Robust helper to determine if a DioException is due to network failure.
  bool isOfflineException(DioException e) {
    return e.response == null ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.unknown;
  }

  /// Applies an optimistic status update to the in-memory incident list and
  /// current incident so the UI reflects the new state immediately.
  void _applyOptimisticStatus(int incidentId, String status) {
    final idx = _incidents.indexWhere((i) => i['id'] == incidentId);
    if (idx != -1) {
      _incidents[idx] = Map<String, dynamic>.from(_incidents[idx])
        ..['status'] = status;
    }
    if (_currentIncident?['id'] == incidentId) {
      _currentIncident = Map<String, dynamic>.from(_currentIncident!)
        ..['status'] = status;
    }
    notifyListeners();
  }

  /// Injects a local timestamp into the incident data when an action is queued offline.
  /// This allows the E-Street form to access timestamps even when offline.
  void _injectLocalTimestamp(int incidentId, String action, String timestamp) {
    debugPrint('💾 Injecting local timestamp for $action: $timestamp');
    
    final idx = _incidents.indexWhere((i) => i['id'] == incidentId);
    if (idx != -1) {
      _incidents[idx] = Map<String, dynamic>.from(_incidents[idx]);
      if (action == 'responding') {
        _incidents[idx]['response_started_at'] = timestamp;
      } else if (action == 'on_scene' || action == 'on-scene') {
        _incidents[idx]['arrived_on_scene_at'] = timestamp;
        _incidents[idx]['on_scene_at'] = timestamp; // Fallback field
      }
    }
    
    if (_currentIncident?['id'] == incidentId) {
      _currentIncident = Map<String, dynamic>.from(_currentIncident!);
      if (action == 'responding') {
        _currentIncident!['response_started_at'] = timestamp;
      } else if (action == 'on_scene' || action == 'on-scene') {
        _currentIncident!['arrived_on_scene_at'] = timestamp;
        _currentIncident!['on_scene_at'] = timestamp; // Fallback field
      }
    }
    
    debugPrint('✅ Local timestamp injected into incident data');
    notifyListeners();
  }

  /// Called every auto-refresh tick. Attempts to sync any pending offline
  /// actions and forms to the server. Skips gracefully if already syncing.
  Future<void> _flushOfflineQueue() async {
    if (_isSyncing) return;
    if (!_actionQueue.hasPending && !_estreetQueue.hasPending) return;

    _isSyncing = true;
    notifyListeners(); // Trigger UI rebuild to show "Uploading..."

    // 1. Sync actions (e.g., acknowledged, responding, on_scene)
    if (_actionQueue.hasPending) {
      final pending = _actionQueue.getAll();
      debugPrint('🔄 OfflineQueue flush: ${pending.length} action(s) to sync');
      for (final action in pending) {
        final success = await _syncPendingAction(action);
        if (!success) {
          // Still offline — stop attempting, try again next tick
          break;
        }
      }
    }

    // 2. Sync E-Street Forms
    if (_estreetQueue.hasPending) {
      final pendingForms = _estreetQueue.getAll();
      debugPrint(
          '🔄 OfflineEStreetQueue flush: ${pendingForms.length} form(s) to sync');
      for (final formLog in pendingForms) {
        final success = await _syncPendingEStreetForm(formLog);
        if (!success) {
          // Still offline
          break;
        }
      }
    }

    _isSyncing = false;
    notifyListeners();
  }

  /// Sends a single [PendingEStreetForm] to the server.
  Future<bool> _syncPendingEStreetForm(PendingEStreetForm pending) async {
    debugPrint('📡 Syncing offline E-Street form for #${pending.incidentId}');
    try {
      final api = await EStreetApiService.create();

      // Load saved images back into the form before submitting
      final images =
          await EStreetLocalStorage.loadAllImages(pending.incidentId);
      final form = pending.form;

      form.patientSignature =
          images['patient_signature'] ?? form.patientSignature;
      form.doctorSignature = images['doctor_signature'] ?? form.doctorSignature;
      form.responderSignature =
          images['responder_signature'] ?? form.responderSignature;
      form.bodyDiagramScreenshot =
          images['body_diagram_screenshot'] ?? form.bodyDiagramScreenshot;

      // Capture the server response which contains the PDF URL
      final response = await api.submitForm(incidentId: pending.incidentId, form: form);
      await _estreetQueue.remove(pending.incidentId);

      debugPrint('✅ Synced offline E-Street form for #${pending.incidentId}');
      debugPrint('📦 API Full Response: $response');
      
      // Store the PDF URL from the submission response
      // Handle multiple possible response structures
      final pdfUrl = response['pdf_url'] as String? ?? 
                     response['data']?['pdf_url'] as String? ??
                     response['e_street_form_pdf'] as String?;
                     
      if (pdfUrl != null) {
        debugPrint('📄 ✅ Received server PDF URL: $pdfUrl');
      } else {
        debugPrint('⚠️ NO PDF URL in API response!');
        debugPrint('   Available keys: ${response.keys.toList()}');
        if (response['data'] != null) {
          debugPrint('   Data keys: ${(response['data'] as Map?)?.keys.toList()}');
        }
      }

      // Once synced, auto-resolve the incident as per normal flow.
      // resolveIncident will call fetchIncident which refreshes _currentIncident
      await resolveIncident(pending.incidentId,
          notes: 'Auto-resolved after background offline E-Street form sync');

      // After resolving, ensure the PDF URL is set in the current incident.
      // This handles the case where the server's incident detail endpoint doesn't
      // immediately return the e_street_form_pdf field after submission.
      if (pdfUrl != null) {
        injectPdfUrl(pending.incidentId, pdfUrl);
      } else {
        // If no PDF URL in the submit response, try fetching incident again after a delay
        // The server might need time to save the PDF path to the database
        debugPrint('⏳ No PDF URL found, will retry fetch after 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
        await fetchIncident(pending.incidentId, silent: true);
        debugPrint('🔄 Refetched incident after delay');
      }

      return true;
    } on DioException catch (e) {
      if (isOfflineException(e)) {
        debugPrint(
            '📵 Still offline — will retry E-Street form sync for #${pending.incidentId} later');
        return false; // Stop syncing and try again later
      }

      // Server error (e.g., validation failed) — discard it to unblock the queue
      debugPrint(
          '❌ Server rejected offline E-Street form for #${pending.incidentId}: ${e.response?.statusCode}');
      await _estreetQueue.remove(pending.incidentId);
      return true;
    } catch (e) {
      debugPrint('❌ Unexpected error syncing offline E-Street form: $e');
      return false;
    }
  }

  /// Sends a single [PendingAction] to the server.
  /// Returns true on success (removes from queue), false on network failure.
  Future<bool> _syncPendingAction(PendingAction action) async {
    final endpoint = _endpointForAction(action.incidentId, action.action);
    if (endpoint == null) return true; // Unknown action — discard

    debugPrint(
        '📡 Syncing offline action: ${action.action} for #${action.incidentId} (recorded ${action.recordedAt})');
    try {
      final data = <String, dynamic>{
        // Pass the original timestamp so the server records the real time
        'recorded_at': action.recordedAt,
        if (action.notes != null && action.notes!.isNotEmpty)
          'notes': action.notes,
      };
      await _api.post(endpoint, data: data);
      await _actionQueue.remove(action.incidentId, action.action);
      debugPrint(
          '✅ Synced offline action: ${action.action} for #${action.incidentId}');

      // Refresh the detail if it's the currently viewed incident
      if (_currentIncident?['id'] == action.incidentId) {
        fetchIncident(action.incidentId, silent: true);
      }
      return true;
    } on DioException catch (e) {
      if (isOfflineException(e)) {
        debugPrint(
            '📵 Still offline/flaky — will retry ${action.action} for #${action.incidentId} later');
        return false;
      }
      // Server error (4xx/5xx) — discard so it doesn't block the queue forever
      debugPrint(
          '❌ Server rejected offline action ${action.action} for #${action.incidentId}: ${e.response?.statusCode}');
      await _actionQueue.remove(action.incidentId, action.action);
      return true;
    } catch (e) {
      debugPrint('❌ Unexpected error syncing offline action: $e');
      return false;
    }
  }

  String? _endpointForAction(int id, String action) {
    switch (action) {
      case 'acknowledged':
        return ApiConstants.incidentAcknowledge(id);
      case 'responding':
        return ApiConstants.incidentRespond(id);
      case 'on_scene':
      case 'on-scene':
        return ApiConstants.incidentOnScene(id);
      case 'resolved':
        return ApiConstants.incidentResolve(id);
      case 'closed':
        return ApiConstants.incidentClose(id);
      case 'cancelled':
        return ApiConstants.incidentCancel(id);
      default:
        return null;
    }
  }

  /// Enqueue an E-Street form to be submitted later when offline
  Future<void> enqueueEStreetForm(int incidentId, EStreetFormModel form) async {
    await _estreetQueue.enqueue(PendingEStreetForm(
      incidentId: incidentId,
      form: form,
      recordedAt: DateTime.now().toIso8601String(),
    ));
    debugPrint('📝 E-Street form queued offline for incident #$incidentId');

    // Optimistically resolve the incident so they don't have to wait
    _applyOptimisticStatus(incidentId, 'resolved');
    notifyListeners();
  }

  // ── Set Filters ────────────────────────────────────────────

  void setFilters({
    String? status,
    String? severity,
    String? type,
    String? municipality,
    String? search,
  }) {
    _statusFilter = status;
    _severityFilter = severity;
    _typeFilter = type;
    _municipalityFilter = municipality;
    _searchQuery = search;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = null;
    _severityFilter = null;
    _typeFilter = null;
    _municipalityFilter = null;
    _searchQuery = null;
    notifyListeners();
  }

  // ── Filter Today and Active ────────────────────────────────────────────

  void filterTodayAndActive() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    // Keep original list for reference
    final allIncidents = List<Map<String, dynamic>>.from(_incidents);

    // Filter to show: active incidents OR incidents resolved/closed/cancelled today
    _incidents = allIncidents.where((incident) {
      final status = incident['status']?.toString().toLowerCase() ?? '';

      // Always show active incidents (not resolved/closed/cancelled)
      if (status != 'resolved' && status != 'closed' && status != 'cancelled') {
        return true;
      }

      // For resolved/closed/cancelled, check if it happened today
      final updatedAtStr = incident['updated_at']?.toString();
      if (updatedAtStr != null) {
        try {
          final updatedAt = DateTime.parse(updatedAtStr);
          return updatedAt.isAfter(todayStart) &&
              updatedAt.isBefore(todayStart.add(Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }

      return false;
    }).toList();

    debugPrint(
        '📊 Dashboard filter: ${allIncidents.length} total → ${_incidents.length} (active + resolved today)');
    notifyListeners();
  }

  Map<String, dynamic> _buildQueryParams({
    int? page,
    int limit = 15,
    bool activeOnly = false,
  }) {
    debugPrint(
        '🔍 _buildQueryParams called: activeOnly=$activeOnly, _statusFilter=$_statusFilter');
    final params = <String, dynamic>{'limit': limit, 'page': page ?? 1};
    if (_statusFilter != null) params['status'] = _statusFilter;
    if (_severityFilter != null) params['severity'] = _severityFilter;
    if (_typeFilter != null) params['type'] = _typeFilter;
    if (_municipalityFilter != null)
      params['municipality'] = _municipalityFilter;
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      params['search'] = _searchQuery;
    }

    // Exclude completed incidents when activeOnly is true and no specific status filter
    if (activeOnly && _statusFilter == null) {
      debugPrint(
          '✅ Applying activeOnly filter: status_not=resolved,closed,cancelled');
      params['status_not'] = 'resolved,closed,cancelled';
    } else {
      debugPrint(
          '❌ NOT applying activeOnly filter (activeOnly=$activeOnly, _statusFilter=$_statusFilter)');
    }

    // ── Unit-based server-side filter ────────────────────────
    // If the user belongs to a specific unit and is not admin,
    // ask the server to return only incidents dispatched to that unit.
    // Uses the `unit` field from users table (e.g., "BFP", "PNP", "PDRRMO-ASSERT").
    if (_userUnit != null && _userUnit!.isNotEmpty && !_isAdmin) {
      params['dispatched_unit'] = _userUnit;
      debugPrint('🏷️ Applying unit filter: dispatched_unit=$_userUnit');
    }

    // Always include relationships for list view
    params['include'] = 'citizen,assigned_user';
    params['with'] = 'citizen,assigned_user';

    debugPrint('📦 Final params: $params');
    return params;
  }

  // ── Fetch Statistics ───────────────────────────────────────

  /// Statistics are computed locally from fetched incidents since
  /// the server does not expose a /statistics endpoint.
  Future<void> fetchStatistics({String period = '24h'}) async {
    // Ensure we have fresh data
    if (_incidents.isEmpty) {
      await fetchIncidents(silent: true);
    }

    // Compute stats from local data
    int totalResponseSeconds = 0;
    int respondedCount = 0;

    for (final inc in _incidents) {
      String? startStr = inc['response_started_at']?.toString() ??
          inc['dispatched_at']?.toString() ??
          inc['accepted_at']?.toString();
      String? endStr = inc['arrived_on_scene_at']?.toString() ??
          inc['on_scene_at']?.toString();

      // Fallback: Check assignments if top-level fields are missing
      if ((startStr == null || endStr == null) &&
          inc['assignments'] is List &&
          (inc['assignments'] as List).isNotEmpty) {
        final firstAssignment = (inc['assignments'] as List).first;
        if (firstAssignment is Map) {
          startStr ??= firstAssignment['response_started_at']?.toString() ??
              firstAssignment['dispatched_at']?.toString() ??
              firstAssignment['accepted_at']?.toString();
          endStr ??= firstAssignment['arrived_on_scene_at']?.toString() ??
              firstAssignment['on_scene_at']?.toString();
        }
      }

      if (startStr != null && endStr != null) {
        try {
          final start = DateTime.parse(startStr);
          final end = DateTime.parse(endStr);
          final diff = end.difference(start).inSeconds;
          if (diff > 0) {
            totalResponseSeconds += diff;
            respondedCount++;
          }
        } catch (e) {
          debugPrint('  ⚠️ Error parsing dates for incident ${inc['id']}: $e');
        }
      }
    }

    final avgSeconds = respondedCount > 0
        ? (totalResponseSeconds / respondedCount).round()
        : 0;

    _statistics = {
      'active_incidents': _incidents
          .where((i) => !['resolved', 'closed', 'cancelled']
              .contains((i['status'] ?? '').toString().toLowerCase()))
          .length,
      'pending_incidents': _incidents
          .where(
              (i) => (i['status'] ?? '').toString().toLowerCase() == 'reported')
          .length,
      'dispatched_incidents': _incidents
          .where((i) => ['acknowledged', 'responding', 'on_scene', 'on-scene']
              .contains((i['status'] ?? '').toString().toLowerCase()))
          .length,
      'resolved_incidents': _incidents
          .where((i) => ['resolved', 'closed']
              .contains((i['status'] ?? '').toString().toLowerCase()))
          .length,
      'average_response_time': _formatDuration(Duration(seconds: avgSeconds)),
    };

    notifyListeners();
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds == 0) return 'N/A';
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  // ── Fetch All Incidents ────────────────────────────────────

  Future<void> fetchIncidents({
    bool silent = false,
    bool activeOnly = false,
  }) async {
    // Store the activeOnly preference so auto-refresh uses the same mode
    _activeOnly = activeOnly;

    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    _currentPage = 1;
    final params = _buildQueryParams(page: 1, activeOnly: activeOnly);
    final endpoint = ApiConstants.incidentsEndpoint;
    final fullUrl = '${ApiConstants.baseUrl}$endpoint';

    if (kDebugMode) {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('🔄 INCIDENT FETCH — START');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('  📡 Endpoint : GET $fullUrl');
      debugPrint('  📎 Params   : $params');
      debugPrint('  🕐 Time     : ${DateTime.now().toIso8601String()}');
      debugPrint('  🔑 Token    : ${_tokenPreview()}');
      debugPrint('───────────────────────────────────────────────────');
    }

    try {
      final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;

      final response = await _api.get(endpoint, queryParameters: params);

      if (kDebugMode && stopwatch != null) {
        stopwatch.stop();
        debugPrint('  ✅ Response in ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  📊 Status code : ${response.statusCode}');
        debugPrint('  📦 Data type   : ${response.data.runtimeType}');

        // Log raw response (truncated)
        final rawStr =
            const JsonEncoder.withIndent('  ').convert(response.data);
        final truncated = rawStr.length > 2000
            ? '${rawStr.substring(0, 2000)}\n  ... [truncated, ${rawStr.length} chars total]'
            : rawStr;
        debugPrint('  📋 Raw response:');
        for (final line in truncated.split('\n')) {
          debugPrint('     $line');
        }
      }

      _parseIncidentList(response.data, activeOnly: activeOnly);
      _lastFetchTime = DateTime.now();
      // Clear any stale errors on successful fetch
      _errorMessage = null;
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('  ❌ Unexpected error: $e');
        debugPrint('     StackTrace: $stackTrace');
      }
      _errorMessage = 'Something went wrong: ${e.runtimeType}';
    }

    _isLoading = false;
    _logFinalState();
    notifyListeners();
  }

  // ── Load More (Pagination) ─────────────────────────────────

  Future<void> loadMore({bool activeOnly = false}) async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    final nextPage = _currentPage + 1;
    final params = _buildQueryParams(page: nextPage, activeOnly: activeOnly);

    debugPrint('');
    debugPrint('📄 LOAD MORE — Page $nextPage of $_lastPage');

    try {
      final response = await _api.get(
        ApiConstants.incidentsEndpoint,
        queryParameters: params,
      );

      final data = response.data;
      List<dynamic> newItems = [];

      if (data is Map<String, dynamic>) {
        // Server returns {incidents: [...], pagination: {...}}
        if (data.containsKey('incidents') && data['incidents'] is List) {
          newItems = data['incidents'] as List;
          final pag = data['pagination'] as Map<String, dynamic>?;
          if (pag != null) {
            _currentPage = (pag['current_page'] as int?) ?? nextPage;
            _lastPage = (pag['last_page'] as int?) ?? _lastPage;
            _total = (pag['total'] as int?) ?? _total;
          } else {
            _currentPage = nextPage;
          }
        } else if (data.containsKey('data') && data['data'] is List) {
          newItems = data['data'] as List;
          _currentPage = nextPage;
        }
      }

      // Client-side filtering when activeOnly is true (backend doesn't support status_not)
      List<Map<String, dynamic>> filteredItems =
          newItems.cast<Map<String, dynamic>>();
      if (activeOnly && filteredItems.isNotEmpty) {
        final beforeCount = filteredItems.length;
        filteredItems = filteredItems.where((incident) {
          final status = incident['status']?.toString().toLowerCase() ?? '';
          return status != 'resolved' &&
              status != 'closed' &&
              status != 'cancelled';
        }).toList();
        final filteredCount = beforeCount - filteredItems.length;
        if (filteredCount > 0) {
          debugPrint(
              '  🗑️ Client-side filter: removed $filteredCount resolved incidents from page $nextPage');
        }
      }

      _incidents.addAll(filteredItems);
      _errorMessage = null; // Clear error on success
      debugPrint(
          '  ✅ Loaded ${filteredItems.length} more (total: ${_incidents.length})');
    } on DioException catch (e) {
      debugPrint('  ❌ Load more failed: ${e.message}');
      _errorMessage = 'Failed to load more incidents';
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // ── Go to Specific Page ────────────────────────────────────

  Future<void> goToPage(int page, {bool activeOnly = false}) async {
    if (page < 1 || page > _lastPage || page == _currentPage) return;
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final params = _buildQueryParams(page: page, activeOnly: activeOnly);

    debugPrint('');
    debugPrint('📄 GO TO PAGE — Page $page of $_lastPage');

    try {
      final response = await _api.get(
        ApiConstants.incidentsEndpoint,
        queryParameters: params,
      );

      _parseIncidentList(response.data, activeOnly: activeOnly);
      _currentPage = page;
      _errorMessage = null; // Clear error on success
      debugPrint('  ✅ Loaded page $page with ${_incidents.length} items');
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      debugPrint('  ❌ Go to page failed: $e');
      _errorMessage = 'Failed to load page';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Fetch Single Incident ─────────────────────────────────

  Future<void> fetchIncident(int incidentId, {bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    final endpoint = ApiConstants.incidentDetail(incidentId);

    if (!silent) {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('🔍 INCIDENT DETAIL — ID: $incidentId');
      debugPrint('═══════════════════════════════════════════════════');
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Add query parameters to load relationships
      // Try both 'include' (common in Laravel APIs with Spatie QueryBuilder)
      // and 'with' (custom Laravel implementations)
      final queryParams = {
        'include': 'citizen,assigned_user',
        'with': 'citizen,assigned_user',
      };

      if (!silent) debugPrint('  📎 Query params: $queryParams');

      final response = await _api.get(endpoint, queryParameters: queryParams);
      stopwatch.stop();

      if (!silent)
        debugPrint('  ✅ Response in ${stopwatch.elapsedMilliseconds}ms');

      final data = response.data;
      if (data is Map<String, dynamic>) {
        // The API likely returns {success: true, incident: {...}}
        // Try 'incident' key first (singular), then 'data', then fall back to full response
        final parsed = data['incident'] as Map<String, dynamic>? ??
            data['data'] as Map<String, dynamic>? ??
            data;

        // Preserve optimistic local status from the definitive queues
        if (hasPendingEStreetFormFor(incidentId)) {
          parsed['status'] = 'resolved';
        } else {
          final pendingAction = latestPendingActionFor(incidentId);
          if (pendingAction != null) {
            parsed['status'] = pendingAction;
          }
        }

        _currentIncident = parsed;
        
        // Clear any stale errors on successful fetch
        if (!silent) _errorMessage = null;

        // START DEBUG LOGGING
        debugPrint('  🔍 DEBUG: Validating Assigned User Data');
        debugPrint('  - ID: ${_currentIncident?['id']}');
        debugPrint('  - Status: ${_currentIncident?['status']}');

        final assignedUser = _currentIncident?['assigned_user'];
        debugPrint('  - raw assigned_user field: $assignedUser');

        if (assignedUser is Map) {
          debugPrint('  - assigned_user[name]: ${assignedUser['name']}');
          debugPrint('  - assigned_user[id]: ${assignedUser['id']}');
        } else if (assignedUser == null) {
          debugPrint('  - assigned_user is NULL');
        } else {
          debugPrint(
              '  - assigned_user is of type: ${assignedUser.runtimeType}');
        }

        // FULL JSON DUMP
        debugPrint('  📜 FULL INCIDENT JSON:');
        try {
          // Simple manual string conversion to avoid import issues if dart:convert is missing/clashing
          debugPrint(_currentIncident.toString());
        } catch (e) {
          debugPrint('  (Failed to print JSON: $e)');
        }
        // END DEBUG LOGGING

        // Debug: Log the raw response structure first
        debugPrint('  📋 Response structure:');
        debugPrint('    - Has "incident" key: ${data.containsKey('incident')}');
        debugPrint('    - Has "data" key: ${data.containsKey('data')}');
        debugPrint(
            '    - Has "success" key: ${data.containsKey('success')} (${data['success']})');
        debugPrint('    - Keys: ${data.keys.toList()}');

        // Debug: Log the FULL incident data to see what we're getting
        debugPrint('  📋 Full incident data:');
        final incidentJson =
            const JsonEncoder.withIndent('    ').convert(_currentIncident);
        final lines = incidentJson.split('\n');
        final maxLines = lines.length < 50 ? lines.length : 50;
        for (var i = 0; i < maxLines; i++) {
          debugPrint('    ${lines[i]}');
        }
        if (lines.length > 50) {
          debugPrint('    ... [${lines.length - 50} more lines]');
        }

        debugPrint('  📋 Loaded: #${_currentIncident?['incident_number']} '
            'status=${_currentIncident?['status']} '
            'severity=${_currentIncident?['severity']}');

        // Debug log to check if relationships are loaded
        final hasCitizen = _currentIncident?['citizen'] != null;
        final hasAssignedUser = _currentIncident?['assigned_user'] != null;
        final hasCitizenId = _currentIncident?['citizen_id'] != null;
        final hasAssignedToId = _currentIncident?['assigned_to'] != null;

        debugPrint('  👤 Citizen object loaded: $hasCitizen');
        debugPrint(
            '  🆔 Citizen ID present: $hasCitizenId (value: ${_currentIncident?['citizen_id']})');
        debugPrint('  🚨 Assigned User object loaded: $hasAssignedUser');
        debugPrint(
            '  🆔 Assigned To ID present: $hasAssignedToId (value: ${_currentIncident?['assigned_to']})');

        if (hasCitizen) {
          final citizenName = _currentIncident?['citizen']?['name'];
          debugPrint('     ✅ Citizen name: $citizenName');
        }
        if (hasAssignedUser) {
          final assignedName = _currentIncident?['assigned_user']?['name'];
          debugPrint('     ✅ Assigned to: $assignedName');
        }

        // Debug: Log E-Street form related fields
        if (_currentIncident != null) {
          debugPrint('  📋 E-Street Form Fields:');
          debugPrint('    - e_street_form: ${_currentIncident!['e_street_form'] != null ? 'EXISTS (${(_currentIncident!['e_street_form'] as String?)?.length ?? 0} chars)' : 'NULL'}');
          debugPrint('    - e_street_form_pdf: ${_currentIncident!['e_street_form_pdf'] ?? 'NULL'}');
        }
      }
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      debugPrint('  ❌ Error: $e');
      if (!silent) _errorMessage = 'Failed to load incident.';
    }

    if (!silent) _isLoading = false;
    notifyListeners();
  }

  // ── Create Incident ────────────────────────────────────────

  Future<bool> createIncident(Map<String, dynamic> incidentData) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('➕ CREATE INCIDENT');
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint(
        '  📦 Data: ${const JsonEncoder.withIndent("  ").convert(incidentData)}');

    try {
      final response = await _api.post(
        ApiConstants.incidentsEndpoint,
        data: incidentData,
      );

      debugPrint('  ✅ Created! Status: ${response.statusCode}');
      debugPrint('  📋 Response: ${response.data}');

      _isSubmitting = false;
      notifyListeners();

      // Refresh list
      fetchIncidents(silent: true);
      return true;
    } on DioException catch (e) {
      debugPrint('  ❌ Create failed: ${e.response?.statusCode}');
      debugPrint('  📋 Errors: ${e.response?.data}');

      if (e.response?.data is Map<String, dynamic>) {
        final errors = e.response!.data['errors'];
        if (errors is Map) {
          _errorMessage =
              errors.values.expand((e) => e is List ? e : [e]).join('\n');
        } else {
          _errorMessage = e.response!.data['message']?.toString() ??
              'Failed to create incident.';
        }
      } else {
        _errorMessage = 'Failed to create incident.';
      }
    } catch (e) {
      debugPrint('  ❌ Unexpected: $e');
      _errorMessage = 'Something went wrong.';
    }

    _isSubmitting = false;
    notifyListeners();
    return false;
  }

  // ── Incident Actions ───────────────────────────────────────

  Future<bool> acknowledgeIncident(int id, {String? notes}) async {
    return _performAction(
        id, 'acknowledged', ApiConstants.incidentAcknowledge(id), notes);
  }

  Future<bool> respondToIncident(int id, {String? notes}) async {
    return _performAction(
        id, 'responding', ApiConstants.incidentRespond(id), notes);
  }

  Future<bool> markOnScene(int id, {String? notes}) async {
    return _performAction(
        id, 'on_scene', ApiConstants.incidentOnScene(id), notes);
  }

  Future<bool> resolveIncident(int id, {String? notes}) async {
    return _performAction(
        id, 'resolved', ApiConstants.incidentResolve(id), notes);
  }

  Future<bool> closeIncident(int id, {String? notes}) async {
    return _performAction(id, 'closed', ApiConstants.incidentClose(id), notes);
  }

  Future<bool> cancelIncident(int id, {String? notes}) async {
    return _performAction(
        id, 'cancelled', ApiConstants.incidentCancel(id), notes);
  }

  Future<bool> _performAction(
      int id, String action, String endpoint, String? notes) async {
    final fullUrl = '${ApiConstants.baseUrl}$endpoint';
    debugPrint('🔄 Incident #$id action: $action');
    debugPrint('  📡 Full URL: POST $fullUrl');

    // ── Optimistic UI update ────────────────────────────────────
    // Immediately reflect the new status in the local state so the button
    // responds instantly regardless of network.
    _applyOptimisticStatus(id, action);

    _isSubmitting = true;
    notifyListeners();

    try {
      final data = notes != null && notes.isNotEmpty ? {'notes': notes} : null;
      final response = await _api.post(endpoint, data: data);
      debugPrint('  ✅ Action completed: ${response.statusCode}');

      // Refresh incident detail and list with real server data
      await Future.wait([
        fetchIncident(id),
        fetchIncidents(silent: true),
      ]);

      // Trigger GPS / response provider callbacks
      _handleActionCallbacks(id, action);

      _isSubmitting = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      // ── Offline / network error → enqueue ─────────────────────
      if (isOfflineException(e)) {
        final recordedAt = DateTime.now().toIso8601String();
        debugPrint(
            '📵 Offline — queuing ${action} for incident #$id to sync later');
        await _actionQueue.enqueue(PendingAction(
          incidentId: id,
          action: action,
          recordedAt: recordedAt,
          notes: notes,
        ));

        // Inject local timestamp into incident data for offline use
        _injectLocalTimestamp(id, action, recordedAt);

        // Still trigger callbacks so GPS / response state changes happen locally
        _handleActionCallbacks(id, action);

        _isSubmitting = false;
        _errorMessage = null; // Clear error — action is queued, not failed
        notifyListeners();
        return true; // Return true so the UI shows success (optimistic)
      }

      // Non-network error (validation, 4xx, etc.) → revert optimistic update
      debugPrint('  ❌ Action failed: ${e.response?.statusCode}');
      debugPrint('  📋 Error response: ${e.response?.data}');

      // Revert status by refreshing from server
      fetchIncident(id, silent: true);

      if (e.response?.data is Map<String, dynamic>) {
        _errorMessage = e.response!.data['message']?.toString() ??
            'Failed to $action incident.';
      } else {
        _errorMessage = 'Failed to $action incident.';
      }
      _isSubmitting = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('  ❌ Unexpected error: $e');
      fetchIncident(id, silent: true); // Revert optimistic update
      _errorMessage = 'Something went wrong.';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Triggers GPS tracking callbacks based on action outcome.
  void _handleActionCallbacks(int id, String action) {
    switch (action) {
      case 'responding':
        debugPrint(
            '📍 Respond succeeded — triggering active GPS tracking for incident #$id');
        onRespondStarted?.call(id);
        break;
      case 'on_scene':
      case 'on-scene':
        debugPrint(
            '📍 On-scene succeeded — notifying response provider for incident #$id');
        onOnSceneReached?.call(id);
        break;
      case 'resolved':
      case 'closed':
      case 'cancelled':
        debugPrint('📍 $action succeeded — reverting to passive GPS tracking');
        onRespondEnded?.call(id);
        break;
    }
  }

  // ── Assignment Actions (Compatibility Layer) ────────────────

  // These methods bridge the gap for screens that use assignment-centric logic
  // but map them to the corresponding incident actions where possible.

  Future<bool> acceptAssignment(int assignmentId) async {
    // If we can map assignmentId to incidentId, great.
    // For now, we assume the UI handles the mapping or we just use the current logic.
    // Use respondToIncident logic if we have an active incident ID context,
    // otherwise just return false or implement specific endpoint if it exists.

    // Attempt to find the incident ID associated with this assignment from our loaded list
    // This is a heuristic since we don't have a direct map loaded.
    // If the backend has specific assignment endpoints, they should be used.
    // For now, to prevent crash, we'll try to use the emergency assign endpoint or standard respond.

    debugPrint(
        '🔄 Accept Assignment #$assignmentId (bridging to respondToIncident)');

    // If we have a current incident loaded, use its ID
    if (_currentIncident != null) {
      return respondToIncident(_currentIncident!['id'] as int);
    }

    _errorMessage = 'Cannot accept assignment: No active incident context.';
    notifyListeners();
    return false;
  }

  Future<bool> rejectAssignment(int assignmentId, String reason) async {
    debugPrint('🔄 Reject Assignment #$assignmentId');
    // Implementation pending backend endpoint
    // For now, just return true to simulate success or false with error
    _errorMessage = 'Reject assignment not yet implemented on backend.';
    notifyListeners();
    return false;
  }

  Future<bool> updateAssignmentStatus(int assignmentId, String status) async {
    debugPrint('🔄 Update Assignment #$assignmentId to $status');

    if (_currentIncident != null) {
      final id = _currentIncident!['id'] as int;
      if (status == 'en_route')
        return respondToIncident(id); // Already responded?
      if (status == 'on_scene') return markOnScene(id);
      if (status == 'completed') return resolveIncident(id);
    }

    return false;
  }

  // Helper to get assignment by ID (stubbed for now to prevent crash)
  // Requires importing assignment model if we want to return a real object.
  // For now return null or dynamic.
  dynamic getAssignment(int assignmentId) {
    return null;
  }

  // ── Fetch Location Updates ─────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchLocationUpdates(int id) async {
    debugPrint('📍 Fetching location updates for incident #$id');

    try {
      final response = await _api
          .get('${ApiConstants.incidentsEndpoint}/$id/location-updates');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        final updates = (data['data'] as List).cast<Map<String, dynamic>>();
        debugPrint('  ✅ ${updates.length} location updates');
        return updates;
      }
    } on DioException catch (e) {
      debugPrint('  ❌ Location updates failed: ${e.message}');
    }
    return [];
  }

  // ── Helpers ────────────────────────────────────────────────

  void _parseIncidentList(dynamic data, {bool activeOnly = false}) {
    List<dynamic> list;

    if (data is Map<String, dynamic>) {
      debugPrint('  🔍 Response is Map — keys: ${data.keys.toList()}');

      // Server returns {success, incidents: [...], pagination: {...}}
      if (data.containsKey('incidents') && data['incidents'] is List) {
        list = data['incidents'] as List;
        final pag = data['pagination'] as Map<String, dynamic>?;
        if (pag != null) {
          _currentPage = (pag['current_page'] as int?) ?? 1;
          _lastPage = (pag['last_page'] as int?) ?? 1;
          _total = (pag['total'] as int?) ?? list.length;
        }
        debugPrint(
            '  ✅ Found "incidents" key with ${list.length} items, page $_currentPage/$_lastPage, total $_total');
      } else if (data.containsKey('data') && data['data'] is List) {
        list = data['data'] as List;
        debugPrint('  ✅ Found "data" key with ${list.length} items');
      } else if (data.containsKey('data') && data['data'] is Map) {
        final inner = data['data'] as Map<String, dynamic>;
        list = (inner['data'] as List?) ?? [];
        _currentPage = (inner['current_page'] as int?) ?? 1;
        _lastPage = (inner['last_page'] as int?) ?? 1;
        _total = (inner['total'] as int?) ?? list.length;
        debugPrint(
            '  ✅ Paginated: ${list.length} items, page $_currentPage/$_lastPage, total $_total');
      } else {
        list = [];
        debugPrint('  ⚠️ Unexpected map keys: ${data.keys.toList()}');
      }

      if (data.containsKey('success'))
        debugPrint('  📌 success: ${data['success']}');
      if (data.containsKey('message'))
        debugPrint('  📌 message: ${data['message']}');
    } else if (data is List) {
      list = data;
      debugPrint('  🔍 Response is List with ${list.length} items');
    } else {
      list = [];
      debugPrint('  ❌ Unexpected type: ${data.runtimeType}');
    }

    _incidents = list.cast<Map<String, dynamic>>();

    // Preserve optimistic local statuses from the definitive queues
    for (int i = 0; i < _incidents.length; i++) {
      final id = _incidents[i]['id'] as int;
      if (hasPendingEStreetFormFor(id)) {
        _incidents[i]['status'] = 'resolved';
      } else {
        final pendingAction = latestPendingActionFor(id);
        if (pendingAction != null) {
          _incidents[i]['status'] = pendingAction;
        }
      }
    }

    // Client-side filtering when activeOnly is true (backend doesn't support status_not)
    if (activeOnly) {
      final beforeCount = _incidents.length;
      _incidents = _incidents.where((incident) {
        final status = incident['status']?.toString().toLowerCase() ?? '';
        return status != 'resolved' &&
            status != 'closed' &&
            status != 'cancelled';
      }).toList();
      final filteredCount = beforeCount - _incidents.length;
      if (filteredCount > 0) {
        debugPrint(
            '  🗑️ Client-side filter: removed $filteredCount resolved/closed/cancelled incidents');
        debugPrint('  ✅ Remaining: ${_incidents.length} active incidents');
      }
    }

    // ── Client-side unit filter (safety net) ─────────────────
    // Only show incidents that have been explicitly dispatched to the
    // current user's unit. Undispatched incidents (null/empty
    // dispatched_unit) are hidden — the MIS must dispatch first.
    // Admins bypass this filter and see everything.
    bool unitFilterWasApplied = false;
    if (_userUnit != null && _userUnit!.isNotEmpty && !_isAdmin) {
      final beforeUnitFilter = _incidents.length;
      _incidents = _incidents.where((incident) {
        final unit = incident['dispatched_unit']?.toString();
        // ONLY keep incidents whose dispatched_unit exactly matches
        // the user's unit. Null/empty = not yet dispatched = hidden.
        return unit != null && unit.isNotEmpty && unit == _userUnit;
      }).toList();
      final removedByUnit = beforeUnitFilter - _incidents.length;
      if (removedByUnit > 0) {
        unitFilterWasApplied = true;
        debugPrint(
            '  🏷️ Unit filter: removed $removedByUnit incidents not dispatched to "$_userUnit"');
        debugPrint('  ✅ Remaining after unit filter: ${_incidents.length}');
      }
    }

    // ── Recalculate pagination after client-side filtering ────
    // If client-side filtering significantly changed the incident count,
    // recalculate pagination to reflect the actual visible results.
    // This is necessary because the server returns pagination for ALL
    // incidents, not just those matching the unit filter.
    if (unitFilterWasApplied || activeOnly) {
      // Update total to reflect filtered count
      _total = _incidents.length;
      // Recalculate last page based on filtered count
      // Assume 15 items per page (matches the default limit)
      final itemsPerPage = 15;
      _lastPage = (_total / itemsPerPage).ceil();
      if (_lastPage < 1) _lastPage = 1;
      // Ensure current page doesn't exceed last page
      if (_currentPage > _lastPage) _currentPage = _lastPage;

      debugPrint(
          '  📊 Recalculated pagination: $_total total incidents, $_lastPage pages');
    } else if (_total == 0) {
      _total = _incidents.length;
    }

    // Check for new incidents and trigger alarm if found
    alarmService.checkForNewIncidents(_incidents);

    if (kDebugMode) {
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('  📋 INCIDENT SUMMARY (${_incidents.length} total):');
      for (var i = 0; i < _incidents.length && i < 10; i++) {
        final inc = _incidents[i];
        debugPrint('     [$i] id=${inc['id']} '
            'type="${inc['incident_type'] ?? inc['type'] ?? 'N/A'}" '
            'status="${inc['status'] ?? 'N/A'}" '
            'severity="${inc['severity'] ?? 'N/A'}"');
      }
      if (_incidents.length > 10) {
        debugPrint('     ... and ${_incidents.length - 10} more');
      }
    }
  }

  void _handleDioError(DioException e) {
    debugPrint('  ❌ DioException: ${e.type}');
    debugPrint('     Status  : ${e.response?.statusCode}');
    debugPrint('     Message : ${e.message}');
    debugPrint('     Response: ${e.response?.data}');

    if (e.response?.statusCode == 401) {
      _errorMessage = 'Not authenticated — please log in again.';
    } else if (e.response?.statusCode == 403) {
      _errorMessage = 'Access denied — insufficient permissions.';
    } else if (e.type == DioExceptionType.connectionError) {
      _errorMessage = 'Cannot reach server. Check connection.';
    } else if (e.type == DioExceptionType.connectionTimeout) {
      _errorMessage = 'Connection timed out.';
    } else {
      _errorMessage = e.response?.data?['message']?.toString() ??
          'Request failed (${e.response?.statusCode ?? "network"}).';
    }
  }

  void _logFinalState() {
    debugPrint('───────────────────────────────────────────────────');
    debugPrint(
        '  📊 Final: ${_incidents.length} incidents, error=${_errorMessage ?? "none"}');
    debugPrint('═══════════════════════════════════════════════════');
  }

  String _tokenPreview() {
    final token = _api.prefs.getString(ApiConstants.tokenKey);
    if (token == null || token.isEmpty) return '⚠️ NO TOKEN';
    if (token.length <= 12) return token;
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearCurrentIncident() {
    _currentIncident = null;
    notifyListeners();
  }

  /// Injects the PDF URL into the current incident if it's missing.
  /// Used after form submission when the server returns a PDF URL but
  /// the incident detail endpoint hasn't updated yet.
  void injectPdfUrl(int incidentId, String pdfUrl) {
    if (_currentIncident != null && _currentIncident!['id'] == incidentId) {
      final currentPdfUrl = _currentIncident!['e_street_form_pdf'];
      if (currentPdfUrl == null) {
        _currentIncident!['e_street_form_pdf'] = pdfUrl;
        debugPrint('📄 ✅ INJECTED PDF URL: $pdfUrl');
        debugPrint('   Into incident #$incidentId');
        notifyListeners();
      } else {
        debugPrint('📄 Current incident already has PDF URL: $currentPdfUrl');
      }
    } else {
      if (_currentIncident == null) {
        debugPrint('⚠️ Cannot inject PDF URL - _currentIncident is null');
      } else {
        debugPrint('⚠️ Cannot inject PDF URL - incident ID mismatch');
        debugPrint('   Expected: $incidentId, Got: ${_currentIncident!['id']}');
      }
    }
  }
}
