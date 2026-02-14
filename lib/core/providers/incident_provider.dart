import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';

/// Manages incident list, detail, statistics, and CRUD state
/// with detailed debug logging.
class IncidentProvider extends ChangeNotifier {
  final ApiClient _api;

  IncidentProvider(this._api);

  // ── State ──────────────────────────────────────────────────

  List<Map<String, dynamic>> _incidents = [];
  Map<String, dynamic>? _currentIncident;
  Map<String, dynamic>? _statistics;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSubmitting = false;
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

  // Auto-refresh
  Timer? _refreshTimer;

  // ── Getters ────────────────────────────────────────────────

  List<Map<String, dynamic>> get incidents => _incidents;
  Map<String, dynamic>? get currentIncident => _currentIncident;
  Map<String, dynamic>? get statistics => _statistics;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  DateTime? get lastFetchTime => _lastFetchTime;
  int get incidentCount => _incidents.length;
  int get totalCount => _total;
  bool get hasMore => _currentPage < _lastPage;

  String? get statusFilter => _statusFilter;
  String? get severityFilter => _severityFilter;
  String? get typeFilter => _typeFilter;
  String? get municipalityFilter => _municipalityFilter;
  String? get searchQuery => _searchQuery;

  // ── Computed Stats ─────────────────────────────────────────

  int get activeCount => _statistics?['active_incidents'] ?? _incidents.where((i) =>
      !['resolved', 'closed', 'cancelled'].contains((i['status'] ?? '').toString().toLowerCase())).length;

  int get criticalCount => _statistics?['critical_incidents'] ?? _incidents.where((i) =>
      (i['severity'] ?? '').toString().toLowerCase() == 'critical').length;

  int get newCount => _statistics?['new_incidents'] ?? _incidents.where((i) =>
      (i['status'] ?? '').toString().toLowerCase() == 'reported').length;

  int get todayTotal => _statistics?['today_total'] ?? _incidents.length;

  // ── Auto-refresh ───────────────────────────────────────────

  void startAutoRefresh({Duration interval = const Duration(seconds: 30)}) {
    stopAutoRefresh();
    debugPrint('⏱️ Auto-refresh started (every ${interval.inSeconds}s)');
    _refreshTimer = Timer.periodic(interval, (_) {
      debugPrint('⏱️ Auto-refresh tick');
      fetchIncidents(silent: true);
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
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

  Map<String, dynamic> _buildQueryParams({int? page, int limit = 1200}) {
    final params = <String, dynamic>{'limit': limit, 'page': page ?? 1};
    if (_statusFilter != null) params['status'] = _statusFilter;
    if (_severityFilter != null) params['severity'] = _severityFilter;
    if (_typeFilter != null) params['type'] = _typeFilter;
    if (_municipalityFilter != null) params['municipality'] = _municipalityFilter;
    if (_searchQuery != null && _searchQuery!.isNotEmpty) params['search'] = _searchQuery;
    return params;
  }

  // ── Fetch Statistics ───────────────────────────────────────

  /// Statistics are computed locally from fetched incidents since
  /// the server does not expose a /statistics endpoint.
  Future<void> fetchStatistics({String period = '24h'}) async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('📊 STATISTICS (computed locally from incident list)');
    debugPrint('═══════════════════════════════════════════════════');

    // Ensure we have fresh data
    if (_incidents.isEmpty) {
      await fetchIncidents(silent: true);
    }

    // Compute stats from local data
    _statistics = {
      'active_incidents': _incidents.where((i) =>
          !['resolved', 'closed', 'cancelled'].contains(
              (i['status'] ?? '').toString().toLowerCase())).length,
      'critical_incidents': _incidents.where((i) =>
          (i['severity'] ?? '').toString().toLowerCase() == 'critical').length,
      'new_incidents': _incidents.where((i) =>
          (i['status'] ?? '').toString().toLowerCase() == 'reported').length,
      'today_total': _incidents.length,
    };

    debugPrint('  📊 Stats: $_statistics');
    notifyListeners();
  }

  // ── Fetch All Incidents ────────────────────────────────────

  Future<void> fetchIncidents({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    _currentPage = 1;
    final params = _buildQueryParams(page: 1);
    final endpoint = ApiConstants.incidentsEndpoint;
    final fullUrl = '${ApiConstants.baseUrl}$endpoint';

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🔄 INCIDENT FETCH — START');
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('  📡 Endpoint : GET $fullUrl');
    debugPrint('  📎 Params   : $params');
    debugPrint('  🕐 Time     : ${DateTime.now().toIso8601String()}');
    debugPrint('  🔑 Token    : ${_tokenPreview()}');
    debugPrint('───────────────────────────────────────────────────');

    try {
      final stopwatch = Stopwatch()..start();

      final response = await _api.get(endpoint, queryParameters: params);

      stopwatch.stop();
      debugPrint('  ✅ Response in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('  📊 Status code : ${response.statusCode}');
      debugPrint('  📦 Data type   : ${response.data.runtimeType}');

      // Log raw response (truncated)
      final rawStr = const JsonEncoder.withIndent('  ').convert(response.data);
      final truncated = rawStr.length > 2000
          ? '${rawStr.substring(0, 2000)}\n  ... [truncated, ${rawStr.length} chars total]'
          : rawStr;
      debugPrint('  📋 Raw response:');
      for (final line in truncated.split('\n')) {
        debugPrint('     $line');
      }

      _parseIncidentList(response.data);
      _lastFetchTime = DateTime.now();
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e, stackTrace) {
      debugPrint('  ❌ Unexpected error: $e');
      debugPrint('     StackTrace: $stackTrace');
      _errorMessage = 'Something went wrong: ${e.runtimeType}';
    }

    _isLoading = false;
    _logFinalState();
    notifyListeners();
  }

  // ── Load More (Pagination) ─────────────────────────────────

  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    final nextPage = _currentPage + 1;
    final params = _buildQueryParams(page: nextPage);

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

      _incidents.addAll(newItems.cast<Map<String, dynamic>>());
      debugPrint('  ✅ Loaded ${newItems.length} more (total: ${_incidents.length})');
    } on DioException catch (e) {
      debugPrint('  ❌ Load more failed: ${e.message}');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // ── Fetch Single Incident ─────────────────────────────────

  Future<void> fetchIncident(int incidentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final endpoint = ApiConstants.incidentDetail(incidentId);

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🔍 INCIDENT DETAIL — ID: $incidentId');
    debugPrint('═══════════════════════════════════════════════════');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await _api.get(endpoint);
      stopwatch.stop();

      debugPrint('  ✅ Response in ${stopwatch.elapsedMilliseconds}ms');

      final data = response.data;
      if (data is Map<String, dynamic>) {
        _currentIncident = data['data'] as Map<String, dynamic>? ?? data;
        debugPrint('  📋 Loaded: #${_currentIncident?['incident_number']} '
            'status=${_currentIncident?['status']} '
            'severity=${_currentIncident?['severity']}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      debugPrint('  ❌ Error: $e');
      _errorMessage = 'Failed to load incident.';
    }

    _isLoading = false;
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
    debugPrint('  📦 Data: ${const JsonEncoder.withIndent("  ").convert(incidentData)}');

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
          _errorMessage = errors.values.expand((e) => e is List ? e : [e]).join('\n');
        } else {
          _errorMessage = e.response!.data['message']?.toString() ?? 'Failed to create incident.';
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
    return _performAction(id, 'acknowledge', ApiConstants.incidentAcknowledge(id), notes);
  }

  Future<bool> respondToIncident(int id, {String? notes}) async {
    return _performAction(id, 'respond', ApiConstants.incidentRespond(id), notes);
  }

  Future<bool> markOnScene(int id, {String? notes}) async {
    return _performAction(id, 'on-scene', ApiConstants.incidentOnScene(id), notes);
  }

  Future<bool> resolveIncident(int id, {String? notes}) async {
    return _performAction(id, 'resolve', ApiConstants.incidentResolve(id), notes);
  }

  Future<bool> closeIncident(int id, {String? notes}) async {
    return _performAction(id, 'close', ApiConstants.incidentClose(id), notes);
  }

  Future<bool> cancelIncident(int id, {String? notes}) async {
    return _performAction(id, 'cancel', ApiConstants.incidentCancel(id), notes);
  }

  Future<bool> _performAction(int id, String action, String endpoint, String? notes) async {
    final fullUrl = '${ApiConstants.baseUrl}$endpoint';
    debugPrint('🔄 Incident #$id action: $action');
    debugPrint('  📡 Full URL: POST $fullUrl');
    debugPrint('  📎 Data: ${notes != null && notes.isNotEmpty ? {'notes': notes} : 'null'}');

    try {
      final response = await _api.post(
        endpoint,
        data: notes != null && notes.isNotEmpty ? {'notes': notes} : null,
      );
      debugPrint('  ✅ Action completed: ${response.statusCode}');
      debugPrint('  📋 Response: ${response.data}');
      
      // Refresh incident detail and list
      await Future.wait([
        fetchIncident(id),
        fetchIncidents(silent: true),
      ]);
      
      return true;
    } on DioException catch (e) {
      debugPrint('  ❌ Action failed: ${e.response?.statusCode}');
      debugPrint('  📋 Error response: ${e.response?.data}');
      debugPrint('  🔍 Error type: ${e.type}');
      debugPrint('  💬 Error message: ${e.message}');
      
      if (e.response?.data is Map<String, dynamic>) {
        _errorMessage = e.response!.data['message']?.toString() ?? 'Failed to $action incident.';
      } else {
        _errorMessage = 'Failed to $action incident.';
      }
      notifyListeners();
      return false;
    }
  }

  // ── Fetch Location Updates ─────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchLocationUpdates(int id) async {
    debugPrint('📍 Fetching location updates for incident #$id');

    try {
      final response = await _api.get('${ApiConstants.incidentsEndpoint}/$id/location-updates');
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

  void _parseIncidentList(dynamic data) {
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
        debugPrint('  ✅ Found "incidents" key with ${list.length} items, page $_currentPage/$_lastPage, total $_total');
      } else if (data.containsKey('data') && data['data'] is List) {
        list = data['data'] as List;
        debugPrint('  ✅ Found "data" key with ${list.length} items');
      } else if (data.containsKey('data') && data['data'] is Map) {
        final inner = data['data'] as Map<String, dynamic>;
        list = (inner['data'] as List?) ?? [];
        _currentPage = (inner['current_page'] as int?) ?? 1;
        _lastPage = (inner['last_page'] as int?) ?? 1;
        _total = (inner['total'] as int?) ?? list.length;
        debugPrint('  ✅ Paginated: ${list.length} items, page $_currentPage/$_lastPage, total $_total');
      } else {
        list = [];
        debugPrint('  ⚠️ Unexpected map keys: ${data.keys.toList()}');
      }

      if (data.containsKey('success')) debugPrint('  📌 success: ${data['success']}');
      if (data.containsKey('message')) debugPrint('  📌 message: ${data['message']}');
    } else if (data is List) {
      list = data;
      debugPrint('  🔍 Response is List with ${list.length} items');
    } else {
      list = [];
      debugPrint('  ❌ Unexpected type: ${data.runtimeType}');
    }

    _incidents = list.cast<Map<String, dynamic>>();
    if (_total == 0) _total = _incidents.length;

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
    debugPrint('  📊 Final: ${_incidents.length} incidents, error=${_errorMessage ?? "none"}');
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
}
