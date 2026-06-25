import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  bool _rememberPosition = true;
  bool get rememberPosition => _rememberPosition;

  bool _autoPlay = true;
  bool get autoPlay => _autoPlay;

  double _defaultSpeed = 1.0;
  double get defaultSpeed => _defaultSpeed;

  String _sortBy = 'date';
  String get sortBy => _sortBy;

  bool _sortDesc = true;
  bool get sortDesc => _sortDesc;

  bool _libraryGridView = false;
  bool get libraryGridView => _libraryGridView;

  bool _foldersGridView = false;
  bool get foldersGridView => _foldersGridView;

  bool _recentGridView = false;
  bool get recentGridView => _recentGridView;

  bool _showSubtitlesByDefault = true;
  bool get showSubtitlesByDefault => _showSubtitlesByDefault;

  double _subtitleFontSize = 30.0;
  double get subtitleFontSize => _subtitleFontSize;

  int _subtitleColorValue = 0xFFFFFFFF;
  Color get subtitleColor => Color(_subtitleColorValue);

  double _subtitleBgOpacity = 0.0;
  double get subtitleBgOpacity => _subtitleBgOpacity;

  Color _subtitleBgColor = const Color(0xFF000000);
  Color get subtitleBgColor => _subtitleBgColor;

  Color _outlineColor = const Color(0xFF000000);
  Color get outlineColor => _outlineColor;

  double _outlineWidth = 2.0;
  double get outlineWidth => _outlineWidth;

  bool _outlineEnabled = true;
  bool get outlineEnabled => _outlineEnabled;

  int _fontWeightIndex = 2;
  int get fontWeightIndex => _fontWeightIndex;

  double _bottomPadding = 48.0;
  double get bottomPadding => _bottomPadding;

  double _horizontalMargin = 24.0;
  double get horizontalMargin => _horizontalMargin;

  String _fontFamily = 'Roboto';
  String get fontFamily => _fontFamily;

  String _subtitleFolder = '';
  String get subtitleFolder => _subtitleFolder;

  String _subtitleEncoding = 'UTF-8';
  String get subtitleEncoding => _subtitleEncoding;

  String _preferredSubtitleLanguage = 'ara';
  String get preferredSubtitleLanguage => _preferredSubtitleLanguage;

  double _defaultSubtitleSync = 0.0;
  double get defaultSubtitleSync => _defaultSubtitleSync;

  bool _subtitleItalic = false;
  bool get subtitleItalic => _subtitleItalic;

  bool _subtitleRTL = false;
  bool get subtitleRTL => _subtitleRTL;

  bool _textShadowEnabled = false;
  bool get textShadowEnabled => _textShadowEnabled;

  Color _textShadowColor = const Color(0xFF000000);
  Color get textShadowColor => _textShadowColor;

  double _textShadowBlurRadius = 4.0;
  double get textShadowBlurRadius => _textShadowBlurRadius;

  double _textShadowOffsetX = 1.0;
  double get textShadowOffsetX => _textShadowOffsetX;

  double _textShadowOffsetY = 1.0;
  double get textShadowOffsetY => _textShadowOffsetY;

  bool _boxShadowEnabled = false;
  bool get boxShadowEnabled => _boxShadowEnabled;

  Color _boxShadowColor = const Color(0xFF000000);
  Color get boxShadowColor => _boxShadowColor;

  double _boxShadowBlurRadius = 4.0;
  double get boxShadowBlurRadius => _boxShadowBlurRadius;

  double _boxShadowOffsetX = 1.0;
  double get boxShadowOffsetX => _boxShadowOffsetX;

  double _boxShadowOffsetY = 1.0;
  double get boxShadowOffsetY => _boxShadowOffsetY;

  double _defaultAudioBoost = 100.0;
  double get defaultAudioBoost => _defaultAudioBoost;

  String _preferredAudioLanguage = 'ara';
  String get preferredAudioLanguage => _preferredAudioLanguage;

  Locale _locale = const Locale('ar');
  Locale get locale => _locale;

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
      _sortBy = p.getString('sortBy') ?? 'date';
      _sortDesc = p.getBool('sortDesc') ?? true;
      _subtitleFontSize = p.getDouble('subtitleFontSize') ?? 30.0;
      _subtitleColorValue = p.getInt('subtitleColorValue') ?? 0xFFFFFFFF;
      _subtitleBgOpacity = p.getDouble('subtitleBgOpacity') ?? 0.0;
      _subtitleBgColor = Color(p.getInt('subtitleBgColor') ?? 0xFF000000);
      _outlineColor = Color(p.getInt('outlineColor') ?? 0xFF000000);
      _outlineWidth = p.getDouble('outlineWidth') ?? 2.0;
      _outlineEnabled = p.getBool('outlineEnabled') ?? true;

      _textShadowEnabled = p.getBool('textShadowEnabled') ?? false;
      _textShadowColor = Color(p.getInt('textShadowColor') ?? 0xFF000000);
      _textShadowBlurRadius = p.getDouble('textShadowBlurRadius') ?? 4.0;
      _textShadowOffsetX = p.getDouble('textShadowOffsetX') ?? 1.0;
      _textShadowOffsetY = p.getDouble('textShadowOffsetY') ?? 1.0;

      _boxShadowEnabled = p.getBool('boxShadowEnabled') ?? false;
      _boxShadowColor = Color(p.getInt('boxShadowColor') ?? 0xFF000000);
      _boxShadowBlurRadius = p.getDouble('boxShadowBlurRadius') ?? 4.0;
      _boxShadowOffsetX = p.getDouble('boxShadowOffsetX') ?? 1.0;
      _boxShadowOffsetY = p.getDouble('boxShadowOffsetY') ?? 1.0;

      _fontWeightIndex = p.getInt('fontWeightIndex') ?? 2;
      _bottomPadding = p.getDouble('bottomPadding') ?? 48.0;
      _horizontalMargin = p.getDouble('horizontalMargin') ?? 24.0;
      _fontFamily = p.getString('fontFamily') ?? 'Roboto';
      _subtitleFolder = p.getString('subtitleFolder') ?? '';
      _subtitleEncoding = p.getString('subtitleEncoding') ?? 'UTF-8';
      _preferredSubtitleLanguage = p.getString('preferredSubtitleLanguage') ?? 'ara';
      _defaultSubtitleSync = p.getDouble('defaultSubtitleSync') ?? 0.0;
      _subtitleItalic = p.getBool('subtitleItalic') ?? false;
      _subtitleRTL = p.getBool('subtitleRTL') ?? false;
      _defaultAudioBoost = p.getDouble('defaultAudioBoost') ?? 100.0;
      _preferredAudioLanguage = p.getString('preferredAudioLanguage') ?? 'ara';

      _libraryGridView = p.getBool('libraryGridView') ?? false;
      _foldersGridView = p.getBool('foldersGridView') ?? false;
      _recentGridView = p.getBool('recentGridView') ?? false;

      final langCode = p.getString('language') ?? 'ar';
      _locale = Locale(langCode);

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
    await p.setString('sortBy', _sortBy);
    await p.setBool('sortDesc', _sortDesc);
    await p.setDouble('subtitleFontSize', _subtitleFontSize);
    await p.setInt('subtitleColorValue', _subtitleColorValue);
    await p.setDouble('subtitleBgOpacity', _subtitleBgOpacity);
    await p.setInt('subtitleBgColor', _subtitleBgColor.toARGB32());
    await p.setInt('outlineColor', _outlineColor.toARGB32());
    await p.setDouble('outlineWidth', _outlineWidth);
    await p.setBool('outlineEnabled', _outlineEnabled);

    await p.setBool('textShadowEnabled', _textShadowEnabled);
    await p.setInt('textShadowColor', _textShadowColor.toARGB32());
    await p.setDouble('textShadowBlurRadius', _textShadowBlurRadius);
    await p.setDouble('textShadowOffsetX', _textShadowOffsetX);
    await p.setDouble('textShadowOffsetY', _textShadowOffsetY);

    await p.setBool('boxShadowEnabled', _boxShadowEnabled);
    await p.setInt('boxShadowColor', _boxShadowColor.toARGB32());
    await p.setDouble('boxShadowBlurRadius', _boxShadowBlurRadius);
    await p.setDouble('boxShadowOffsetX', _boxShadowOffsetX);
    await p.setDouble('boxShadowOffsetY', _boxShadowOffsetY);

    await p.setInt('fontWeightIndex', _fontWeightIndex);
    await p.setDouble('bottomPadding', _bottomPadding);
    await p.setDouble('horizontalMargin', _horizontalMargin);
    await p.setString('fontFamily', _fontFamily);
    await p.setString('subtitleFolder', _subtitleFolder);
    await p.setString('subtitleEncoding', _subtitleEncoding);
    await p.setString('preferredSubtitleLanguage', _preferredSubtitleLanguage);
    await p.setDouble('defaultSubtitleSync', _defaultSubtitleSync);
    await p.setBool('subtitleItalic', _subtitleItalic);
    await p.setBool('subtitleRTL', _subtitleRTL);
    await p.setDouble('defaultAudioBoost', _defaultAudioBoost);
    await p.setString('preferredAudioLanguage', _preferredAudioLanguage);

    await p.setBool('libraryGridView', _libraryGridView);
    await p.setBool('foldersGridView', _foldersGridView);
    await p.setBool('recentGridView', _recentGridView);

    await p.setString('language', _locale.languageCode);
  }

  void setLocale(Locale v) {
    _locale = v;
    EasyLocalization.of(GlobalObjectKey(0).currentContext!)!.setLocale(v);
    notifyListeners();
    _save();
  }

  void setThemeMode(ThemeMode v) { _themeMode = v; notifyListeners(); _save(); }
  void setRememberPosition(bool v) { _rememberPosition = v; notifyListeners(); _save(); }
  void setAutoPlay(bool v) { _autoPlay = v; notifyListeners(); _save(); }
  void setDefaultSpeed(double v) { _defaultSpeed = v; notifyListeners(); _save(); }
  void setShowSubtitlesByDefault(bool v) { _showSubtitlesByDefault = v; notifyListeners(); _save(); }
  void setSortBy(String v) { _sortBy = v; notifyListeners(); _save(); }
  void setSortDesc(bool v) { _sortDesc = v; notifyListeners(); _save(); }
  void setSubtitleFontSize(double v) { _subtitleFontSize = v; notifyListeners(); _save(); }
  void setSubtitleColor(Color c) { _subtitleColorValue = c.toARGB32(); notifyListeners(); _save(); }
  void setSubtitleBgOpacity(double v) { _subtitleBgOpacity = v; notifyListeners(); _save(); }
  void setSubtitleBgColor(Color c) { _subtitleBgColor = c; notifyListeners(); _save(); }
  void setOutlineColor(Color c) { _outlineColor = c; notifyListeners(); _save(); }
  void setOutlineWidth(double v) { _outlineWidth = v; notifyListeners(); _save(); }
  void setOutlineEnabled(bool v) { _outlineEnabled = v; notifyListeners(); _save(); }

  void setTextShadowEnabled(bool v) { _textShadowEnabled = v; notifyListeners(); _save(); }
  void setTextShadowColor(Color c) { _textShadowColor = c; notifyListeners(); _save(); }
  void setTextShadowBlurRadius(double v) { _textShadowBlurRadius = v; notifyListeners(); _save(); }
  void setTextShadowOffsetX(double v) { _textShadowOffsetX = v; notifyListeners(); _save(); }
  void setTextShadowOffsetY(double v) { _textShadowOffsetY = v; notifyListeners(); _save(); }

  void setBoxShadowEnabled(bool v) { _boxShadowEnabled = v; notifyListeners(); _save(); }
  void setBoxShadowColor(Color c) { _boxShadowColor = c; notifyListeners(); _save(); }
  void setBoxShadowBlurRadius(double v) { _boxShadowBlurRadius = v; notifyListeners(); _save(); }
  void setBoxShadowOffsetX(double v) { _boxShadowOffsetX = v; notifyListeners(); _save(); }
  void setBoxShadowOffsetY(double v) { _boxShadowOffsetY = v; notifyListeners(); _save(); }

  void setFontWeightIndex(int v) { _fontWeightIndex = v; notifyListeners(); _save(); }
  void setBottomPadding(double v) { _bottomPadding = v; notifyListeners(); _save(); }
  void setHorizontalMargin(double v) { _horizontalMargin = v; notifyListeners(); _save(); }
  void setFontFamily(String v) { _fontFamily = v; notifyListeners(); _save(); }
  void setSubtitleFolder(String v) { _subtitleFolder = v; notifyListeners(); _save(); }
  void setSubtitleEncoding(String v) { _subtitleEncoding = v; notifyListeners(); _save(); }
  void setPreferredSubtitleLanguage(String v) { _preferredSubtitleLanguage = v; notifyListeners(); _save(); }
  void setDefaultSubtitleSync(double v) { _defaultSubtitleSync = v; notifyListeners(); _save(); }
  void setSubtitleItalic(bool v) { _subtitleItalic = v; notifyListeners(); _save(); }
  void setSubtitleRTL(bool v) { _subtitleRTL = v; notifyListeners(); _save(); }
  void setDefaultAudioBoost(double v) { _defaultAudioBoost = v; notifyListeners(); _save(); }
  void setPreferredAudioLanguage(String v) { _preferredAudioLanguage = v; notifyListeners(); _save(); }

  void setLibraryGridView(bool v) { _libraryGridView = v; notifyListeners(); _save(); }
  void setFoldersGridView(bool v) { _foldersGridView = v; notifyListeners(); _save(); }
  void setRecentGridView(bool v) { _recentGridView = v; notifyListeners(); _save(); }
}