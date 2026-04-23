import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark, amoled }

extension AppThemeModeX on AppThemeMode {
  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
        return ThemeMode.dark;
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  AppThemeMode _appThemeMode;
  Color? _seedColor;

  ThemeProvider(this._prefs, this._appThemeMode, this._seedColor);

  AppThemeMode get appThemeMode => _appThemeMode;
  ThemeMode get themeMode => _appThemeMode.themeMode;
  Color? get seedColor => _seedColor;
  bool get isAmoled => _appThemeMode == AppThemeMode.amoled;

  static Future<ThemeProvider> create() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('themeMode') ?? 0;
    final appThemeMode = AppThemeMode.values[modeIndex.clamp(0, AppThemeMode.values.length - 1)];
    final seedValue = prefs.getInt('seedColor') ?? -1;
    final seedColor = seedValue == -1 ? null : Color(seedValue);
    return ThemeProvider(prefs, appThemeMode, seedColor);
  }

  Future<void> setAppThemeMode(AppThemeMode mode) async {
    _appThemeMode = mode;
    await _prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  Future<void> setSeedColor(Color? color) async {
    _seedColor = color;
    await _prefs.setInt('seedColor', color?.toARGB32() ?? -1);
    notifyListeners();
  }
}
