import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class SubtitleAppearancePanel extends StatelessWidget {
  const SubtitleAppearancePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Row(children: [
        const Icon(Symbols.format_size_rounded, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Text('الحجم', style: TextStyle(color: Colors.white))),
        Text('${s.subtitleFontSize.toInt()}', style: TextStyle(color: cs.primary)),
      ]),
      Slider(
        value: s.subtitleFontSize, min: 12, max: 80,
        onChanged: s.setSubtitleFontSize,
        activeColor: cs.primary,
      ),
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Symbols.format_paint_rounded, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Text('اللون', style: TextStyle(color: Colors.white))),
        GestureDetector(
          onTap: () => _showColorPicker(context, s.subtitleColor, s.setSubtitleColor),
          child: Container(width: 24, height: 24, decoration: BoxDecoration(color: s.subtitleColor, shape: BoxShape.circle)),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Symbols.format_italic_rounded, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Text('مائل', style: TextStyle(color: Colors.white))),
        Switch(value: s.subtitleItalic, onChanged: s.setSubtitleItalic, activeColor: cs.primary),
      ]),
    ]);
  }

  void _showColorPicker(BuildContext ctx, Color current, ValueChanged<Color> onChanged) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('اختر لون'),
        content: SizedBox(
          width: 280,
          height: 280,
          child: GridView.count(
            crossAxisCount: 5,
            children: [Colors.white, Colors.yellow, Colors.cyan, Colors.lime, Colors.orange, Colors.red, Colors.green, Colors.blue, Colors.purple, Colors.pink].map((c) => GestureDetector(
              onTap: () { onChanged(c); Navigator.pop(ctx); },
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: current == c ? Colors.white : Colors.transparent, width: 3)),
              ),
            )).toList(),
          ),
        ),
      ),
    );
  }
}