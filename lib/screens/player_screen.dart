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
    case VideoFitMode.contain: return BoxFit.contain;
    case VideoFitMode.cover:   return BoxFit.cover;
    case VideoFitMode.fill:    return BoxFit.fill;
  }
}

String modeName(VideoFitMode mode) {
  switch (mode) {
    case VideoFitMode.contain: return 'Fit';
    case VideoFitMode.cover:   return 'Crop';
    case VideoFitMode.fill:    return 'Stretch';
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

  double _gestureVolume = 0.8;
  double _audioBoost = 100.0;
  double get _effectiveVolume => (_gestureVolume * _audioBoost).clamp(0, 200);

  double _speed = 1.0;
  final _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  double _brightness = 0.7;

  // متغيرات الإيماءة الجديدة
  double _subtitleBaseScale = 1.0;
  double _seekPreviewMs = 0.0;
  bool _showSeekIndicator = false;
  DateTime? _lastSeekTime;

  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  Timer? _indicatorTimer;

  bool _isLandscape = true;

  VideoFitMode _fitMode = VideoFitMode.contain;
  String? _fitOverlayText;
  Timer? _fitOverlayTimer;

  double _subtitleSync = 0.0;
  double _subtitleSpeed = 1.0;
  bool _autoSubtitleSelected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _enterFullscreen();

    final settings = context.read<SettingsProvider>();
    _showSubtitles = settings.showSubtitlesByDefault;
    _speed = settings.defaultSpeed;
    _audioBoost = settings.defaultAudioBoost.clamp(50.0, 200.0);
    _subtitleSync = settings.defaultSubtitleSync;

    _player = Player();
    _controller = VideoController(_player);

    _initPlayer();
    _loadFitMode();
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
      _player.setVolume(_effectiveVolume);

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
        _brightness = await ScreenBrightness.instance.application;
        await ScreenBrightness.instance.setApplicationScreenBrightness(_brightness);
      } catch (_) {
        _brightness = 0.7;
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

  // ── الترجمة ───────────────────────────────────
  Future<void> _loadSubtitleFromPreferredFolder(SettingsProvider s) async {
    if (s.subtitleFolder.isEmpty) {
      final srtPath = SubtitleService.findSrt(widget.video.path);
      if (srtPath != null) await _loadSrtFile(srtPath, s.subtitleEncoding);
      return;
    }

    final videoName = widget.video.path.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
    final folder = Directory(s.subtitleFolder);
    if (await folder.exists()) {
      await for (final file in folder.list()) {
        if (file is File) {
          final fileName = file.path.split('/').last;
          if (fileName.startsWith(videoName) &&
              (fileName.endsWith('.srt') || fileName.endsWith('.SRT') ||
               fileName.endsWith('.ssa') || fileName.endsWith('.ass'))) {
            await _loadSrtFile(file.path, s.subtitleEncoding);
            return;
          }
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
      final entries = await SubtitleService.load(path);
      if (entries.isEmpty) return;

      final srtContent = StringBuffer();
      for (int i = 0; i < entries.length; i++) {
        final e = entries[i];
        srtContent.writeln('${i + 1}');
        srtContent.writeln('${_formatSrtTime(e.start)} --> ${_formatSrtTime(e.end)}');
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
        type: FileType.custom, allowedExtensions: ['srt', 'SRT', 'ssa', 'ass']);
    if (result?.files.single.path != null) {
      final settings = context.read<SettingsProvider>();
      await _loadSrtFile(result!.files.single.path!, settings.subtitleEncoding);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying && !_isLocked) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  Future<void> _enterPip() async {
    try { await PipService.enter(); } catch (_) {}
  }

  // ════════════════════════════════════════════════
  // 🎯 الإيماءات (Live Scrubbing + Throttling)
  // ════════════════════════════════════════════════
  void _onScaleStart(ScaleStartDetails details) {
    if (_isLocked) return;
    _hideTimer?.cancel();
    _indicatorTimer?.cancel();

    if (details.pointerCount == 2) {
      _subtitleBaseScale = 1.0;
    } else {
      _seekPreviewMs = _position.inMilliseconds.toDouble();
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double screenWidth) {
    if (_isLocked) return;

    if (details.pointerCount == 2) {
      _handleSubtitleScale(details.scale);
      setState(() {
        _showBrightnessIndicator = false;
        _showVolumeIndicator = false;
        _showSeekIndicator = false;
      });
      return;
    }

    final dx = details.focalPointDelta.dx;
final dy = details.focalPointDelta.dy;

    if (dx.abs() < 2 && dy.abs() < 2) return;

    if (dx.abs() > dy.abs()) {
      // ➜ Live Scrubbing (أفقي)
      final seekChangeMs = (dx / screenWidth) * _duration.inMilliseconds;
      final newMs = (_seekPreviewMs + seekChangeMs).clamp(0.0, _duration.inMilliseconds.toDouble());
      _seekPreviewMs = newMs;

      setState(() {
        _showSeekIndicator = true;
        _showBrightnessIndicator = false;
        _showVolumeIndicator = false;
      });

      // Throttling: لا نرسل seek أكثر من مرة كل 250ms
      final now = DateTime.now();
      if (_lastSeekTime == null || now.difference(_lastSeekTime!) > const Duration(milliseconds: 250)) {
        _player.seek(Duration(milliseconds: newMs.toInt()));
        _lastSeekTime = now;
      }
    } else {
      // ➜ عمودي = صوت / سطوع
      final delta = -dy / 200.0;
      final isLeft = details.localFocalPoint.dx < screenWidth / 2;

      if (isLeft) {
        final newBrightness = (_brightness + delta).clamp(0.0, 1.0);
        try {
          ScreenBrightness.instance.setApplicationScreenBrightness(newBrightness);
          setState(() {
            _brightness = newBrightness;
            _showBrightnessIndicator = true;
            _showVolumeIndicator = false;
            _showSeekIndicator = false;
          });
        } catch (_) {}
      } else {
        final newVol = (_gestureVolume + delta).clamp(0.0, 1.0);
        _gestureVolume = newVol;
        _player.setVolume(_effectiveVolume);
        setState(() {
          _showVolumeIndicator = true;
          _showBrightnessIndicator = false;
          _showSeekIndicator = false;
        });
      }
      _resetIndicatorTimer();
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (details.pointerCount == 2) {
      // يمكن حفظ الحجم هنا
    } else {
      // Seek نهائي دقيق
      _player.seek(Duration(milliseconds: _seekPreviewMs.toInt()));
      setState(() => _showSeekIndicator = false);
      _resetIndicatorTimer();
      _scheduleHide();
    }
  }

  void _handleSubtitleScale(double gestureScale) {
    final newScale = (_subtitleBaseScale * gestureScale).clamp(0.5, 3.0);

    try {
      if (_player.platform is NativePlayer) {
        final nativePlayer = _player.platform as NativePlayer;
        nativePlayer.setProperty('sub-scale', newScale.toStringAsFixed(2));
      }
    } catch (_) {}
  }

  void _resetIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 1, milliseconds: 500), () {
      if (mounted) setState(() {
        _showBrightnessIndicator = false;
        _showVolumeIndicator = false;
      });
    });
  }

  // ════════════════════════════════════════════════
  // مؤشرات الصوت والسطوع والتمرير (FadeOut)
  // ════════════════════════════════════════════════
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
              offset: const Offset(0, 4),
            ),
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
                    Colors.white.withOpacity(0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          activeTrackColor: color,
                          inactiveTrackColor: Colors.white.withOpacity(0.2),
                          thumbColor: Colors.white,
                          overlayColor: color.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: displayValue.clamp(0.0, 1.0),
                          onChanged: null,
                          min: 0,
                          max: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labelText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── القوائم ──────────────────────────────────
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
                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const Divider(height: 1),
          ..._speeds.map((sp) => ListTile(
                title: Text('${sp}x'),
                trailing: _speed == sp ? Icon(Symbols.check_rounded, color: cs.primary) : null,
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
      if (!seen.contains(k)) { seen.add(k); uniqueTracks.add(t); }
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
                      ? Text(track.language!, style: const TextStyle(color: Colors.white54))
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
              title: const Text('تحميل ترجمة من ملف', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _pickSubtitle(); },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text('مزامنة وإعدادات', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _showSyncSpeedPaletteSheet(); },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.palette, color: Colors.white),
              title: const Text('تخصيص المظهر', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _showSubtitleSettingsSheet(); },
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
      if (!seen.contains(k)) { seen.add(k); uniqueAudio.add(t); }
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
                  title: Text(name, style: const TextStyle(color: Colors.white)),
                  subtitle: track.language != null
                      ? Text(track.language!, style: const TextStyle(color: Colors.white54))
                      : null,
                  trailing: _player.state.track.audio == track
                      ? Icon(Icons.check, color: cs.primary)
                      : null,
                  onTap: () { _player.setAudioTrack(track); Navigator.pop(ctx); },
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
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white24),
            ListTile(
              dense: true,
              title: const Text('مزامنة الترجمة', style: TextStyle(color: Colors.white)),
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
              title: const Text('سرعة الترجمة', style: TextStyle(color: Colors.white)),
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
            const Divider(color: Colors.white24),
            const Text('ألوان سريعة', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _colorChip(Colors.white, 'أبيض'),
              _colorChip(Colors.yellowAccent, 'أصفر'),
              _colorChip(Colors.cyanAccent, 'سماوي'),
              _colorChip(Colors.lightGreenAccent, 'أخضر'),
              _colorChip(Colors.redAccent, 'أحمر'),
            ]),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق', style: TextStyle(color: Colors.white70))),
          ]),
        ),
      ),
    );
  }

  Widget _colorChip(Color color, String label) {
    return GestureDetector(
      onTap: () { context.read<SettingsProvider>().setSubtitleColor(color); Navigator.pop(context); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showSubtitleSettingsSheet() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(16),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('تخصيص الترجمة',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white24),
          _buildSettingsContent(),
        ])),
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
              value: s.subtitleFontSize, min: 10, max: 150,
              onChanged: (v) => s.setSubtitleFontSize(v), activeColor: cs.primary)),
      ListTile(
          dense: true,
          title: const Text('نوع الخط', style: TextStyle(color: Colors.white)),
          trailing: Text(s.fontFamily, style: const TextStyle(color: Colors.white54)),
          onTap: () { Navigator.pop(context); _showFontFamilyPicker(); }),
      ListTile(
          dense: true,
          title: const Text('لون النص', style: TextStyle(color: Colors.white)),
          trailing: CircleAvatar(backgroundColor: s.subtitleColor, radius: 12),
          onTap: () { Navigator.pop(context); _showColorPicker(context, s.subtitleColor, (c) => s.setSubtitleColor(c)); }),
      SwitchListTile(
          dense: true,
          title: const Text('تفعيل الخلفية', style: TextStyle(color: Colors.white)),
          value: s.subtitleBgOpacity > 0,
          onChanged: (v) => s.setSubtitleBgOpacity(v ? 0.4 : 0.0),
          activeColor: Colors.lightBlue),
      if (s.subtitleBgOpacity > 0) ...[
        ListTile(
            dense: true,
            title: const Text('لون الخلفية', style: TextStyle(color: Colors.white)),
            trailing: CircleAvatar(backgroundColor: s.subtitleBgColor, radius: 12),
            onTap: () { Navigator.pop(context); _showColorPicker(context, s.subtitleBgColor, (c) => s.setSubtitleBgColor(c)); }),
        ListTile(
            dense: true,
            title: const Text('شفافية الخلفية', style: TextStyle(color: Colors.white)),
            subtitle: Slider(
                value: s.subtitleBgOpacity, min: 0, max: 1,
                onChanged: (v) => s.setSubtitleBgOpacity(v), activeColor: cs.primary)),
      ],

      SwitchListTile(
          dense: true,
          title: const Text('تفعيل ظل الأحرف', style: TextStyle(color: Colors.white)),
          value: s.textShadowEnabled,
          onChanged: (v) => s.setTextShadowEnabled(v),
          activeColor: Colors.lightBlue),
      if (s.textShadowEnabled) ...[
        ListTile(
            dense: true,
            title: const Text('لون ظل الأحرف', style: TextStyle(color: Colors.white)),
            trailing: CircleAvatar(backgroundColor: s.textShadowColor, radius: 12),
            onTap: () { Navigator.pop(context); _showColorPicker(context, s.textShadowColor, (c) => s.setTextShadowColor(c)); }),
        ListTile(
            dense: true,
            title: const Text('توهج ظل الأحرف', style: TextStyle(color: Colors.white)),
            subtitle: Slider(
                value: s.textShadowBlurRadius, min: 0, max: 20,
                onChanged: (v) => s.setTextShadowBlurRadius(v), activeColor: cs.primary)),
      ],

      SwitchListTile(
          dense: true,
          title: const Text('تفعيل ظل الصندوق', style: TextStyle(color: Colors.white)),
          value: s.boxShadowEnabled,
          onChanged: (v) => s.setBoxShadowEnabled(v),
          activeColor: Colors.lightBlue),
      if (s.boxShadowEnabled) ...[
        ListTile(
            dense: true,
            title: const Text('لون ظل الصندوق', style: TextStyle(color: Colors.white)),
            trailing: CircleAvatar(backgroundColor: s.boxShadowColor, radius: 12),
            onTap: () { Navigator.pop(context); _showColorPicker(context, s.boxShadowColor, (c) => s.setBoxShadowColor(c)); }),
        ListTile(
            dense: true,
            title: const Text('توهج ظل الصندوق', style: TextStyle(color: Colors.white)),
            subtitle: Slider(
                value: s.boxShadowBlurRadius, min: 0, max: 20,
                onChanged: (v) => s.setBoxShadowBlurRadius(v), activeColor: cs.primary)),
      ],
    ]);
  }

  void _showFontFamilyPicker() {
    final fonts = ['Adobe Arabic', 'Roboto', 'Cairo', 'Amiri', 'Noto Naskh Arabic', 'Courier', 'Monospace'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر نوع الخط'),
        content: SingleChildScrollView(
          child: Column(children: fonts.map((font) => ListTile(
                title: Text(font),
                onTap: () { context.read<SettingsProvider>().setFontFamily(font); Navigator.pop(ctx); },
              )).toList()),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, Color current, Function(Color) onSave) {
    Color tempColor = current;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختيار اللون'),
        content: ColorPicker(color: tempColor, onColorChanged: (c) => tempColor = c),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () { onSave(tempColor); Navigator.pop(context); },
              child: const Text('موافق')),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  FontWeight _getFontWeight(int index) {
    switch (index) {
      case 0: return FontWeight.w300;
      case 1: return FontWeight.normal;
      case 2: return FontWeight.w500;
      case 3: return FontWeight.bold;
      default: return FontWeight.normal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final s = context.watch<SettingsProvider>();

    if (_isPip) return Scaffold(backgroundColor: Colors.black, body: Video(controller: _controller));

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
            onDoubleTapDown: _isLocked ? null : (details) {
              final isRight = details.localPosition.dx > screenWidth / 2;
              final target = isRight
                  ? (_position + const Duration(seconds: 10))
                  : (_position - const Duration(seconds: 10));
              _player.seek(target.isNegative ? Duration.zero : (target > _duration ? _duration : target));
            },
            onScaleStart: _onScaleStart,
            onScaleUpdate: (details) => _onScaleUpdate(details, screenWidth),
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
                  fontStyle: s.subtitleItalic ? FontStyle.italic : FontStyle.normal,
                  backgroundColor: s.subtitleBgColor.withOpacity(s.subtitleBgOpacity),
                  shadows: s.textShadowEnabled
                      ? [Shadow(color: s.textShadowColor, blurRadius: s.textShadowBlurRadius,
                          offset: Offset(s.textShadowOffsetX, s.textShadowOffsetY))]
                      : null,
                ),
                textAlign: s.subtitleRTL ? TextAlign.right : TextAlign.center,
                padding: EdgeInsets.fromLTRB(s.horizontalMargin, 0, s.horizontalMargin, s.bottomPadding),
              ),
            ),
          ),

          if (_fitOverlayText != null)
            Positioned(top: 100, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_fitOverlayText!,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              ))),

          if (_showSeekIndicator)
            Center(
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 200),
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
                      _fmt(Duration(milliseconds: _seekPreviewMs.toInt())),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ]),
                ),
              ),
            ),

          if (_showVolumeIndicator)
            Positioned(
              left: 24,
              top: MediaQuery.of(context).size.height * 0.25,
              child: _buildFloatingIndicator(
                icon: _gestureVolume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                displayValue: _gestureVolume,
                labelText: '${(_gestureVolume * _audioBoost).round()}%',
                color: cs.primary,
              ),
            ),

          if (_showBrightnessIndicator)
            Positioned(
              right: 24,
              top: MediaQuery.of(context).size.height * 0.25,
              child: _buildFloatingIndicator(
                icon: _brightness < 0.15 ? Icons.brightness_low_rounded : Icons.brightness_6_rounded,
                displayValue: _brightness,
                labelText: '${(_brightness * 100).round()}%',
                color: cs.secondary,
              ),
            ),

          if (_isLocked)
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(child: GestureDetector(
                onTap: _toggleLock,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Symbols.lock_rounded, color: Colors.white, size: 22),
                ),
              )),
            ),

          if (_showControls && !_isLocked) ...[

            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  child: Row(children: [
                    IconButton(
                        icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context)),
                    Expanded(child: Text(widget.video.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
                    IconButton(
                        icon: Icon(_isLocked ? Symbols.lock_rounded : Symbols.lock_open_rounded,
                            color: _isLocked ? Colors.orange : Colors.white54),
                        onPressed: _toggleLock),
                    IconButton(
                        icon: const Icon(Symbols.aspect_ratio_rounded, color: Colors.white70),
                        onPressed: _toggleFit,
                        tooltip: 'تغيير وضع الملء'),
                    IconButton(
                        icon: Icon(_isLandscape ? Symbols.screen_rotation_rounded : Symbols.stay_current_portrait_rounded,
                            color: Colors.white70),
                        onPressed: _toggleOrientation),
                    IconButton(
                        icon: const Icon(Symbols.picture_in_picture_rounded, color: Colors.white70),
                        onPressed: _enterPip),
                    IconButton(
                        icon: const Icon(Symbols.graphic_eq_rounded, color: Colors.white70),
                        onPressed: _showAudioMenu),
                    IconButton(
                        icon: Icon(_showSubtitles ? Symbols.subtitles_rounded : Symbols.subtitles_off_rounded,
                            color: _showSubtitles ? Colors.lightBlue : Colors.white54),
                        onPressed: _showSubtitleMenu),
                  ]),
                ),
              ),
            ),

            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Row(children: [
                      Text(_fmt(_position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            activeTrackColor: cs.primary,
                            inactiveTrackColor: Colors.white.withOpacity(0.2),
                            thumbColor: cs.primary,
                            overlayColor: cs.primary.withOpacity(0.2),
                          ),
                          child: Slider(
                            value: _duration.inMilliseconds > 0
                                ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                                : 0.0,
                            onChanged: (v) => _player.seek(
                                Duration(milliseconds: (v * _duration.inMilliseconds).toInt())),
                          ),
                        ),
                      ),
                      Text(_fmt(_duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
            ),

            Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _CtrlBtn(Symbols.replay_10_rounded,
                  () => _player.seek(_position - const Duration(seconds: 10))),
              const SizedBox(width: 28),
              GestureDetector(
                onTap: () => _isPlaying ? _player.pause() : _player.play(),
                child: Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_isPlaying ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
                      color: cs.onPrimaryContainer, size: 38),
                ),
              ),
              const SizedBox(width: 28),
              _CtrlBtn(Symbols.forward_10_rounded,
                  () => _player.seek(_position + const Duration(seconds: 10))),
            ])),

          ],
        ]),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _indicatorTimer?.cancel();
    _fitOverlayTimer?.cancel();
    try { ScreenBrightness.instance.resetApplicationScreenBrightness(); } catch (_) {}
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _player.dispose();
    super.dispose();
  }
}

// ═══════════════ _AudioBoostSection (بدون تغيير) ═══════════════
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
  void initState() { super.initState(); _local = widget.boost; }

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
        const Text('تكبير الصوت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        Text(_boostLabel(_local), style: TextStyle(color: color, fontSize: 11)),
      ]),
      const SizedBox(height: 6),
      AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 36),
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
          tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
          activeTickMarkColor: Colors.white30,
          inactiveTickMarkColor: Colors.white12,
        ),
        child: Slider(value: _local, min: 50, max: 200, divisions: 30,
          onChanged: (v) { setState(() => _local = v); widget.onChanged(v); }),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        for (final val in [100.0, 130.0, 160.0, 200.0])
          _QuickBtn(label: '${val.toInt()}%', active: (_local - val).abs() < 2,
            color: _boostColor(val),
            onTap: () { setState(() => _local = val); widget.onChanged(val); }),
      ]),
      const SizedBox(height: 4),
      Text('الجيستشر (السحب يمين): ${(_local).round()}%',
          style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ]);
  }
}

class _QuickBtn extends StatelessWidget {
  final String label; final bool active; final Color color; final VoidCallback onTap;
  const _QuickBtn({required this.label, required this.active, required this.color, required this.onTap});
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
        child: Text(label, style: TextStyle(color: active ? color : Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _CtrlBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      );
}