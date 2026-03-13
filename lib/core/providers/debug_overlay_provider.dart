import 'package:flutter/material.dart';

/// Controls the system-wide floating debug overlay button.
/// Activated by a secret gesture on the dashboard; persists across routes.
class DebugOverlayProvider extends ChangeNotifier {
  bool _isEnabled = false;
  bool _isMinimized = false;
  Offset _position = const Offset(16, 140);

  bool get isEnabled => _isEnabled;
  bool get isMinimized => _isMinimized;
  Offset get position => _position;

  void activate() {
    _isEnabled = true;
    _isMinimized = false;
    notifyListeners();
  }

  void deactivate() {
    _isEnabled = false;
    notifyListeners();
  }

  void minimize() {
    _isMinimized = true;
    notifyListeners();
  }

  void expand() {
    _isMinimized = false;
    notifyListeners();
  }

  void updatePosition(Offset delta) {
    _position = _position + delta;
    notifyListeners();
  }
}
