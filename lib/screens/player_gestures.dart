import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

enum GestureType { none, seek, volumeBrightness }

mixin PlayerGestures {
  late final Player Function() getPlayer;
  late final ValueNotifier<double> volumeNotifier;
  late final ValueNotifier<double> brightnessNotifier;
  late final ValueNotifier<double> seekMsNotifier;
  late final ValueNotifier<bool> showVolNotifier;
  late final ValueNotifier<bool> showBrightNotifier;
  late final ValueNotifier<bool> showSeekNotifier;
  late final bool Function() isLocked;
  late final double Function() getAudioBoost;
  late final Duration Function() getDuration;
  late final Duration Function() getPosition;
  late final void Function() scheduleHide;
  late final void Function() cancelHideTimer;
  late final BuildContext Function() getContext;

  double _panStartVolume = 0.8;
  double _panStartBrightness = 0.7;
  double _panStartSeekMs = 0.0;
  GestureType _panType = GestureType.none;
  Offset _panStartPos = Offset.zero;
  DateTime? _lastVolTime;
  DateTime? _lastBrightTime;

  bool _isScaling = false;
  double _startSubtitleSize = 24.0;
  double _startBottomPadding = 48.0;
  Offset _scaleStartFocalPoint = Offset.zero;
  bool? _verticalTwoFingerMode;

  Timer? _indicatorTimer;

  double get effectiveVolume =>
      (volumeNotifier.value * getAudioBoost()).clamp(0, 200);

  void onPanDown(DragDownDetails details) {
    if (isLocked() || _isScaling) return;
    cancelHideTimer();
    _indicatorTimer?.cancel();

    _panStartPos = details.localPosition;
    _panType = GestureType.none;
    _panStartVolume = volumeNotifier.value;
    _panStartBrightness = brightnessNotifier.value;
    _panStartSeekMs = getPosition().inMilliseconds.toDouble();
    seekMsNotifier.value = _panStartSeekMs;
  }

  void onPanUpdate(DragUpdateDetails details, double screenWidth) {
    if (isLocked() || _isScaling) return;

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
    final dur = getDuration();
    final double seekFactor = (dur.inMilliseconds * 0.25).clamp(50000, 500000);
    final seekChangeMs = (dx / screenWidth) * seekFactor;
    seekMsNotifier.value = (seekMsNotifier.value + seekChangeMs)
        .clamp(0.0, dur.inMilliseconds.toDouble());

    showSeekNotifier.value = true;
    showBrightNotifier.value = false;
    showVolNotifier.value = false;
    _resetIndicatorTimer();
  }

  void _handleVolumeBrightnessPan(DragUpdateDetails details, double screenWidth) {
    final dy = details.delta.dy;
    final double delta = -dy / 200.0;
    final bool isLeft = details.localPosition.dx < screenWidth / 2;
    final DateTime now = DateTime.now();

    if (isLeft) {
      final newBrightness = (brightnessNotifier.value + delta).clamp(0.1, 1.0);
      brightnessNotifier.value = newBrightness;
      showBrightNotifier.value = true;
      showVolNotifier.value = false;
      showSeekNotifier.value = false;

      if (_lastBrightTime == null ||
          now.difference(_lastBrightTime!) > const Duration(milliseconds: 50)) {
        try {
          ScreenBrightness.instance.setApplicationScreenBrightness(newBrightness);
        } catch (_) {}
        _lastBrightTime = now;
      }
    } else {
      final newVol = (volumeNotifier.value + delta).clamp(0.0, 1.0);
      volumeNotifier.value = newVol;
      showVolNotifier.value = true;
      showBrightNotifier.value = false;
      showSeekNotifier.value = false;

      if (_lastVolTime == null ||
          now.difference(_lastVolTime!) > const Duration(milliseconds: 50)) {
        getPlayer().setVolume(effectiveVolume);
        _lastVolTime = now;
      }
    }
    _resetIndicatorTimer();
  }

  void onPanEnd(DragEndDetails details) {
    if (isLocked() || _isScaling) return;

    if (_panType == GestureType.seek) {
      getPlayer().seek(Duration(milliseconds: seekMsNotifier.value.toInt()));
      showSeekNotifier.value = false;
      scheduleHide();
    }

    _saveVolumeAndBrightness();
    _panType = GestureType.none;
    _resetIndicatorTimer();
  }

  void onScaleStart(ScaleStartDetails details) {
    if (isLocked()) return;
    _isScaling = true;
    cancelHideTimer();
    _indicatorTimer?.cancel();

    final settings = getContext().read<SettingsProvider>();
    _startSubtitleSize = settings.subtitleFontSize;
    _startBottomPadding = settings.bottomPadding;
    _scaleStartFocalPoint = details.focalPoint;
    _verticalTwoFingerMode = null;
    showBrightNotifier.value = false;
    showVolNotifier.value = false;
    showSeekNotifier.value = false;
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    if (isLocked() || !_isScaling) return;

    final settings = getContext().read<SettingsProvider>();
    final scaleChange = (details.scale - 1.0).abs();
    final focalDy = details.focalPointDelta.dy;
    final focalDx = details.focalPointDelta.dx;

    if (_verticalTwoFingerMode == null) {
      if (scaleChange > 0.03 || focalDy.abs() > 5 || focalDx.abs() > 5) {
        if (scaleChange > 0.03) {
          _verticalTwoFingerMode = false;
        } else if (focalDy.abs() > focalDx.abs()) {
          _verticalTwoFingerMode = true;
        } else {
          _verticalTwoFingerMode = false;
        }
      } else {
        return;
      }
    }

    if (_verticalTwoFingerMode == true) {
      final newBottomPadding = (_startBottomPadding - focalDy * 0.5).clamp(0.0, 200.0);
      settings.setBottomPadding(newBottomPadding);
    } else {
      final newSize = (_startSubtitleSize * details.scale).clamp(10.0, 150.0);
      settings.setSubtitleFontSize(newSize);
    }
  }

  void onScaleEnd(ScaleEndDetails details) {
    _isScaling = false;
    _verticalTwoFingerMode = null;
    _panType = GestureType.none;
    _resetIndicatorTimer();
  }

  Future<void> _saveVolumeAndBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('player_volume', volumeNotifier.value);
    await prefs.setDouble('player_brightness', brightnessNotifier.value);
  }

  void _resetIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 1), () {
      showBrightNotifier.value = false;
      showVolNotifier.value = false;
    });
  }

  void disposeGestures() {
    _indicatorTimer?.cancel();
  }
}