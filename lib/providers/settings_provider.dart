import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  bool _rememberPosition = true;
  bool get rememberPosition => _rememberPosition;

  bool _autoPlay = true;
  bool get autoPlay => _autoPlay;

  double _defaultSpeed = 1.0;
  double get defaultSpeed => _defaultSpeed;

  bool _showSubtitlesByDefault = true;
  bool get showSubtitlesByDefault => _showSubtitlesByDefault;

  bool _gridView = false;
  bool get gridView => _gridView;

  String _sortBy = 'date';
  String get sortBy => _sortBy;

  bool _sortDesc = true;
  bool get sortDesc => _sortDesc;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();

      // قراءة آمنة للـ themeMode مع ضمان أنه ضمن القيم المسموحة
      final themeIndex = p.getInt('themeMode') ?? 1;
      _themeMode = themeIndex >= 0 && themeIndex < ThemeMode.values.length
          ? ThemeMode.values[themeIndex]
          : ThemeMode.dark;

      _rememberPosition = p.getBool('rememberPosition') ?? true;
      _autoPlay = p.getBool('autoPlay') ?? true;
      _defaultSpeed = p.getDouble('defaultSpeed') ?? 1.0;
      _showSubtitlesByDefault = p.getBool('showSubtitles') ?? true;
      _gridView = p.getBool('gridView') ?? false;
      _sortBy = p.getString('sortBy') ?? 'date';
      _sortDesc = p.getBool('sortDesc') ?? true;
      notifyListeners();
    } catch (e) {
      // في حال فشل القراءة، نبقى على الإعدادات الافتراضية
      debugPrint('Settings load error: $e');
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('themeMode', _themeMode.index);
    await p.setBool('rememberPosition', _rememberPosition);
    await p.setBool('autoPlay', _autoPlay);
    await p.setDouble('defaultSpeed', _defaultSpeed);
    await p.setBool('showSubtitles', _showSubtitlesByDefault);
    await p.setBool('gridView', _gridView);
    await p.setString('sortBy', _sortBy);
    await p.setBool('sortDesc', _sortDesc);
  }

  void setThemeMode(ThemeMode v) { _themeMode = v; notifyListeners(); _save(); }
  void setRememberPosition(bool v) { _rememberPosition = v; notifyListeners(); _save(); }
  void setAutoPlay(bool v) { _autoPlay = v; notifyListeners(); _save(); }
  void setDefaultSpeed(double v) { _defaultSpeed = v; notifyListeners(); _save(); }
  void setShowSubtitlesByDefault(bool v) { _showSubtitlesByDefault = v; notifyListeners(); _save(); }
  void setGridView(bool v) { _gridView = v; notifyListeners(); _save(); }
  void setSortBy(String v) { _sortBy = v; notifyListeners(); _save(); }
  void setSortDesc(bool v) { _sortDesc = v; notifyListeners(); _save(); }
}