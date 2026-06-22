import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/settings_provider.dart';

/// محتوى لوحة تخصيص مظهر الترجمة بالكامل: الخط، الألوان، الحدّ
/// الخارجي (Outline)، ظل النص، وظل الصندوق المحيط.
class SubtitleAppearancePanel extends StatelessWidget {
  const SubtitleAppearancePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SliderRow(
            title: 'حجم الخط',
            value: s.subtitleFontSize,
            min: 10,
            max: 100,
            label: '${s.subtitleFontSize.toInt()} px',
            onChanged: s.setSubtitleFontSize,
            activeColor: cs.primary,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('نوع الخط', style: TextStyle(color: Colors.white, fontSize: 14)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.fontFamily, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const Icon(Icons.arrow_drop_down, color: Colors.white70),
              ],
            ),
            onTap: () => _showFontPicker(context, s),
          ),

          const Divider(color: Colors.white24, height: 24),

          // ── ألوان النص والخلفية ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('لون النص', style: TextStyle(color: Colors.white, fontSize: 14)),
              GestureDetector(
                onTap: () async {
                  final color = await showColorPickerDialog(context, s.subtitleColor);
                  s.setSubtitleColor(color);
                },
                child: ColorIndicator(color: s.subtitleColor, width: 30, height: 30, borderRadius: 8),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('خلفية النص', style: TextStyle(color: Colors.white, fontSize: 14)),
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final color = await showColorPickerDialog(context, s.subtitleBgColor);
                      s.setSubtitleBgColor(color);
                    },
                    child: ColorIndicator(color: s.subtitleBgColor, width: 30, height: 30, borderRadius: 8),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: s.subtitleBgOpacity > 0,
                    onChanged: (v) => s.setSubtitleBgOpacity(v ? 0.6 : 0.0),
                    activeColor: cs.primary,
                  ),
                ],
              ),
            ],
          ),
          if (s.subtitleBgOpacity > 0) ...[
            const SizedBox(height: 8),
            _SliderRow(
              title: 'شفافية الخلفية',
              value: s.subtitleBgOpacity,
              min: 0.1,
              max: 1.0,
              label: '${(s.subtitleBgOpacity * 100).toInt()}%',
              onChanged: s.setSubtitleBgOpacity,
              activeColor: cs.primary,
            ),
          ],

          const Divider(color: Colors.white24, height: 24),

          // ── الحدّ الخارجي للنص (Outline) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('حدّ خارجي للنص', style: TextStyle(color: Colors.white, fontSize: 14)),
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final color = await showColorPickerDialog(context, s.outlineColor);
                      s.setOutlineColor(color);
                    },
                    child: ColorIndicator(color: s.outlineColor, width: 28, height: 28, borderRadius: 8),
                  ),
                  const SizedBox(width: 12),
                  Switch(value: s.outlineEnabled, onChanged: s.setOutlineEnabled, activeColor: cs.primary),
                ],
              ),
            ],
          ),
          if (s.outlineEnabled) ...[
            const SizedBox(height: 8),
            _SliderRow(
              title: 'سماكة الحدّ',
              value: s.outlineWidth,
              min: 0.5,
              max: 6.0,
              label: s.outlineWidth.toStringAsFixed(1),
              onChanged: s.setOutlineWidth,
              activeColor: cs.primary,
            ),
          ],

          const Divider(color: Colors.white24, height: 24),

          // ── ظل النص ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ظل النص', style: TextStyle(color: Colors.white, fontSize: 14)),
              Switch(value: s.textShadowEnabled, onChanged: s.setTextShadowEnabled, activeColor: cs.primary),
            ],
          ),
          if (s.textShadowEnabled) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('لون الظل', style: TextStyle(color: Colors.white70, fontSize: 13)),
                GestureDetector(
                  onTap: () async {
                    final color = await showColorPickerDialog(context, s.textShadowColor);
                    s.setTextShadowColor(color);
                  },
                  child: ColorIndicator(color: s.textShadowColor, width: 24, height: 24, borderRadius: 6),
                ),
              ],
            ),
            _SliderRow(
              title: 'حجم الظل (Blur)',
              value: s.textShadowBlurRadius,
              min: 0,
              max: 20,
              label: '${s.textShadowBlurRadius.toInt()}',
              onChanged: s.setTextShadowBlurRadius,
              activeColor: cs.primary,
            ),
          ],

          const Divider(color: Colors.white24, height: 24),

          // ── ظل الصندوق المحيط بالنص ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ظل الصندوق', style: TextStyle(color: Colors.white, fontSize: 14)),
              Switch(value: s.boxShadowEnabled, onChanged: s.setBoxShadowEnabled, activeColor: cs.primary),
            ],
          ),
          if (s.boxShadowEnabled) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('لون الظل', style: TextStyle(color: Colors.white70, fontSize: 13)),
                GestureDetector(
                  onTap: () async {
                    final color = await showColorPickerDialog(context, s.boxShadowColor);
                    s.setBoxShadowColor(color);
                  },
                  child: ColorIndicator(color: s.boxShadowColor, width: 24, height: 24, borderRadius: 6),
                ),
              ],
            ),
            _SliderRow(
              title: 'حجم الظل (Blur)',
              value: s.boxShadowBlurRadius,
              min: 0,
              max: 20,
              label: '${s.boxShadowBlurRadius.toInt()}',
              onChanged: s.setBoxShadowBlurRadius,
              activeColor: cs.primary,
            ),
            _SliderRow(
              title: 'إزاحة أفقية',
              value: s.boxShadowOffsetX,
              min: -10,
              max: 10,
              label: s.boxShadowOffsetX.toStringAsFixed(1),
              onChanged: s.setBoxShadowOffsetX,
              activeColor: cs.primary,
            ),
            _SliderRow(
              title: 'إزاحة رأسية',
              value: s.boxShadowOffsetY,
              min: -10,
              max: 10,
              label: s.boxShadowOffsetY.toStringAsFixed(1),
              onChanged: s.setBoxShadowOffsetY,
              activeColor: cs.primary,
            ),
          ],

          const Divider(color: Colors.white24, height: 24),

          // ── الموقع على الشاشة ──
          _SliderRow(
            title: 'الارتفاع عن الأسفل',
            value: s.bottomPadding,
            min: 0,
            max: 300,
            label: '${s.bottomPadding.toInt()} px',
            onChanged: s.setBottomPadding,
            activeColor: cs.primary,
          ),
        ],
      ),
    );
  }

  void _showFontPicker(BuildContext context, SettingsProvider s) {
    // الخطوط العربية (Cairo, Amiri, Noto Naskh Arabic) تُحمَّل ديناميكياً
    // عبر google_fonts بدل الاعتماد على ملفات .ttf مرفقة يدوياً مع
    // التطبيق، فلا حاجة لإضافتها في pubspec.yaml.
    final fonts = ['Roboto', 'monospace', 'sans-serif', 'Cairo', 'Amiri', 'Noto Naskh Arabic'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('اختر نوع الخط', style: TextStyle(color: Colors.white), textAlign: TextAlign.right),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fonts
                .map((font) => ListTile(
                      title: Text(
                        font,
                        textAlign: TextAlign.right,
                        style: _previewStyle(font).copyWith(
                          color: s.fontFamily == font ? Theme.of(context).colorScheme.primary : Colors.white,
                        ),
                      ),
                      trailing: s.fontFamily == font
                          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        s.setFontFamily(font);
                        Navigator.pop(ctx);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  TextStyle _previewStyle(String font) {
    const builtIn = {'Roboto', 'monospace', 'sans-serif'};
    if (builtIn.contains(font)) return TextStyle(fontFamily: font == 'Roboto' ? null : font);
    try {
      return GoogleFonts.getFont(font);
    } catch (_) {
      return const TextStyle();
    }
  }
}

class _SliderRow extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final String label;
  final ValueChanged<double> onChanged;
  final Color activeColor;

  const _SliderRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged, activeColor: activeColor),
          ),
        ],
      ),
    );
  }
}
