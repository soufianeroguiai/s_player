import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/video_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/subtitle_service.dart';
import '../../services/pip_service.dart';
import '../info_screen.dart';
import 'player_indicators.dart';
import 'player_controls.dart';
import 'player_audio_panel.dart';
import 'player_subtitle_panel.dart';
import 'player_settings_panel.dart';
import 'player_fit_mode.dart';
import 'subtitle_style_builder.dart';

enum ActiveMenu { none, subtitles, audio, settings }

class PlayerScreen extends StatefulWidget {
  final VideoItem video;
  const PlayerScreen({super.key, required this.video});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _controller;

  ActiveMenu _currentMenu = ActiveMenu.none;
  bool _showQuickActions = false;

  double _volumeLevel = 1.0;
  double _audioDelay = 0.0;

  bool _initialized = false;
  bool _showControls = true;
  bool _isLocked = false;
  Timer? _hideTimer;
  Timer? _saveTimer;

  bool _showSubtitles = true;
  List<SubtitleTrack> _subtitleTracks = [];
  List<AudioTrack> _audioTracks = [];

  double _speed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLandscape = true;
  VideoFitMode _fitMode = VideoFitMode.contain;
  String? _fitOverlayText;
  Timer? _fitOverlayTimer;

  double _subtitleSync = 0.0;
  bool _autoSubtitleSelected = false;
  bool _autoAudioSelected = false;

  List<SubtitleEntry>? _lastSubtitleEntries;
  bool _hasExternalSubtitle = false;
  String? _externalSubtitlePath;

  final ValueNotifier<double> _brightnessNotifier = ValueNotifier(0.7);
  final ValueNotifier<double> _seekMsNotifier = ValueNotifier(0.0);

  final List<String> _favorites = [];
  final List<String> _playlist = [];

  double _startSubtitleSize = 24.0;
  double _startBottomPadding = 0.0;
  Offset _startFocalPoint = Offset.zero;
  bool _subtitleGestureActive = false;
  final ValueNotifier<bool> _showVolNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showBrightNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showSeekNotifier = ValueNotifier(false);
  Timer? _indicatorTimer;

  String? _seekHintText;
  Timer? _seekHintTimer;

  bool _showLockHint = false;
  double _lockIconOffset = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    PipService.isInPipMode.addListener(_onPipModeChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isLandscape = MediaQuery.of(context).orientation == Orientation.landscape);
      }
    });

    _enterFullscreen();
    final settings = context.read<SettingsProvider>();
    _showSubtitles = settings.showSubtitlesByDefault;
    _speed = settings.defaultSpeed;
    _subtitleSync = settings.defaultSubtitleSync;
    _volumeLevel = (settings.defaultAudioBoost / 100.0).clamp(0.0, 2.0);

    _loadPersistedVolumeAndBrightness();
    _loadFavorites();
    _loadPlaylist();

    _player = Player();
    _controller = VideoController(_player);
    _initPlayer();
    _loadFitMode();
  }

  void _onPipModeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPersistedVolumeAndBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble('player_volume_level');
    if (saved != null) {
      _volumeLevel = saved.clamp(0.0, 2.0);
      if (mounted) setState(() {});
    }
    final bright = prefs.getDouble('player_brightness') ?? 0.7;
    _brightnessNotifier.value = bright.clamp(0.1, 1.0);
  }

  Future<void> _savePersistedVolume() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('player_volume_level', _volumeLevel);
  }

  Future<void> _loadFavorites() async {
    final p = await SharedPreferences.getInstance();
    final favs = p.getStringList('favorite_paths') ?? [];
    _favorites.addAll(favs);
  }

  Future<void> _loadPlaylist() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('playlist_paths') ?? [];
    _playlist.addAll(list);
  }

  bool _isFavorite(String path) => _favorites.contains(path);

  void _toggleFavorite() {
    final path = widget.video.path;
    if (_isFavorite(path)) {
      _favorites.remove(path);
    } else {
      _favorites.add(path);
    }
    SharedPreferences.getInstance().then((p) => p.setStringList('favorite_paths', _favorites));
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isFavorite(path) ? 'تمت إضافة للمفضلة' : 'تمت إزالة من المفضلة')),
    );
  }

  void _addToPlaylist() {
    final path = widget.video.path;
    if (!_playlist.contains(path)) {
      _playlist.add(path);
      SharedPreferences.getInstance().then((p) => p.setStringList('playlist_paths', _playlist));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الإضافة إلى قائمة التشغيل')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الملف موجود مسبقاً في القائمة')),
      );
    }
  }

  void _shareVideo() {
    Share.shareXFiles([XFile(widget.video.path)], subject: widget.video.name);
  }

  Future<void> _loadFitMode() async {
    _fitMode = await VideoFitSettings.load();
    if (mounted) setState(() {});
  }

  void _enterFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _setOrientations();
  }

  void _setOrientations() {
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    _setOrientations();
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      if (_isLocked) {
        _showControls = false;
        _currentMenu = ActiveMenu.none;
        _showQuickActions = false;
        _showLockHint = false;
        _lockIconOffset = 0.0;
      }
    });
  }

  void _toggleFit() {
    setState(() {
      _fitMode = VideoFitMode.values[(_fitMode.index + 1) % VideoFitMode.values.length];
      _showFitOverlay();
    });
    VideoFitSettings.save(_fitMode);
  }

  void _showFitOverlay() {
    _fitOverlayText = modeName(_fitMode);
    _fitOverlayTimer?.cancel();
    _fitOverlayTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _fitOverlayText = null);
    });
  }

  Future<void> _initPlayer() async {
    final settings = context.read<SettingsProvider>();
    try {
      await _player.open(Media(widget.video.path), play: settings.autoPlay);
      _player.setRate(_speed);
      _player.setVolume(_volumeLevel * 100.0);

      if (settings.rememberPosition) {
        try {
          final saved = await context.read<LibraryProvider>().getPosition(widget.video.path);
          if (saved != null && saved.inSeconds > 0) await _player.seek(saved);
        } catch (_) {}
      }

      _player.stream.position.listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
        if (settings.rememberPosition) {
          _saveTimer?.cancel();
          _saveTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) context.read<LibraryProvider>().savePosition(widget.video.path, _position);
          });
        }
      });

      _player.stream.duration.listen((dur) => mounted ? setState(() => _duration = dur) : null);
      _player.stream.playing.listen((playing) => mounted ? setState(() => _isPlaying = playing) : null);

      _player.stream.tracks.listen((tracks) {
        if (!mounted) return;
        setState(() {
          _subtitleTracks = tracks.subtitle;
          _audioTracks = tracks.audio;
        });
        _applyPreferredSubtitleLanguage(settings);
        _applyPreferredAudioLanguage(settings);
      });

      try {
        _brightnessNotifier.value = await ScreenBrightness.instance.application;
        if (_brightnessNotifier.value < 0.1) _brightnessNotifier.value = 0.1;
        await ScreenBrightness.instance.setApplicationScreenBrightness(_brightnessNotifier.value);
      } catch (_) {
        _brightnessNotifier.value = 0.7;
      }

      setState(() => _initialized = true);
      _scheduleHide();
      await _loadSubtitleFromAdjacentFile(settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تشغيل الملف: $e')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadSubtitleFromAdjacentFile(SettingsProvider s) async {
    if (_autoSubtitleSelected && _showSubtitles) return;
    final srtPath = SubtitleService.findSrt(widget.video.path);
    if (srtPath != null) {
      await _loadSrtFile(srtPath, s.subtitleEncoding, silent: true);
      _hasExternalSubtitle = true;
    }
  }

  void _applyPreferredSubtitleLanguage(SettingsProvider s) {
    if (_autoSubtitleSelected || _subtitleTracks.isEmpty) return;
    for (final track in _subtitleTracks) {
      if (track.language == s.preferredSubtitleLanguage) {
        _player.setSubtitleTrack(track);
        setState(() => _showSubtitles = true);
        _autoSubtitleSelected = true;
        return;
      }
    }
    _autoSubtitleSelected = true;
  }

  void _applyPreferredAudioLanguage(SettingsProvider s) {
    if (_autoAudioSelected || _audioTracks.isEmpty) return;
    for (final track in _audioTracks) {
      if (track.language == s.preferredAudioLanguage) {
        _player.setAudioTrack(track);
        _autoAudioSelected = true;
        return;
      }
    }
    _autoAudioSelected = true;
  }

  Future<void> _loadSrtFile(String path, String encoding, {bool silent = false}) async {
    try {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      final entries = await SubtitleService.load(path, encodingName: encoding);
      if (entries.isEmpty) return;

      _lastSubtitleEntries = entries;
      await _applySubtitleSyncOffset();
      _hasExternalSubtitle = true;

      if (mounted) {
        setState(() => _showSubtitles = true);
        if (!silent) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('✅ تم تحميل الترجمة')));
        }
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحميل الترجمة: $e')));
      }
    }
  }

  String _formatSrtTime(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds.remainder(1000)).toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }

  Future<void> _pickSubtitle() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['srt', 'SRT', 'ssa', 'ass']);
    if (result?.files.single.path != null) {
      final settings = context.read<SettingsProvider>();
      await _loadSrtFile(result!.files.single.path!, settings.subtitleEncoding);
    }
  }

  void _removeExternalSubtitle() {
    _hasExternalSubtitle = false;
    _lastSubtitleEntries = null;
    _player.setSubtitleTrack(SubtitleTrack.no());
    if (_subtitleTracks.isNotEmpty) {
      _player.setSubtitleTrack(_subtitleTracks.first);
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إزالة الترجمة الخارجية')),
    );
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying && !_isLocked && _currentMenu == ActiveMenu.none && !_showQuickActions) {
        setState(() => _showControls = false);
      }
    });
  }

  void cancelHideTimer() {
    _hideTimer?.cancel();
  }

  void _toggleControls() {
    if (_isLocked) {
      setState(() {
        _showLockHint = true;
        _lockIconOffset = 0.0;
      });
      return;
    }
    if (_currentMenu != ActiveMenu.none || _showQuickActions) {
      setState(() {
        _currentMenu = ActiveMenu.none;
        _showQuickActions = false;
      });
      _scheduleHide();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  Future<void> _enterPip() async {
    await PipService.enter();
  }

  void _onVolumeChanged(double newLevel) {
    setState(() {
      _volumeLevel = newLevel.clamp(0.0, 2.0);
      _player.setVolume(_volumeLevel * 100.0);
    });
    _savePersistedVolume();
  }

  void _onSubtitleSyncChanged(double v) {
    setState(() => _subtitleSync = v);
    context.read<SettingsProvider>().setDefaultSubtitleSync(v);
    if (_lastSubtitleEntries != null && _lastSubtitleEntries!.isNotEmpty) {
      _applySubtitleSyncOffset();
    }
  }

  Future<void> _applySubtitleSyncOffset() async {
    final entries = _lastSubtitleEntries;
    if (entries == null || entries.isEmpty) return;
    final offset = Duration(milliseconds: (_subtitleSync * 1000).round());

    final srtContent = StringBuffer();
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final start = e.start + offset;
      final end = e.end + offset;
      if (end.isNegative) continue;
      srtContent.writeln('${i + 1}');
      srtContent.writeln(
          '${_formatSrtTime(start.isNegative ? Duration.zero : start)} --> ${_formatSrtTime(end)}');
      srtContent.writeln(e.text);
      srtContent.writeln();
    }
    await _player.setSubtitleTrack(SubtitleTrack.data(srtContent.toString(), title: 'ترجمة خارجية'));
  }

  void _openSettingsPanel() {
    setState(() {
      _currentMenu = ActiveMenu.settings;
      cancelHideTimer();
    });
  }

  Widget _buildVideoWidget(SettingsProvider s) {
    return Video(
      key: ValueKey('video_${s.bottomPadding}_${s.horizontalMargin}'),
      controller: _controller,
      fit: getBoxFit(_fitMode),
      controls: NoVideoControls,
      subtitleViewConfiguration: SubtitleViewConfiguration(
        style: buildSubtitleTextStyle(s),
        textAlign: s.subtitleRTL ? TextAlign.right : TextAlign.center,
        padding: EdgeInsets.fromLTRB(s.horizontalMargin, 0, s.horizontalMargin, s.bottomPadding),
      ),
    );
  }

  Widget _buildSidePanel() {
    const double panelWidth = 340.0;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: 0,
      bottom: 0,
      right: _currentMenu != ActiveMenu.none ? 0 : -panelWidth,
      width: panelWidth,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currentMenu == ActiveMenu.subtitles
                            ? 'إعدادات الترجمة'
                            : _currentMenu == ActiveMenu.audio
                                ? 'إعدادات الصوت'
                                : 'المزيد',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _currentMenu = ActiveMenu.none);
                          _scheduleHide();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Symbols.close_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _currentMenu == ActiveMenu.subtitles
                      ? SubtitleAppearancePanel(
                          subtitleTracks: _subtitleTracks,
                          currentSubtitleTrack: _player.state.track.subtitle,
                          onTrackSelected: (track) {
                            if (track is SubtitleTrack) _player.setSubtitleTrack(track);
                            setState(() => _showSubtitles = true);
                          },
                          onPickSubtitle: _pickSubtitle,
                          onRemoveExternal: _removeExternalSubtitle,
                          hasExternalSubtitle: _hasExternalSubtitle,
                          showSubtitles: _showSubtitles,
                          onToggleSubtitles: (v) {
                            setState(() => _showSubtitles = v);
                            if (!v) _player.setSubtitleTrack(SubtitleTrack.no());
                          },
                          subtitleSync: _subtitleSync,
                          onSyncChanged: _onSubtitleSyncChanged,
                        )
                      : _currentMenu == ActiveMenu.audio
                          ? AudioSettingsPanel(
                              player: _player,
                              volumeLevel: _volumeLevel,
                              onVolumeChanged: _onVolumeChanged,
                              audioTracks: _audioTracks,
                              currentAudioTrack: _player.state.track.audio,
                              onTrackSelected: (track) => setState(() => _player.setAudioTrack(track)),
                              audioDelay: _audioDelay,
                              onAudioDelayChanged: (v) {
                                setState(() => _audioDelay = v);
                              },
                              onClose: () => setState(() => _currentMenu = ActiveMenu.none),
                            )
                          : _currentMenu == ActiveMenu.settings
                              ? PlayerSettingsPanel(
                                  isFavorite: _isFavorite(widget.video.path),
                                  onToggleFavorite: _toggleFavorite,
                                  onAddToPlaylist: _addToPlaylist,
                                  onCaptureScreenshot: _captureScreenshot,
                                  onToggleFit: _toggleFit,
                                  onToggleOrientation: _toggleOrientation,
                                  onEnterPip: _enterPip,
                                  onShowInfo: () {
                                    setState(() => _currentMenu = ActiveMenu.none);
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => InfoScreen(video: widget.video)));
                                  },
                                  onSleepTimer: null,
                                  onShowSpeedPicker: () {
                                    final settings = context.read<SettingsProvider>();
                                    _showSpeedPicker(settings);
                                    setState(() => _currentMenu = ActiveMenu.none);
                                  },
                                  onToggleRememberPosition: () {
                                    final settings = context.read<SettingsProvider>();
                                    settings.setRememberPosition(!settings.rememberPosition);
                                    setState(() => _currentMenu = ActiveMenu.none);
                                  },
                                  rememberPosition: context.read<SettingsProvider>().rememberPosition,
                                  currentSpeed: _speed,
                                  currentFitMode: modeName(_fitMode),
                                  onClose: () => setState(() => _currentMenu = ActiveMenu.none),
                                )
                              : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _captureScreenshot() async {
    try {
      final Uint8List? bytes = await _player.screenshot(format: 'image/jpeg');
      if (bytes != null) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم حفظ اللقطة: ${file.path}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التقاط اللقطة: $e')),
        );
      }
    }
  }

  Widget _qaBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: 26),
    );
  }

  void _showSpeedPicker(SettingsProvider s) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Text('سرعة التشغيل', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16))),
          const Divider(height: 1),
          ...[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((sp) => ListTile(
                title: Text('${sp}x'),
                trailing: s.defaultSpeed == sp ? Icon(Symbols.check_rounded, color: cs.primary) : null,
                onTap: () {
                  s.setDefaultSpeed(sp);
                  _player.setRate(sp);
                  Navigator.pop(context);
                },
              )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = context.watch<SettingsProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (PipService.isInPipMode.value) {
      return Scaffold(backgroundColor: Colors.black, body: Video(controller: _controller));
    }

    final bool controlsVisible = _showControls && !_isLocked && _currentMenu == ActiveMenu.none;

    return PopScope(
      canPop: !_isLocked,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (_currentMenu != ActiveMenu.none || _showQuickActions) {
            setState(() {
              _currentMenu = ActiveMenu.none;
              _showQuickActions = false;
            });
            return;
          }
          if (!_isLocked) await _enterPip();
        }
        if (_isLocked) setState(() => _isLocked = false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: !_initialized
            ? Center(child: CircularProgressIndicator(color: cs.primary))
            : Stack(children: [
                GestureDetector(
                  onTap: _toggleControls,
                  onDoubleTapDown: _isLocked
                      ? null
                      : (details) {
                          final x = details.localPosition.dx;
                          if (x < screenWidth / 3) {
                            final target = _position - const Duration(seconds: 10);
                            _player.seek(target.isNegative ? Duration.zero : target);
                            _showSeekHint(-10);
                          } else if (x > screenWidth * 2 / 3) {
                            final target = _position + const Duration(seconds: 10);
                            _player.seek(target > _duration ? _duration : target);
                            _showSeekHint(10);
                          } else {
                            _isPlaying ? _player.pause() : _player.play();
                          }
                        },
                  onScaleStart: (details) {
                    if (_isLocked) return;
                    if (details.pointerCount == 2 && !_isPlaying) {
                      _startSubtitleSize = s.subtitleFontSize;
                      _startBottomPadding = s.bottomPadding;
                      _startFocalPoint = details.focalPoint;
                      _subtitleGestureActive = true;
                    } else {
                      _seekMsNotifier.value = _position.inMilliseconds.toDouble();
                      _subtitleGestureActive = false;
                    }
                  },
                  onScaleUpdate: (details) {
                    if (_isLocked) return;

                    if (details.pointerCount == 2 && _subtitleGestureActive && !_isPlaying) {
                      final newSize = (_startSubtitleSize * details.scale).clamp(10.0, 150.0);
                      s.setSubtitleFontSize(newSize);

                      final dy = details.focalPoint.dy - _startFocalPoint.dy;
                      final newPadding = (_startBottomPadding - dy).clamp(0.0, screenHeight * 0.85);
                      s.setBottomPadding(newPadding);
                      return;
                    }

                    if (details.pointerCount != 1) return;
                    if (details.focalPointDelta.distance < 0.5) return;

                    final isRight = details.focalPoint.dx > screenWidth / 2;
                    final dx = details.focalPointDelta.dx.abs();
                    final dy = details.focalPointDelta.dy.abs();
                    final isHorizontal = dx > dy;

                    if (isHorizontal) {
                      final seekFactor = (_duration.inMilliseconds * 0.25)
                          .clamp(30000.0, 600000.0);
                      final change = (details.focalPointDelta.dx / screenWidth) * seekFactor;
                      _seekMsNotifier.value = (_seekMsNotifier.value + change)
                          .clamp(0.0, _duration.inMilliseconds.toDouble());
                      _showSeekNotifier.value = true;
                      _showVolNotifier.value = false;
                      _showBrightNotifier.value = false;
                    } else {
                      final delta = -details.focalPointDelta.dy / 180.0;
                      if (isRight) {
                        _onVolumeChanged(_volumeLevel + delta);
                        _showVolNotifier.value = true;
                        _showBrightNotifier.value = false;
                        _showSeekNotifier.value = false;
                      } else {
                        final newBright = (_brightnessNotifier.value + delta).clamp(0.05, 1.0);
                        _brightnessNotifier.value = newBright;
                        ScreenBrightness.instance.setApplicationScreenBrightness(newBright);
                        _showBrightNotifier.value = true;
                        _showVolNotifier.value = false;
                        _showSeekNotifier.value = false;
                      }
                      _resetIndicatorTimer();
                    }
                  },
                  onScaleEnd: (details) {
                    if (_isLocked) return;
                    _subtitleGestureActive = false;
                    if (_showSeekNotifier.value) {
                      _player.seek(Duration(milliseconds: _seekMsNotifier.value.toInt()));
                      _showSeekNotifier.value = false;
                    }
                  },
                  child: _buildVideoWidget(s),
                ),

                if (_isLocked)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _showLockHint = true);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _showLockHint = false);
                          });
                        },
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _lockIconOffset = (_lockIconOffset + details.delta.dx).clamp(0.0, 100.0);
                          });
                        },
                        onHorizontalDragEnd: (_) {
                          if (_lockIconOffset >= 70) {
                            _toggleLock();
                          }
                          setState(() {
                            _lockIconOffset = 0.0;
                            _showLockHint = false;
                          });
                        },
                        child: AnimatedOpacity(
                          opacity: _showLockHint ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            width: 220,
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.centerLeft,
                              children: [
                                const Center(
                                  child: Text(
                                    'اسحب لفتح القفل',
                                    style: TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                                PositionedDirectional(
                                  start: _lockIconOffset,
                                  top: 7,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      color: Colors.white24,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _lockIconOffset >= 70
                                          ? Symbols.lock_open_rounded
                                          : Symbols.lock_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                ValueListenableBuilder<bool>(
                  valueListenable: _showSeekNotifier,
                  builder: (context, show, child) {
                    if (!show) return const SizedBox.shrink();
                    return ValueListenableBuilder<double>(
                      valueListenable: _seekMsNotifier,
                      builder: (context, seekMs, child) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Symbols.fast_forward_rounded, color: Colors.white, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                _fmt(Duration(milliseconds: seekMs.toInt())),
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ]),
                          ),
                        );
                      },
                    );
                  },
                ),

                ValueListenableBuilder<bool>(
                  valueListenable: _showVolNotifier,
                  builder: (context, show, child) {
                    if (!show) return const SizedBox.shrink();
                    final bool isBoosted = _volumeLevel > 1.0;
                    return Positioned(
                      left: 20,
                      top: MediaQuery.of(context).size.height * 0.22,
                      child: PlayerIndicators.buildFloatingIndicator(
                        icon: _volumeLevel == 0
                            ? Icons.volume_off_rounded
                            : isBoosted
                                ? Icons.volume_up_rounded
                                : Icons.volume_down_rounded,
                        displayValue: (_volumeLevel / 2.0).clamp(0.0, 1.0),
                        labelText: '${(_volumeLevel * 100).round()}%',
                        color: isBoosted ? Colors.orangeAccent : const Color(0xFF4FC3F7),
                      ),
                    );
                  },
                ),

                ValueListenableBuilder<bool>(
                  valueListenable: _showBrightNotifier,
                  builder: (context, show, child) {
                    if (!show) return const SizedBox.shrink();
                    return ValueListenableBuilder<double>(
                      valueListenable: _brightnessNotifier,
                      builder: (context, brightness, child) {
                        return Positioned(
                          right: 20,
                          top: MediaQuery.of(context).size.height * 0.22,
                          child: PlayerIndicators.buildFloatingIndicator(
                            icon: brightness < 0.15
                                ? Icons.brightness_2_rounded
                                : brightness < 0.5
                                    ? Icons.brightness_5_rounded
                                    : Icons.brightness_7_rounded,
                            displayValue: brightness,
                            labelText: '${(brightness * 100).round()}%',
                            color: const Color(0xFFFFD54F),
                          ),
                        );
                      },
                    );
                  },
                ),

                if (_seekHintText != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        _seekHintText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                if (_fitOverlayText != null)
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_fitOverlayText!,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),

                if (controlsVisible) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: PlayerTopBar(
                      videoName: widget.video.name,
                      onBack: () => Navigator.pop(context),
                      onAudioMenu: () {
                        setState(() {
                          _currentMenu = _currentMenu == ActiveMenu.audio ? ActiveMenu.none : ActiveMenu.audio;
                          _showQuickActions = false;
                          if (_currentMenu != ActiveMenu.none) cancelHideTimer(); else _scheduleHide();
                        });
                      },
                      onSubtitleMenu: () {
                        setState(() {
                          _currentMenu = _currentMenu == ActiveMenu.subtitles ? ActiveMenu.none : ActiveMenu.subtitles;
                          _showQuickActions = false;
                          if (_currentMenu != ActiveMenu.none) cancelHideTimer(); else _scheduleHide();
                        });
                      },
                      onQuickActions: () {
                        setState(() {
                          _currentMenu = ActiveMenu.none;
                          _showQuickActions = !_showQuickActions;
                          if (_showQuickActions) cancelHideTimer(); else _scheduleHide();
                        });
                      },
                      onSettingsMenu: _openSettingsPanel,
                      isAudioActive: _currentMenu == ActiveMenu.audio,
                      isSubtitleActive: _currentMenu == ActiveMenu.subtitles,
                      isQuickActionsActive: _showQuickActions,
                      quickActionWidgets: _showQuickActions
                          ? [
                              _qaBtn(Symbols.camera_rounded, Colors.white70, _captureScreenshot),
                              const SizedBox(width: 10),
                              _qaBtn(
                                _isFavorite(widget.video.path)
                                    ? Symbols.favorite_rounded
                                    : Symbols.favorite_border,
                                _isFavorite(widget.video.path) ? Colors.amber : Colors.white70,
                                _toggleFavorite,
                              ),
                              const SizedBox(width: 10),
                              _qaBtn(Symbols.playlist_add_rounded, Colors.white70, _addToPlaylist),
                              const SizedBox(width: 10),
                              _qaBtn(Symbols.share_rounded, Colors.white70, _shareVideo),
                            ]
                          : [],
                    ),
                  ),

                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: PlayerBottomBar(
                      position: _position,
                      duration: _duration,
                      onSeek: (v) => _player.seek(Duration(milliseconds: (v * _duration.inMilliseconds).toInt())),
                      primaryColor: cs.primary,
                      isPlaying: _isPlaying,
                      onPlayPause: () => _isPlaying ? _player.pause() : _player.play(),
                      onSkipBack: () {
                        final target = _position - const Duration(seconds: 10);
                        _player.seek(target.isNegative ? Duration.zero : target);
                      },
                      onSkipForward: () {
                        final target = _position + const Duration(seconds: 10);
                        _player.seek(target > _duration ? _duration : target);
                      },
                      onToggleFit: _toggleFit,
                      onToggleLock: _toggleLock,
                      onPip: _enterPip,
                      onToggleOrientation: _toggleOrientation,
                      isLandscape: _isLandscape,
                    ),
                  ),
                ],

                _buildSidePanel(),
              ]),
      ),
    );
  }

  void _showSeekHint(int seconds) {
    setState(() => _seekHintText = seconds > 0 ? '+${seconds}s ⏩' : '${seconds}s ⏪');
    _seekHintTimer?.cancel();
    _seekHintTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekHintText = null);
    });
  }

  void _resetIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 1), () {
      _showVolNotifier.value = false;
      _showBrightNotifier.value = false;
    });
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PipService.isInPipMode.removeListener(_onPipModeChanged);
    _brightnessNotifier.dispose();
    _seekMsNotifier.dispose();
    _showVolNotifier.dispose();
    _showBrightNotifier.dispose();
    _showSeekNotifier.dispose();
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _indicatorTimer?.cancel();
    _fitOverlayTimer?.cancel();
    _seekHintTimer?.cancel();
    try {
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _player.dispose();
    super.dispose();
  }
}
