import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/video_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/pip_service.dart';
import '../../services/subtitle_service.dart';
import '../../services/player_control_service.dart';
import '../../widgets/color_adjustment_panel.dart';
import '../../widgets/video_thumbnail_loader.dart';
import '../../services/smart_enhance_service.dart';
import '../info_screen.dart';
import 'player_controls.dart';
import 'player_audio_panel.dart';
import 'player_subtitle_panel.dart';
import 'player_settings_panel.dart';
import 'player_fit_mode.dart';
import 'player_gesture_layer.dart';
import 'subtitle_style_builder.dart';
import 'player_state.dart';

class PlayerScreen extends StatefulWidget {
  final VideoItem video;
  const PlayerScreen({super.key, required this.video});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _controller;
  late final PlayerUIState _state;
  late final PlayerControlService _service;
  late final LibraryProvider _libraryProvider;
  late final SettingsProvider _settingsProvider;

  Timer? _hideTimer;
  Timer? _saveTimer;
  Timer? _fitOverlayTimer;
  Timer? _sleepTimer;
  int? _sleepMinutes;
  bool _showPlaylistEditor = false;
  final Set<String> _hiddenFromSession = {};
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;

  final ValueNotifier<double> _brightnessNotifier = ValueNotifier(0.7);
  final ValueNotifier<double> _seekMsNotifier = ValueNotifier(0.0);

  static const double _lockBtnSize = 44.0;
  static const double _lockTrackWidth = 220.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    PipService.isInPipMode.addListener(_onPipModeChanged);

    _state = PlayerUIState();
    _player = Player();
    _controller = VideoController(_player);

    _libraryProvider = context.read<LibraryProvider>();
    _settingsProvider = context.read<SettingsProvider>();
    _service = PlayerControlService(
      player: _player,
      state: _state,
      video: widget.video,
      libraryProvider: _libraryProvider,
      settingsProvider: _settingsProvider,
      context: context,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setOrientations();
    });

    _enterFullscreen();
    _initAll();
  }

  Future<void> _initAll() async {
    await _service.initSharedPrefs();
    final bright = (await SharedPreferences.getInstance()).getDouble('player_brightness') ?? 0.7;
    _brightnessNotifier.value = bright.clamp(0.1, 1.0);
    _state.fitMode = await VideoFitSettings.load();
    _enableSmartRotation();
    await _service.initPlayer();
    _state.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _onPipModeChanged() => setState(() {});

  void _enableSmartRotation() {
    _sensorSubscription = accelerometerEventStream().listen((event) {
      if (!mounted || _state.isLocked) return;
      if (event.x > 6.0) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
      } else if (event.x < -6.0) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight]);
      }
    });
  }

  void _enterFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _setOrientations() {}

  void _showLockMessage() {
    if (!mounted) return;
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 80,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('تم قفل الشاشة', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry?.remove();
    });
  }

  void _toggleLock() {
    _state.isLocked = !_state.isLocked;
    if (_state.isLocked) {
      _showLockMessage();
      _state.showControls = false;
      _state.currentMenu = ActiveMenu.none;
      _state.showQuickActions = false;
      _state.showLockHint = false;
      _state.lockIconOffset = 0.0;
    }
    _state.notifyListeners();
  }

  void _toggleFit() {
    _state.fitMode = VideoFitMode.values[(_state.fitMode.index + 1) % VideoFitMode.values.length];
    _state.fitOverlayText = modeName(_state.fitMode);
    _fitOverlayTimer?.cancel();
    _fitOverlayTimer = Timer(const Duration(milliseconds: 1200), () {
      _state.fitOverlayText = null;
      _state.notifyListeners();
    });
    _state.notifyListeners();
    VideoFitSettings.save(_state.fitMode);
  }

  void _toggleControls() {
    if (_state.isLocked) {
      _state.showLockHint = true;
      _state.lockIconOffset = 0.0;
      _state.notifyListeners();
      return;
    }
    if (_state.currentMenu != ActiveMenu.none || _state.showQuickActions) {
      _state.resetMenu();
      _service.scheduleHide();
      return;
    }
    _state.showControls = !_state.showControls;
    _state.notifyListeners();
    if (_state.showControls) _service.scheduleHide();
  }

  void openPlaylistEditor() {
    setState(() {
      _showPlaylistEditor = true;
    });
  }

  Future<void> _loadSubtitleFromAdjacentFile() async {
    if (_state.autoSubtitleSelected && _state.showSubtitles) return;
    final srtPath = SubtitleService.findSrt(widget.video.path);
    if (srtPath != null) {
      await _loadSrtFile(srtPath, _settingsProvider.subtitleEncoding, silent: true);
      _state.hasExternalSubtitle = true;
      _state.notifyListeners();
    }
  }

  Future<void> _loadSrtFile(String path, String encoding, {bool silent = false}) async {
    try {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      final entries = await SubtitleService.load(path, encodingName: encoding);
      if (entries.isEmpty) return;
      _state.lastSubtitleEntries = entries;
      await _applySubtitleSyncOffset();
      _state.hasExternalSubtitle = true;
      _state.showSubtitles = true;
      _state.notifyListeners();
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تحميل الترجمة')));
      }
    } catch (e) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحميل الترجمة: $e')));
      }
    }
  }

  Future<void> _pickSubtitle() async {
    final result = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['srt', 'SRT', 'ssa', 'ass']);
    if (result?.files.single.path != null) {
      await _loadSrtFile(result!.files.single.path!, _settingsProvider.subtitleEncoding);
    }
  }

  void _removeExternalSubtitle() {
    _state.hasExternalSubtitle = false;
    _state.lastSubtitleEntries = null;
    _player.setSubtitleTrack(SubtitleTrack.no());
    if (_state.subtitleTracks.isNotEmpty) {
      _player.setSubtitleTrack(_state.subtitleTracks.first);
    }
    _state.notifyListeners();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إزالة الترجمة الخارجية')));
  }

  Future<void> _applySubtitleSyncOffset() async {
    final entries = _state.lastSubtitleEntries;
    if (entries == null || entries.isEmpty) return;
    final offset = Duration(milliseconds: (_state.subtitleSync * 1000).round());
    final srtContent = StringBuffer();
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i] as SubtitleEntry;
      final start = e.start + offset;
      final end = e.end + offset;
      if (end.isNegative) continue;
      srtContent.writeln('${i + 1}');
      srtContent.writeln('${_formatSrtTime(start.isNegative ? Duration.zero : start)} --> ${_formatSrtTime(end)}');
      srtContent.writeln(e.text);
      srtContent.writeln();
    }
    await _player.setSubtitleTrack(SubtitleTrack.data(srtContent.toString(), title: 'ترجمة خارجية'));
  }

  String _formatSrtTime(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds.remainder(1000)).toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }

  void _onSubtitleSyncChanged(double v) {
    _state.subtitleSync = v;
    _state.notifyListeners();
    _settingsProvider.setDefaultSubtitleSync(v);
    if (_state.lastSubtitleEntries != null) _applySubtitleSyncOffset();
  }

  void _startFromBeginning() {
    _libraryProvider.clearPosition(widget.video.path);
    _player.seek(Duration.zero);
    _player.play();
    _state.showResumeDialog = false;
    _state.notifyListeners();
    _service.scheduleHide();
  }

  void _showColorAdjustment() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'تنسيق الألوان',
      barrierColor: Colors.transparent,
      pageBuilder: (context, anim1, anim2) => Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80, right: 20),
          child: SizedBox(
            width: 320,
            child: ColorAdjustmentPanel(
              brightness: _state.brightness,
              contrast: _state.contrast,
              saturation: _state.saturation,
              hue: _state.hue,
              gamma: _state.gamma,
              onChanged: (type, value) {
                switch (type) {
                  case 'brightness': _state.brightness = value; break;
                  case 'contrast': _state.contrast = value; break;
                  case 'saturation': _state.saturation = value; break;
                  case 'hue': _state.hue = value; break;
                  case 'gamma': _state.gamma = value; break;
                }
                _state.notifyListeners();
                _service.applyColorSetting(type, value);
              },
              onReset: () => _service.resetColorSettings(),
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }

  void _showSpeedPicker() {
    final controller = TextEditingController(text: _state.speed.toStringAsFixed(2));
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'سرعة التشغيل',
      barrierColor: Colors.transparent,
      pageBuilder: (context, anim1, anim2) => Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80, right: 20),
          child: SizedBox(
            width: 320,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                ),
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(context)),
                            const Text('سرعة التشغيل', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                              onPressed: () {
                                _service.setSpeed(1.0);
                                controller.text = '1.00';
                                setDialogState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('السرعة', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: Theme.of(context).colorScheme.primary,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Theme.of(context).colorScheme.primary,
                                ),
                                child: Slider(
                                  value: _state.speed.clamp(0.25, 4.0),
                                  min: 0.25,
                                  max: 4.0,
                                  divisions: 15,
                                  onChanged: (v) {
                                    _service.setSpeed(v);
                                    controller.text = v.toStringAsFixed(2);
                                    setDialogState(() {});
                                  },
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              child: Text('${_state.speed}x', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text('مخصص', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: controller,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                                ),
                                onSubmitted: (val) {
                                  final sp = double.tryParse(val);
                                  if (sp != null && sp >= 0.25 && sp <= 4.0) {
                                    _service.setSpeed(sp);
                                    setDialogState(() {});
                                  }
                                },
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () {
                                final sp = double.tryParse(controller.text);
                                if (sp != null && sp >= 0.25 && sp <= 4.0) {
                                  _service.setSpeed(sp);
                                  setDialogState(() {});
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                              child: const Text('تطبيق'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTimerPicker() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'مؤقت النوم',
      barrierColor: Colors.transparent,
      pageBuilder: (context, anim1, anim2) => Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80, right: 20),
          child: SizedBox(
            width: 320,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                ),
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    final controller = TextEditingController(text: _sleepMinutes != null ? '$_sleepMinutes' : '');
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(context)),
                            const Text('مؤقت النوم', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                              onPressed: () {
                                _sleepTimer?.cancel();
                                _sleepTimer = null;
                                _sleepMinutes = null;
                                setDialogState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('اختر الوقت (دقائق)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [15, 30, 45, 60, 90, 120].map((mins) => ChoiceChip(
                            label: Text('$mins'),
                            selected: _sleepMinutes == mins,
                            onSelected: (_) {
                              _sleepTimer?.cancel();
                              _sleepMinutes = mins;
                              _sleepTimer = Timer(Duration(minutes: mins), () {
                                _player.pause();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إيقاف التشغيل بواسطة المؤقت')));
                                }
                              });
                              Navigator.pop(context);
                            },
                            selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            backgroundColor: Colors.white.withOpacity(0.1),
                            labelStyle: const TextStyle(color: Colors.white),
                          )).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('مخصص (دقيقة)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                final mins = int.tryParse(controller.text);
                                if (mins != null && mins > 0) {
                                  _sleepTimer?.cancel();
                                  _sleepMinutes = mins;
                                  _sleepTimer = Timer(Duration(minutes: mins), () {
                                    _player.pause();
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إيقاف التشغيل بواسطة المؤقت')));
                                  });
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                              child: const Text('بدء'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _qaBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }

  Widget _buildResumeDialog() {
    final cs = Theme.of(context).colorScheme;
    final pos = _state.savedPosition;
    if (pos == null || !_state.showResumeDialog) return const SizedBox.shrink();

    return Positioned(
      bottom: 16,
      left: 16,
      child: GestureDetector(
        onTap: _startFromBeginning,
        child: AnimatedOpacity(
          opacity: _state.showResumeDialog ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.history_rounded, color: cs.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  'استئناف ${_fmt(pos)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 4),
                Text(
                  'اضغط للبداية',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                ),
              ],
            ),
          ),
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

  Widget _buildSidePanel() {
    const double panelWidth = 340.0;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: 0,
      bottom: 0,
      right: _state.currentMenu != ActiveMenu.none ? 0 : -panelWidth,
      width: panelWidth,
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
                      _state.currentMenu == ActiveMenu.subtitles
                          ? 'إعدادات الترجمة'
                          : _state.currentMenu == ActiveMenu.audio
                              ? 'إعدادات الصوت'
                              : 'المزيد',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () {
                        _state.currentMenu = ActiveMenu.none;
                        _state.notifyListeners();
                        _service.scheduleHide();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Symbols.close_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _state.currentMenu == ActiveMenu.subtitles
                    ? SubtitleAppearancePanel(
                        subtitleTracks: _state.subtitleTracks,
                        currentSubtitleTrack: _player.state.track.subtitle,
                        onTrackSelected: (track) {
                          if (track is SubtitleTrack) {
                            _player.setSubtitleTrack(track);
                          }
                          _state.showSubtitles = true;
                          _state.notifyListeners();
                        },
                        onPickSubtitle: _pickSubtitle,
                        onRemoveExternal: _removeExternalSubtitle,
                        hasExternalSubtitle: _state.hasExternalSubtitle,
                        showSubtitles: _state.showSubtitles,
                        onToggleSubtitles: (v) {
                          _state.showSubtitles = v;
                          _state.notifyListeners();
                          if (!v) _player.setSubtitleTrack(SubtitleTrack.no());
                        },
                        subtitleSync: _state.subtitleSync,
                        onSyncChanged: _onSubtitleSyncChanged,
                      )
                    : _state.currentMenu == ActiveMenu.audio
                        ? AudioSettingsPanel(
                            player: _player,
                            volumeLevel: _state.volumeLevel,
                            onVolumeChanged: _service.onVolumeChanged,
                            audioTracks: _state.audioTracks,
                            currentAudioTrack: _player.state.track.audio,
                            onTrackSelected: (track) => _player.setAudioTrack(track),
                            audioDelay: _state.audioDelay,
                            onAudioDelayChanged: (v) {
                              _state.audioDelay = v;
                              _state.notifyListeners();
                            },
                            onClose: () {
                              _state.currentMenu = ActiveMenu.none;
                              _state.notifyListeners();
                            },
                          )
                        : _state.currentMenu == ActiveMenu.settings
                            ? PlayerSettingsPanel(
                                isFavorite: _libraryProvider.isFavorite(widget.video.path),
                                onToggleFavorite: _service.toggleFavorite,
                                onAddToPlaylist: _service.addToPlaylist,
                                onCaptureScreenshot: _service.captureScreenshot,
                                onToggleFit: _toggleFit,
                                onEnterPip: () async => PipService.enter(),
                                onShowInfo: () {
                                  _state.currentMenu = ActiveMenu.none;
                                  _state.notifyListeners();
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => InfoScreen(video: widget.video)));
                                },
                                onSleepTimer: _showTimerPicker,
                                onShowSpeedPicker: () {
                                  _state.currentMenu = ActiveMenu.none;
                                  _state.notifyListeners();
                                  _showSpeedPicker();
                                },
                                onToggleRememberPosition: () {
                                  _settingsProvider.setRememberPosition(!_settingsProvider.rememberPosition);
                                },
                                rememberPosition: _settingsProvider.rememberPosition,
                                currentSpeed: _state.speed,
                                currentFitMode: modeName(_state.fitMode),
                                onClose: () {
                                  _state.currentMenu = ActiveMenu.none;
                                  _state.notifyListeners();
                                },
                                onOpenPlaylistEditor: openPlaylistEditor,
                              )
                            : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistEditor() {
    final isCustom = _libraryProvider.playlistPaths.isNotEmpty;

    final videos = isCustom
        ? _libraryProvider.playlistPaths
            .map((path) => _libraryProvider.allVideos.where((v) => v.path == path).firstOrNull)
            .whereType<VideoItem>()
            .toList()
        : _libraryProvider.allVideos
            .where((v) => v.folder == widget.video.folder && !_hiddenFromSession.contains(v.path))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    void remove(String path) {
      if (isCustom) {
        _libraryProvider.removeFromPlaylist(path);
      } else {
        _hiddenFromSession.add(path);
      }
      setState(() {});
    }

    return Container(
      color: Colors.black.withOpacity(0.65),
      child: Column(
        children: [
          AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('قوائم التشغيل', style: TextStyle(fontSize: 16)),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _showPlaylistEditor = false),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: videos.length,
              onReorder: (oldIndex, newIndex) {
                if (isCustom) {
                  _libraryProvider.reorderPlaylist(oldIndex, newIndex);
                  setState(() {});
                }
              },
              itemBuilder: (context, index) {
                final video = videos[index];
                final isPlaying = video.path == widget.video.path;

                return ListTile(
                  key: Key(video.path),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.drag_handle, color: Colors.white54),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        height: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoThumbnailLoader(video: video, width: 80, height: 50),
                              if (isPlaying)
                                Container(
                                  color: Colors.black.withOpacity(0.55),
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: const Center(
                                    child: PlayingIndicator(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    video.name,
                    style: TextStyle(
                      color: isPlaying ? Theme.of(context).colorScheme.primary : Colors.white,
                      fontSize: 13,
                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(video.formattedDuration,
                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => remove(video.path),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = context.watch<SettingsProvider>();
    final lib = context.watch<LibraryProvider>();

    if (PipService.isInPipMode.value) {
      return Scaffold(backgroundColor: Colors.black, body: Video(controller: _controller));
    }

    final controlsVisible = _state.showControls && !_state.isLocked && _state.currentMenu == ActiveMenu.none;

    return PopScope(
      canPop: !_state.isLocked,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (_state.currentMenu != ActiveMenu.none || _state.showQuickActions) {
            _state.resetMenu();
            return;
          }
          if (!_state.isLocked) await PipService.enter();
        }
        if (_state.isLocked) {
          _state.isLocked = false;
          _state.notifyListeners();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: !_state.initialized
            ? Center(child: CircularProgressIndicator(color: cs.primary))
            : Stack(children: [
                PlayerGestureLayer(
                  player: _player,
                  isLocked: _state.isLocked,
                  volumeLevel: _state.volumeLevel,
                  brightnessNotifier: _brightnessNotifier,
                  seekMsNotifier: _seekMsNotifier,
                  position: _state.position,
                  duration: _state.duration,
                  isPlaying: _state.isPlaying,
                  onToggleControls: _toggleControls,
                  onVolumeChanged: _service.onVolumeChanged,
                  onPlayPause: () => _state.isPlaying ? _player.pause() : _player.play(),
                  child: Video(
                    key: ValueKey('video_${s.bottomPadding}_${s.horizontalMargin}'),
                    controller: _controller,
                    fit: getBoxFit(_state.fitMode),
                    controls: NoVideoControls,
                    subtitleViewConfiguration: SubtitleViewConfiguration(
                      style: buildSubtitleTextStyle(s),
                      textAlign: s.subtitleRTL ? TextAlign.right : TextAlign.center,
                      padding: EdgeInsets.fromLTRB(s.horizontalMargin, 0, s.horizontalMargin, s.bottomPadding),
                    ),
                  ),
                ),

                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _state.showScreenshotFlash ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(color: Colors.white),
                  ),
                ),

                if (_state.isLocked)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _state.showLockHint = true;
                          });
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) {
                              setState(() {
                                _state.showLockHint = false;
                              });
                            }
                          });
                        },
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _state.lockIconOffset =
                                (_state.lockIconOffset + details.delta.dx)
                                    .clamp(0.0, _lockTrackWidth - _lockBtnSize);
                          });
                        },
                        onHorizontalDragEnd: (_) {
                          if (_state.lockIconOffset >= _lockTrackWidth - _lockBtnSize - 8) {
                            _toggleLock();
                          }
                          setState(() {
                            _state.lockIconOffset = 0.0;
                            _state.showLockHint = false;
                          });
                        },
                        child: AnimatedOpacity(
                          opacity: _state.showLockHint ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Builder(builder: (context) {
                            final cs = Theme.of(context).colorScheme;
                            final progress = (_state.lockIconOffset /
                                    (_lockTrackWidth - _lockBtnSize))
                                .clamp(0.0, 1.0);
                            return Container(
                              width: _lockTrackWidth,
                              height: _lockBtnSize + 8,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular((_lockBtnSize + 8) / 2),
                                border: Border.all(
                                    color: cs.primary.withOpacity(0.4), width: 1.5),
                              ),
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  if (progress > 0)
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: _state.lockIconOffset + _lockBtnSize,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: cs.primary.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(_lockBtnSize / 2),
                                        ),
                                      ),
                                    ),
                                  Center(
                                    child: Text(
                                      progress > 0.6
                                          ? 'أطلق للفتح'
                                          : 'اسحب لفتح القفل ←',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 13),
                                    ),
                                  ),
                                  AnimatedPositioned(
                                    duration: Duration.zero,
                                    left: _state.lockIconOffset,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: _lockBtnSize,
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: cs.primary.withOpacity(0.5),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _state.lockIconOffset >=
                                                _lockTrackWidth - _lockBtnSize - 8
                                            ? Symbols.lock_open_rounded
                                            : Symbols.lock_rounded,
                                        color: cs.onPrimary,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),

                if (_state.fitOverlayText != null)
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
                        child: Text(
                          _state.fitOverlayText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                if (controlsVisible) ...[
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: PlayerTopBar(
                      videoName: widget.video.name,
                      onBack: () => Navigator.pop(context),
                      onAudioMenu: () {
                        _state.currentMenu = _state.currentMenu == ActiveMenu.audio ? ActiveMenu.none : ActiveMenu.audio;
                        _state.showQuickActions = false;
                        _state.notifyListeners();
                      },
                      onSubtitleMenu: () {
                        _state.currentMenu = _state.currentMenu == ActiveMenu.subtitles ? ActiveMenu.none : ActiveMenu.subtitles;
                        _state.showQuickActions = false;
                        _state.notifyListeners();
                      },
                      onQuickActions: () {
                        _state.showQuickActions = !_state.showQuickActions;
                        _state.notifyListeners();
                      },
                      onSettingsMenu: () {
                        _state.currentMenu = ActiveMenu.settings;
                        _state.notifyListeners();
                      },
                      isAudioActive: _state.currentMenu == ActiveMenu.audio,
                      isSubtitleActive: _state.currentMenu == ActiveMenu.subtitles,
                      isQuickActionsActive: _state.showQuickActions,
                      quickActionWidgets: _state.showQuickActions
                          ? [
                              _qaBtn(Symbols.camera_rounded, Colors.white70, _service.captureScreenshot),
                              _qaBtn(
                                _state.smartEnhance ? Symbols.auto_awesome_rounded : Symbols.auto_awesome_rounded,
                                _state.smartEnhance ? Colors.amber : Colors.white70,
                                _service.toggleSmartEnhance,
                              ),
                              _qaBtn(
                                _state.hdrEnabled ? Symbols.hdr_on_rounded : Symbols.hdr_off_rounded,
                                _state.hdrEnabled ? Colors.amber : Colors.white70,
                                _service.toggleHDREnhancement,
                              ),
                              _qaBtn(
                                _state.hwEnabled ? Symbols.memory_rounded : Symbols.sd_card_rounded,
                                _state.hwEnabled ? Colors.amber : Colors.white70,
                                _service.toggleHardwareDecoding,
                              ),
                              _qaBtn(
                                lib.isFavorite(widget.video.path) ? Symbols.favorite_rounded : Symbols.favorite_border,
                                lib.isFavorite(widget.video.path) ? Colors.amber : Colors.white70,
                                _service.toggleFavorite,
                              ),
                              _qaBtn(Symbols.playlist_add_rounded, Colors.white70, _service.addToPlaylist),
                              _qaBtn(Symbols.share_rounded, Colors.white70, _service.shareVideo),
                              _qaBtn(Symbols.speed_rounded, Colors.white70, () {
                                _showSpeedPicker();
                                _state.showQuickActions = false;
                                _state.notifyListeners();
                              }),
                              _qaBtn(
                                Symbols.timer_rounded,
                                _sleepMinutes != null ? Colors.amber : Colors.white70,
                                _showTimerPicker,
                              ),
                              _qaBtn(
                                Symbols.dark_mode_rounded,
                                _state.isNightMode ? Colors.amber : Colors.white70,
                                () {
                                  setState(() {
                                    _state.isNightMode = !_state.isNightMode;
                                    if (_state.isNightMode) {
                                      _state.preNightBrightness = _brightnessNotifier.value;
                                      _brightnessNotifier.value = 0.05;
                                    } else {
                                      _brightnessNotifier.value = _state.preNightBrightness;
                                    }
                                  });
                                  ScreenBrightness.instance.setApplicationScreenBrightness(_brightnessNotifier.value);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(_state.isNightMode ? 'تم تفعيل الوضع الليلي' : 'تم إيقاف الوضع الليلي'),
                                  ));
                                },
                              ),
                              _qaBtn(
                                _state.volumeLevel == 0 ? Symbols.volume_off_rounded : Symbols.volume_up_rounded,
                                _state.volumeLevel == 0 ? Colors.amber : Colors.white70,
                                _service.toggleMute,
                              ),
                              _qaBtn(
                                _state.playlistMode == PlaylistMode.single ? Symbols.repeat_one_rounded : Symbols.repeat_rounded,
                                _state.playlistMode != PlaylistMode.none ? Colors.amber : Colors.white70,
                                _service.toggleRepeat,
                              ),
                              _qaBtn(
                                Symbols.shuffle_rounded,
                                _state.isShuffle ? Colors.amber : Colors.white70,
                                _service.toggleShuffle,
                              ),
                              _qaBtn(Symbols.palette_rounded, Colors.white70, _showColorAdjustment),
                            ]
                          : [],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: PlayerBottomBar(
                      position: _state.position,
                      duration: _state.duration,
                      onSeek: (v) => _player.seek(Duration(milliseconds: (v * _state.duration.inMilliseconds).toInt())),
                      primaryColor: cs.primary,
                      isPlaying: _state.isPlaying,
                      onPlayPause: () => _state.isPlaying ? _player.pause() : _player.play(),
                      onSkipBack: () {
                        final t = _state.position - const Duration(seconds: 10);
                        _player.seek(t.isNegative ? Duration.zero : t);
                      },
                      onSkipForward: () {
                        final t = _state.position + const Duration(seconds: 10);
                        _player.seek(t > _state.duration ? _state.duration : t);
                      },
                      onToggleFit: _toggleFit,
                      onToggleLock: _toggleLock,
                      onPip: () async => PipService.enter(),
                      chapters: _state.chapters,
                      onPrevious: _service.playPrevious,
                      onNext: _service.playNext,
                    ),
                  ),
                ],
                if (_state.showResumeDialog) _buildResumeDialog(),
                _buildSidePanel(),
                if (_showPlaylistEditor)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: _buildPlaylistEditor(),
                  ),
              ]),
      ),
    );
  }

  @override
  void dispose() {
    _service.savePositionOnExit();
    if (_state.smartEnhance) {
      SmartEnhanceService.disable(
        _player,
        userContrast:   _state.contrast,
        userSaturation: _state.saturation,
        userBrightness: _state.brightness,
        userGamma:      _state.gamma,
        userHue:        _state.hue,
      );
    }
    _state.removeListener(_onStateChanged);
    _sensorSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    PipService.isInPipMode.removeListener(_onPipModeChanged);
    _brightnessNotifier.dispose();
    _seekMsNotifier.dispose();
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _fitOverlayTimer?.cancel();
    _sleepTimer?.cancel();
    _service.disposeTimers();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _player.dispose();
    super.dispose();
  }
}

class PlayingIndicator extends StatefulWidget {
  const PlayingIndicator({super.key});

  @override
  State<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<PlayingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final height = 6.0 + (index == 1 ? 10.0 * _ctrl.value : 8.0 * (1 - _ctrl.value));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3.0,
              height: height,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      }),
    );
  }
}