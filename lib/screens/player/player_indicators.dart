import 'package:flutter/material.dart';

/// مؤشرات بتصميم شريط أفقي بسيط وهادئ مع أيقونة متغيرة.
class PlayerIndicators {
  static Widget buildFloatingIndicator({
    required IconData icon,
    required double displayValue, // 0.0 → 1.0
    required String labelText,
    required Color color,
  }) {
    return _MinimalPill(
      icon: icon,
      value: displayValue.clamp(0.0, 1.0),
      label: labelText,
      barColor: color,
    );
  }
}

/// شريط أفقي بسيط (Pill) مع أيقونة تتغير حسب القيمة.
class _MinimalPill extends StatelessWidget {
  final IconData icon;
  final double value;
  final String label;
  final Color barColor;

  const _MinimalPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.barColor,
  });

  // أيقونات الصوت حسب المستوى
  IconData _volumeIcon(double vol) {
    if (vol == 0) return Icons.volume_off_rounded;
    if (vol < 0.33) return Icons.volume_mute_rounded;
    if (vol < 0.66) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  // أيقونات السطوع حسب المستوى
  IconData _brightnessIcon(double bright) {
    if (bright < 0.25) return Icons.brightness_low_rounded;
    if (bright < 0.6) return Icons.brightness_medium_rounded;
    return Icons.brightness_high_rounded;
  }

  @override
  Widget build(BuildContext context) {
    // معرفة هل المؤشر للصوت أم للسطوع
    final bool isVolume = icon == Icons.volume_off_rounded ||
        icon == Icons.volume_up_rounded ||
        icon == Icons.volume_down_rounded ||
        icon == Icons.volume_mute_rounded;

    final bool isBrightness = icon == Icons.brightness_2_rounded ||
        icon == Icons.brightness_5_rounded ||
        icon == Icons.brightness_7_rounded;

    IconData currentIcon = icon;
    if (isVolume) {
      currentIcon = _volumeIcon(value);
    } else if (isBrightness) {
      currentIcon = _brightnessIcon(value);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // أيقونة متغيرة مع حركة سلسة
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              currentIcon,
              color: Colors.white70,
              size: 18,
              key: ValueKey(currentIcon),
            ),
          ),
          const SizedBox(width: 10),
          // شريط التقدم
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                  barColor.withOpacity(0.8),
                ),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // النسبة
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}