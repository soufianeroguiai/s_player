import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

Widget _buildSliderRow({
  required String title,
  required double value,
  required double min,
  required double max,
  required String label,
  required ValueChanged<double> onChanged,
  required Color activeColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
            Text(label, style: TextStyle(color: activeColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: activeColor,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    ),
  );
}

Widget buildSubtitleSettingsContent(BuildContext context) {
  final s = context.watch<SettingsProvider>();
  final cs = Theme.of(context).colorScheme;

  final List<String> availableFonts = ['Default', 'Adobe Arabic', 'Cairo', 'Amiri', 'Roboto'];
  if (!availableFonts.contains(s.fontFamily) && s.fontFamily != 'Default') {
    availableFonts.add(s.fontFamily);
  }

  return Directionality(
    textDirection: TextDirection.rtl,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('الخط', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableFonts.map((font) {
            final isSelected = s.fontFamily == font;
            return ChoiceChip(
              label: Text(font.split('/').last,
                  style: TextStyle(
                    color: isSelected ? cs.onPrimary : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  )),
              selected: isSelected,
              onSelected: (_) => s.setFontFamily(font),
              selectedColor: cs.primary,
              backgroundColor: isSelected ? cs.primary : Colors.grey[850]!,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _buildSliderRow(
          title: 'حجم الخط', value: s.subtitleFontSize, min: 10, max: 150,
          label: '${s.subtitleFontSize.toInt()} px',
          onChanged: (v) => s.setSubtitleFontSize(v), activeColor: cs.primary,
        ),
        _buildSliderRow(
          title: 'الهامش السفلي', value: s.bottomPadding, min: 0, max: 300,
          label: '${s.bottomPadding.toInt()} px',
          onChanged: (v) => s.setBottomPadding(v), activeColor: cs.primary,
        ),
        _buildSliderRow(
          title: 'الهامش الجانبي', value: s.horizontalMargin, min: 0, max: 100,
          label: '${s.horizontalMargin.toInt()} px',
          onChanged: (v) => s.setHorizontalMargin(v), activeColor: cs.primary,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('مائل', style: TextStyle(color: Colors.white, fontSize: 14)),
            Switch(
              value: s.subtitleItalic,
              onChanged: (v) => s.setSubtitleItalic(v),
              activeColor: cs.primary,
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('اتجاه النص (RTL)', style: TextStyle(color: Colors.white, fontSize: 14)),
            Switch(
              value: s.subtitleRTL,
              onChanged: (v) => s.setSubtitleRTL(v),
              activeColor: cs.primary,
            ),
          ],
        ),
        const Divider(color: Colors.white24, height: 24),
        const Text('الألوان والخلفية', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildColorPickerRow(context, 'لون النص', s.subtitleColor, (c) => s.setSubtitleColor(c)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('لون الخلفية', style: TextStyle(color: Colors.white, fontSize: 14)),
            GestureDetector(
              onTap: () async {
                final newColor = await showDialog<Color>(
                  context: context,
                  builder: (_) => _SimpleColorPicker(initialColor: s.subtitleBgColor),
                );
                if (newColor != null) s.setSubtitleBgColor(newColor);
              },
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: s.subtitleBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white30),
                ),
              ),
            ),
          ],
        ),
        if (s.subtitleBgOpacity > 0) ...[
          const SizedBox(height: 8),
          _buildSliderRow(
            title: 'شفافية الخلفية', value: s.subtitleBgOpacity, min: 0.0, max: 1.0,
            label: '${(s.subtitleBgOpacity * 100).toInt()}%',
            onChanged: (v) => s.setSubtitleBgOpacity(v), activeColor: cs.primary,
          ),
        ],
        const Divider(color: Colors.white24, height: 24),
        const Text('تأثيرات الظل', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('تفعيل ظل النص', style: TextStyle(color: Colors.white, fontSize: 14)),
            Switch(
              value: s.textShadowEnabled,
              onChanged: (v) => s.setTextShadowEnabled(v),
              activeColor: cs.primary,
            ),
          ],
        ),
        if (s.textShadowEnabled) ...[
          const SizedBox(height: 8),
          _buildColorPickerRow(context, 'لون الظل', s.textShadowColor, (c) => s.setTextShadowColor(c)),
          _buildSliderRow(
            title: 'قوة الظل', value: s.textShadowBlurRadius, min: 0, max: 20,
            label: '${s.textShadowBlurRadius.toInt()}',
            onChanged: (v) => s.setTextShadowBlurRadius(v), activeColor: cs.primary,
          ),
          _buildSliderRow(
            title: 'إزاحة أفقية (X)', value: s.textShadowOffsetX, min: -10, max: 10,
            label: '${s.textShadowOffsetX.toInt()}',
            onChanged: (v) => s.setTextShadowOffsetX(v), activeColor: cs.primary,
          ),
          _buildSliderRow(
            title: 'إزاحة رأسية (Y)', value: s.textShadowOffsetY, min: -10, max: 10,
            label: '${s.textShadowOffsetY.toInt()}',
            onChanged: (v) => s.setTextShadowOffsetY(v), activeColor: cs.primary,
          ),
        ],
      ],
    ),
  );
}

Widget _buildColorPickerRow(BuildContext context, String title, Color currentColor, ValueChanged<Color> onColorChanged) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      GestureDetector(
        onTap: () async {
          final newColor = await showDialog<Color>(
            context: context,
            builder: (_) => _SimpleColorPicker(initialColor: currentColor),
          );
          if (newColor != null) onColorChanged(newColor);
        },
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: currentColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white30),
          ),
        ),
      ),
    ],
  );
}

class _SimpleColorPicker extends StatefulWidget {
  final Color initialColor;
  const _SimpleColorPicker({required this.initialColor});

  @override
  State<_SimpleColorPicker> createState() => _SimpleColorPickerState();
}

class _SimpleColorPickerState extends State<_SimpleColorPicker> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.white, Colors.yellow, Colors.cyanAccent, Colors.greenAccent,
      Colors.red, Colors.blue, Colors.orange, Colors.purple, Colors.black,
    ];
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('اختر لوناً', style: TextStyle(color: Colors.white)),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: colors.map((c) => GestureDetector(
          onTap: () => setState(() => _selectedColor = c),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedColor == c ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
          ),
        )).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedColor),
          child: const Text('موافق'),
        ),
      ],
    );
  }
}