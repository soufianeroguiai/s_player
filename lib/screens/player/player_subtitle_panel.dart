import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/settings_provider.dart';

class SubtitleAppearancePanel extends StatefulWidget {
  const SubtitleAppearancePanel({super.key});
  @override
  State<SubtitleAppearancePanel> createState() => _SubtitleAppearancePanelState();
}

class _SubtitleAppearancePanelState extends State<SubtitleAppearancePanel> {
  int _open = 0;

  static const _fontList = [
    ('sans-serif', 'System Default', false),
    ('Roboto', 'Roboto', false),
    ('monospace', 'Monospace', false),
    ('Cairo', 'Cairo', true),
    ('Amiri', 'Amiri', true),
    ('Noto Naskh Arabic', 'Noto Naskh', true),
    ('Noto Kufi Arabic', 'Noto Kufi', true),
    ('Lateef', 'Lateef', true),
    ('Tajawal', 'Tajawal', true),
    ('Scheherazade New', 'Scheherazade', true),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Accordion(
            index: 0, open: _open,
            icon: Icons.text_fields_rounded,
            title: 'النص والخط',
            onToggle: (i) => setState(() => _open = _open == i ? -1 : i),
            child: _FontSection(s: s, fonts: _fontList, onPickColor: _pickColor),
          ),
          _Accordion(
            index: 1, open: _open,
            icon: Icons.palette_rounded,
            title: 'الألوان',
            onToggle: (i) => setState(() => _open = _open == i ? -1 : i),
            child: _ColorSection(s: s, onPickColor: _pickColor),
          ),
          _Accordion(
            index: 2, open: _open,
            icon: Icons.auto_fix_high_rounded,
            title: 'الحدّ والظل',
            onToggle: (i) => setState(() => _open = _open == i ? -1 : i),
            child: _EffectsSection(s: s, onPickColor: _pickColor),
          ),
          _Accordion(
            index: 3, open: _open,
            icon: Icons.vertical_align_bottom_rounded,
            title: 'الموضع',
            onToggle: (i) => setState(() => _open = _open == i ? -1 : i),
            child: _PositionSection(s: s),
          ),
        ],
      ),
    );
  }

  Future<void> _pickColor(BuildContext ctx, Color cur, ValueChanged<Color> fn) async {
    final c = await showColorPickerDialog(ctx, cur,
        title: const Text('اختر لوناً', style: TextStyle(fontWeight: FontWeight.bold)));
    fn(c);
  }
}

class _Accordion extends StatelessWidget {
  final int index, open;
  final IconData icon;
  final String title;
  final Widget child;
  final void Function(int) onToggle;
  const _Accordion({required this.index, required this.open, required this.icon,
    required this.title, required this.child, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isOpen = open == index;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isOpen ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen ? cs.primary.withOpacity(0.5) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onToggle(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Icon(icon, size: 18, color: isOpen ? cs.primary : Colors.white54),
              const SizedBox(width: 8),
              Expanded(child: Text(title,
                  style: TextStyle(
                    color: isOpen ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: isOpen ? FontWeight.w700 : FontWeight.w500,
                  ))),
              Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                  color: isOpen ? cs.primary : Colors.white38, size: 20),
            ]),
          ),
        ),
        if (isOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
            child: child,
          ),
      ]),
    );
  }
}

class _FontSection extends StatelessWidget {
  final SettingsProvider s;
  final List<(String, String, bool)> fonts;
  final Future<void> Function(BuildContext, Color, ValueChanged<Color>) onPickColor;
  const _FontSection({required this.s, required this.fonts, required this.onPickColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label('حجم الخط'),
      _SliderRow(value: s.subtitleFontSize, min: 10, max: 100,
          display: '${s.subtitleFontSize.toInt()} px',
          onChanged: s.setSubtitleFontSize, color: cs.primary),
      const SizedBox(height: 12),
      _Label('نوع الخط'),
      const SizedBox(height: 6),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 6, crossAxisSpacing: 6,
          childAspectRatio: 2.6,
        ),
        itemCount: fonts.length,
        itemBuilder: (ctx, i) {
          final (id, label, isGoogle) = fonts[i];
          final sel = s.fontFamily == id;
          return GestureDetector(
            onTap: () => s.setFontFamily(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? cs.primary.withOpacity(0.18) : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sel ? cs.primary : Colors.white.withOpacity(0.15),
                    width: sel ? 1.5 : 1),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('مرحباً Hello',
                    style: _style(id, isGoogle).copyWith(
                      fontSize: 13,
                      color: sel ? cs.primary : Colors.white,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(label,
                    style: TextStyle(fontSize: 10,
                        color: sel ? cs.primary.withOpacity(0.7) : Colors.white38),
                    maxLines: 1),
              ]),
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      _Label('وزن الخط'),
      const SizedBox(height: 6),
      Row(children: [
        for (final (i, lbl, fw) in [
          (0, 'خفيف', FontWeight.w300), (1, 'عادي', FontWeight.normal),
          (2, 'متوسط', FontWeight.w500), (3, 'عريض', FontWeight.bold),
        ]) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: GestureDetector(
              onTap: () => s.setFontWeightIndex(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: s.fontWeightIndex == i
                      ? cs.primary.withOpacity(0.2)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: s.fontWeightIndex == i ? cs.primary : Colors.white24),
                ),
                child: Center(
                  child: Text(lbl,
                      style: TextStyle(
                        color: s.fontWeightIndex == i ? cs.primary : Colors.white54,
                        fontWeight: fw, fontSize: 11,
                      )),
                ),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _Chip(label: 'مائل', icon: Icons.format_italic_rounded,
            value: s.subtitleItalic, onChanged: s.setSubtitleItalic, color: cs.primary)),
        const SizedBox(width: 8),
        Expanded(child: _Chip(label: 'يمين←يسار', icon: Icons.format_textdirection_r_to_l_rounded,
            value: s.subtitleRTL, onChanged: s.setSubtitleRTL, color: cs.secondary)),
      ]),
    ]);
  }

  TextStyle _style(String id, bool isGoogle) {
    if (!isGoogle) return TextStyle(fontFamily: id == 'Roboto' ? null : id);
    try {
      final name = id.replaceAll(' New', '').replaceAll(' Arabic', '');
      return GoogleFonts.getFont(name);
    } catch (_) { return const TextStyle(); }
  }
}

class _ColorSection extends StatelessWidget {
  final SettingsProvider s;
  final Future<void> Function(BuildContext, Color, ValueChanged<Color>) onPickColor;
  const _ColorSection({required this.s, required this.onPickColor});

  static const _textColors = [
    Colors.white, Colors.yellow, Color(0xFFFFE680),
    Color(0xFF80FF80), Color(0xFF80D4FF), Color(0xFFFFB3B3),
  ];
  static const _bgColors = [
    Colors.black, Color(0xFF1A1A1A), Color(0xFF001133),
    Color(0xFF002200), Color(0xFF220000), Color(0xFF222200),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label('لون النص'),
      const SizedBox(height: 6),
      _ColorRow(
        colors: _textColors, selected: s.subtitleColor,
        onSelect: s.setSubtitleColor,
        onCustom: () => onPickColor(context, s.subtitleColor, s.setSubtitleColor),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _Label('خلفية النص')),
        Switch(value: s.subtitleBgOpacity > 0,
            onChanged: (v) => s.setSubtitleBgOpacity(v ? 0.65 : 0.0),
            activeColor: cs.primary),
      ]),
      const SizedBox(height: 6),
      _ColorRow(
        colors: _bgColors, selected: s.subtitleBgColor,
        onSelect: s.setSubtitleBgColor,
        onCustom: () => onPickColor(context, s.subtitleBgColor, s.setSubtitleBgColor),
      ),
      if (s.subtitleBgOpacity > 0) ...[
        const SizedBox(height: 8),
        _SliderRow(value: s.subtitleBgOpacity, min: 0.1, max: 1.0,
            display: '${(s.subtitleBgOpacity * 100).toInt()}%',
            onChanged: s.setSubtitleBgOpacity, color: cs.primary),
      ],
      const SizedBox(height: 14),
      _Label('معاينة'),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Center(
          child: Text('مرحباً • Hello World',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: (s.subtitleFontSize * 0.55).clamp(12.0, 32.0),
                color: s.subtitleColor,
                fontWeight: _fw(s.fontWeightIndex),
                fontStyle: s.subtitleItalic ? FontStyle.italic : FontStyle.normal,
                backgroundColor: s.subtitleBgColor.withOpacity(s.subtitleBgOpacity),
              )),
        ),
      ),
    ]);
  }

  FontWeight _fw(int i) => [FontWeight.w300, FontWeight.normal, FontWeight.w500, FontWeight.bold][i.clamp(0, 3)];
}

class _EffectsSection extends StatelessWidget {
  final SettingsProvider s;
  final Future<void> Function(BuildContext, Color, ValueChanged<Color>) onPickColor;
  const _EffectsSection({required this.s, required this.onPickColor});

  static const _shadowColors = [
    Colors.black, Color(0xFF0D0D0D), Color(0xFF1A1A2E),
    Color(0xFF003366), Color(0xFF330000), Colors.white,
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SwitchRow(label: 'حدّ خارجي للنص', value: s.outlineEnabled, onChanged: s.setOutlineEnabled, color: cs.primary),
      if (s.outlineEnabled) ...[
        const SizedBox(height: 6),
        _ColorRow(colors: _shadowColors, selected: s.outlineColor,
            onSelect: s.setOutlineColor,
            onCustom: () => onPickColor(context, s.outlineColor, s.setOutlineColor)),
        const SizedBox(height: 6),
        _SliderRow(value: s.outlineWidth, min: 0.5, max: 6.0,
            display: 'سماكة ${s.outlineWidth.toStringAsFixed(1)}',
            onChanged: s.setOutlineWidth, color: cs.primary),
      ],
      const SizedBox(height: 10),
      _SwitchRow(label: 'ظل النص', value: s.textShadowEnabled, onChanged: s.setTextShadowEnabled, color: cs.secondary),
      if (s.textShadowEnabled) ...[
        const SizedBox(height: 6),
        _ColorRow(colors: _shadowColors, selected: s.textShadowColor,
            onSelect: s.setTextShadowColor,
            onCustom: () => onPickColor(context, s.textShadowColor, s.setTextShadowColor)),
        const SizedBox(height: 6),
        _SliderRow(value: s.textShadowBlurRadius, min: 0, max: 20,
            display: 'ضبابية ${s.textShadowBlurRadius.toInt()}',
            onChanged: s.setTextShadowBlurRadius, color: cs.secondary),
      ],
      const SizedBox(height: 10),
      _SwitchRow(label: 'ظل الصندوق', value: s.boxShadowEnabled, onChanged: s.setBoxShadowEnabled, color: cs.tertiary),
      if (s.boxShadowEnabled) ...[
        const SizedBox(height: 6),
        _ColorRow(colors: _shadowColors, selected: s.boxShadowColor,
            onSelect: s.setBoxShadowColor,
            onCustom: () => onPickColor(context, s.boxShadowColor, s.setBoxShadowColor)),
        const SizedBox(height: 6),
        _SliderRow(value: s.boxShadowBlurRadius, min: 0, max: 20,
            display: 'ضبابية ${s.boxShadowBlurRadius.toInt()}',
            onChanged: s.setBoxShadowBlurRadius, color: cs.tertiary),
      ],
    ]);
  }
}

class _PositionSection extends StatelessWidget {
  final SettingsProvider s;
  const _PositionSection({required this.s});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label('الارتفاع عن الأسفل'),
      _SliderRow(value: s.bottomPadding, min: 0, max: 300,
          display: '${s.bottomPadding.toInt()} px',
          onChanged: s.setBottomPadding, color: cs.primary),
      const SizedBox(height: 10),
      _Label('الهامش الأفقي'),
      _SliderRow(value: s.horizontalMargin, min: 0, max: 120,
          display: '${s.horizontalMargin.toInt()} px',
          onChanged: s.setHorizontalMargin, color: cs.primary),
    ]);
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600));
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;
  const _SwitchRow({required this.label, required this.value, required this.onChanged, required this.color});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          Switch(value: value, onChanged: onChanged, activeColor: color),
        ],
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;
  const _Chip({required this.label, required this.icon, required this.value,
    required this.onChanged, required this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: value ? color.withOpacity(0.18) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: value ? color : Colors.white24),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: value ? color : Colors.white38),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: value ? color : Colors.white54)),
          ]),
        ),
      );
}

class _ColorRow extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelect;
  final VoidCallback onCustom;
  const _ColorRow({required this.colors, required this.selected,
    required this.onSelect, required this.onCustom});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final c in colors)
        GestureDetector(
          onTap: () => onSelect(c),
          child: Container(
            margin: const EdgeInsets.only(left: 5),
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected.value == c.value ? Colors.white : Colors.white30,
                width: selected.value == c.value ? 2.5 : 1,
              ),
            ),
            child: selected.value == c.value
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
        ),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: onCustom,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white38),
            gradient: const SweepGradient(colors: [
              Colors.red, Colors.yellow, Colors.green,
              Colors.cyan, Colors.blue, Colors.purple, Colors.red,
            ]),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
        ),
      ),
    ]);
  }
}

class _SliderRow extends StatelessWidget {
  final double value, min, max;
  final String display;
  final ValueChanged<double> onChanged;
  final Color color;
  const _SliderRow({required this.value, required this.min, required this.max,
    required this.display, required this.onChanged, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: color,
            inactiveTrackColor: Colors.white12,
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
          ),
          child: Slider(
              value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ),
      ),
      SizedBox(
        width: 70,
        child: Text(display, textAlign: TextAlign.end,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    ]);
  }
}