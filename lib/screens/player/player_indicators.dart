import 'package:flutter/material.dart';

/// مؤشرات عائمة بتصميم أيقوني متحرك (دائرة + شريط تقدم + نسبة).
class PlayerIndicators {
  static Widget buildFloatingIndicator({
    required IconData icon,
    required double displayValue,   // 0.0 → 1.0
    required String labelText,
    required Color color,
  }) {
    return _AnimatedIndicator(
      icon: icon,
      value: displayValue.clamp(0.0, 1.0),
      label: labelText,
      color: color,
    );
  }
}

/// دائرة متحركة بشريط تقدم ونسبة مئوية.
class _AnimatedIndicator extends StatelessWidget {
  final IconData icon;
  final double value;
  final String label;
  final Color color;

  const _AnimatedIndicator({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xDD111111),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(0.6),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // شريط التقدم الدائري (الحركة)
          CircularProgressIndicator(
            value: value,
            strokeWidth: 3.5,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          // الأيقونة والنسبة
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}