import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../providers/settings_provider.dart';
import 'settings_widgets.dart';
import 'settings_dialogs.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        settingsHeader(context, 'المظهر', Symbols.palette_rounded),
        settingsCard(context, [
          settingsChoiceTile(context,
              icon: Symbols.dark_mode_rounded,
              title: 'المظهر',
              subtitle: themeName(s.themeMode),
              onTap: () => showThemePicker(context, s)),
        ]),
        const SizedBox(height: 20),
        settingsHeader(context, 'المشغل', Symbols.play_circle_rounded),
        settingsCard(context, [
          settingsSwitchTile(context,
              icon: Symbols.resume_rounded,
              title: 'تذكر موضع التشغيل',
              subtitle: 'متابعة من آخر موضع',
              value: s.rememberPosition,
              onChanged: s.setRememberPosition),
          settingsDivider(),
          settingsSwitchTile(context,
              icon: Symbols.play_arrow_rounded,
              title: 'تشغيل تلقائي',
              subtitle: 'تشغيل الفيديو فور الفتح',
              value: s.autoPlay,
              onChanged: s.setAutoPlay),
          settingsDivider(),
          settingsChoiceTile(context,
              icon: Symbols.speed_rounded,
              title: 'سرعة التشغيل الافتراضية',
              subtitle: '${s.defaultSpeed}x',
              onTap: () => showSpeedPicker(context, s)),
        ]),
        const SizedBox(height: 20),
        settingsHeader(context, 'الصوت', Symbols.graphic_eq_rounded),
        settingsCard(context, [
          settingsChoiceTile(context,
              icon: Symbols.volume_up_rounded,
              title: 'تضخيم الصوت الافتراضي',
              subtitle: '${s.defaultAudioBoost.round()}%',
              onTap: () => showBoostDialog(context, s)),
          settingsDivider(),
          settingsChoiceTile(context,
              icon: Symbols.language_rounded,
              title: 'لغة الصوت المفضلة',
              subtitle: langName(s.preferredAudioLanguage),
              onTap: () => showAudioLanguagePicker(context, s)),
        ]),
        const SizedBox(height: 20),
        settingsHeader(context, 'الترجمة', Symbols.subtitles_rounded),
        settingsCard(context, [
          settingsSwitchTile(context,
              icon: Symbols.subtitles_rounded,
              title: 'إظهار الترجمة تلقائياً',
              subtitle: 'تفعيل عند بدء التشغيل',
              value: s.showSubtitlesByDefault,
              onChanged: s.setShowSubtitlesByDefault),
          settingsDivider(),
          settingsChoiceTile(context,
              icon: Symbols.folder_open_rounded,
              title: 'مجلد الترجمة',
              subtitle: s.subtitleFolder.isEmpty ? 'غير محدد' : s.subtitleFolder,
              onTap: () async {
                final result = await FilePicker.getDirectoryPath();
                if (result != null) s.setSubtitleFolder(result);
              }),
          settingsDivider(),
          settingsChoiceTile(context,
              icon: Symbols.text_fields_rounded,
              title: 'ترميز الأحرف',
              subtitle: s.subtitleEncoding,
              onTap: () => showEncodingPicker(context, s)),
          settingsDivider(),
          settingsChoiceTile(context,
              icon: Symbols.language_rounded,
              title: 'لغة الترجمة المفضلة',
              subtitle: langName(s.preferredSubtitleLanguage),
              onTap: () => showSubtitleLanguagePicker(context, s)),
          settingsDivider(),
          settingsChoiceTile(context,
              icon: Symbols.timeline_rounded,
              title: 'مزامنة افتراضية',
              subtitle: '${s.defaultSubtitleSync.toStringAsFixed(1)} ثانية',
              onTap: () => showSyncDialog(context, s)),
          settingsDivider(),
          settingsSwitchTile(context,
              icon: Symbols.format_italic_rounded,
              title: 'تأثير مائل',
              subtitle: 'تفعيل الخط المائل للترجمة',
              value: s.subtitleItalic,
              onChanged: s.setSubtitleItalic),
          settingsDivider(),
          settingsSwitchTile(context,
              icon: Symbols.format_textdirection_r_to_l_rounded,
              title: 'اتجاه النص',
              subtitle: s.subtitleRTL ? 'من اليمين إلى اليسار' : 'من اليسار إلى اليمين',
              value: s.subtitleRTL,
              onChanged: s.setSubtitleRTL),
        ]),
        const SizedBox(height: 20),
        settingsHeader(context, 'حدّ ومظهر الترجمة', Symbols.format_color_text_rounded),
        settingsCard(context, [
          settingsSwitchTile(context,
              icon: Symbols.border_color_rounded,
              title: 'حدّ خارجي للنص',
              subtitle: 'إطار حول كل حرف لتحسين الوضوح',
              value: s.outlineEnabled,
              onChanged: s.setOutlineEnabled),
          if (s.outlineEnabled) ...[
            settingsDivider(),
            _colorRow(context, 'لون الحدّ', s.outlineColor, s.setOutlineColor),
            settingsDivider(),
            _sliderRow(context, 'سماكة الحدّ', s.outlineWidth, 0.5, 6.0, s.outlineWidth.toStringAsFixed(1),
                s.setOutlineWidth),
          ],
          settingsDivider(),
          settingsSwitchTile(context,
              icon: Symbols.blur_on_rounded,
              title: 'ظل الصندوق',
              subtitle: 'ظل خلف نص الترجمة',
              value: s.boxShadowEnabled,
              onChanged: s.setBoxShadowEnabled),
          if (s.boxShadowEnabled) ...[
            settingsDivider(),
            _colorRow(context, 'لون الظل', s.boxShadowColor, s.setBoxShadowColor),
            settingsDivider(),
            _sliderRow(context, 'حجم الظل', s.boxShadowBlurRadius, 0, 20, '${s.boxShadowBlurRadius.toInt()}',
                s.setBoxShadowBlurRadius),
          ],
        ]),
        const SizedBox(height: 20),
        settingsHeader(context, 'المكتبة', Symbols.video_library_rounded),
        settingsCard(context, [
          settingsChoiceTile(context,
              icon: Symbols.sort_rounded,
              title: 'الترتيب الافتراضي',
              subtitle: sortName(s.sortBy),
              onTap: () => showSortPicker(context, s)),
          settingsDivider(),
          settingsSwitchTile(context,
              icon: Symbols.arrow_downward_rounded,
              title: 'ترتيب تنازلي',
              subtitle: 'من الأحدث إلى الأقدم',
              value: s.sortDesc,
              onChanged: s.setSortDesc),
          settingsDivider(),
          settingsSwitchTile(context,
              icon: Symbols.grid_view_rounded,
              title: 'عرض شبكي للمكتبة',
              subtitle: 'عرض فيديوهات المكتبة كبطاقات',
              value: s.libraryGridView,
              onChanged: s.setLibraryGridView),
          settingsDivider(),
          settingsSwitchTile(context,
              icon: Symbols.grid_view_rounded,
              title: 'عرض شبكي للمجلدات',
              subtitle: 'عرض المجلدات كبطاقات',
              value: s.foldersGridView,
              onChanged: s.setFoldersGridView),
          settingsDivider(),
          settingsSwitchTile(context,
              icon: Symbols.grid_view_rounded,
              title: 'عرض شبكي للأخيرة',
              subtitle: 'عرض قائمة الأخيرة كبطاقات',
              value: s.recentGridView,
              onChanged: s.setRecentGridView),
        ]),
        const SizedBox(height: 20),
        settingsHeader(context, 'عن التطبيق', Symbols.info_rounded),
        settingsCard(context, [
          ListTile(
            leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(Symbols.play_arrow_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer)),
            title: const Text('SR Player', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('الإصدار 1.0.0'),
          ),
        ]),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _colorRow(BuildContext ctx, String label, Color color, ValueChanged<Color> onChanged) {
    return ListTile(
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

  Widget _sliderRow(
      BuildContext ctx, String label, double value, double min, double max, String display, ValueChanged<double> onChanged) {
    final cs = Theme.of(ctx).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              Text(display, style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          Slider(value: value, min: min, max: max, onChanged: onChanged, activeColor: cs.primary),
        ],
      ),
    );
  }
}