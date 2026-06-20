import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../models/video_item.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/subtitle_service.dart';
import '../services/pip_service.dart';
import 'info_screen.dart';

enum VideoFitMode { contain, cover, fill }

BoxFit getBoxFit(VideoFitMode mode) {
  switch (mode) {
    case VideoFitMode.contain:
      return BoxFit.contain;
    case VideoFitMode.cover:
      return BoxFit.cover;
    case VideoFitMode.fill:
      return BoxFit.fill;
  }
}

String modeName(VideoFitMode mode) {
  switch (mode) {
    case VideoFitMode.contain:
      return 'Fit';
    case VideoFitMode.cover:
      return 'Crop';
    case VideoFitMode.fill:
      return 'Stretch';
  }
}

class VideoFitSettings {
  static const _key = 'video_fit_mode';

  static Future<void> save(VideoFitMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }

  static Future<VideoFitMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    return VideoFitMode.values[index];
  }
}

enum GestureType { none, seek, volumeBrightness }

class PlayerScreen extends StatefulWidget {
  final VideoItem video;

  const PlayerScreen({super.key, required this.video});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _controller;

  bool _initialized = false;
  bool _showControls = true;
  bool _isPip = false;
  bool _isLocked = false;
  Timer? _hideTimer;
  Timer? _saveTimer;

  bool _showSubtitles = true;
  List<SubtitleTrack> _subtitleTracks = [];
  List<AudioTrack> _audioTracks = [];

  double _audioBoost = 100.0;
  double _speed = 1.0;
  final _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  bool _isLandscape = true;
  VideoFitMode _fitMode = VideoFitMode.contain;
  String? _fitOverlayText;
  Timer? _fitOverlayTimer;

  double _subtitleSync = 0.0;
  double _subtitleSpeed = 1.0;
  bool _autoSubtitleSelected = false;

  final ValueNotifier<double> _volumeNotifier = ValueNotifier(0.8);
  final ValueNotifier<double> _brightnessNotifier = ValueNotifier(0.7);
  final ValueNotifier<double> _seekMsNotifier = ValueNotifier(0.0);

  final ValueNotifier<bool> _showVolNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showBrightNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showSeekNotifier = ValueNotifier(false);

  double get _effectiveVolume =>
      (_volumeNotifier.value * _audioBoost).clamp(0, 200);

  double _startSubtitleSize = 24.0;
  DateTime? _lastVolTime;
  DateTime? _lastBrightTime;
  Timer? _indicatorTimer;

  // Pan variables
  double _panStartVolume = 0.8;
  double _panStartBrightness = 0.7;
  double _panStartSeekMs = 0.0;
  GestureType _panType = GestureType.none;
  Offset _panStartPos = Offset.zero;

  // Scale (two‑finger) variables
  bool _isScaling = false;
  double _startBottomPadding = 48.0;
  Offset _scaleStartFocalPoint = Offset.zero;
  bool? _verticalTwoFingerMode; // true = vertical move, false = pinch zoom

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final orientation = MediaQuery.of(context).orientation;
        setState(() => _isLandscape = orientation == Orientation.landscape);
      }
    });

    _enterFullscreen();

    final settings = context.read<SettingsProvider>();
    _showSubtitles = settings.showSubtitlesByDefault;
    _speed = settings.defaultSpeed;
    _audioBoost = settings.defaultAudioBoost.clamp(50.0, 200.0);
    _subtitleSync = settings.defaultSubtitleSync;

    _loadPersistedVolumeAndBrightness();

    _player = Player();
    _controller = VideoController(_player);

    _initPlayer();
    _loadFitMode();
  }

  Future<void> _loadPersistedVolumeAndBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    final vol = prefs.getDouble('player_volume') ?? 0.8;
    final bright = prefs.getDouble('player_brightness') ?? 0.7;
    _volumeNotifier.value = vol.clamp(0.0, 1.0);
    _brightnessNotifier.value = bright.clamp(0.1, 1.0);
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
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
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
      if (_isLocked) _showControls = false;
    });
  }

  void _toggleFit() {
    setState(() {
      _fitMode =
          VideoFitMode.values[(_fitMode.index + 1) % VideoFitMode.values.length];
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
      _player.setVolume(_effectiveVolume);

      if (settings.rememberPosition) {
        try {
          final saved =
              await context.read<LibraryProvider>().getPosition(widget.video.path);
          if (saved != null && saved.inSeconds > 0) await _player.seek(saved);
        } catch (_) {}
      }

      _player.stream.position.listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
        if (settings.rememberPosition) {
          _saveTimer?.cancel();
          _saveTimer = Timer(const Duration(seconds: 5), () {
            if (mounted)
              context
                  .read<LibraryProvider>()
                  .savePosition(widget.video.path, _position);
          });
        }
      });

      _player.stream.duration.listen((dur) {
        if (mounted) setState(() => _duration = dur);
      });

      _player.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });

      _player.stream.tracks.listen((tracks) {
        if (!mounted) return;
        setState(() {
          _subtitleTracks = tracks.subtitle;
          _audioTracks = tracks.audio;
        });
        _applyPreferredSubtitleLanguage(settings);
      });

      try {
        _brightnessNotifier.value =
            await ScreenBrightness.instance.application;
        if (_brightnessNotifier.value < 0.1) _brightnessNotifier.value = 0.1;
        await ScreenBrightness.instance
            .setApplicationScreenBrightness(_brightnessNotifier.value);
      } catch (_) {
        _brightnessNotifier.value = 0.7;
      }

      setState(() => _initialized = true);
      _scheduleHide();

      await _loadSubtitleFromPreferredFolder(settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تشغيل الملف: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadSubtitleFromPreferredFolder(SettingsProvider s) async {
    if (s.subtitleFolder.isEmpty) {
      final srtPath = SubtitleService.findSrt(widget.video.path);
      if (srtPath != null) await _loadSrtFile(srtPath, s.subtitleEncoding);
      return;
    }

    final videoName =
        widget.video.path.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
    final folder = Directory(s.subtitleFolder);
    if (await folder.exists()) {
      final matchedFiles = <File>[];
      await for (final file in folder.list()) {
        if (file is File) {
          final fileName = file.path.split('/').last;
          if (fileName.startsWith(videoName) &&
              (fileName.endsWith('.srt') ||
                  fileName.endsWith('.SRT') ||
                  fileName.endsWith('.ssa') ||
                  fileName.endsWith('.ass'))) {
            matchedFiles.add(file);
          }
        }
      }

      if (matchedFiles.length == 1) {
        await _loadSrtFile(matchedFiles.first.path, s.subtitleEncoding);
        return;
      } else if (matchedFiles.length > 1) {
        final chosen = await showDialog<File>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('اختر ملف الترجمة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: matchedFiles
                    .map((f) => ListTile(
                          title: Text(f.path.split('/').last),
                          onTap: () => Navigator.pop(ctx, f),
                        ))
                    .toList(),
              ),
            ),
          ),
        );
        if (chosen != null) {
          await _loadSrtFile(chosen.path, s.subtitleEncoding);
          return;
        }
      }
    }

    final srtPath = SubtitleService.findSrt(widget.video.path);
    if (srtPath != null) await _loadSrtFile(srtPath, s.subtitleEncoding);
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

  Future<void> _loadSrtFile(String path, [String encoding = 'UTF-8']) async {
    try {
      await _player.setSubtitleTrack(SubtitleTrack.no());

      final entries = await SubtitleService.load(path);
      if (entries.isEmpty) return;

      final srtContent = StringBuffer();
      for (int i = 0; i < entries.length; i++) {
        final e = entries[i];
        srtContent.writeln('${i + 1}');
        srtContent
            .writeln('${_formatSrtTime(e.start)} --> ${_formatSrtTime(e.end)}');
        srtContent.writeln(e.text);
        srtContent.writeln();
      }

      await _player.setSubtitleTrack(
        SubtitleTrack.data(srtContent.toString(), title: 'ترجمة خارجية'),
      );

      if (mounted) {
        setState(() => _showSubtitles = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تحميل الترجمة')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل الترجمة: $e')),
        );
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
    final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'SRT', 'ssa', 'ass']);
    if (result?.files.single.path != null) {
      final settings = context.read<SettingsProvider>();
      await _loadSrtFile(result!.files.single.path!, settings.subtitleEncoding);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying && !_isLocked)
        setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  Future<void> _enterPip() async {
    try {
      await PipService.enter();
    } catch (_) {}
  }

  // ──────────────────────────────────────────────
  // Pan gestures (one finger) – volume / brightness / seek
  // ──────────────────────────────────────────────
  void _onPanDown(DragDownDetails details) {
    if (_isLocked || _isScaling) return;
    _hideTimer?.cancel();
    _indicatorTimer?.cancel();

    _panStartPos = details.localPosition;
    _panType = GestureType.none;
    _panStartVolume = _volumeNotifier.value;
    _panStartBrightness = _brightnessNotifier.value;
    _panStartSeekMs = _position.inMilliseconds.toDouble();
    _seekMsNotifier.value = _panStartSeekMs;
  }

  void _onPanUpdate(DragUpdateDetails details, double screenWidth) {
    if (_isLocked || _isScaling) return;

    if (_panType == GestureType.none) {
      final delta = details.localPosition - _panStartPos;
      if (delta.distance < 8) return;
      if (delta.dx.abs() > delta.dy.abs()) {
        _panType = GestureType.seek;
      } else {
        _panType = GestureType.volumeBrightness;
      }
    }

    if (_panType == GestureType.seek) {
      _handleSeekPan(details, screenWidth);
    } else if (_panType == GestureType.volumeBrightness) {
      _handleVolumeBrightnessPan(details, screenWidth);
    }
  }

  void _handleSeekPan(DragUpdateDetails details, double screenWidth) {
    final dx = details.delta.dx;
    final double seekFactor =
        (_duration.inMilliseconds * 0.25).clamp(50000, 500000);
    final seekChangeMs = (dx / screenWidth) * seekFactor;
    _seekMsNotifier.value = (_seekMsNotifier.value + seekChangeMs)
        .clamp(0.0, _duration.inMilliseconds.toDouble());

    _showSeekNotifier.value = true;
    _showBrightNotifier.value = false;
    _showVolNotifier.value = false;
    _resetIndicatorTimer();
  }

  void _handleVolumeBrightnessPan(
      DragUpdateDetails details, double screenWidth) {
    final dy = details.delta.dy;
    final double delta = -dy / 200.0;
    final bool isLeft = details.localPosition.dx < screenWidth / 2;
    final DateTime now = DateTime.now();

    if (isLeft) {
      final newBrightness =
          (_brightnessNotifier.value + delta).clamp(0.1, 1.0);
      _brightnessNotifier.value = newBrightness;
      _showBrightNotifier.value = true;
      _showVolNotifier.value = false;
      _showSeekNotifier.value = false;

      if (_lastBrightTime == null ||
          now.difference(_lastBrightTime!) >
              const Duration(milliseconds: 50)) {
        try {
          ScreenBrightness.instance
              .setApplicationScreenBrightness(newBrightness);
        } catch (_) {}
        _lastBrightTime = now;
      }
    } else {
      final newVol = (_volumeNotifier.value + delta).clamp(0.0, 1.0);
      _volumeNotifier.value = newVol;
      _showVolNotifier.value = true;
      _showBrightNotifier.value = false;
      _showSeekNotifier.value = false;

      if (_lastVolTime == null ||
          now.difference(_lastVolTime!) > const Duration(milliseconds: 50)) {
        _player.setVolume(_effectiveVolume);
        _lastVolTime = now;
      }
    }
    _resetIndicatorTimer();
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isLocked || _isScaling) return;

    if (_panType == GestureType.seek) {
      _player.seek(Duration(milliseconds: _seekMsNotifier.value.toInt()));
      _showSeekNotifier.value = false;
      _scheduleHide();
    }

    _saveVolumeAndBrightness();
    _panType = GestureType.none;
    _resetIndicatorTimer();
  }

  // ──────────────────────────────────────────────
  // Scale gestures (two fingers) – subtitle zoom & vertical move
  // ──────────────────────────────────────────────
  void _onScaleStart(ScaleStartDetails details) {
    if (_isLocked) return;
    if (details.pointerCount >= 2) {
      _isScaling = true;
      _hideTimer?.cancel();
      _indicatorTimer?.cancel();

      final settings = context.read<SettingsProvider>();
      _startSubtitleSize = settings.subtitleFontSize;
      _startBottomPadding = settings.bottomPadding;
      _scaleStartFocalPoint = details.focalPoint;
      _verticalTwoFingerMode = null; // will be decided on first move
      // hide other indicators
      _showBrightNotifier.value = false;
      _showVolNotifier.value = false;
      _showSeekNotifier.value = false;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double screenWidth) {
    if (_isLocked || !_isScaling) return;
    if (details.pointerCount < 2) return;

    final settings = context.read<SettingsProvider>();
    final scaleChange = (details.scale - 1.0).abs();
    final focalDy = details.focalPointDelta.dy;
    final focalDx = details.focalPointDelta.dx;

    // Determine mode on first significant move
    if (_verticalTwoFingerMode == null) {
      if (scaleChange > 0.03 || focalDy.abs() > 5 || focalDx.abs() > 5) {
        // If scale changed noticeably → pinch zoom, otherwise vertical pan
        if (scaleChange > 0.03) {
          _verticalTwoFingerMode = false;
        } else if (focalDy.abs() > focalDx.abs()) {
          _verticalTwoFingerMode = true;
        } else {
          _verticalTwoFingerMode = false; // default to zoom if unsure
        }
      } else {
        return; // wait for clearer input
      }
    }

    if (_verticalTwoFingerMode == true) {
      // Vertical movement of subtitles
      final newBottomPadding =
          (_startBottomPadding - focalDy * 0.5).clamp(0.0, 200.0);
      settings.setBottomPadding(newBottomPadding);
    } else {
      // Pinch zoom
      final newSize =
          (_startSubtitleSize * details.scale).clamp(10.0, 150.0);
      settings.setSubtitleFontSize(newSize);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_isLocked) return;
    _isScaling = false;
    _verticalTwoFingerMode = null;
    _panType = GestureType.none;
    _resetIndicatorTimer();
    // settings are already saved via provider setters
  }

  Future<void> _saveVolumeAndBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('player_volume', _volumeNotifier.value);
    await prefs.setDouble('player_brightness', _brightnessNotifier.value);
  }

  void _resetIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _showBrightNotifier.value = false;
        _showVolNotifier.value = false;
      }
    });
  }

  // ──────────────────────────────────────────────
  // Floating indicators (unchanged)
  // ──────────────────────────────────────────────
  Widget _buildFloatingIndicator({
    required IconData icon,
    required double displayValue,
    required String labelText,
    required Color color,
  }) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 52,
        height: 200,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.18),
                    Colors.white.withOpacity(0.06)
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border:
                    Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              ),
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(height: 8),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: -1,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5),
                          activeTrackColor: color,
                          inactiveTrackColor:
                              Colors.white.withOpacity(0.2),
                          thumbColor: Colors.white,
                          overlayColor: color.withOpacity(0.2),
                        ),
                        child: Slider(
                            value: displayValue.clamp(0.0, 1.0),
                            onChanged: null,
                            min: 0,
                            max: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labelText,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSpeedSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Text('سرعة التشغيل',
                style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ),
          const Divider(height: 1),
          ..._speeds.map((sp) => ListTile(
                title: Text('${sp}x'),
                trailing: _speed == sp
                    ? Icon(Symbols.check_rounded, color: cs.primary)
                    : null,
                selected: _speed == sp,
                onTap: () {
                  setState(() => _speed = sp);
                  _player.setRate(sp);
                  Navigator.pop(context);
                },
              )),
        ]),
      ),
    );
  }

  void _showSubtitleMenu() {
    final cs = Theme.of(context).colorScheme;
    final seen = <String>{};
    final uniqueTracks = <SubtitleTrack>[];
    for (final t in _subtitleTracks) {
      final k = t.title ?? t.language ?? 'unknown';
      if (!seen.contains(k)) {
        seen.add(k);
        uniqueTracks.add(t);
      }
    }

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(16),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: Colors.lightBlue,
              title: Text(_showSubtitles ? 'إيقاف الترجمة' : 'تشغيل الترجمة',
                  style: const TextStyle(color: Colors.white)),
              value: _showSubtitles,
              onChanged: (v) {
                setState(() => _showSubtitles = v);
                if (!v) _player.setSubtitleTrack(SubtitleTrack.no());
                Navigator.pop(ctx);
              },
            ),
            if (uniqueTracks.isNotEmpty) ...[
              const Divider(color: Colors.white24),
              ...uniqueTracks.map((track) {
                final name = track.title ?? track.language ?? 'ترجمة';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(name, style: const TextStyle(color: Colors.white)),
                  subtitle: track.language != null
                      ? Text(track.language!,
                          style: const TextStyle(color: Colors.white54))
                      : null,
                  trailing: _player.state.track.subtitle == track
                      ? Icon(Icons.check, color: cs.primary)
                      : null,
                  onTap: () {
                    _player.setSubtitleTrack(track);
                    setState(() => _showSubtitles = true);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.white),
              title: const Text('تحميل ترجمة من ملف',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickSubtitle();
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text('مزامنة وإعدادات',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showSyncSpeedPaletteSheet();
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.palette, color: Colors.white),
              title: const Text('تخصيص المظهر',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showSubtitleSettingsSheet();
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _showAudioMenu() async {
    final cs = Theme.of(context).colorScheme;
    final seen = <String>{};
    final uniqueAudio = <AudioTrack>[];
    for (final t in _audioTracks) {
      final k = t.title ?? t.language ?? 'unknown';
      if (!seen.contains(k)) {
        seen.add(k);
        uniqueAudio.add(t);
      }
    }

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(16),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (uniqueAudio.isNotEmpty) ...[
              const Text('المسارات الصوتية',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              ...uniqueAudio.map((track) {
                final name = track.title ?? track.language ?? 'مسار صوتي';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title:
                      Text(name, style: const TextStyle(color: Colors.white)),
                  subtitle: track.language != null
                      ? Text(track.language!,
                          style: const TextStyle(color: Colors.white54))
                      : null,
                  trailing: _player.state.track.audio == track
                      ? Icon(Icons.check, color: cs.primary)
                      : null,
                  onTap: () {
                    _player.setAudioTrack(track);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const Divider(color: Colors.white24),
            ],
            _AudioBoostSection(
              boost: _audioBoost,
              onChanged: (v) {
                setState(() => _audioBoost = v);
                _player.setVolume(_effectiveVolume);
              },
            ),
          ]),
        ),
      ),
    );
  }

  void _showSyncSpeedPaletteSheet() {
    final settings = context.read<SettingsProvider>();
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(16),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('إعدادات الترجمة',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white24),
            ListTile(
              dense: true,
              title: const Text('مزامنة الترجمة',
                  style: TextStyle(color: Colors.white)),
              subtitle: Slider(
                value: _subtitleSync,
                min: -5.0,
                max: 5.0,
                divisions: 100,
                label: '${_subtitleSync.toStringAsFixed(1)}s',
                onChanged: (v) {
                  setState(() => _subtitleSync = v);
                  settings.setDefaultSubtitleSync(v);
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            ListTile(
              dense: true,
              title: const Text('سرعة الترجمة',
                  style: TextStyle(color: Colors.white)),
              subtitle: Slider(
                value: _subtitleSpeed,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                label: '${_subtitleSpeed}x',
                onChanged: (v) => setState(() => _subtitleSpeed = v),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showSubtitleSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    const Text(
                      'تخصيص الترجمة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    _buildSettingsContent(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    final s = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(
        dense: true,
        title: const Text('حجم الخط', style: TextStyle(color: Colors.white)),
        subtitle: Slider(
          value: s.subtitleFontSize,
          min: 10,
          max: 150,
          onChanged: (v) => s.setSubtitleFontSize(v),
          activeColor: cs.primary,
        ),
      ),
      ListTile(
        dense: true,
        title: const Text('لون النص', style: TextStyle(color: Colors.white)),
        trailing: GestureDetector(
          onTap: () async {
            final color =
                await showColorPickerDialog(context, s.subtitleColor);
            if (color != null) s.setSubtitleColor(color);
          },
          child: ColorIndicator(color: s.subtitleColor),
        ),
      ),
      ListTile(
        dense: true,
        title:
            const Text('لون الخلفية', style: TextStyle(color: Colors.white)),
        trailing: GestureDetector(
          onTap: () async {
            final color =
                await showColorPickerDialog(context, s.subtitleBgColor);
            if (color != null) s.setSubtitleBgColor(color);
          },
          child: ColorIndicator(color: s.subtitleBgColor),
        ),
      ),
      ListTile(
        dense: true,
        title: const Text('شفافية الخلفية',
            style: TextStyle(color: Colors.white)),
        subtitle: Slider(
          value: s.subtitleBgOpacity,
          min: 0.0,
          max: 1.0,
          onChanged: (v) => s.setSubtitleBgOpacity(v),
          activeColor: cs.primary,
        ),
      ),
      SwitchListTile(
        dense: true,
        title: const Text('ظل النص', style: TextStyle(color: Colors.white)),
        value: s.textShadowEnabled,
        activeColor: cs.primary,
        onChanged: (v) => s.setTextShadowEnabled(v),
      ),
      if (s.textShadowEnabled) ...[
        ListTile(
          dense: true,
          title:
              const Text('لون الظل', style: TextStyle(color: Colors.white70)),
          trailing: GestureDetector(
            onTap: () async {
              final color =
                  await showColorPickerDialog(context, s.textShadowColor);
              if (color != null) s.setTextShadowColor(color);
            },
            child: ColorIndicator(color: s.textShadowColor),
          ),
        ),
        ListTile(
          dense: true,
          title:
              const Text('حجم الظل', style: TextStyle(color: Colors.white70)),
          subtitle: Slider(
            value: s.textShadowBlurRadius,
            min: 0,
            max: 20,
            onChanged: (v) => s.setTextShadowBlurRadius(v),
            activeColor: cs.primary,
          ),
        ),
        ListTile(
          dense: true,
          title: const Text('إزاحة أفقية',
              style: TextStyle(color: Colors.white70)),
          subtitle: Slider(
            value: s.textShadowOffsetX,
            min: -10,
            max: 10,
            onChanged: (v) => s.setTextShadowOffsetX(v),
            activeColor: cs.primary,
          ),
        ),
        ListTile(
          dense: true,
          title: const Text('إزاحة رأسية',
              style: TextStyle(color: Colors.white70)),
          subtitle: Slider(
            value: s.textShadowOffsetY,
            min: -10,
            max: 10,
            onChanged: (v) => s.setTextShadowOffsetY(v),
            activeColor: cs.primary,
          ),
        ),
      ],
      ListTile(
        dense: true,
        title: const Text('الهامش الأفقي',
            style: TextStyle(color: Colors.white)),
        subtitle: Slider(
          value: s.horizontalMargin,
          min: 0,
          max: 100,
          onChanged: (v) => s.setHorizontalMargin(v),
          activeColor: cs.primary,
        ),
      ),
      ListTile(
        dense: true,
        title: const Text('المسافة السفلية',
            style: TextStyle(color: Colors.white)),
        subtitle: Slider(
          value: s.bottomPadding,
          min: 0,
          max: 200,
          onChanged: (v) => s.setBottomPadding(v),
          activeColor: cs.primary,
        ),
      ),
    ]);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  FontWeight _getFontWeight(int index) {
    switch (index) {
      case 0:
        return FontWeight.w300;
      case 1:
        return FontWeight.normal;
      case 2:
        return FontWeight.w500;
      case 3:
        return FontWeight.bold;
      default:
        return FontWeight.normal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final s = context.watch<SettingsProvider>();

    if (_isPip)
      return Scaffold(
          backgroundColor: Colors.black, body: Video(controller: _controller));

    return PopScope(
      canPop: !_isLocked,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && !_isLocked) await _enterPip();
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
                          final isRight =
                              details.localPosition.dx > screenWidth / 2;
                          final target = isRight
                              ? (_position + const Duration(seconds: 10))
                              : (_position - const Duration(seconds: 10));
                          _player.seek(target.isNegative
                              ? Duration.zero
                              : (target > _duration ? _duration : target));
                        },
                  onPanDown: _onPanDown,
                  onPanUpdate: (details) => _onPanUpdate(details, screenWidth),
                  onPanEnd: _onPanEnd,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: (details) =>
                      _onScaleUpdate(details, screenWidth),
                  onScaleEnd: _onScaleEnd,
                  child: Video(
                    controller: _controller,
                    fit: getBoxFit(_fitMode),
                    controls: NoVideoControls,
                    subtitleViewConfiguration: SubtitleViewConfiguration(
                      style: TextStyle(
                        fontSize: s.subtitleFontSize,
                        color: s.subtitleColor,
                        fontWeight: _getFontWeight(s.fontWeightIndex),
                        fontFamily: s.fontFamily,
                        fontStyle: s.subtitleItalic
                            ? FontStyle.italic
                            : FontStyle.normal,
                        backgroundColor:
                            s.subtitleBgColor.withOpacity(s.subtitleBgOpacity),
                        shadows: s.textShadowEnabled
                            ? [
                                Shadow(
                                    color: s.textShadowColor,
                                    blurRadius: s.textShadowBlurRadius,
                                    offset: Offset(s.textShadowOffsetX,
                                        s.textShadowOffsetY))
                              ]
                            : null,
                      ),
                      textAlign:
                          s.subtitleRTL ? TextAlign.right : TextAlign.center,
                      padding: EdgeInsets.fromLTRB(s.horizontalMargin, 0,
                          s.horizontalMargin, s.bottomPadding),
                    ),
                  ),
                ),

                // Seek indicator
                ValueListenableBuilder<bool>(
                  valueListenable: _showSeekNotifier,
                  builder: (context, show, child) {
                    if (!show) return const SizedBox.shrink();
                    return ValueListenableBuilder<double>(
                      valueListenable: _seekMsNotifier,
                      builder: (context, seekMs, child) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Symbols.fast_forward_rounded,
                                      color: Colors.white, size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    _fmt(Duration(
                                        milliseconds: seekMs.toInt())),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ]),
                          ),
                        );
                      },
                    );
                  },
                ),

                // Volume indicator
                ValueListenableBuilder<bool>(
                  valueListenable: _showVolNotifier,
                  builder: (context, show, child) {
                    if (!show) return const SizedBox.shrink();
                    return ValueListenableBuilder<double>(
                      valueListenable: _volumeNotifier,
                      builder: (context, volume, child) {
                        return Positioned(
                          left: 24,
                          top: MediaQuery.of(context).size.height * 0.25,
                          child: _buildFloatingIndicator(
                            icon: volume == 0
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            displayValue: volume,
                            labelText:
                                '${(volume * _audioBoost).round()}%',
                            color: cs.primary,
                          ),
                        );
                      },
                    );
                  },
                ),

                // Brightness indicator
                ValueListenableBuilder<bool>(
                  valueListenable: _showBrightNotifier,
                  builder: (context, show, child) {
                    if (!show) return const SizedBox.shrink();
                    return ValueListenableBuilder<double>(
                      valueListenable: _brightnessNotifier,
                      builder: (context, brightness, child) {
                        return Positioned(
                          right: 24,
                          top: MediaQuery.of(context).size.height * 0.25,
                          child: _buildFloatingIndicator(
                            icon: brightness < 0.15
                                ? Icons.brightness_low_rounded
                                : Icons.brightness_6_rounded,
                            displayValue: brightness,
                            labelText: '${(brightness * 100).round()}%',
                            color: cs.secondary,
                          ),
                        );
                      },
                    );
                  },
                ),

                if (_fitOverlayText != null)
                  Positioned(
                      top: 100,
                      left: 0,
                      right: 0,
                      child: Center(
                          child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(_fitOverlayText!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600)),
                      ))),

                if (_isLocked)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: SafeArea(
                        child: GestureDetector(
                      onTap: _toggleLock,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.85),
                            shape: BoxShape.circle),
                        child: const Icon(Symbols.lock_rounded,
                            color: Colors.white, size: 22),
                      ),
                    )),
                  ),

                if (_showControls && !_isLocked) ...[
                  // Top bar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.8),
                              Colors.transparent
                            ]),
                      ),
                      child: SafeArea(
                        child: Row(children: [
                          IconButton(
                              icon: const Icon(Symbols.arrow_back_rounded,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(context)),
                          Expanded(
                              child: Text(widget.video.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14))),
                          IconButton(
                              icon: const Icon(Symbols.aspect_ratio_rounded,
                                  color: Colors.white70),
                              onPressed: _toggleFit),
                          IconButton(
                              icon: Icon(
                                  _isLandscape
                                      ? Symbols.screen_rotation_rounded
                                      : Symbols.stay_current_portrait_rounded,
                                  color: Colors.white70),
                              onPressed: _toggleOrientation),
                          IconButton(
                              icon: const Icon(
                                  Symbols.picture_in_picture_rounded,
                                  color: Colors.white70),
                              onPressed: _enterPip),
                          IconButton(
                              icon: const Icon(Symbols.graphic_eq_rounded,
                                  color: Colors.white70),
                              onPressed: _showAudioMenu),
                          IconButton(
                              icon: Icon(
                                  _showSubtitles
                                      ? Symbols.subtitles_rounded
                                      : Symbols.subtitles_off_rounded,
                                  color: _showSubtitles
                                      ? Colors.lightBlue
                                      : Colors.white54),
                              onPressed: _showSubtitleMenu),
                        ]),
                      ),
                    ),
                  ),

                  // Bottom bar (progress)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.85),
                              Colors.transparent
                            ]),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Row(children: [
                            Text(_fmt(_position),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                    trackHeight: 3,
                                    thumbShape:
                                        const RoundSliderThumbShape(
                                            enabledThumbRadius: 6),
                                    activeTrackColor: cs.primary,
                                    inactiveTrackColor:
                                        Colors.white.withOpacity(0.2),
                                    thumbColor: cs.primary),
                                child: Slider(
                                  value: _duration.inMilliseconds > 0
                                      ? (_position.inMilliseconds /
                                              _duration.inMilliseconds)
                                          .clamp(0.0, 1.0)
                                      : 0.0,
                                  onChanged: (v) => _player.seek(Duration(
                                      milliseconds:
                                          (v * _duration.inMilliseconds)
                                              .toInt())),
                                ),
                              ),
                            ),
                            Text(_fmt(_duration),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ]),
                        ),
                      ),
                    ),
                  ),

                  // Play/Pause & skip buttons
                  Center(
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        _CtrlBtn(
                          Symbols.replay_10_rounded,
                          () {
                            final target = _position -
                                const Duration(seconds: 10);
                            _player.seek(target.isNegative
                                ? Duration.zero
                                : target);
                          },
                        ),
                        const SizedBox(width: 28),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _isPlaying
                                ? _player.pause()
                                : _player.play(),
                            borderRadius: BorderRadius.circular(34),
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color:
                                    cs.primaryContainer.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                  _isPlaying
                                      ? Symbols.pause_rounded
                                      : Symbols.play_arrow_rounded,
                                  color: cs.onPrimaryContainer,
                                  size: 38),
                            ),
                          ),
                        ),
                        const SizedBox(width: 28),
                        _CtrlBtn(
                          Symbols.forward_10_rounded,
                          () {
                            final target = _position +
                                const Duration(seconds: 10);
                            _player.seek(
                                target > _duration ? _duration : target);
                          },
                        ),
                      ])),
                ],
              ]),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _volumeNotifier.dispose();
    _brightnessNotifier.dispose();
    _seekMsNotifier.dispose();
    _showVolNotifier.dispose();
    _showBrightNotifier.dispose();
    _showSeekNotifier.dispose();

    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _indicatorTimer?.cancel();
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

class _AudioBoostSection extends StatefulWidget {
  final double boost;
  final ValueChanged<double> onChanged;
  const _AudioBoostSection({required this.boost, required this.onChanged});
  @override
  State<_AudioBoostSection> createState() => _AudioBoostSectionState();
}

class _AudioBoostSectionState extends State<_AudioBoostSection> {
  late double _local;
  @override
  void initState() {
    super.initState();
    _local = widget.boost;
  }

  Color _boostColor(double v) {
    if (v <= 100) return Colors.lightBlue;
    if (v <= 150) return Colors.orange;
    return Colors.redAccent;
  }

  String _boostLabel(double v) {
    if (v <= 100) return 'طبيعي';
    if (v <= 130) return 'مرتفع';
    if (v <= 160) return 'عالٍ جداً';
    return '⚠️ تشويه محتمل';
  }

  @override
  Widget build(BuildContext context) {
    final color = _boostColor(_local);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('تكبير الصوت',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        Text(_boostLabel(_local),
            style: TextStyle(color: color, fontSize: 11)),
      ]),
      const SizedBox(height: 6),
      AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
            color: color, fontWeight: FontWeight.w800, fontSize: 36),
        child: Text('${_local.round()}%'),
      ),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 5,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          activeTrackColor: color,
          inactiveTrackColor: Colors.white12,
          thumbColor: color,
          overlayColor: color.withOpacity(0.2),
        ),
        child: Slider(
            value: _local,
            min: 50,
            max: 200,
            divisions: 30,
            onChanged: (v) {
              setState(() => _local = v);
              widget.onChanged(v);
            }),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        for (final val in [100.0, 130.0, 160.0, 200.0])
          _QuickBtn(
              label: '${val.toInt()}%',
              active: (_local - val).abs() < 2,
              color: _boostColor(val),
              onTap: () {
                setState(() => _local = val);
                widget.onChanged(val);
              }),
      ]),
    ]);
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn(
      {required this.label,
      required this.active,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.25) : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? color : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CtrlBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      );
}