import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class PlayerTopBar extends StatelessWidget {
  final String videoName;
  final VoidCallback onBack;
  final VoidCallback onToggleFit;
  final VoidCallback onToggleOrientation;
  final VoidCallback onPip;
  final VoidCallback onAudioMenu;
  final VoidCallback onSubtitleMenu;
  final bool isLandscape;
  final bool showSubtitles;

  const PlayerTopBar({
    super.key,
    required this.videoName,
    required this.onBack,
    required this.onToggleFit,
    required this.onToggleOrientation,
    required this.onPip,
    required this.onAudioMenu,
    required this.onSubtitleMenu,
    required this.isLandscape,
    required this.showSubtitles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent]),
      ),
      child: SafeArea(
        child: Row(children: [
          IconButton(
              icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white),
              onPressed: onBack),
          Expanded(
              child: Text(videoName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14))),
          IconButton(
              icon: const Icon(Symbols.aspect_ratio_rounded, color: Colors.white70),
              onPressed: onToggleFit),
          IconButton(
              icon: Icon(
                  isLandscape
                      ? Symbols.screen_rotation_rounded
                      : Symbols.stay_current_portrait_rounded,
                  color: Colors.white70),
              onPressed: onToggleOrientation),
          IconButton(
              icon: const Icon(Symbols.picture_in_picture_rounded, color: Colors.white70),
              onPressed: onPip),
          IconButton(
              icon: const Icon(Symbols.graphic_eq_rounded, color: Colors.white70),
              onPressed: onAudioMenu),
          IconButton(
              icon: Icon(
                  showSubtitles
                      ? Symbols.subtitles_rounded
                      : Symbols.subtitles_off_rounded,
                  color: showSubtitles ? Colors.lightBlue : Colors.white54),
              onPressed: onSubtitleMenu),
        ]),
      ),
    );
  }
}

class PlayerBottomBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;
  final Color primaryColor;

  const PlayerBottomBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.primaryColor,
  });

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.85), Colors.transparent]),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            Text(_fmt(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: primaryColor,
                    inactiveTrackColor: Colors.white.withOpacity(0.2),
                    thumbColor: primaryColor),
                child: Slider(
                  value: duration.inMilliseconds > 0
                      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0,
                  onChanged: onSeek,
                ),
              ),
            ),
            Text(_fmt(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class PlayerCenterButtons extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final Color primaryColor;
  final Color onPrimaryContainer;

  const PlayerCenterButtons({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.primaryColor,
    required this.onPrimaryContainer,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      CtrlBtn(Symbols.replay_10_rounded, onSkipBack),
      const SizedBox(width: 28),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPlayPause,
          borderRadius: BorderRadius.circular(34),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: primaryColor.withOpacity(0.9), shape: BoxShape.circle),
            child: Icon(isPlaying ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
                color: onPrimaryContainer, size: 38),
          ),
        ),
      ),
      const SizedBox(width: 28),
      CtrlBtn(Symbols.forward_10_rounded, onSkipForward),
    ]);
  }
}

class CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const CtrlBtn(this.icon, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      );
}
