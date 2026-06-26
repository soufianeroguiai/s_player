import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../providers/settings_provider.dart';
import 'settings_widgets.dart';
import 'settings_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _openSection = 0;
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _sectionHeader(context, 'عام', Symbols.settings_rounded),
        _card(context, [
          _choiceTile(context, Symbols.dark_mode_rounded, 'المظهر', themeName(s.themeMode), () => showThemePicker(context, s)),
        ]),
        const SizedBox(height: 16),
        _sectionHeader(context, 'المشغل', Symbols.play_circle_rounded),
        _card(context, [
          _switchTile(context, Symbols.resume_rounded, 'تذكر موضع التشغيل', 'متابعة من آخر موضع', s.rememberPosition, s.setRememberPosition),
          _divider(),
          _switchTile(context, Symbols.play_arrow_rounded, 'تشغيل تلقائي', 'تشغيل الفيديو فور الفتح', s.autoPlay, s.setAutoPlay),
          _divider(),
          _choiceTile(context, Symbols.speed_rounded, 'سرعة التشغيل الافتراضية', '${s.defaultSpeed}x', () => showSpeedPicker(context, s)),
        ]),
        const SizedBox(height: 16),
        _sectionHeader(context, 'الصوت', Symbols.graphic_eq_rounded),
        _card(context, [
          _choiceTile(context, Symbols.volume_up_rounded, 'تضخيم الصوت الافتراضي', '${s.defaultAudioBoost.round()}%', () => showBoostDialog(context, s)),
          _divider(),
          _choiceTile(context, Symbols.language_rounded, 'لغة الصوت المفضلة', langName(s.preferredAudioLanguage), () => showAudioLanguagePicker(context, s)),
        ]),
        const SizedBox(height: 16),
        _sectionHeader(context, 'الترجمة', Symbols.subtitles_rounded),
        _card(context, [
          _switchTile(context, Symbols.subtitles_rounded, 'إظهار الترجمة تلقائياً', 'تفعيل عند بدء التشغيل', s.showSubtitlesByDefault, s.setShowSubtitlesByDefault),
          _divider(),
          _choiceTile(context, Symbols.folder_open_rounded, 'مجلد الترجمة', s.subtitleFolder.isEmpty ? 'غير محدد' : s.subtitleFolder, () async {
            final result = await FilePicker.getDirectoryPath();
            if (result != null) s.setSubtitleFolder(result);
          }),
          _divider(),
          _choiceTile(context, Symbols.text_fields_rounded, 'ترميز الأحرف', s.subtitleEncoding, () => showEncodingPicker(context, s)),
          _divider(),
          _choiceTile(context, Symbols.language_rounded, 'لغة الترجمة المفضلة', langName(s.preferredSubtitleLanguage), () => showSubtitleLanguagePicker(context, s)),
          _divider(),
          _choiceTile(context, Symbols.timeline_rounded, 'مزامنة افتراضية', '${s.defaultSubtitleSync.toStringAsFixed(1)} ثانية', () => showSyncDialog(context, s)),
          _divider(),
          _switchTile(context, Symbols.format_italic_rounded, 'تأثير مائل', 'تفعيل الخط المائل للترجمة', s.subtitleItalic, s.setSubtitleItalic),
          _divider(),
          _switchTile(context, Symbols.format_textdirection_r_to_l_rounded, 'اتجاه النص', s.subtitleRTL ? 'من اليمين إلى اليسار' : 'من اليسار إلى اليمين', s.subtitleRTL, s.setSubtitleRTL),
          _divider(),
          _moreTile(context, 'مظهر الترجمة المتقدم', _showAdvanced, () => setState(() => _showAdvanced = !_showAdvanced)),
          if (_showAdvanced) ...[
            const SizedBox(height: 8),
            _fontSection(context, s),
            const SizedBox(height: 12),
            _colorSection(context, s),
            const SizedBox(height: 12),
            _effectsSection(context, s),
            const SizedBox(height: 12),
            _positionSection(context, s),
          ],
        ]),
        const SizedBox(height: 16),
        _sectionHeader(context, 'المكتبة', Symbols.video_library_rounded),
        _card(context, [
          _choiceTile(context, Symbols.sort_rounded, 'الترتيب الافتراضي', sortName(s.sortBy), () => showSortPicker(context, s)),
          _divider(),
          _switchTile(context, Symbols.arrow_downward_rounded, 'ترتيب تنازلي', 'من الأحدث إلى الأقدم', s.sortDesc, s.setSortDesc),
          _divider(),
          _switchTile(context, Symbols.grid_view_rounded, 'عرض شبكي للمكتبة', 'عرض فيديوهات المكتبة كبطاقات', s.libraryGridView, s.setLibraryGridView),
          _divider(),
          _switchTile(context, Symbols.grid_view_rounded, 'عرض شبكي للمجلدات', 'عرض المجلدات كبطاقات', s.foldersGridView, s.setFoldersGridView),
          _divider(),
          _switchTile(context, Symbols.grid_view_rounded, 'عرض شبكي للأخيرة', 'عرض قائمة الأخيرة كبطاقات', s.recentGridView, s.setRecentGridView),
        ]),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () => _confirmReset(context, s),
            icon: Icon(Symbols.restart_alt_rounded, color: cs.error),
            label: Text('استعادة الإعدادات الافتراضية', style: TextStyle(color: cs.error)),
          ),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }

  void _confirmReset(BuildContext context, SettingsProvider s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة الإعدادات'),
        content: const Text('هل تريد إعادة جميع الإعدادات إلى الوضع الافتراضي؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              s.resetAll();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استعادة الإعدادات')));
            },
            child: Text('استعادة', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  // أقسام مظهر الترجمة المتقدم
  Widget _fontSection(BuildContext context, SettingsProvider s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('الخط والحجم', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      _sliderRow(context, 'حجم الخط', s.subtitleFontSize, 10, 100, '${s.subtitleFontSize.toInt()} px', s.setSubtitleFontSize),
      const SizedBox(height: 8),
      _choiceTile(context, Symbols.font_download_rounded, 'نوع الخط', s.fontFamily, () => showFontPicker(context, s)),
    ]);
  }

  Widget _colorSection(BuildContext context, SettingsProvider s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('الألوان', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      _colorRow(context, 'لون النص', s.subtitleColor, s.setSubtitleColor),
      const SizedBox(height: 8),
      _switchTile(context, Symbols.format_paint_rounded, 'خلفية النص', '', s.subtitleBgOpacity > 0, (v) => s.setSubtitleBgOpacity(v ? 0.65 : 0.0)),
      if (s.subtitleBgOpacity > 0) ...[
        const SizedBox(height: 8),
        _colorRow(context, 'لون الخلفية', s.subtitleBgColor, s.setSubtitleBgColor),
        const SizedBox(height: 8),
        _sliderRow(context, 'شفافية الخلفية', s.subtitleBgOpacity, 0.1, 1.0, '${(s.subtitleBgOpacity * 100).toInt()}%', s.setSubtitleBgOpacity),
      ],
    ]);
  }

  Widget _effectsSection(BuildContext context, SettingsProvider s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('الحدود والظلال', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      _switchTile(context, Symbols.border_color_rounded, 'حدّ خارجي للنص', 'إطار حول كل حرف', s.outlineEnabled, s.setOutlineEnabled),
      if (s.outlineEnabled) ...[
        const SizedBox(height: 8),
        _colorRow(context, 'لون الحدّ', s.outlineColor, s.setOutlineColor),
        const SizedBox(height: 8),
        _sliderRow(context, 'سماكة الحدّ', s.outlineWidth, 0.5, 6.0, s.outlineWidth.toStringAsFixed(1), s.setOutlineWidth),
      ],
      const SizedBox(height: 8),
      _switchTile(context, Symbols.blur_on_rounded, 'ظل الصندوق', 'ظل خلف نص الترجمة', s.boxShadowEnabled, s.setBoxShadowEnabled),
      if (s.boxShadowEnabled) ...[
        const SizedBox(height: 8),
        _colorRow(context, 'لون الظل', s.boxShadowColor, s.setBoxShadowColor),
        const SizedBox(height: 8),
        _sliderRow(context, 'حجم الظل', s.boxShadowBlurRadius, 0, 20, '${s.boxShadowBlurRadius.toInt()}', s.setBoxShadowBlurRadius),
      ],
    ]);
  }

  Widget _positionSection(BuildContext context, SettingsProvider s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('الموضع', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      _sliderRow(context, 'الارتفاع عن الأسفل', s.bottomPadding, 0, 300, '${s.bottomPadding.toInt()} px', s.setBottomPadding),
      const SizedBox(height: 8),
      _sliderRow(context, 'الهامش الأفقي', s.horizontalMargin, 0, 120, '${s.horizontalMargin.toInt()} px', s.setHorizontalMargin),
    ]);
  }

  // عناصر مساعدة
  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }

  Widget _card(BuildContext context, List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 56);

  Widget _switchTile(BuildContext ctx, IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    final cs = Theme.of(ctx).colorScheme;
    return ListTile(
      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: value ? cs.primaryContainer : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: value ? cs.onPrimaryContainer : cs.onSurfaceVariant, size: 22)),
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }

  Widget _choiceTile(BuildContext ctx, IconData icon, String title, String subtitle, VoidCallback onTap) {
    final cs = Theme.of(ctx).colorScheme;
    return ListTile(
      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: cs.onSurfaceVariant, size: 22)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant, size: 20),
      onTap: onTap,
    );
  }

  Widget _moreTile(BuildContext ctx, String title, bool expanded, VoidCallback onTap) {
    final cs = Theme.of(ctx).colorScheme;
    return ListTile(
      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: Icon(Symbols.tune_rounded, color: cs.onSurfaceVariant, size: 22)),
      title: Text(title),
      trailing: Icon(expanded ? Symbols.expand_less_rounded : Symbols.expand_more_rounded, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }

  Widget _colorRow(BuildContext ctx, String label, Color color, ValueChanged<Color> onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(label),
      trailing: GestureDetector(
        onTap: () async {
          final picked = await showColorPickerDialog(ctx, color);
          onChanged(picked);
        },
        child: ColorIndicator(color: color, width: 30, height: 30, borderRadius: 8),
      ),
    );
  }

  Widget _sliderRow(BuildContext ctx, String label, double value, double min, double max, String display, ValueChanged<double> onChanged) {
    final cs = Theme.of(ctx).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          Text(display, style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        Slider(value: value, min: min, max: max, onChanged: onChanged, activeColor: cs.primary),
      ]),
    );
  }
}