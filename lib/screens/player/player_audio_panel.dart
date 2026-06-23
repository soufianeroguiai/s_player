import 'package:flutter/material.dart';

/// قسم تكبير الصوت ضمن لوحة الصوت الجانبية.
/// يعكس مباشرة _volumeLevel من PlayerScreen (نفس المصدر الذي
/// تستخدمه إيماءة السحب العمودي) فلا يوجد مصدران للحقيقة.
class AudioBoostSection extends StatelessWidget {
  final double boost; // من 0 إلى 200 (%)
  final ValueChanged<double> onChanged;

  const AudioBoostSection({
    super.key,
    required this.boost,
    required this.onChanged,
  });

  Color _color(double v) {
    if (v <= 100) return const Color(0xFF4FC3F7); // أزرق فاتح
    if (v <= 140) return const Color(0xFFFFB74D); // برتقالي
    return const Color(0xFFEF5350);               // أحمر
  }

  String _label(double v) {
    if (v <= 100) return 'مستوى طبيعي';
    if (v <= 130) return 'تكبير خفيف';
    if (v <= 160) return 'تكبير قوي';
    return '⚠️ تشويه محتمل';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(boost);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── العنوان الرئيسي ──
      _PanelHeader(icon: Icons.graphic_eq_rounded, title: 'تكبير الصوت'),
      const SizedBox(height: 12),

      // ── قيمة كبيرة + حالة ──
      Center(
        child: Column(children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 48,
            ),
            child: Text('${boost.round()}%'),
          ),
          const SizedBox(height: 2),
          Text(_label(boost), style: TextStyle(color: color.withOpacity(0.75), fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 12),

      // ── شريط السحب ──
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 5,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          activeTrackColor: color,
          inactiveTrackColor: Colors.white10,
          thumbColor: color,
          overlayColor: color.withOpacity(0.2),
        ),
        child: Slider(
          value: boost.clamp(50, 200),
          min: 50, max: 200,
          divisions: 30,
          onChanged: onChanged,
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('50%', style: TextStyle(color: Colors.white38, fontSize: 11)),
          Text('100%', style: TextStyle(color: Colors.white38, fontSize: 11)),
          Text('200%', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
      const SizedBox(height: 14),

      // ── أزرار سريعة ──
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        for (final val in [100.0, 130.0, 160.0, 200.0])
          _QuickBtn(
            label: '${val.toInt()}%',
            active: (boost - val).abs() < 3,
            color: _color(val),
            onTap: () => onChanged(val),
          ),
      ]),
    ]);
  }
}

/// رأس موحَّد للوحة
class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  const _PanelHeader({required this.icon, required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: c.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: c, size: 18),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          )),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.22) : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : Colors.white24, width: active ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
              color: active ? color : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }
}
