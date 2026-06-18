import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
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

  double _volume = 0.8;
  double _brightness = 0.7;

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

      try {
        _volume = await VolumeController.instance.getVolume();
      } catch (_) {
        _volume = 0.8;
      }
      VolumeController.instance.addListener((vol) {
        if (mounted) setState(() => _volume = vol);
      });

      // تعديل السطوع على مستوى التطبيق بدلاً من النظام لتفادي أخطاء الصلاحيات
      try {
        await ScreenBrightness.instance.setScreenBrightness(_brightness);
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
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['srt', 'SRT']);
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

  Widget _buildFloatingIndicator({required IconData icon, required double value, required Color color}) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 52,
        height: 180,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)]),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(height: 8),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: SliderTheme(
                      data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          activeTrackColor: color, inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white, overlayColor: color.withOpacity(0.2)),
                      child: Slider(value: value, onChanged: (v) {}, min: 0, max: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${(value * 100).round()}%', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

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
        ? (totalDx.abs() > totalDy.abs() ? 'h' : 'v') : null;
    if (_dragAxis == null) return;

    if (_dragAxis == 'h') {
      final seekSeconds = (totalDx / screenWidth) * 90;
      var target = _dragStartPosition + Duration(seconds: seekSeconds.round());
      if (target < Duration.zero) target = Duration.zero;
      if (_duration > Duration.zero && target > _duration) target = _duration;
      setState(() { _seekPreview = target; _showSeekIndicator = true; _showBrightnessIndicator = false; _showVolumeIndicator = false; });
    } else {
      _handleVerticalGesture(details.delta.dy);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragAxis == 'h') { _player.seek(_seekPreview); setState(() => _showSeekIndicator = false); }
    else if (_dragAxis == 'v') {
      _resetIndicatorTimer();
    }
    _dragAxis = null;
    _scheduleHide();
  }

  void _handleVerticalGesture(double dy) {
    final delta = -dy / 200;
    if (_dragIsLeftSide) {
      final newBrightness = (_brightness + delta).clamp(0.0, 1.0);
      try { 
        ScreenBrightness.instance.setScreenBrightness(newBrightness); 
        setState(() { _brightness = newBrightness; _showBrightnessIndicator = true; _showVolumeIndicator = false; }); 
      } catch (_) {}
    } else {
      final newVolume = (_volume + delta).clamp(0.0, 1.0);
      // 🔥 تعديل: إخفاء بار صوت النظام عند السحب على الشاشة
      VolumeController.instance.setVolume(newVolume, showSystemUI: false);
      setState(() { _volume = newVolume; _showVolumeIndicator = true; _showBrightnessIndicator = false; });
    }
    _resetIndicatorTimer();
  }

  void _resetIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 1), () => setState(() { _showBrightnessIndicator = false; _showVolumeIndicator = false; }));
  }

  void _showSpeedSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(context: context, builder: (_) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 12), child: Text('سرعة التشغيل', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16))),
        const Divider(height: 1),
        ..._speeds.map((sp) => ListTile(title: Text('${sp}x'), trailing: _speed == sp ? Icon(Symbols.check_rounded, color: cs.primary) : null, selected: _speed == sp, onTap: () { setState(() => _speed = sp); _player.setRate(sp); Navigator.pop(context); })),
      ]),
    ));
  }

  Future<void> _showSubtitleMenu() async {
    final cs = Theme.of(context).colorScheme;
    final seen = <String>{}; 
    final uniqueTracks = <SubtitleTrack>[];
    for (final t in _subtitleTracks) {
      final k = t.title ?? t.language ?? 'unknown';
      if (!seen.contains(k)) { seen.add(k); uniqueTracks.add(t); }
    }

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final buttonPosition = RelativeRect.fromLTRB(size.width - 160, 80, size.width - 60, 130);

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
            activeColor: Colors.lightBlue,
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
          return PopupMenuItem<String>(
            value: track.id,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(name, style: const TextStyle(color: Colors.white)),
              subtitle: track.language != null ? Text(track.language!, style: const TextStyle(color: Colors.white54)) : null,
              trailing: _player.state.track.subtitle == track ? Icon(Icons.check, color: cs.primary) : null,
            ),
            onTap: () {
              _player.setSubtitleTrack(track);
              setState(() => _showSubtitles = true);
              // 🔥 تم حذف Navigator.pop لقفل القائمة بشكل طبيعي دون إغلاق الفيديو
            },
          );
        }),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'load',
          child: const ListTile(leading: Icon(Icons.upload, color: Colors.white), title: Text('تحميل ترجمة', style: TextStyle(color: Colors.white))),
          onTap: () {
            Navigator.pop(context); // هنا مسموح للإغلاق لفتح منتقي الملفات
            _pickSubtitle();
          },
        ),
      ],
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

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final buttonPosition = RelativeRect.fromLTRB(size.width - 220, 80, size.width - 120, 130);

    showMenu<String>(
      context: context,
      position: buttonPosition,
      color: Colors.black87,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        ...uniqueAudio.map((track) {
          String name = track.title ?? track.language ?? 'مسار صوتي';
          return PopupMenuItem<String>(
            value: track.id,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(name, style: const TextStyle(color: Colors.white)),
              subtitle: track.language != null ? Text(track.language!, style: const TextStyle(color: Colors.white54)) : null,
              trailing: _player.state.track.audio == track ? Icon(Icons.check, color: cs.primary) : null,
            ),
            onTap: () {
              _player.setAudioTrack(track);
              // 🔥 تم حذف Navigator.pop لمنع إغلاق الشاشة بالخطأ
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
    showModalBottomSheet(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setSheetState) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('تكبير الصوت', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
        Slider(value: _audioBoost, min: 50, max: 200, onChanged: (v) { 
          setSheetState(() {}); 
          setState(() => _audioBoost = v); 
          // 🔥 تعديل: تحويل الصوت لنسبة مئوية وإخفاء واجهة النظام
          VolumeController.instance.setVolume(v / 100, showSystemUI: false); 
        }),
      ]),
    )));
  }

  void _showSubtitleSettingsSheet() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final buttonPosition = RelativeRect.fromLTRB(size.width - 100, 80, size.width - 20, 130);

    showMenu<String>(
      context: context,
      position: buttonPosition,
      color: Colors.black87,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 350, maxWidth: 250),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [_buildSettingsContent()]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsContent() {
    final s = context.watch<SettingsProvider>();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('إعدادات الترجمة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const Divider(color: Colors.white24),
        ListTile(dense: true, title: const Text('حجم الخط', style: TextStyle(color: Colors.white)), subtitle: Slider(value: s.subtitleFontSize, min: 10, max: 50, onChanged: (v) => s.setSubtitleFontSize(v), activeColor: Theme.of(context).colorScheme.primary)),
        ListTile(dense: true, title: const Text('لون النص', style: TextStyle(color: Colors.white)), trailing: CircleAvatar(backgroundColor: s.subtitleColor, radius: 12), onTap: () { Navigator.pop(context); _showColorPicker(context, s.subtitleColor, (c) => s.setSubtitleColor(c)); }),
        ListTile(dense: true, title: const Text('لون الخلفية', style: TextStyle(color: Colors.white)), trailing: CircleAvatar(backgroundColor: s.subtitleBgColor, radius: 12), onTap: () { Navigator.pop(context); _showColorPicker(context, s.subtitleBgColor, (c) => s.setSubtitleBgColor(c)); }),
        ListTile(dense: true, title: const Text('شفافية الخلفية', style: TextStyle(color: Colors.white)), subtitle: Slider(value: s.subtitleBgOpacity, min: 0, max: 1, onChanged: (v) => s.setSubtitleBgOpacity(v), activeColor: Theme.of(context).colorScheme.primary)),
        SwitchListTile(dense: true, title: const Text('تفعيل الظل', style: TextStyle(color: Colors.white)), value: s.shadowEnabled, onChanged: (v) => s.setShadowEnabled(v), activeColor: Colors.lightBlue),
        if (s.shadowEnabled) ...[
          ListTile(dense: true, title: const Text('لون الظل', style: TextStyle(color: Colors.white)), trailing: CircleAvatar(backgroundColor: s.shadowColor, radius: 12), onTap: () { Navigator.pop(context); _showColorPicker(context, s.shadowColor, (c) => s.setShadowColor(c)); }),
          ListTile(dense: true, title: const Text('توهج الظل', style: TextStyle(color: Colors.white)), subtitle: Slider(value: s.shadowBlurRadius, min: 0, max: 20, onChanged: (v) => s.setShadowBlurRadius(v), activeColor: Theme.of(context).colorScheme.primary)),
        ],
      ]),
    );
  }

  void _showColorPicker(BuildContext context, Color current, Function(Color) onSave) {
    Color tempColor = current;
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('اختيار اللون'),
      content: ColorPicker(color: tempColor, onColorChanged: (c) => tempColor = c),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), ElevatedButton(onPressed: () { onSave(tempColor); Navigator.pop(context); }, child: const Text('موافق'))],
    ));
  }

  String _fmt(Duration d) {
    final h = d.inHours; final m = d.inMinutes.remainder(60).toString().padLeft(2, '0'); final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final s = context.watch<SettingsProvider>();

    if (_isPip) return Scaffold(backgroundColor: Colors.black, body: Video(controller: _controller));

    // 🔥 تعديل: تغليف الواجهة بـ KeyboardListener لـ صامت التقاط نقرات أزرار الهاتف الجانبية وحجب البار المزعج
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
            final newVolume = (_volume + 0.05).clamp(0.0, 1.0);
            VolumeController.instance.setVolume(newVolume, showSystemUI: false);
            setState(() { _volume = newVolume; _showVolumeIndicator = true; _showBrightnessIndicator = false; });
            _resetIndicatorTimer();
          } else if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
            final newVolume = (_volume - 0.05).clamp(0.0, 1.0);
            VolumeController.instance.setVolume(newVolume, showSystemUI: false);
            setState(() { _volume = newVolume; _showVolumeIndicator = true; _showBrightnessIndicator = false; });
            _resetIndicatorTimer();
          }
        }
      },
      child: PopScope(
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
            onDoubleTapDown: _isLocked ? null : _onDoubleTapDown, 
            onPanStart: _onPanStart, 
            onPanUpdate: (d) => _onPanUpdate(d, screenWidth), 
            onPanEnd: _onPanEnd, 
            child: Video(
              controller: _controller, 
              controls: NoVideoControls,
              subtitleViewConfiguration: SubtitleViewConfiguration(
                style: TextStyle(fontSize: s.subtitleFontSize, color: s.subtitleColor, fontWeight: FontWeight.normal, backgroundColor: s.subtitleBgColor.withOpacity(s.subtitleBgOpacity)), 
                textAlign: TextAlign.center, 
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 56)
              ),
            )
          ),
          if (_showVolumeIndicator) Positioned(right: 24, top: MediaQuery.of(context).size.height * 0.3, child: _buildFloatingIndicator(icon: Icons.volume_up, value: _volume, color: cs.primary)),
          if (_showBrightnessIndicator) Positioned(left: 24, top: MediaQuery.of(context).size.height * 0.3, child: _buildFloatingIndicator(icon: Icons.brightness_6, value: _brightness, color: cs.secondary)),
          if (_showControls && !_isLocked) ...[
            Positioned(top: 0, left: 0, right: 0, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])), child: SafeArea(child: Row(children: [
              IconButton(icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
              Expanded(child: Text(widget.video.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
              IconButton(icon: Icon(_isLocked ? Symbols.lock_rounded : Symbols.lock_open_rounded, color: _isLocked ? Colors.orange : Colors.white54), onPressed: _toggleLock),
              IconButton(icon: Icon(_isLandscape ? Symbols.screen_rotation_rounded : Symbols.stay_current_portrait_rounded, color: Colors.white70), onPressed: _toggleOrientation),
              IconButton(icon: const Icon(Symbols.picture_in_picture_rounded, color: Colors.white70), onPressed: _enterPip),
              IconButton(icon: const Icon(Symbols.graphic_eq_rounded, color: Colors.white70), onPressed: _showAudioMenu),
              IconButton(icon: Icon(_showSubtitles ? Symbols.subtitles_rounded : Symbols.subtitles_off_rounded, color: _showSubtitles ? Colors.lightBlue : Colors.white54), onPressed: _showSubtitleMenu),
              IconButton(icon: const Icon(Icons.subtitles, color: Colors.white70), onPressed: _showSubtitleSettingsSheet),
            ])))),
            Positioned(bottom: 0, left: 0, right: 0, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.85), Colors.transparent])), child: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: Row(children: [
              Text(_fmt(_position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(child: SliderTheme(data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), activeTrackColor: cs.primary, inactiveTrackColor: Colors.white24, thumbColor: cs.primary, overlayColor: cs.primary.withOpacity(0.2)), child: Slider(value: _duration.inMilliseconds > 0 ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0) : 0.0, onChanged: (v) => _player.seek(Duration(milliseconds: (v * _duration.inMilliseconds).toInt()))))),
              Text(_fmt(_duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]))))),
            Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _CtrlBtn(Symbols.replay_10_rounded, () => _player.seek(_position - const Duration(seconds: 10))),
              const SizedBox(width: 28),
              GestureDetector(onTap: () => _isPlaying ? _player.pause() : _player.play(), child: Container(width: 68, height: 68, decoration: BoxDecoration(color: cs.primaryContainer.withOpacity(0.9), shape: BoxShape.circle), child: Icon(_isPlaying ? Symbols.pause_rounded : Symbols.play_arrow_rounded, color: cs.onPrimaryContainer, size: 38))),
              const SizedBox(width: 28),
              _CtrlBtn(Symbols.forward_10_rounded, () => _player.seek(_position + const Duration(seconds: 10))),
            ])),
          ],
        ]))
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _indicatorTimer?.cancel();
    VolumeController.instance.removeListener();
    // 🔥 إعادة ضبط سطوع الشاشة لـ الوضع الطبيعي عند الخروج بصيغة آمنة
    try { ScreenBrightness.instance.resetScreenBrightness(); } catch (_) {}
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _player.dispose();
    super.dispose();
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _CtrlBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 28)));
}
