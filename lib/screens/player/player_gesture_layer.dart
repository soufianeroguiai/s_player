import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../providers/settings_provider.dart';
import 'player_indicators.dart';

class PlayerGestureLayer extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final bool isLocked;
  final double volumeLevel;
  final ValueNotifier<double> brightnessNotifier;
  final ValueNotifier<double> seekMsNotifier;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final VoidCallback onToggleControls;
  final void Function(double newVolume) onVolumeChanged;
  final VoidCallback onPlayPause;
  final Widget child;

  const PlayerGestureLayer({
    super.key,
    required this.player,
    required this.controller,
    required this.isLocked,
    required this.volumeLevel,
    required this.brightnessNotifier,
    required this.seekMsNotifier,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.onToggleControls,
    required this.onVolumeChanged,
    required this.onPlayPause,
    required this.child,
  });

  @override
  State<PlayerGestureLayer> createState() => _PlayerGestureLayerState();
}

class _PlayerGestureLayerState extends State<PlayerGestureLayer> {
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

  @override
  void dispose() {
    _showVolNotifier.dispose();
    _showBrightNotifier.dispose();
    _showSeekNotifier.dispose();
    _indicatorTimer?.cancel();
    _seekHintTimer?.cancel();
    super.dispose();
  }

  void _resetIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 1), () {
      _showVolNotifier.value = false;
      _showBrightNotifier.value = false;
    });
  }

  void _showSeekHint(int seconds) {
    setState(() => _seekHintText = seconds > 0 ? '+${seconds}s ⏩' : '${seconds}s ⏪');
    _seekHintTimer?.cancel();
    _seekHintTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekHintText = null);
    });
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final s = context.watch<SettingsProvider>();

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onToggleControls,
          onDoubleTapDown: widget.isLocked
              ? null
              : (details) {
                  final x = details.localPosition.dx;
                  if (x < screenWidth / 3) {
                    final target = widget.position - const Duration(seconds: 10);
                    widget.player.seek(target.isNegative ? Duration.zero : target);
                    _showSeekHint(-10);
                  } else if (x > screenWidth * 2 / 3) {
                    final target = widget.position + const Duration(seconds: 10);
                    widget.player.seek(target > widget.duration ? widget.duration : target);
                    _showSeekHint(10);
                  } else {
                    widget.onPlayPause();
                  }
                },
          onScaleStart: (details) {
            if (widget.isLocked) return;
            if (details.pointerCount == 2) {
              _startSubtitleSize = s.subtitleFontSize;
              _startBottomPadding = s.bottomPadding;
              _startFocalPoint = details.focalPoint;
              _subtitleGestureActive = true;
            } else {
              widget.seekMsNotifier.value = widget.position.inMilliseconds.toDouble();
              _subtitleGestureActive = false;
            }
          },
          onScaleUpdate: (details) {
            if (widget.isLocked) return;

            if (details.pointerCount == 2 && _subtitleGestureActive) {
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
              final seekFactor = (widget.duration.inMilliseconds * 0.25)
                  .clamp(30000.0, 600000.0);
              final change = (details.focalPointDelta.dx / screenWidth) * seekFactor;
              widget.seekMsNotifier.value = (widget.seekMsNotifier.value + change)
                  .clamp(0.0, widget.duration.inMilliseconds.toDouble());
              _showSeekNotifier.value = true;
              _showVolNotifier.value = false;
              _showBrightNotifier.value = false;
            } else {
              final delta = -details.focalPointDelta.dy / 180.0;
              if (isRight) {
                widget.onVolumeChanged(widget.volumeLevel + delta);
                _showVolNotifier.value = true;
                _showBrightNotifier.value = false;
                _showSeekNotifier.value = false;
              } else {
                final newBright = (widget.brightnessNotifier.value + delta).clamp(0.05, 1.0);
                widget.brightnessNotifier.value = newBright;
                ScreenBrightness.instance.setApplicationScreenBrightness(newBright);
                _showBrightNotifier.value = true;
                _showVolNotifier.value = false;
                _showSeekNotifier.value = false;
              }
              _resetIndicatorTimer();
            }
          },
          onScaleEnd: (details) {
            if (widget.isLocked) return;
            _subtitleGestureActive = false;
            if (_showSeekNotifier.value) {
              widget.player.seek(Duration(milliseconds: widget.seekMsNotifier.value.toInt()));
              _showSeekNotifier.value = false;
            }
          },
          child: widget.child,
        ),

        ValueListenableBuilder<bool>(
          valueListenable: _showSeekNotifier,
          builder: (context, show, child) {
            if (!show) return const SizedBox.shrink();
            return Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    _fmt(Duration(milliseconds: widget.seekMsNotifier.value.toInt())),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
            );
          },
        ),

        // ✅ مؤشر الصوت (يظهر على اليسار – شريط عمودي)
        ValueListenableBuilder<bool>(
          valueListenable: _showVolNotifier,
          builder: (context, show, child) {
            if (!show) return const SizedBox.shrink();
            final bool isBoosted = widget.volumeLevel > 1.0;
            return Positioned(
              left: 20,
              top: MediaQuery.of(context).size.height * 0.22,
              child: PlayerIndicators.buildFloatingIndicator(
                icon: widget.volumeLevel == 0
                    ? Icons.volume_off_rounded
                    : isBoosted
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded,
                displayValue: (widget.volumeLevel / 2.0).clamp(0.0, 1.0),
                labelText: '${(widget.volumeLevel * 100).round()}%',
                color: isBoosted
                    ? const Color(0xFFFF8A65)
                    : const Color(0xFF64B5F6),
              ),
            );
          },
        ),

        // ✅ مؤشر السطوع (يظهر على اليمين – شريط عمودي)
        ValueListenableBuilder<bool>(
          valueListenable: _showBrightNotifier,
          builder: (context, show, child) {
            if (!show) return const SizedBox.shrink();
            return ValueListenableBuilder<double>(
              valueListenable: widget.brightnessNotifier,
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
                    color: const Color(0xFFFFF176),
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
      ],
    );
  }
}