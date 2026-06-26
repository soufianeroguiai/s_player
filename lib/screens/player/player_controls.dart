import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class PlayerTopBar extends StatelessWidget {
  final String videoName;
  final VoidCallback onBack;
  final VoidCallback onAudioMenu;
  final VoidCallback onSubtitleMenu;
  final VoidCallback onQuickActions;
  final VoidCallback onSettingsMenu;
  final bool isAudioActive;
  final bool isSubtitleActive;
  final bool isQuickActionsActive;
  final List<Widget> quickActionWidgets;

  const PlayerTopBar({
    super.key,
    required this.videoName,
    required this.onBack,
    required this.onAudioMenu,
    required this.onSubtitleMenu,
    required this.onQuickActions,
    required this.onSettingsMenu,
    this.isAudioActive = false,
    this.isSubtitleActive = false,
    this.isQuickActionsActive = false,
    this.quickActionWidgets = const [],
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.75), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          IconButton(
            icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white),
            onPressed: onBack,
          ),
          if (!isQuickActionsActive)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.35),
              child: _MarqueeText(
                text: videoName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                ),
              ),
            )
          else
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: isQuickActionsActive ? 1.0 : 0.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: quickActionWidgets,
                ),
              ),
            ),
          const Spacer(),
          _AnimatedIconBtn(
            icon: Symbols.keyboard_arrow_left_rounded,
            color: isQuickActionsActive ? Colors.amberAccent : Colors.white70,
            onTap: onQuickActions,
          ),
          _AnimatedIconBtn(
            icon: Symbols.graphic_eq_rounded,
            color: isAudioActive ? Colors.amberAccent : Colors.white70,
            onTap: onAudioMenu,
          ),
          _AnimatedIconBtn(
            icon: isSubtitleActive ? Symbols.closed_caption_rounded : Symbols.closed_caption_off_rounded,
            color: isSubtitleActive ? Colors.amberAccent : Colors.white60,
            onTap: onSubtitleMenu,
          ),
          _AnimatedIconBtn(
            icon: Symbols.more_vert_rounded,
            color: Colors.white70,
            onTap: onSettingsMenu,
          ),
        ]),
      ),
    );
  }
}

