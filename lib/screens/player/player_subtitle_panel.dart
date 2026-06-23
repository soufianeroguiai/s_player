import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/settings_provider.dart';

/// لوحة إعدادات الترجمة الشاملة — منظَّمة في أقسام:
///   ① النص والخط        ② الألوان        ③ الحدّ والظل        ④ الموضع
class SubtitleAppearancePanel extends StatefulWidget {
  const SubtitleAppearancePanel({super.key});
  @override
  State<SubtitleAppearancePanel> createState() => _SubtitleAppearancePanelState();
}

class _SubtitleAppearancePanelState extends State<SubtitleAppearancePanel> {
  int _openSection = 0; // القسم المفتوح حالياً (accordion)

  // ── قائمة الخطوط المدعومة مع معاينة حية ──
  static const _fonts = [
    ('Roboto', 'Roboto', false),
    ('sans-serif', 'System Default', false),
    ('monospace', 'Monospace', false),
    ('Cairo', 'Cairo', true),
    ('Amiri', 'Amiri', true),
    ('Noto Naskh Arabic', 'Noto Naskh', true),
    ('Noto Kufi Arabic', 'Noto Kufi', true),   // بديل حرفي لـ Adobe Arabic
    ('Lateef', 'Lateef', true),
    ('Tajawal', 'Tajawal', true),
    ('Scheherazade New', 'Scheherazade', true),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section(
            index: 0,
            openIndex: _openSection,
            icon: Icons.text_fields_rounded,
            title: 'النص والخط',
            onTap: (i) => setState(() => _openSection = _openSection == i ? -1 : i),
            child: _buildTextSection(s, cs),
          ),
          _Section(
            index: 1,
            openIndex: _openSection,
            icon: Icons.palette_rounded,
            title: 'الألوان',
            onTap: (i) => setState(() => _openSection = _openSection == i ? -1 : i),
            child: _buildColorsSection(s, cs),
          ),
          _Section(
            index: 2,
            openIndex: _openSection,
            icon: Icons.blur_on_rounded,
            title: 'الحدّ والظل',
            onTap: (i) => setState(() => _openSection = _openSection == i ? -1 : i),
            child: _buildEffectsSection(s, cs),
          ),
          _Section(
            index: 3,
            openIndex: _openSection,
            icon: Icons.vertical_align_bottom_rounded,
            title: 'الموضع والمحاذاة',
            onTap: (i) => setState(() => _openSection = _openSection == i ? -1 : i),
            child: _buildPositionSection(s, cs),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // ① قسم النص والخط
  // ──────────────────────────────────────────────
  Widget _buildTextSection(SettingsProvider s, ColorScheme cs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // حجم الخط
      _SubLabel('حجم الخط'),
      _SliderRow(
        value: s.subtitleFontSize,
        min: 10, max: 100,
        display: '${s.subtitleFontSize.toInt()} px',
        onChanged: s.setSubtitleFontSize,
        activeColor: cs.primary,
      ),
      const SizedBox(height: 16),
      // اختيار الخط مع معاينة حية
      _SubLabel('نوع الخط'),
      const SizedBox(height: 8),
      _FontPicker(fonts: _fonts, selected: s.fontFamily, onSelect: s.setFontFamily),
      const SizedBox(height: 16),
      // وزن الخط
      _SubLabel('وزن الخط'),
      const SizedBox(height: 8),
      _FontWeightPicker(index: s.fontWeightIndex, onChanged: s.setFontWeightIndex, primaryColor: cs.primary),
      const SizedBox(height: 12),
      // مائل + RTL
      Row(children: [
        Expanded(child: _ToggleChip(
          label: 'مائل',
          icon: Icons.format_italic_rounded,
          value: s.subtitleItalic,
          onChanged: s.setSubtitleItalic,
          color: cs.primary,
        )),
        const SizedBox(width: 8),
        Expanded(child: _ToggleChip(
          label: 'RTL يمين→يسار',
          icon: Icons.format_textdirection_r_to_l_rounded,
          value: s.subtitleRTL,
          onChanged: s.setSubtitleRTL,
          color: cs.secondary,
        )),
      ]),
    ]);
  }

  // ──────────────────────────────────────────────
  // ② قسم الألوان
  // ──────────────────────────────────────────────
  Widget _buildColorsSection(SettingsProvider s, ColorScheme cs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // لون النص
      _SubLabel('لون النص'),
      const SizedBox(height: 8),
      _ColorStrip(
        colors: _textPresets,
        selected: s.subtitleColor,
        onSelect: s.setSubtitleColor,
        onCustom: () => _pickColor(context, s.subtitleColor, s.setSubtitleColor),
      ),
      const SizedBox(height: 16),
      // خلفية النص
      _SubLabel('خلفية النص'),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _ColorStrip(
          colors: _bgPresets,
          selected: s.subtitleBgColor,
          onSelect: s.setSubtitleBgColor,
          onCustom: () => _pickColor(context, s.subtitleBgColor, s.setSubtitleBgColor),
        )),
        const SizedBox(width: 8),
        Switch(
          value: s.subtitleBgOpacity > 0,
          onChanged: (v) => s.setSubtitleBgOpacity(v ? 0.65 : 0.0),
          activeColor: cs.primary,
        ),
      ]),
      if (s.subtitleBgOpacity > 0) ...[
        const SizedBox(height: 8),
        _SliderRow(
          value: s.subtitleBgOpacity,
          min: 0.1, max: 1.0,
          display: '${(s.subtitleBgOpacity * 100).toInt()}%',
          onChanged: s.setSubtitleBgOpacity,
          activeColor: cs.primary,
        ),
      ],
      // ── معاينة حية ──
      const SizedBox(height: 16),
      _SubLabel('معاينة'),
      const SizedBox(height: 8),
      _SubtitlePreview(s: s),
    ]);
  }

  // ──────────────────────────────────────────────
  // ③ قسم الحدّ والظل
  // ──────────────────────────────────────────────
  Widget _buildEffectsSection(SettingsProvider s, ColorScheme cs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ─ الحدّ الخارجي ─
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _SubLabel('حدّ خارجي للنص'),
        Switch(value: s.outlineEnabled, onChanged: s.setOutlineEnabled, activeColor: cs.primary),
      ]),
      if (s.outlineEnabled) ...[
        _ColorStrip(
          colors: _shadowPresets,
          selected: s.outlineColor,
          onSelect: s.setOutlineColor,
          onCustom: () => _pickColor(context, s.outlineColor, s.setOutlineColor),
        ),
        const SizedBox(height: 8),
        _SliderRow(
          value: s.outlineWidth, min: 0.5, max: 6.0,
          display: 'سماكة ${s.outlineWidth.toStringAsFixed(1)}',
          onChanged: s.setOutlineWidth,
          activeColor: cs.primary,
        ),
      ],
      const SizedBox(height: 16),
      // ─ ظل النص ─
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _SubLabel('ظل النص'),
        Switch(value: s.textShadowEnabled, onChanged: s.setTextShadowEnabled, activeColor: cs.secondary),
      ]),
      if (s.textShadowEnabled) ...[
        _ColorStrip(
          colors: _shadowPresets,
          selected: s.textShadowColor,
          onSelect: s.setTextShadowColor,
          onCustom: () => _pickColor(context, s.textShadowColor, s.setTextShadowColor),
        ),
        const SizedBox(height: 8),
        _SliderRow(
          value: s.textShadowBlurRadius, min: 0, max: 20,
          display: 'ضبابية ${s.textShadowBlurRadius.toInt()}',
          onChanged: s.setTextShadowBlurRadius,
          activeColor: cs.secondary,
        ),
      ],
      const SizedBox(height: 16),
      // ─ ظل الصندوق ─
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _SubLabel('ظل الصندوق'),
        Switch(value: s.boxShadowEnabled, onChanged: s.setBoxShadowEnabled, activeColor: cs.tertiary),
      ]),
      if (s.boxShadowEnabled) ...[
        _ColorStrip(
          colors: _shadowPresets,
          selected: s.boxShadowColor,
          onSelect: s.setBoxShadowColor,
          onCustom: () => _pickColor(context, s.boxShadowColor, s.setBoxShadowColor),
        ),
        const SizedBox(height: 8),
        _SliderRow(
          value: s.boxShadowBlurRadius, min: 0, max: 20,
          display: 'ضبابية ${s.boxShadowBlurRadius.toInt()}',
          onChanged: s.setBoxShadowBlurRadius,
          activeColor: cs.tertiary,
        ),
        Row(children: [
          Expanded(child: _SliderRow(
            value: s.boxShadowOffsetX, min: -10, max: 10,
            display: 'أفقي ${s.boxShadowOffsetX.toStringAsFixed(1)}',
            onChanged: s.setBoxShadowOffsetX,
            activeColor: cs.tertiary,
          )),
          Expanded(child: _SliderRow(
            value: s.boxShadowOffsetY, min: -10, max: 10,
            display: 'رأسي ${s.boxShadowOffsetY.toStringAsFixed(1)}',
            onChanged: s.setBoxShadowOffsetY,
            activeColor: cs.tertiary,
          )),
        ]),
      ],
    ]);
  }

  // ──────────────────────────────────────────────
  // ④ قسم الموضع والمحاذاة
  // ──────────────────────────────────────────────
  Widget _buildPositionSection(SettingsProvider s, ColorScheme cs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SubLabel('الارتفاع عن أسفل الشاشة'),
      _SliderRow(
        value: s.bottomPadding, min: 0, max: 300,
        display: '${s.bottomPadding.toInt()} px',
        onChanged: s.setBottomPadding,
        activeColor: cs.primary,
      ),
      const SizedBox(height: 12),
      _SubLabel('الهامش الأفقي'),
      _SliderRow(
        value: s.horizontalMargin, min: 0, max: 120,
        display: '${s.horizontalMargin.toInt()} px',
        onChanged: s.setHorizontalMargin,
        activeColor: cs.primary,
      ),
    ]);
  }

  Future<void> _pickColor(BuildContext ctx, Color current, ValueChanged<Color> onPicked) async {
    final picked = await showColorPickerDialog(ctx, current,
        title: const Text('اختر لون', style: TextStyle(fontWeight: FontWeight.bold)));
    onPicked(picked);
  }

  // ── ألوان سريعة مقترحة ──
  static const _textPresets = [
    Colors.white, Colors.yellow, Color(0xFFFFE680),
    Color(0xFF80FF80), Color(0xFF80D4FF), Color(0xFFFFB3B3),
  ];
  static const _bgPresets = [
    Colors.black, Color(0xFF1A1A1A), Color(0xFF001133),
    Color(0xFF002200), Color(0xFF220000), Color(0xFF222200),
  ];
  static const _shadowPresets = [
    Colors.black, Color(0xFF1A1A2E), Color(0xFF0D0D0D),
    Color(0xFF003366), Color(0xFF330000), Colors.white,
  ];
}

// ══════════════════════════════════════════════
// Widgets المساعدة
// ══════════════════════════════════════════════

/// عنوان فرعي موحَّد
class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white70,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
}

/// قسم accordion قابل للطي
class _Section extends StatelessWidget {
  final int index;
  final int openIndex;
  final IconData icon;
  final String title;
  final Widget child;
  final void Function(int) onTap;
  const _Section({
    required this.index,
    required this.openIndex,
    required this.icon,
    required this.title,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final open = openIndex == index;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: open ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: open ? cs.primary.withOpacity(0.4) : Colors.white12,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onTap(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Icon(icon, size: 20, color: open ? cs.primary : Colors.white54),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                      color: open ? Colors.white : Colors.white70,
                      fontWeight: open ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    )),
              ),
              Icon(
                open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: open ? cs.primary : Colors.white38,
                size: 20,
              ),
            ]),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: child,
          ),
      ]),
    );
  }
}

/// منتقي خط مع معاينة حية لكل خط
class _FontPicker extends StatelessWidget {
  final List<(String, String, bool)> fonts;
  final String selected;
  final ValueChanged<String> onSelect;
  const _FontPicker({required this.fonts, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (id, label, isGoogle) in fonts)
        GestureDetector(
          onTap: () => onSelect(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected == id ? cs.primary.withOpacity(0.2) : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected == id ? cs.primary : Colors.white24,
                width: selected == id ? 1.5 : 1,
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                'مرحباً Hello',
                style: _fontStyle(id, isGoogle).copyWith(
                  fontSize: 15,
                  color: selected == id ? cs.primary : Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: selected == id ? cs.primary.withOpacity(0.8) : Colors.white38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ),
        ),
    ]);
  }

  TextStyle _fontStyle(String id, bool isGoogle) {
    if (!isGoogle) return TextStyle(fontFamily: id == 'Roboto' ? null : id);
    try {
      return GoogleFonts.getFont(id.replaceAll(' New', '').replaceAll(' Arabic', ''));
    } catch (_) {
      return const TextStyle();
    }
  }
}

/// منتقي وزن الخط
class _FontWeightPicker extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final Color primaryColor;
  const _FontWeightPicker({required this.index, required this.onChanged, required this.primaryColor});

  static const _weights = [
    (0, 'خفيف', FontWeight.w300),
    (1, 'عادي', FontWeight.normal),
    (2, 'متوسط', FontWeight.w500),
    (3, 'عريض', FontWeight.bold),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final (i, label, fw) in _weights) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: index == i ? primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: index == i ? primaryColor : Colors.white24),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: index == i ? primaryColor : Colors.white54,
                    fontWeight: fw,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// toggle chip موحَّد
class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;
  const _ToggleChip({required this.label, required this.icon, required this.value, required this.onChanged, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: value ? color.withOpacity(0.18) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: value ? color : Colors.white24),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: value ? color : Colors.white38),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: value ? color : Colors.white54)),
        ]),
      ),
    );
  }
}

/// شريط ألوان سريعة مع زر "مخصص"
class _ColorStrip extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelect;
  final VoidCallback onCustom;
  const _ColorStrip({required this.colors, required this.selected, required this.onSelect, required this.onCustom});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final c in colors)
        GestureDetector(
          onTap: () => onSelect(c),
          child: Container(
            margin: const EdgeInsets.only(left: 6),
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected == c ? Colors.white : Colors.white24,
                width: selected == c ? 2.5 : 1,
              ),
            ),
            child: selected == c
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
          ),
        ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onCustom,
        child: Container(
          width: 32, height: 32,
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

/// معاينة حية للترجمة
class _SubtitlePreview extends StatelessWidget {
  final SettingsProvider s;
  const _SubtitlePreview({required this.s});

  @override
  Widget build(BuildContext context) {
    TextStyle style = TextStyle(
      fontSize: (s.subtitleFontSize * 0.6).clamp(12, 36),
      color: s.subtitleColor,
      fontWeight: _fw(s.fontWeightIndex),
      fontStyle: s.subtitleItalic ? FontStyle.italic : FontStyle.normal,
      backgroundColor: s.subtitleBgColor.withOpacity(s.subtitleBgOpacity),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: Text('مرحباً • Hello World', style: style, textAlign: TextAlign.center),
      ),
    );
  }

  FontWeight _fw(int i) {
    switch (i) {
      case 0: return FontWeight.w300;
      case 1: return FontWeight.normal;
      case 3: return FontWeight.bold;
      default: return FontWeight.w500;
    }
  }
}

/// slider موحَّد
class _SliderRow extends StatelessWidget {
  final double value, min, max;
  final String display;
  final ValueChanged<double> onChanged;
  final Color activeColor;
  const _SliderRow({required this.value, required this.min, required this.max,
    required this.display, required this.onChanged, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: activeColor,
            inactiveTrackColor: Colors.white12,
            thumbColor: activeColor,
            overlayColor: activeColor.withOpacity(0.2),
          ),
          child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ),
      ),
      SizedBox(
        width: 72,
        child: Text(display,
            textAlign: TextAlign.end,
            style: TextStyle(color: activeColor, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    ]);
  }
}
