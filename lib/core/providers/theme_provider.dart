import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  static const String _themeKey = 'isDarkMode';

  // Default to true since Government Rescue theme is the baseline
  bool _isDarkMode = true;

  ThemeProvider(this._prefs) {
    _loadTheme();
  }

  bool get isDarkMode => _isDarkMode;

  void _loadTheme() {
    // If no preference is saved, it defaults to true (dark theme)
    _isDarkMode = _prefs.getBool(_themeKey) ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }
}
