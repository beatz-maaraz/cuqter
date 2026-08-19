import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = const Color(0xFF7C3AED);
  bool _isLiquidBackgroundEnabled = false;
  double _liquidOpacity = 0.15;
  double _liquidBlur = 40.0;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  bool get isLiquidBackgroundEnabled => _isLiquidBackgroundEnabled;
  double get liquidOpacity => _liquidOpacity;
  double get liquidBlur => _liquidBlur;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt('theme_mode');
      if (themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeIndex];
      }
      
      final colorHex = prefs.getInt('theme_primary_color');
      if (colorHex != null) {
        _primaryColor = Color(colorHex);
      }
      
      _isLiquidBackgroundEnabled = prefs.getBool('theme_liquid_background') ?? false;
      _liquidOpacity = prefs.getDouble('theme_liquid_opacity') ?? 0.15;
      _liquidBlur = prefs.getDouble('theme_liquid_blur') ?? 40.0;
      
      notifyListeners();
    } catch (e) {
      // SharedPreferences might fail to initialize in some environments, ignore gracefully
    }
  }

  Future<void> toggleTheme(bool isOn) async {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', _themeMode.index);
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', _themeMode.index);
    } catch (_) {}
  }

  Future<void> updatePrimaryColor(Color color) async {
    _primaryColor = color;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_primary_color', color.toARGB32());
    } catch (_) {}
  }

  Future<void> toggleLiquidBackground(bool isEnabled) async {
    _isLiquidBackgroundEnabled = isEnabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('theme_liquid_background', _isLiquidBackgroundEnabled);
    } catch (_) {}
  }

  Future<void> updateLiquidOpacity(double opacity, {bool save = true}) async {
    _liquidOpacity = opacity;
    notifyListeners();
    if (!save) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('theme_liquid_opacity', _liquidOpacity);
    } catch (_) {}
  }

  Future<void> updateLiquidBlur(double blur, {bool save = true}) async {
    _liquidBlur = blur;
    notifyListeners();
    if (!save) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('theme_liquid_blur', _liquidBlur);
    } catch (_) {}
  }
}
