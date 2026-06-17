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

  // 📝 تخصيص الترجمة
  double _subtitleFontSize = 19.0;
  double get subtitleFontSize => _subtitleFontSize;

  int _subtitleColorValue = 0xFFFFFFFF; // أبيض افتراضياً
  Color get subtitleColor => Color(_subtitleColorValue);

  double _subtitleBgOpacity = 0.6;
  double get subtitleBgOpacity => _subtitleBgOpacity;

  // 🔊 صوت المشغل الداخلي (افتراضي)
  double _defaultVolume = 1.0;
  double get defaultVolume => _defaultVolume;

  // ☀️ سطوع التطبيق (افتراضي)
  double _defaultBrightness = 0.7;
  double get defaultBrightness => _defaultBrightness;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();

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
      _subtitleFontSize = p.getDouble('subtitleFontSize') ?? 19.0;
      _subtitleColorValue = p.getInt('subtitleColorValue') ?? 0xFFFFFFFF;
      _subtitleBgOpacity = p.getDouble('subtitleBgOpacity') ?? 0.6;
      _defaultVolume = p.getDouble('defaultVolume') ?? 1.0;
      _defaultBrightness = p.getDouble('defaultBrightness') ?? 0.7;

      notifyListeners();
    } catch (e) {
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
    await p.setDouble('subtitleFontSize', _subtitleFontSize);
    await p.setInt('subtitleColorValue', _subtitleColorValue);
    await p.setDouble('subtitleBgOpacity', _subtitleBgOpacity);
    await p.setDouble('defaultVolume', _defaultVolume);
    await p.setDouble('defaultBrightness', _defaultBrightness);
  }

  // Setters
  void setThemeMode(ThemeMode v) { _themeMode = v; notifyListeners(); _save(); }
  void setRememberPosition(bool v) { _rememberPosition = v; notifyListeners(); _save(); }
  void setAutoPlay(bool v) { _autoPlay = v; notifyListeners(); _save(); }
  void setDefaultSpeed(double v) { _defaultSpeed = v; notifyListeners(); _save(); }
  void setShowSubtitlesByDefault(bool v) { _showSubtitlesByDefault = v; notifyListeners(); _save(); }
  void setGridView(bool v) { _gridView = v; notifyListeners(); _save(); }
  void setSortBy(String v) { _sortBy = v; notifyListeners(); _save(); }
  void setSortDesc(bool v) { _sortDesc = v; notifyListeners(); _save(); }
  void setSubtitleFontSize(double v) { _subtitleFontSize = v; notifyListeners(); _save(); }
  void setSubtitleColor(Color c) { _subtitleColorValue = c.value; notifyListeners(); _save(); }
  void setSubtitleBgOpacity(double v) { _subtitleBgOpacity = v; notifyListeners(); _save(); }
  void setDefaultVolume(double v) { _defaultVolume = v; notifyListeners(); _save(); }
  void setDefaultBrightness(double v) { _defaultBrightness = v; notifyListeners(); _save(); }
}