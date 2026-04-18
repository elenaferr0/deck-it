import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  ThemeMode _themeMode;
  Color? _seedColor; // null = dynamic (follow system/platform)

  ThemeProvider(this._prefs, this._themeMode, this._seedColor);

  ThemeMode get themeMode => _themeMode;
  Color? get seedColor => _seedColor;

  static Future<ThemeProvider> create() async {
    final prefs = await SharedPreferences.getInstance();
    // ThemeMode stored as index: 0=system, 1=light, 2=dark. Default: system.
    final modeIndex = prefs.getInt('themeMode') ?? 0;
    final themeMode = ThemeMode.values[modeIndex.clamp(0, 2)];
    // Seed color stored as int; -1 means dynamic. Default: dynamic.
    final seedValue = prefs.getInt('seedColor') ?? -1;
    final seedColor = seedValue == -1 ? null : Color(seedValue);
    return ThemeProvider(prefs, themeMode, seedColor);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  Future<void> setSeedColor(Color? color) async {
    _seedColor = color;
    await _prefs.setInt('seedColor', color?.toARGB32() ?? -1);
    notifyListeners();
  }
}
