import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app's theme mode and map's night mode.
class ThemeProvider extends ChangeNotifier {
  static const _appThemeKey = 'isAppDarkMode';
  static const _mapNightModeKey = 'isMapNightMode';
  
  ThemeMode _themeMode = ThemeMode.light;
  bool _isMapNightMode = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isMapNightMode => _isMapNightMode;

  ThemeProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_appThemeKey) ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _isMapNightMode = prefs.getBool(_mapNightModeKey) ?? prefs.getBool('isDarkMode') ?? false; // fallback for old settings
    notifyListeners();
  }

  Future<void> toggleAppTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appThemeKey, isDark);
  }

  Future<void> toggleMapNightMode() async {
    _isMapNightMode = !_isMapNightMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mapNightModeKey, _isMapNightMode);
  }
}
