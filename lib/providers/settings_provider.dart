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

  bool _shadowEnabled = false;
  bool get shadowEnabled => _shadowEnabled;

  Color _shadowColor = const Color(0xFF000000);
  Color get shadowColor => _shadowColor;

  double _shadowBlurRadius = 4.0;
  double get shadowBlurRadius => _shadowBlurRadius;

  double _shadowOffsetX = 1.0;
  double get shadowOffsetX => _shadowOffsetX;

  double _shadowOffsetY = 1.0;
  double get shadowOffsetY => _shadowOffsetY;

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

  bool _subtitleHwAcceleration = false;
  bool get subtitleHwAcceleration => _subtitleHwAcceleration;

  String _subtitleFontsFolder = '';
  String get subtitleFontsFolder => _subtitleFontsFolder;

  bool _subtitleItalic = false;
  bool get subtitleItalic => _subtitleItalic;

  bool _subtitleRTL = false;
  bool get subtitleRTL => _subtitleRTL;

  String _audioPlayerEngine = 'media_kit';
  String get audioPlayerEngine => _audioPlayerEngine;

  String _audioOutput = 'auto';
  String get audioOutput => _audioOutput;

  double _defaultAudioBoost = 100.0;
  double get defaultAudioBoost => _defaultAudioBoost;

  double _defaultVolume = 1.0;
  double get defaultVolume => _defaultVolume;

  bool _showVolumePanel = true;
  bool get showVolumePanel => _showVolumePanel;

  bool _pauseOnHeadphonesDisconnect = false;
  bool get pauseOnHeadphonesDisconnect => _pauseOnHeadphonesDisconnect;

  bool _fadeInStart = false;
  bool get fadeInStart => _fadeInStart;

  bool _fadeInSeek = false;
  bool get fadeInSeek => _fadeInSeek;

  String _preferredAudioLanguage = 'ara';
  String get preferredAudioLanguage => _preferredAudioLanguage;

  double _bluetoothAudioDelayMs = 0.0;
  double get bluetoothAudioDelayMs => _bluetoothAudioDelayMs;

  bool _audioPassthrough = false;
  bool get audioPassthrough => _audioPassthrough;

  double _audioRate = 1.0;
  double get audioRate => _audioRate;

  // --- Load & Save ---
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
      _subtitleFontSize = p.getDouble('subtitleFontSize') ?? 30.0;
      _subtitleColorValue = p.getInt('subtitleColorValue') ?? 0xFFFFFFFF;
      _subtitleBgOpacity = p.getDouble('subtitleBgOpacity') ?? 0.0;
      _subtitleBgColor = Color(p.getInt('subtitleBgColor') ?? 0xFF000000);
      _outlineColor = Color(p.getInt('outlineColor') ?? 0xFF000000);
      _outlineWidth = p.getDouble('outlineWidth') ?? 2.0;
      _shadowEnabled = p.getBool('shadowEnabled') ?? false;
      _shadowColor = Color(p.getInt('shadowColor') ?? 0xFF000000);
      _shadowBlurRadius = p.getDouble('shadowBlurRadius') ?? 4.0;
      _shadowOffsetX = p.getDouble('shadowOffsetX') ?? 1.0;
      _shadowOffsetY = p.getDouble('shadowOffsetY') ?? 1.0;
      _fontWeightIndex = p.getInt('fontWeightIndex') ?? 2;
      _bottomPadding = p.getDouble('bottomPadding') ?? 48.0;
      _horizontalMargin = p.getDouble('horizontalMargin') ?? 24.0;
      _fontFamily = p.getString('fontFamily') ?? 'Roboto';
      _subtitleFolder = p.getString('subtitleFolder') ?? '';
      _subtitleEncoding = p.getString('subtitleEncoding') ?? 'UTF-8';
      _preferredSubtitleLanguage = p.getString('preferredSubtitleLanguage') ?? 'ara';
      _defaultSubtitleSync = p.getDouble('defaultSubtitleSync') ?? 0.0;
      _subtitleHwAcceleration = p.getBool('subtitleHwAcceleration') ?? false;
      _subtitleFontsFolder = p.getString('subtitleFontsFolder') ?? '';
      _subtitleItalic = p.getBool('subtitleItalic') ?? false;
      _subtitleRTL = p.getBool('subtitleRTL') ?? false;
      _audioPlayerEngine = p.getString('audioPlayerEngine') ?? 'media_kit';
      _audioOutput = p.getString('audioOutput') ?? 'auto';
      _defaultAudioBoost = p.getDouble('defaultAudioBoost') ?? 100.0;
      _defaultVolume = p.getDouble('defaultVolume') ?? 1.0;
      _showVolumePanel = p.getBool('showVolumePanel') ?? true;
      _pauseOnHeadphonesDisconnect = p.getBool('pauseOnHeadphonesDisconnect') ?? false;
      _fadeInStart = p.getBool('fadeInStart') ?? false;
      _fadeInSeek = p.getBool('fadeInSeek') ?? false;
      _preferredAudioLanguage = p.getString('preferredAudioLanguage') ?? 'ara';
      _bluetoothAudioDelayMs = p.getDouble('bluetoothAudioDelayMs') ?? 0.0;
      _audioPassthrough = p.getBool('audioPassthrough') ?? false;
      _audioRate = p.getDouble('audioRate') ?? 1.0;
      notifyListeners();
    } catch (e) {
      debugPrint('Settings load error: $e');
    }
  }

  Future<void> save() async {
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
    await p.setInt('subtitleBgColor', _subtitleBgColor.value);
    await p.setInt('outlineColor', _outlineColor.value);
    await p.setDouble('outlineWidth', _outlineWidth);
    await p.setBool('shadowEnabled', _shadowEnabled);
    await p.setInt('shadowColor', _shadowColor.value);
    await p.setDouble('shadowBlurRadius', _shadowBlurRadius);
    await p.setDouble('shadowOffsetX', _shadowOffsetX);
    await p.setDouble('shadowOffsetY', _shadowOffsetY);
    await p.setInt('fontWeightIndex', _fontWeightIndex);
    await p.setDouble('bottomPadding', _bottomPadding);
    await p.setDouble('horizontalMargin', _horizontalMargin);
    await p.setString('fontFamily', _fontFamily);
    await p.setString('subtitleFolder', _subtitleFolder);
    await p.setString('subtitleEncoding', _subtitleEncoding);
    await p.setString('preferredSubtitleLanguage', _preferredSubtitleLanguage);
    await p.setDouble('defaultSubtitleSync', _defaultSubtitleSync);
    await p.setBool('subtitleHwAcceleration', _subtitleHwAcceleration);
    await p.setString('subtitleFontsFolder', _subtitleFontsFolder);
    await p.setBool('subtitleItalic', _subtitleItalic);
    await p.setBool('subtitleRTL', _subtitleRTL);
    await p.setString('audioPlayerEngine', _audioPlayerEngine);
    await p.setString('audioOutput', _audioOutput);
    await p.setDouble('defaultAudioBoost', _defaultAudioBoost);
    await p.setDouble('defaultVolume', _defaultVolume);
    await p.setBool('showVolumePanel', _showVolumePanel);
    await p.setBool('pauseOnHeadphonesDisconnect', _pauseOnHeadphonesDisconnect);
    await p.setBool('fadeInStart', _fadeInStart);
    await p.setBool('fadeInSeek', _fadeInSeek);
    await p.setString('preferredAudioLanguage', _preferredAudioLanguage);
    await p.setDouble('bluetoothAudioDelayMs', _bluetoothAudioDelayMs);
    await p.setBool('audioPassthrough', _audioPassthrough);
    await p.setDouble('audioRate', _audioRate);
  }

  // Setters (بدون حفظ فوري)
  void setThemeMode(ThemeMode v) { _themeMode = v; notifyListeners(); }
  void setRememberPosition(bool v) { _rememberPosition = v; notifyListeners(); }
  void setAutoPlay(bool v) { _autoPlay = v; notifyListeners(); }
  void setDefaultSpeed(double v) { _defaultSpeed = v; notifyListeners(); }
  void setShowSubtitlesByDefault(bool v) { _showSubtitlesByDefault = v; notifyListeners(); }
  void setGridView(bool v) { _gridView = v; notifyListeners(); }
  void setSortBy(String v) { _sortBy = v; notifyListeners(); }
  void setSortDesc(bool v) { _sortDesc = v; notifyListeners(); }
  void setSubtitleFontSize(double v) { _subtitleFontSize = v; notifyListeners(); }
  void setSubtitleColor(Color c) { _subtitleColorValue = c.value; notifyListeners(); }
  void setSubtitleBgOpacity(double v) { _subtitleBgOpacity = v; notifyListeners(); }
  void setSubtitleBgColor(Color c) { _subtitleBgColor = c; notifyListeners(); }
  void setOutlineColor(Color c) { _outlineColor = c; notifyListeners(); }
  void setOutlineWidth(double v) { _outlineWidth = v; notifyListeners(); }
  void setShadowEnabled(bool v) { _shadowEnabled = v; notifyListeners(); }
  void setShadowColor(Color c) { _shadowColor = c; notifyListeners(); }
  void setShadowBlurRadius(double v) { _shadowBlurRadius = v; notifyListeners(); }
  void setFontWeightIndex(int v) { _fontWeightIndex = v; notifyListeners(); }
  void setBottomPadding(double v) { _bottomPadding = v; notifyListeners(); }
  void setHorizontalMargin(double v) { _horizontalMargin = v; notifyListeners(); }
  void setFontFamily(String v) { _fontFamily = v; notifyListeners(); }
  void setSubtitleFolder(String v) { _subtitleFolder = v; notifyListeners(); }
  void setSubtitleEncoding(String v) { _subtitleEncoding = v; notifyListeners(); }
  void setPreferredSubtitleLanguage(String v) { _preferredSubtitleLanguage = v; notifyListeners(); }
  void setDefaultSubtitleSync(double v) { _defaultSubtitleSync = v; notifyListeners(); }
  void setSubtitleHwAcceleration(bool v) { _subtitleHwAcceleration = v; notifyListeners(); }
  void setSubtitleFontsFolder(String v) { _subtitleFontsFolder = v; notifyListeners(); }
  void setSubtitleItalic(bool v) { _subtitleItalic = v; notifyListeners(); }
  void setSubtitleRTL(bool v) { _subtitleRTL = v; notifyListeners(); }
  void setAudioPlayerEngine(String v) { _audioPlayerEngine = v; notifyListeners(); }
  void setAudioOutput(String v) { _audioOutput = v; notifyListeners(); }
  void setDefaultAudioBoost(double v) { _defaultAudioBoost = v; notifyListeners(); }
  void setDefaultVolume(double v) { _defaultVolume = v; notifyListeners(); }
  void setShowVolumePanel(bool v) { _showVolumePanel = v; notifyListeners(); }
  void setPauseOnHeadphonesDisconnect(bool v) { _pauseOnHeadphonesDisconnect = v; notifyListeners(); }
  void setFadeInStart(bool v) { _fadeInStart = v; notifyListeners(); }
  void setFadeInSeek(bool v) { _fadeInSeek = v; notifyListeners(); }
  void setPreferredAudioLanguage(String v) { _preferredAudioLanguage = v; notifyListeners(); }
  void setBluetoothAudioDelayMs(double v) { _bluetoothAudioDelayMs = v; notifyListeners(); }
  void setAudioPassthrough(bool v) { _audioPassthrough = v; notifyListeners(); }
  void setAudioRate(double v) { _audioRate = v; notifyListeners(); }
}