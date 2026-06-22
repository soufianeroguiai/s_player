import 'package:flutter/material.dart';

/// قسم تكبير الصوت (Audio Boost) ضمن لوحة الصوت الجانبية.
/// القيمة هنا ممثَّلة بنسبة مئوية (50% - 200%) وتُمرَّر مباشرة إلى
/// PlayerScreen الذي يطبّقها فعلياً على Player.setVolume().
class AudioBoostSection extends StatelessWidget {
  final double boost;
  final ValueChanged<double> onChanged;
  const AudioBoostSection({super.key, required this.boost, required this.onChanged});

  Color _boostColor(double v) {
    if (v <= 100) return Colors.lightBlue;
    if (v <= 150) return Colors.orange;
    return Colors.redAccent;
  }

  String _boostLabel(double v) {
    if (v <= 100) return 'طبيعي';
    if (v <= 130) return 'مرتفع';
    if (v <= 160) return 'عالٍ جداً';
    return '⚠️ تشويه محتمل';
  }

  @override
  Widget build(BuildContext context) {
    final color = _boostColor(boost);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('تكبير الصوت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        Text(_boostLabel(boost), style: TextStyle(color: color, fontSize: 11)),
      ]),
      const SizedBox(height: 6),
      AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 36),
        child: Text('${boost.round()}%'),
      ),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 5,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          activeTrackColor: color,
          inactiveTrackColor: Colors.white12,
          thumbColor: color,
          overlayColor: color.withOpacity(0.2),
        ),
        child: Slider(value: boost, min: 50, max: 200, divisions: 30, onChanged: onChanged),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        for (final val in [100.0, 130.0, 160.0, 200.0])
          _QuickBtn(
              label: '${val.toInt()}%',
              active: (boost - val).abs() < 2,
              color: _boostColor(val),
              onTap: () => onChanged(val)),
      ]),
    ]);
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.25) : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? color : Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
