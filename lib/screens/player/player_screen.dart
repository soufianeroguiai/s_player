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

  // ── متغيرات جاستر الترجمة (إصبعين) ──
  double _startSubtitleSize = 24.0;
  double _startBottomPadding = 0.0;
  Offset _startFocalPoint = Offset.zero;

  // ── مستوى الصوت/التكبير المدمج (0% إلى 200%)، نفس المصدر المستخدَم
  // من قِبل كلٍ من جاستر السحب العمودي ولوحة "تكبير الصوت" الجانبية،
  // حتى لا يوجد مصدران منفصلان للحقيقة. القيمة الافتراضية الأولى
  // تُؤخذ من Settings.defaultAudioBoost عند فتح الفيديو لأول مرة.
  double _volumeLevel = 1.0;

  bool _initialized = false;
  bool _showControls = true;
  bool _isLocked = false;
  Timer? _hideTimer;
  Timer? _saveTimer;
  Timer? _indicatorTimer;

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

  /// هل جاستر الإصبعين نشط حالياً لتحريك الترجمة/تكبيرها
  bool _subtitleGestureActive = false;

  /// آخر إدخالات SRT الخام (قبل تطبيق إزاحة المزامنة)، تُستخدم لإعادة
  /// بناء الترجمة بسرعة عند تغيير _subtitleSync دون إعادة قراءة الملف.
  List<SubtitleEntry>? _lastSubtitleEntries;

  final ValueNotifier<double> _brightnessNotifier = ValueNotifier(0.7);
  final ValueNotifier<double> _seekMsNotifier = ValueNotifier(0.0);

  final ValueNotifier<bool> _showVolNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showBrightNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showSeekNotifier = ValueNotifier(false);

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
    // قيمة افتراضية أولية من إعدادات تكبير الصوت؛ تُستبدَل بالقيمة
    // المحفوظة محلياً لهذا التشغيل إن وُجدت (انظر _loadPersistedVolumeAndBrightness).
    _volumeLevel = (settings.defaultAudioBoost / 100.0).clamp(0.0, 2.0);

    _loadPersistedVolumeAndBrightness();

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
      // محاولة تحميل ترجمة خارجية مجاورة للفيديو. تُطبَّق هذه بعد
      // محاولة اختيار مسار ترجمة مدمج مفضّل (عبر تدفّق tracks أعلاه)
      // لإعطاء الأولوية للترجمة الداخلية إن وُجدت بنفس اللغة المفضّلة.
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

  /// يطبّق لغة الصوت المفضَّلة من الإعدادات إن وُجد مسار صوتي مطابق
  /// ضمن مسارات الفيديو المتعددة. سابقاً كان هذا الإعداد محفوظاً دون
  /// أي تأثير فعلي على اختيار المسار الصوتي.
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
    final result =
        await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['srt', 'SRT', 'ssa', 'ass']);
    if (result?.files.single.path != null) {
      final settings = context.read<SettingsProvider>();
      await _loadSrtFile(result!.files.single.path!, settings.subtitleEncoding);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying && !_isLocked && _currentMenu == ActiveMenu.none) {
        setState(() => _showControls = false);
      }
    });
  }

  void cancelHideTimer() {
    _hideTimer?.cancel();
  }

  void _toggleControls() {
    if (_isLocked) return;
    if (_currentMenu != ActiveMenu.none) {
      setState(() => _currentMenu = ActiveMenu.none);
      _scheduleHide();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  Future<void> _enterPip() async {
    await PipService.enter();
  }

  void _resetIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 1), () {
      _showVolNotifier.value = false;
      _showBrightNotifier.value = false;
    });
  }

  String? _seekHintText;
  Timer? _seekHintTimer;

  void _showSeekHint(int seconds) {
    setState(() => _seekHintText = seconds > 0 ? '+${seconds}s ⏩' : '${seconds}s ⏪');
    _seekHintTimer?.cancel();
    _seekHintTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekHintText = null);
    });
  }

  void _onVolumeChanged(double newLevel) {
    setState(() {
      _volumeLevel = newLevel.clamp(0.0, 2.0);
      _player.setVolume(_volumeLevel * 100.0);
    });
    _savePersistedVolume();
  }

  /// يطبّق إزاحة مزامنة الترجمة على المشغل. ملاحظة تقنية: نسخة
  /// media_kit المستخدَمة هنا لا توفر دالة موثَّقة لضبط تأخير الترجمة
  /// مباشرة (لا يوجد ما يعادل setSubtitleDelay في الواجهة الرسمية)،
  /// لذا تُطبَّق الإزاحة عملياً بإعادة بناء نص SRT بتوقيت معدَّل
  /// وإعادة تحميله عبر SubtitleTrack.data، وهي واجهة موثَّقة ومضمونة.
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

  // ─── دوال بناء النافذة الجانبية ───
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final s = context.watch<SettingsProvider>();

    // الحالة الحقيقية القادمة من Android (انظر PipService)، وليست
    // قيمة محلية مفترَضة لا تتحدّث أبداً عند الدخول الفعلي في PiP.
    if (PipService.isInPipMode.value) {
      return Scaffold(backgroundColor: Colors.black, body: Video(controller: _controller));
    }

    return PopScope(
      canPop: !_isLocked,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (_currentMenu != ActiveMenu.none) {
            setState(() => _currentMenu = ActiveMenu.none);
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
                // ─── طبقة الجاستر الشاملة ───
                // مقسّمة لثلاث مناطق أفقية:
                //   يسار الشاشة  → سطوع (سحب عمودي)  + تأخير (ضغط مزدوج)
                //   منتصف الشاشة → play/pause (ضغط مزدوج)
                //   يمين الشاشة  → صوت   (سحب عمودي)  + تقديم (ضغط مزدوج)
                // إصبعان في أي مكان → تكبير/تصغير وتحريك الترجمة (عند الإيقاف فقط)
                GestureDetector(
                  onTap: _toggleControls,
                  onDoubleTapDown: _isLocked
                      ? null
                      : (details) {
                          final x = details.localPosition.dx;
                          // ثلث أيسر → تأخير 10 ثواني
                          if (x < screenWidth / 3) {
                            final target = _position - const Duration(seconds: 10);
                            _player.seek(target.isNegative ? Duration.zero : target);
                            _showSeekHint(-10);
                          }
                          // ثلث أيمن → تقديم 10 ثواني
                          else if (x > screenWidth * 2 / 3) {
                            final target = _position + const Duration(seconds: 10);
                            _player.seek(target > _duration ? _duration : target);
                            _showSeekHint(10);
                          }
                          // المنتصف → play / pause
                          else {
                            _isPlaying ? _player.pause() : _player.play();
                          }
                        },
                  onScaleStart: (details) {
                    if (_isLocked) return;
                    if (details.pointerCount == 2) {
                      // إصبعان: تكبير الترجمة + رفعها/خفضها
                      // متاح فقط عند إيقاف الفيديو
                      if (!_isPlaying) {
                        _startSubtitleSize = s.subtitleFontSize;
                        _startBottomPadding = s.bottomPadding;
                        _startFocalPoint = details.focalPoint;
                        _subtitleGestureActive = true;
                      }
                    } else {
                      // إصبع واحد: seek بالسحب الأفقي
                      _seekMsNotifier.value = _position.inMilliseconds.toDouble();
                      _subtitleGestureActive = false;
                    }
                  },
                  onScaleUpdate: (details) {
                    if (_isLocked) return;

                    // ── إصبعان: تكبير/تصغير وتحريك الترجمة ──
                    if (details.pointerCount == 2 && _subtitleGestureActive) {
                      final newSize = (_startSubtitleSize * details.scale).clamp(10.0, 150.0);
                      s.setSubtitleFontSize(newSize);

                      final dy = details.focalPoint.dy - _startFocalPoint.dy;
                      final newPadding = (_startBottomPadding - dy).clamp(0.0, screenHeight * 0.85);
                      s.setBottomPadding(newPadding);
                      return;
                    }

                    // ── إصبع واحد ──
                    if (details.pointerCount != 1) return;
                    if (details.focalPointDelta.distance < 0.5) return;

                    final isRight = details.focalPoint.dx > screenWidth / 2;
                    final dx = details.focalPointDelta.dx.abs();
                    final dy = details.focalPointDelta.dy.abs();
                    final isHorizontal = dx > dy;

                    if (isHorizontal) {
                      // سحب أفقي → seek مرئي
                      final seekFactor = (_duration.inMilliseconds * 0.25)
                          .clamp(30000.0, 600000.0);
                      final change = (details.focalPointDelta.dx / screenWidth) * seekFactor;
                      _seekMsNotifier.value = (_seekMsNotifier.value + change)
                          .clamp(0.0, _duration.inMilliseconds.toDouble());
                      _showSeekNotifier.value = true;
                      _showVolNotifier.value = false;
                      _showBrightNotifier.value = false;
                    } else {
                      // سحب عمودي → صوت (يمين) أو سطوع (يسار)
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
                      _scheduleHide();
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

                // ── شريط مؤشر التمرير (Seek) ──
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

                // ── شريط مؤشر الصوت الذكي ──
                ValueListenableBuilder<bool>(
                  valueListenable: _showVolNotifier,
                  builder: (context, show, child) {
                    if (!show) return const SizedBox.shrink();
                    final bool isBoosted = _volumeLevel > 1.0;
                    return Positioned(
                      left: 24,
                      top: MediaQuery.of(context).size.height * 0.25,
                      child: PlayerIndicators.buildFloatingIndicator(
                        icon: _volumeLevel == 0
                            ? Icons.volume_off_rounded
                            : (isBoosted ? Icons.volume_up_rounded : Icons.volume_down_rounded),
                        displayValue: _volumeLevel / 2.0,
                        labelText: '${(_volumeLevel * 100).round()}%',
                        color: isBoosted ? Colors.orangeAccent : cs.primary,
                      ),
                    );
                  },
                ),

                // ── شريط مؤشر الإضاءة ──
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
                          child: PlayerIndicators.buildFloatingIndicator(
                            icon: brightness < 0.15 ? Icons.brightness_low_rounded : Icons.brightness_6_rounded,
                            displayValue: brightness,
                            labelText: '${(brightness * 100).round()}%',
                            color: cs.secondary,
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

                // تلميح جاستر الإصبعين عند الإيقاف
                if (!_isPlaying && !_subtitleGestureActive && _showControls)
                  Positioned(
                    bottom: 90,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pinch_rounded, color: Colors.white54, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'إصبعان لتعديل الترجمة',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
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
                        decoration:
                            BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(20)),
                        child: Text(_fitOverlayText!,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),

                if (_isLocked)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: SafeArea(
                      child: GestureDetector(
                        onTap: _toggleLock,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.85), shape: BoxShape.circle),
                          child: const Icon(Symbols.lock_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ),

                // ── واجهة أزرار التحكم العلوية والسفلية ──
                if (_showControls && !_isLocked) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: PlayerTopBar(
                      videoName: widget.video.name,
                      onBack: () => Navigator.pop(context),
                      onToggleFit: _toggleFit,
                      onToggleOrientation: _toggleOrientation,
                      onPip: _enterPip,
                      onAudioMenu: () {
                        setState(() {
                          _currentMenu = _currentMenu == ActiveMenu.audio ? ActiveMenu.none : ActiveMenu.audio;
                          if (_currentMenu != ActiveMenu.none) {
                            cancelHideTimer();
                          } else {
                            _scheduleHide();
                          }
                        });
                      },
                      onSubtitleMenu: () {
                        setState(() {
                          _currentMenu =
                              _currentMenu == ActiveMenu.subtitles ? ActiveMenu.none : ActiveMenu.subtitles;
                          if (_currentMenu != ActiveMenu.none) {
                            cancelHideTimer();
                          } else {
                            _scheduleHide();
                          }
                        });
                      },
                      isLandscape: _isLandscape,
                      showSubtitles: _showSubtitles,
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
                    ),
                  ),
                  Center(
                    child: PlayerCenterButtons(
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
                      primaryColor: cs.primaryContainer,
                      onPrimaryContainer: cs.onPrimaryContainer,
                    ),
                  ),
                ],

                // ── النافذة الجانبية ──
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

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
