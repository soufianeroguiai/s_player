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
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../models/video_item.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/subtitle_service.dart';
import '../services/pip_service.dart';
import 'info_screen.dart';

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

  bool _showSubtitles = true;
  List<SubtitleTrack> _subtitleTracks = [];
  List<AudioTrack> _audioTracks = [];
  double _audioBoost = 100.0;

  double _speed = 1.0;
  final _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  double _volume = 0.8;                // 0.0 - 1.0 (للواجهة)
  double _brightness = 0.7;
  double? _originalSystemBrightness;

  String? _dragAxis;
  bool _dragIsLeftSide = false;
  Offset _dragStartGlobal = Offset.zero;
  Duration _dragStartPosition = Duration.zero;
  Duration _seekPreview = Duration.zero;
  bool _showSeekIndicator = false;

  bool _showBrightnessIndicator = false;
  bool _showVolumeIndicator = false;
  Timer? _indicatorTimer;

  bool _isLandscape = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _enterFullscreen();

    final settings = context.read<SettingsProvider>();
    _showSubtitles = settings.showSubtitlesByDefault;
    _speed = settings.defaultSpeed;
    // لا نقرأ من system volume بعد الآن

    _player = Player();
    _controller = VideoController(_player);

    _initPlayer();
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

  Future<void> _initPlayer() async {
    final settings = context.read<SettingsProvider>();

    try {
      await _player.open(Media(widget.video.path), play: settings.autoPlay);
      _player.setRate(_speed);
      _player.setVolume(_volume * 100);   // صوت داخلي (0-100)

      if (settings.rememberPosition) {
        try {
          final saved = await context.read<LibraryProvider>().getPosition(widget.video.path);
          if (saved != null && saved.inSeconds > 0) await _player.seek(saved);
        } catch (_) {}
      }

      _player.stream.position.listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
        if (pos.inSeconds % 5 == 0 && settings.rememberPosition) {
          context.read<LibraryProvider>().savePosition(widget.video.path, pos);
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
      });

      // السطوع: نستخدم ApplicationScreenBrightness (لا يحتاج صلاحيات)
      try {
        _originalSystemBrightness = await ScreenBrightness.instance.system;
        await ScreenBrightness.instance.setApplicationScreenBrightness(_brightness);
      } catch (_) {}

      setState(() => _initialized = true);
      _scheduleHide();

      final srtPath = SubtitleService.findSrt(widget.video.path);
      if (srtPath != null) await _loadSrtFile(srtPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تشغيل الملف: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadSrtFile(String path) async {
    try {
      final content = await File(path).readAsString();
      await _player.setSubtitleTrack(SubtitleTrack.data(content, title: 'ترجمة خارجية'));
      if (mounted) {
        setState(() => _showSubtitles = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تحميل الترجمة الخارجية')),
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

  Future<void> _pickSubtitle() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['srt', 'SRT']);
    if (result?.files.single.path != null) {
      await _loadSrtFile(result!.files.single.path!);
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

  void _onDoubleTapDown(TapDownDetails details) {
    if (_isLocked) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final isRight = details.localPosition.dx > screenWidth / 2;
    final seekAmount = const Duration(seconds: 10);
    if (isRight) {
      final target = _position + seekAmount;
      _player.seek(target > _duration ? _duration : target);
    } else {
      final target = _position - seekAmount;
      _player.seek(target < Duration.zero ? Duration.zero : target);
    }
  }

  // مؤشر عائم زجاجي (صوت/سطوع)
  Widget _buildFloatingIndicator({
    required IconData icon,
    required double value,
    required Color color,
  }) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 52,
        height: 180,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(height: 8),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: -1,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          activeTrackColor: color,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                          overlayColor: color.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: value,
                          onChanged: (v) {},
                          min: 0,
                          max: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(value * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  // ── الإيماءات ────────────────────────────────
  void _onPanStart(DragStartDetails details) {
    if (_isLocked) return;
    _hideTimer?.cancel();
    _indicatorTimer?.cancel();
    _dragAxis = null;
    _dragStartGlobal = details.globalPosition;
    _dragStartPosition = _position;
    _dragIsLeftSide = details.localPosition.dx < MediaQuery.of(context).size.width / 2;
  }

  void _onPanUpdate(DragUpdateDetails details, double screenWidth) {
    if (_isLocked) return;
    final totalDx = details.globalPosition.dx - _dragStartGlobal.dx;
    final totalDy = details.globalPosition.dy - _dragStartGlobal.dy;

    _dragAxis ??= (totalDx.abs() > 12 || totalDy.abs() > 12)
        ? (totalDx.abs() > totalDy.abs() ? 'h' : 'v')
        : null;
    if (_dragAxis == null) return;

    if (_dragAxis == 'h') {
      final seekSeconds = (totalDx / screenWidth) * 90;
      var target = _dragStartPosition + Duration(seconds: seekSeconds.round());
      if (target < Duration.zero) target = Duration.zero;
      if (_duration > Duration.zero && target > _duration) target = _duration;
      setState(() {
        _seekPreview = target;
        _showSeekIndicator = true;
        _showBrightnessIndicator = false;
        _showVolumeIndicator = false;
      });
    } else {
      _handleVerticalGesture(details.delta.dy);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragAxis == 'h') {
      _player.seek(_seekPreview);
      setState(() => _showSeekIndicator = false);
    } else if (_dragAxis == 'v') {
      _indicatorTimer?.cancel();
      _indicatorTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showBrightnessIndicator = false;
            _showVolumeIndicator = false;
          });
        }
      });
    }
    _dragAxis = null;
    _scheduleHide();
  }

  void _handleVerticalGesture(double dy) {
    final delta = -dy / 200;

    if (_dragIsLeftSide) {
      // سطوع التطبيق (لا يؤثر على النظام)
      final newBrightness = (_brightness + delta).clamp(0.0, 1.0);
      try {
        ScreenBrightness.instance.setApplicationScreenBrightness(newBrightness);
        setState(() {
          _brightness = newBrightness;
          _showBrightnessIndicator = true;
          _showVolumeIndicator = false;
        });
      } catch (_) {}
    } else {
      // صوت المشغل الداخلي (0-100)
      final newVolume = (_volume + delta).clamp(0.0, 1.0);
      _player.setVolume(newVolume * 100);
      setState(() {
        _volume = newVolume;
        _showVolumeIndicator = true;
        _showBrightnessIndicator = false;
      });
    }
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showBrightnessIndicator = false;
          _showVolumeIndicator = false;
        });
      }
    });
  }

  void _showSpeedSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(context: context, builder: (_) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Text('سرعة التشغيل', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16))),
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
    ));
  }

  // ── قائمة الترجمة (بدون تكرار وبدون إغلاق المشغل) ──
  Future<void> _showSubtitleMenu() async {
    final cs = Theme.of(context).colorScheme;
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final buttonPosition = RelativeRect.fromLTRB(size.width - 160, 80, size.width - 60, 130);

    // إزالة التكرار باستخدام Set حسب اللغة أو title
    final seen = <String>{};
    final uniqueTracks = <SubtitleTrack>[];
    for (final track in _subtitleTracks) {
      final key = track.title ?? track.language ?? 'unknown';
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueTracks.add(track);
      }
    }

    showMenu<String>(
      context: context,
      position: buttonPosition,
      color: Colors.black87,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(_showSubtitles ? 'إيقاف الترجمة' : 'تشغيل الترجمة', style: const TextStyle(color: Colors.white)),
            value: _showSubtitles,
            onChanged: (v) {
              setState(() => _showSubtitles = v);
              if (!v) _player.setSubtitleTrack(SubtitleTrack.no());
              Navigator.pop(context);
            },
          ),
        ),
        ...uniqueTracks.map((track) {
          String name = track.title ?? track.language ?? 'ترجمة';
          String? lang = track.language;
          return PopupMenuItem<String>(
            value: track.id, // أي قيمة فريدة
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(name, style: const TextStyle(color: Colors.white)),
              subtitle: lang != null ? Text(lang, style: const TextStyle(color: Colors.white54)) : null,
              trailing: _player.state.track.subtitle == track ? Icon(Icons.check, color: cs.primary) : null,
            ),
            onTap: () {
              _player.setSubtitleTrack(track);
              setState(() => _showSubtitles = true);
              // لا نستخدم Navigator.pop هنا، القائمة ستغلق تلقائياً عند الضغط على أيقونة أخرى
              // لكن showMenu لا يغلق إلا إذا استدعينا Navigator.pop، لذلك نستدعيه
              Navigator.pop(context);
            },
          );
        }),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'load',
          child: const ListTile(leading: Icon(Icons.upload, color: Colors.white), title: Text('تحميل ترجمة', style: TextStyle(color: Colors.white))),
          onTap: () {
            Navigator.pop(context);
            _pickSubtitle();
          },
        ),
      ],
    );
  }

  // ── قائمة الصوت (بدون تكرار وبدون إغلاق المشغل) ──
  Future<void> _showAudioMenu() async {
    final cs = Theme.of(context).colorScheme;
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final buttonPosition = RelativeRect.fromLTRB(size.width - 220, 80, size.width - 120, 130);

    // إزالة التكرار
    final seen = <String>{};
    final uniqueAudio = <AudioTrack>[];
    for (final track in _audioTracks) {
      final key = track.title ?? track.language ?? 'unknown';
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueAudio.add(track);
      }
    }

    showMenu<String>(
      context: context,
      position: buttonPosition,
      color: Colors.black87,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        ...uniqueAudio.map((track) {
          String name = track.title ?? track.language ?? 'مسار صوتي';
          String? lang = track.language;
          return PopupMenuItem<String>(
            value: track.id,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(name, style: const TextStyle(color: Colors.white)),
              subtitle: lang != null ? Text(lang, style: const TextStyle(color: Colors.white54)) : null,
              trailing: _player.state.track.audio == track ? Icon(Icons.check, color: cs.primary) : null,
            ),
            onTap: () {
              _player.setAudioTrack(track);
              Navigator.pop(context);
            },
          );
        }),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'boost',
          child: ListTile(
            leading: const Icon(Icons.volume_up, color: Colors.white),
            title: const Text('رفع الصوت (Boost)', style: TextStyle(color: Colors.white)),
            subtitle: Text('${_audioBoost.round()}%', style: const TextStyle(color: Colors.white54)),
          ),
          onTap: () {
            Navigator.pop(context);
            _showAudioBoostSheet();
          },
        ),
      ],
    );
  }

  void _showAudioBoostSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('تكبير الصوت', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
            Slider(
              value: _audioBoost, min: 50, max: 200,
              onChanged: (v) { setSheetState(() {}); setState(() => _audioBoost = v); _player.setVolume(v); },
            ),
          ]),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final settings = context.watch<SettingsProvider>();

    if (_isPip) {
      return Scaffold(backgroundColor: Colors.black, body: Video(controller: _controller));
    }

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
            : Stack(
                children: [
                  GestureDetector(
                    onTap: _toggleControls,
                    onDoubleTapDown: _isLocked ? null : _onDoubleTapDown,
                    onPanStart: _onPanStart,
                    onPanUpdate: (details) => _onPanUpdate(details, screenWidth),
                    onPanEnd: _onPanEnd,
                    child: Video(
                      controller: _controller,
                      controls: NoVideoControls,
                      subtitleViewConfiguration: SubtitleViewConfiguration(
                        style: TextStyle(
                          height: 1.3,
                          fontSize: settings.subtitleFontSize,
                          color: settings.subtitleColor,
                          fontWeight: FontWeight.w600,
                          backgroundColor: Colors.black.withOpacity(settings.subtitleBgOpacity),
                        ),
                        textAlign: TextAlign.center,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
                      ),
                    ),
                  ),

                  if (_showVolumeIndicator)
                    Positioned(
                      right: 24,
                      top: MediaQuery.of(context).size.height * 0.3,
                      child: _buildFloatingIndicator(
                        icon: Icons.volume_up,
                        value: _volume,
                        color: cs.primary,
                      ),
                    ),

                  if (_showBrightnessIndicator)
                    Positioned(
                      left: 24,
                      top: MediaQuery.of(context).size.height * 0.3,
                      child: _buildFloatingIndicator(
                        icon: Icons.brightness_6,
                        value: _brightness,
                        color: cs.secondary,
                      ),
                    ),

                  if (_showSeekIndicator)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            _seekPreview >= _position ? Symbols.fast_forward_rounded : Symbols.fast_rewind_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _fmt(_seekPreview),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ]),
                      ),
                    ),

                  if (_isLocked)
                    const Center(child: Icon(Icons.lock_outline, color: Colors.white38, size: 48)),

                  if (_showControls && !_isLocked) ...[
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Container(
                        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])),
                        child: SafeArea(
                          child: Row(children: [
                            IconButton(icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                            Expanded(child: Text(widget.video.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
                            IconButton(icon: Icon(_isLocked ? Symbols.lock_rounded : Symbols.lock_open_rounded, color: _isLocked ? Colors.orange : Colors.white54), onPressed: _toggleLock),
                            IconButton(icon: Icon(_isLandscape ? Symbols.screen_rotation_rounded : Symbols.stay_current_portrait_rounded, color: Colors.white70), onPressed: _toggleOrientation),
                            IconButton(icon: const Icon(Symbols.picture_in_picture_rounded, color: Colors.white70), onPressed: _enterPip),
                            IconButton(icon: const Icon(Symbols.graphic_eq_rounded, color: Colors.white70), onPressed: _showAudioMenu),
                            IconButton(icon: Icon(_showSubtitles ? Symbols.subtitles_rounded : Symbols.subtitles_off_rounded, color: _showSubtitles ? Colors.lightBlue : Colors.white54), onPressed: _showSubtitleMenu),
                          ]),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.85), Colors.transparent])),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Row(children: [
                              Text(_fmt(_position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), activeTrackColor: cs.primary, inactiveTrackColor: Colors.white24, thumbColor: cs.primary, overlayColor: cs.primary.withOpacity(0.2)),
                                  child: Slider(
                                    value: _duration.inMilliseconds > 0 ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0) : 0.0,
                                    onChanged: (v) => _player.seek(Duration(milliseconds: (v * _duration.inMilliseconds).toInt())),
                                  ),
                                ),
                              ),
                              Text(_fmt(_duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _CtrlBtn(Symbols.replay_10_rounded, () => _player.seek(_position - const Duration(seconds: 10))),
                        const SizedBox(width: 28),
                        GestureDetector(
                          onTap: () => _isPlaying ? _player.pause() : _player.play(),
                          child: Container(
                            width: 68, height: 68,
                            decoration: BoxDecoration(color: cs.primaryContainer.withOpacity(0.9), shape: BoxShape.circle),
                            child: Icon(_isPlaying ? Symbols.pause_rounded : Symbols.play_arrow_rounded, color: cs.onPrimaryContainer, size: 38),
                          ),
                        ),
                        const SizedBox(width: 28),
                        _CtrlBtn(Symbols.forward_10_rounded, () => _player.seek(_position + const Duration(seconds: 10))),
                      ]),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _indicatorTimer?.cancel();
    if (_originalSystemBrightness != null) {
      try {
        ScreenBrightness.instance.setSystemScreenBrightness(_originalSystemBrightness!);
      } catch (_) {}
    }
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _player.dispose();
    super.dispose();
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CtrlBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}