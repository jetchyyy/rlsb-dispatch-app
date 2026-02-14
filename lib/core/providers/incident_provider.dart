import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../constants/api_constants.dart';
import '../models/assignment.dart';
import '../models/incident.dart';
import '../services/api_service.dart';

/// Manages incident assignments state.
class IncidentProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Assignment> _assignments = [];
  Incident? _currentIncident;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Getters ────────────────────────────────────────────────

  List<Assignment> get assignments => _assignments;
  Incident? get currentIncident => _currentIncident;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Active (non-completed/rejected) assignments.
  List<Assignment> get activeAssignments => _assignments
      .where((a) =>
          a.status != 'completed' && a.status != 'rejected')
      .toList();

  // ── Fetch Assignments ──────────────────────────────────────

  Future<void> fetchAssignments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.get(ApiConstants.assignments);
      final data = response.data;
      final List<dynamic> list =
          data is Map ? (data['data'] as List<dynamic>? ?? []) : data as List;
      _assignments = list
          .map((json) => Assignment.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['message']?.toString() ??
          'Failed to fetch assignments.';
    } catch (e) {
      _errorMessage = 'Something went wrong.';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Fetch Single Incident ─────────────────────────────────

  Future<void> fetchIncident(int incidentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response =
          await _api.get(ApiConstants.incidentDetail(incidentId));
      final data = response.data as Map<String, dynamic>;
      _currentIncident = Incident.fromJson(
        data['incident'] as Map<String, dynamic>? ?? data,
      );
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['message']?.toString() ??
          'Failed to fetch incident.';
    } catch (e) {
      _errorMessage = 'Something went wrong.';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Accept Assignment ──────────────────────────────────────

  Future<bool> acceptAssignment(int assignmentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.post(ApiConstants.acceptAssignment(assignmentId));
      // Update local state
      _updateLocalStatus(assignmentId, 'accepted');
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['message']?.toString() ??
          'Failed to accept assignment.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Reject Assignment ──────────────────────────────────────

  Future<bool> rejectAssignment(int assignmentId, String reason) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.post(
        ApiConstants.rejectAssignment(assignmentId),
        data: {'reason': reason},
      );
      _updateLocalStatus(assignmentId, 'rejected');
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['message']?.toString() ??
          'Failed to reject assignment.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Update Assignment Status ───────────────────────────────

  Future<bool> updateAssignmentStatus(
      int assignmentId, String status) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.put(
        ApiConstants.updateAssignmentStatus(assignmentId),
        data: {'status': status},
      );
      _updateLocalStatus(assignmentId, status);
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['message']?.toString() ??
          'Failed to update status.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────

  void _updateLocalStatus(int assignmentId, String status) {
    final index = _assignments.indexWhere((a) => a.id == assignmentId);
    if (index != -1) {
      final old = _assignments[index];
      _assignments[index] = Assignment(
        id: old.id,
        incidentId: old.incidentId,
        responderId: old.responderId,
        status: status,
        role: old.role,
        dispatchedAt: old.dispatchedAt,
        acceptedAt: old.acceptedAt,
        rejectedAt: old.rejectedAt,
        enRouteAt: old.enRouteAt,
        onSceneAt: old.onSceneAt,
        completedAt: old.completedAt,
        rejectionReason: old.rejectionReason,
        incident: old.incident,
        createdAt: old.createdAt,
        updatedAt: old.updatedAt,
      );
    }
  }

  /// Finds an assignment by its ID.
  Assignment? getAssignment(int id) {
    try {
      return _assignments.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
