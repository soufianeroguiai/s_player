import 'package:flutter/material.dart';

/// مؤشرات الصوت والسطوع العائمة — مصمّمة لتكون مرئية على أي خلفية
/// (سواء كانت سوداء أو فاتحة) عبر حدّ ناصع + ظل واضح + لون مميّز.
class PlayerIndicators {
  static Widget buildFloatingIndicator({
    required IconData icon,
    required double displayValue,   // 0.0 → 1.0
    required String labelText,
    required Color color,
  }) {
    return _FloatingBar(
      icon: icon,
      value: displayValue.clamp(0.0, 1.0),
      label: labelText,
      color: color,
    );
  }
}

class _FloatingBar extends StatelessWidget {
  final IconData icon;
  final double value;
  final String label;
  final Color color;

  const _FloatingBar({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 210,
      decoration: BoxDecoration(
        // خلفية داكنة شبه شفافة مع border واضح
        color: const Color(0xCC111111),
        borderRadius: BorderRadius.circular(29),
        border: Border.all(color: color.withOpacity(0.7), width: 1.5),
        boxShadow: [
          // ظل ملوّن خارجي يجعل الـ indicator مرئياً حتى على خلفية سوداء
          BoxShadow(
            color: color.withOpacity(0.45),
            blurRadius: 14,
            spreadRadius: 1,
          ),
          // ظل أسود داخلي لرفع التباين
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 4,
            spreadRadius: -2,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // أيقونة علوية
          Icon(icon, color: color, size: 20),

          // شريط تقدم عمودي
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _VerticalBar(value: value, color: color),
            ),
          ),

          // النسبة المئوية
          Text(
            labelText,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalBar extends StatelessWidget {
  final double value;
  final Color color;
  const _VerticalBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final totalH = constraints.maxHeight;
      final filledH = totalH * value;
      return Stack(alignment: Alignment.bottomCenter, children: [
        // الخلفية (الجزء الفارغ)
        Container(
          width: 8,
          height: totalH,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        // الجزء الممتلئ
        AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 8,
          height: filledH.clamp(0, totalH),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                color,
                color.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 6),
            ],
          ),
        ),
      ]);
    });
  }
}
