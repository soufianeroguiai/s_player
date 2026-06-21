import 'package:flutter/material.dart';

class AudioBoostSection extends StatefulWidget {
  final double boost;
  final ValueChanged<double> onChanged;
  const AudioBoostSection({super.key, required this.boost, required this.onChanged});
  @override
  State<AudioBoostSection> createState() => _AudioBoostSectionState();
}

class _AudioBoostSectionState extends State<AudioBoostSection> {
  late double _local;
  @override
  void initState() {
    super.initState();
    _local = widget.boost;
  }

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
    final color = _boostColor(_local);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('تكبير الصوت',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        Text(_boostLabel(_local), style: TextStyle(color: color, fontSize: 11)),
      ]),
      const SizedBox(height: 6),
      AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 36),
        child: Text('${_local.round()}%'),
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
        child: Slider(
            value: _local,
            min: 50,
            max: 200,
            divisions: 30,
            onChanged: (v) {
              setState(() => _local = v);
              widget.onChanged(v);
            }),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        for (final val in [100.0, 130.0, 160.0, 200.0])
          QuickBtn(
              label: '${val.toInt()}%',
              active: (_local - val).abs() < 2,
              color: _boostColor(val),
              onTap: () {
                setState(() => _local = val);
                widget.onChanged(val);
              }),
      ]),
    ]);
  }
}

class QuickBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const QuickBtn(
      {super.key, required this.label, required this.active, required this.color, required this.onTap});
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
                color: active ? color : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}