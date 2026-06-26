import 'dart:async';
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
import '../../models/video_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/subtitle_service.dart';
import '../../services/pip_service.dart';
import 'player_indicators.dart';
import 'player_controls.dart';
import 'player_audio_panel.dart';
import 'player_subtitle_panel.dart';
import 'player_fit_mode.dart';
import 'subtitle_style_builder.dart';

enum ActiveMenu { none, subtitles, audio }

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

  final ValueNotifier<double> _brightnessNotifier = ValueNotifier(0.7);
  final ValueNotifier<double> _seekMsNotifier = ValueNotifier(0.0);

  final List<String> _favorites = [];
  final List<String> _playlist = [];

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
    if (srtPath != null) await _loadSrtFile(srtPath, s.subtitleEncoding, silent: true);
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
    if (_isLocked) return;
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

  void _showSettingsMenu() {
    final settings = context.read<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 10,
        80,
        MediaQuery.of(context).size.width,
        0,
      ),
      items: [
        PopupMenuItem(
          value: 'speed',
          child: Row(children: [
            Icon(Symbols.speed_rounded, color: cs.primary),
            const SizedBox(width: 12),
            Text('سرعة التشغيل (${settings.defaultSpeed}x)'),
          ]),
        ),
        PopupMenuItem(
          value: 'fit',
          child: Row(children: [
            Icon(Symbols.aspect_ratio_rounded, color: cs.primary),
            const SizedBox(width: 12),
            Text('وضع الملء (${modeName(_fitMode)})'),
          ]),
        ),
        PopupMenuItem(
          value: 'remember',
          child: Row(children: [
            Icon(settings.rememberPosition ? Symbols.bookmark_rounded : Symbols.bookmark_border_rounded, color: cs.primary),
            const SizedBox(width: 12),
            Text(settings.rememberPosition ? 'إيقاف تذكر الموضع' : 'تفعيل تذكر الموضع'),
          ]),
        ),
      ],
    ).then((value) {
      if (value == 'speed') {
        _showSpeedPicker(settings);
      } else if (value == 'fit') {
        _toggleFit();
      } else if (value == 'remember') {
        settings.setRememberPosition(!settings.rememberPosition);
      }
    });
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _qaBtn(Symbols.favorite_rounded, _isFavorite(widget.video.path) ? Colors.amber : Colors.white70, _toggleFavorite),
        const SizedBox(height: 12),
        _qaBtn(Symbols.playlist_add_rounded, Colors.white70, _addToPlaylist),
        const SizedBox(height: 12),
        _qaBtn(Symbols.share_rounded, Colors.white70, _shareVideo),
      ],
    );
  }

  Widget _qaBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: 26),
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
          color: Color(0xD9000000),
          border: Border(left: BorderSide(color: Colors.white24, width: 1)),
        ),
        child: SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currentMenu == ActiveMenu.subtitles ? 'إعدادات الترجمة' : 'إعدادات الصوت',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Symbols.close_rounded, color: Colors.white70),
                        onPressed: () {
                          setState(() => _currentMenu = ActiveMenu.none);
                          _scheduleHide();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: _currentMenu == ActiveMenu.subtitles
                      ? _buildSubtitlePanelContent()
                      : _currentMenu == ActiveMenu.audio
                          ? _buildAudioPanelContent()
                          : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPanelContent() {
    final cs = Theme.of(context).colorScheme;
    final uniqueAudio = _audioTracks.toSet().toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AudioBoostSection(boost: _volumeLevel * 100, onChanged: (v) => _onVolumeChanged(v / 100)),
          const Divider(color: Colors.white24, height: 32),
          if (uniqueAudio.isNotEmpty) ...[
            const Text('المسارات الصوتية',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...uniqueAudio.map((track) {
              final name = track.title ?? track.language ?? 'مسار صوتي';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(name, style: const TextStyle(color: Colors.white)),
                subtitle: track.language != null
                    ? Text(track.language!, style: const TextStyle(color: Colors.white54))
                    : null,
                trailing: _player.state.track.audio == track ? Icon(Icons.check, color: cs.primary) : null,
                onTap: () => setState(() => _player.setAudioTrack(track)),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSubtitlePanelContent() {
    final cs = Theme.of(context).colorScheme;
    final uniqueTracks = _subtitleTracks.toSet().toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('تفعيل الترجمة', style: TextStyle(color: Colors.white, fontSize: 15)),
              Switch(
                value: _showSubtitles,
                onChanged: (v) {
                  setState(() => _showSubtitles = v);
                  if (!v) _player.setSubtitleTrack(SubtitleTrack.no());
                },
                activeColor: cs.primary,
              ),
            ],
          ),
          if (uniqueTracks.isNotEmpty) ...[
            const Divider(color: Colors.white24, height: 24),
            ...uniqueTracks.map((track) {
              final name = track.title ?? track.language ?? 'ترجمة';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(name, style: const TextStyle(color: Colors.white)),
                trailing:
                    _player.state.track.subtitle == track ? Icon(Icons.check, color: cs.primary) : null,
                onTap: () {
                  _player.setSubtitleTrack(track);
                  setState(() => _showSubtitles = true);
                },
              );
            }),
          ],
          const Divider(color: Colors.white24, height: 24),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_open, color: Colors.white70),
            title: const Text('اختيار ملف ترجمة يدوي', style: TextStyle(color: Colors.white)),
            onTap: () {
              _pickSubtitle();
              setState(() => _currentMenu = ActiveMenu.none);
            },
          ),
          const Divider(color: Colors.white24, height: 24),
          const Text('المزامنة والسرعة',
              style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('تأخير الترجمة', style: TextStyle(color: Colors.white, fontSize: 14)),
              Text('${_subtitleSync > 0 ? '+' : ''}${_subtitleSync.toStringAsFixed(1)}s',
                  style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
            child: Slider(
              value: _subtitleSync,
              min: -5.0,
              max: 5.0,
              divisions: 100,
              onChanged: _onSubtitleSyncChanged,
              activeColor: cs.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text('المظهر والتخصيص',
              style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const SubtitleAppearancePanel(),
        ],
      ),
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

    if (PipService.isInPipMode.value) {
      return Scaffold(backgroundColor: Colors.black, body: Video(controller: _controller));
    }

    final bool controlsVisible = _showControls && !_isLocked && _currentMenu == ActiveMenu.none && !_showQuickActions;

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
                          final screenWidth = MediaQuery.of(context).size.width;
                          if (x < screenWidth / 3) {
                            final target = _position - const Duration(seconds: 10);
                            _player.seek(target.isNegative ? Duration.zero : target);
                          } else if (x > screenWidth * 2 / 3) {
                            final target = _position + const Duration(seconds: 10);
                            _player.seek(target > _duration ? _duration : target);
                          } else {
                            _isPlaying ? _player.pause() : _player.play();
                          }
                        },
                  child: Video(
                    controller: _controller,
                    fit: getBoxFit(_fitMode),
                    controls: NoVideoControls,
                    subtitleViewConfiguration: SubtitleViewConfiguration(
                      style: buildSubtitleTextStyle(s),
                      textAlign: s.subtitleRTL ? TextAlign.right : TextAlign.center,
                      padding: EdgeInsets.fromLTRB(s.horizontalMargin, 0, s.horizontalMargin, s.bottomPadding),
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

                if (_isLocked)
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _toggleLock,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('مقفل — اضغط للفتح', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ]),
                        ),
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
                      onSettingsMenu: () {
                        _showQuickActions = false;
                        _showSettingsMenu();
                      },
                      isAudioActive: _currentMenu == ActiveMenu.audio,
                      isSubtitleActive: _currentMenu == ActiveMenu.subtitles,
                      isQuickActionsActive: _showQuickActions,
                    ),
                  ),
                  if (_showQuickActions)
                    Positioned(
                      top: 80,
                      right: 20,
                      child: _buildFloatingActions(),
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PipService.isInPipMode.removeListener(_onPipModeChanged);
    _brightnessNotifier.dispose();
    _seekMsNotifier.dispose();
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _fitOverlayTimer?.cancel();
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