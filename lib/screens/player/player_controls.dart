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
  });

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: _MarqueeText(
              text: videoName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
              ),
            ),
          ),
          _AnimatedIconBtn(
            icon: isQuickActionsActive ? Symbols.arrow_drop_up_rounded : Symbols.arrow_drop_down_rounded,
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

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _textWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    WidgetsBinding.instance.addPostFrameCallback(_startIfNeeded);
  }

  void _startIfNeeded(_) {
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: double.infinity);
    _textWidth = textPainter.width;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && _textWidth > renderBox.size.width) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return ClipRect(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final maxTranslate = (_textWidth - constraints.maxWidth).clamp(0.0, double.infinity);
            if (maxTranslate <= 0) {
              return Text(widget.text, style: widget.style, maxLines: 1, overflow: TextOverflow.ellipsis);
            }
            final offset = maxTranslate * _animation.value;
            return Transform.translate(
              offset: Offset(-offset, 0),
              child: Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
            );
          },
        ),
      );
    });
  }
}

class _AnimatedIconBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedIconBtn({required this.icon, required this.color, required this.onTap});

  @override
  State<_AnimatedIconBtn> createState() => _AnimatedIconBtnState();
}

class _AnimatedIconBtnState extends State<_AnimatedIconBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: IconButton(
          icon: Icon(widget.icon, color: widget.color, size: 24),
          onPressed: null,
        ),
      ),
    );
  }
}

class PlayerBottomBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;
  final Color primaryColor;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final VoidCallback onToggleFit;
  final VoidCallback onToggleLock;
  final VoidCallback onPip;
  final VoidCallback onToggleOrientation;
  final bool isLandscape;

  const PlayerBottomBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.primaryColor,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onToggleFit,
    required this.onToggleLock,
    required this.onPip,
    required this.onToggleOrientation,
    this.isLandscape = true,
  });

  @override
  State<PlayerBottomBar> createState() => _PlayerBottomBarState();
}

class _PlayerBottomBarState extends State<PlayerBottomBar> {
  bool _isSliding = false;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.duration.inMilliseconds > 0
        ? (widget.position.inMilliseconds / widget.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.85), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(children: [
                Text(_fmt(widget.position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: _isSliding ? 6 : 3,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: _isSliding ? 10 : 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: widget.primaryColor,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: widget.primaryColor,
                      overlayColor: widget.primaryColor.withOpacity(0.25),
                    ),
                    child: Slider(
                      value: progress,
                      onChanged: (v) {
                        setState(() => _isSliding = true);
                        widget.onSeek(v);
                      },
                      onChangeEnd: (_) {
                        setState(() => _isSliding = false);
                      },
                    ),
                  ),
                ),
                Text(_fmt(widget.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            SizedBox(
              height: 52,
              child: Row(children: [
                _BottomBtn(icon: Symbols.picture_in_picture_rounded, onTap: widget.onPip, size: 22),
                _BottomBtn(icon: Symbols.lock_rounded, onTap: widget.onToggleLock, size: 22),
                const Spacer(),
                _BottomBtn(icon: Symbols.replay_10_rounded, onTap: widget.onSkipBack, size: 28),
                const SizedBox(width: 8),
                _PlayBtn(
                  isPlaying: widget.isPlaying,
                  onTap: widget.onPlayPause,
                  color: widget.primaryColor,
                ),
                const SizedBox(width: 8),
                _BottomBtn(icon: Symbols.forward_10_rounded, onTap: widget.onSkipForward, size: 28),
                const Spacer(),
                _BottomBtn(
                  icon: widget.isLandscape ? Symbols.screen_rotation_rounded : Symbols.stay_current_portrait_rounded,
                  onTap: widget.onToggleOrientation, size: 22,
                ),
                _BottomBtn(icon: Symbols.aspect_ratio_rounded, onTap: widget.onToggleFit, size: 22),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PlayBtn extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final Color color;
  const _PlayBtn({required this.isPlaying, required this.onTap, required this.color});

  @override
  State<_PlayBtn> createState() => _PlayBtnState();
}

class _PlayBtnState extends State<_PlayBtn> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_rotationController.isCompleted) {
      _rotationController.reverse();
    } else {
      _rotationController.forward();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _rotationController,
        builder: (context, child) => Transform.rotate(
          angle: _rotationController.value * 3.14159,
          child: child,
        ),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 2),
            color: Colors.transparent,
          ),
          child: Icon(
            widget.isPlaying ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
            color: Colors.white70,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _BottomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _BottomBtn({required this.icon, required this.onTap, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white70, size: size),
      ),
    );
  }
}