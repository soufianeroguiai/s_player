import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pip_flutter/pip_flutter.dart';

import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../models/video_item.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/subtitle_service.dart';
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
  Timer? _hideTimer;

  // Subtitle
  List<SubtitleEntry> _subtitles = [];
  SubtitleEntry? _currentSub;
  bool _showSubtitles = true;
  Timer? _subTimer;

  // Speed
  double _speed = 1.0;
  final _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  // Progress
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _enterFullscreen();

    final settings = context.read<SettingsProvider>();
    _showSubtitles = settings.showSubtitlesByDefault;
    _speed = settings.defaultSpeed;

    _player = Player();
    _controller = VideoController(_player);

    _initPlayer();
  }

  void _enterFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _initPlayer() async {
    final settings = context.read<SettingsProvider>();

    // تحميل الفيديو
    await _player.open(Media(widget.video.path), play: settings.autoPlay);
    _player.setRate(_speed);

    // استعادة الموضع المحفوظ
    if (settings.rememberPosition) {
      final saved = await context.read<LibraryProvider>().getPosition(widget.video.path);
      if (saved != null && saved.inSeconds > 0) {
        await _player.seek(saved);
      }
    }

    // Listeners
    _player.stream.position.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
      // حفظ الموضع كل 5 ثواني
      if (pos.inSeconds % 5 == 0 && settings.rememberPosition) {
        context.read<LibraryProvider>().savePosition(widget.video.path, pos);
      }
      // تحديث الترجمة
      _updateSubtitle(pos);
    });

    _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    setState(() => _initialized = true);
    _scheduleHide();

    // Auto-load SRT
    final srtPath = SubtitleService.findSrt(widget.video.path);
    if (srtPath != null) await _loadSrtFile(srtPath);
  }

  void _updateSubtitle(Duration pos) {
    if (_subtitles.isEmpty) return;
    SubtitleEntry? found;
    for (final s in _subtitles) {
      if (pos >= s.start && pos <= s.end) { found = s; break; }
    }
    if (found != _currentSub) setState(() => _currentSub = found);
  }

  Future<void> _loadSrtFile(String path) async {
    final subs = await SubtitleService.load(path);
    setState(() => _subtitles = subs);
    if (mounted && subs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ تم تحميل ${subs.length} سطر ترجمة'),
      ));
    }
  }

  Future<void> _pickSubtitle() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'SRT'],
    );
    if (result?.files.single.path != null) {
      await _loadSrtFile(result!.files.single.path!);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  // ── PiP ───────────────────────────────────────────────────────────
  Future<void> _enterPip() async {
    try {
      await PipFlutter.enterPictureInPictureMode();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      // عند الخروج → ندخل PiP تلقائياً
      _enterPip();
    }
  }

  void _showSpeedSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(context: context, builder: (_) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Text('سرعة التشغيل', style: TextStyle(
              color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16))),
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

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isPip) {
      // في وضع PiP نعرض فقط الفيديو
      return Scaffold(
        backgroundColor: Colors.black,
        body: Video(controller: _controller),
      );
    }

    return PopScope(
      // عند الضغط على Back → ندخل PiP بدل الإغلاق
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _enterPip();
        }
      },
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: !_initialized
            ? Center(child: CircularProgressIndicator(color: cs.primary))
            : GestureDetector(
                onTap: _toggleControls,
                child: Stack(children: [
                  // ── الفيديو ──────────────────────────────────────
                  Video(
                    controller: _controller,
                    controls: NoVideoControls, // نستخدم controls مخصصة
                  ),

                  // ── الترجمة ──────────────────────────────────────
                  if (_showSubtitles && _currentSub != null)
                    Positioned(
                      bottom: 72, left: 20, right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _currentSub!.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 17, height: 1.4,
                            shadows: [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black)],
                          ),
                        ),
                      ),
                    ),

                  // ── Controls ─────────────────────────────────────
                  if (_showControls) ...[
                    // Top bar
                    _TopBar(
                      name: widget.video.name,
                      speed: _speed,
                      subtitlesOn: _showSubtitles,
                      onBack: () => Navigator.pop(context),
                      onPip: _enterPip,
                      onSpeed: _showSpeedSheet,
                      onSubToggle: () => setState(() => _showSubtitles = !_showSubtitles),
                      onSubLoad: _pickSubtitle,
                      onInfo: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => InfoScreen(video: widget.video))),
                    ),

                    // Center controls
                    Center(child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CtrlBtn(Symbols.replay_10_rounded, () => _player.seek(_position - const Duration(seconds: 10))),
                        const SizedBox(width: 28),
                        GestureDetector(
                          onTap: () => _isPlaying ? _player.pause() : _player.play(),
                          child: Container(
                            width: 68, height: 68,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
                              color: cs.onPrimaryContainer, size: 38,
                            ),
                          ),
                        ),
                        const SizedBox(width: 28),
                        _CtrlBtn(Symbols.forward_10_rounded, () => _player.seek(_position + const Duration(seconds: 10))),
                      ],
                    )),

                    // Bottom bar
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
                              Text(_fmt(_position),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    activeTrackColor: cs.primary,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: cs.primary,
                                    overlayColor: cs.primary.withOpacity(0.2),
                                  ),
                                  child: Slider(
                                    value: _duration.inMilliseconds > 0
                                        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                                        : 0.0,
                                    onChanged: (v) => _player.seek(
                                      Duration(milliseconds: (v * _duration.inMilliseconds).toInt()),
                                    ),
                                  ),
                                ),
                              ),
                              Text(_fmt(_duration),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _subTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _player.dispose();
    super.dispose();
  }
}

// ── Widgets مساعدة ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String name;
  final double speed;
  final bool subtitlesOn;
  final VoidCallback onBack, onPip, onSpeed, onSubToggle, onSubLoad, onInfo;

  const _TopBar({
    required this.name, required this.speed, required this.subtitlesOn,
    required this.onBack, required this.onPip, required this.onSpeed,
    required this.onSubToggle, required this.onSubLoad, required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
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
              onPressed: onBack,
            ),
            Expanded(
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            // PiP button
            IconButton(
              icon: const Icon(Symbols.picture_in_picture_rounded, color: Colors.white70),
              onPressed: onPip,
              tooltip: 'نافذة عائمة',
            ),
            // Speed
            GestureDetector(
              onTap: onSpeed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${speed}x', style: TextStyle(
                    color: cs.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 4),
            // Subtitle toggle
            IconButton(
              icon: Icon(
                subtitlesOn ? Symbols.subtitles_rounded : Symbols.subtitles_off_rounded,
                color: subtitlesOn ? Colors.lightBlue : Colors.white54,
              ),
              onPressed: onSubToggle,
            ),
            // Load subtitle
            IconButton(
              icon: const Icon(Symbols.upload_file_rounded, color: Colors.white54),
              onPressed: onSubLoad,
              tooltip: 'تحميل ترجمة SRT',
            ),
            // Info
            IconButton(
              icon: const Icon(Symbols.info_rounded, color: Colors.white54),
              onPressed: onInfo,
            ),
          ]),
        ),
      ),
    );
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
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
