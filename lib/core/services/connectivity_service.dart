import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Singleton service that monitors network connectivity state changes.
///
/// Wraps `connectivity_plus` and provides:
/// - A stream of connectivity changes (debounced to avoid rapid-fire events)
/// - A cached `hasConnection` getter for sync access
/// - Callback registration for when connection is restored
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Whether the device currently has network connectivity.
  bool _hasConnection = true;
  bool get hasConnection => _hasConnection;

  /// Whether the service has been initialized.
  bool _initialized = false;

  /// Callbacks to invoke when connectivity is restored (offline → online).
  final List<VoidCallback> _onRestoredCallbacks = [];

  /// Register a callback that fires when connection transitions from
  /// offline → online. Used by LocationTrackingProvider to flush queue.
  void onConnectionRestored(VoidCallback callback) {
    _onRestoredCallbacks.add(callback);
  }

  /// Remove a previously registered callback.
  void removeOnConnectionRestored(VoidCallback callback) {
    _onRestoredCallbacks.remove(callback);
  }

  /// Initialize the service and start listening to connectivity changes.
  /// Safe to call multiple times (idempotent).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Check initial state
    try {
      final result = await _connectivity.checkConnectivity();
      _hasConnection = _isConnected(result);
      debugPrint('📍 🌐 ConnectivityService: initial state = ${_hasConnection ? "online" : "offline"}');
    } catch (e) {
      debugPrint('📍 ⚠️ ConnectivityService: failed to check initial state: $e');
      _hasConnection = true; // Assume connected if check fails
    }

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (e) {
        debugPrint('📍 ⚠️ ConnectivityService: stream error: $e');
      },
    );
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final nowConnected = _isConnected(results);
    final wasConnected = _hasConnection;
    _hasConnection = nowConnected;

    if (wasConnected != nowConnected) {
      debugPrint('📍 🌐 Connectivity changed: ${wasConnected ? "online" : "offline"} → ${nowConnected ? "online" : "offline"}');

      // Fire restoration callbacks when transitioning offline → online
      if (!wasConnected && nowConnected) {
        debugPrint('📍 🌐 Connection restored — notifying ${_onRestoredCallbacks.length} listener(s)');
        for (final cb in _onRestoredCallbacks) {
          try {
            cb();
          } catch (e) {
            debugPrint('📍 ⚠️ ConnectivityService: callback error: $e');
          }
        }
      }
    }
  }

  /// Returns true if any of the results indicate active connectivity.
  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  /// Dispose the service (call on app teardown, if needed).
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _onRestoredCallbacks.clear();
    _initialized = false;
  }
}
