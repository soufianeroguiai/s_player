import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AudioBoostSection extends StatelessWidget {
  final double boost;
  final ValueChanged<double> onChanged;

  const AudioBoostSection({super.key, required this.boost, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Row(children: [
        const Icon(Symbols.volume_up_rounded, color: Colors.white70),
        const SizedBox(width: 8),
        const Expanded(child: Text('مستوى الصوت', style: TextStyle(color: Colors.white))),
        Text('${boost.round()}%', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
      ]),
      Slider(
        value: boost.clamp(50, 200), min: 50, max: 200, divisions: 30,
        onChanged: onChanged, activeColor: cs.primary,
      ),
    ]);
  }
}