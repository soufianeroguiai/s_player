import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void dispose() {
    // حفظ الإعدادات عند الخروج من الشاشة
    context.read<SettingsProvider>().save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _header(context, 'المظهر', Symbols.palette_rounded),
        _card(context, [
          _choice(context, icon: Symbols.dark_mode_rounded, title: 'المظهر',
              subtitle: _themeName(s.themeMode), onTap: () => _themePicker(context, s)),
        ]),
        const SizedBox(height: 20),
        _header(context, 'المشغل', Symbols.play_circle_rounded),
        _card(context, [
          _switch(context, icon: Symbols.resume_rounded, title: 'تذكر موضع التشغيل',
              subtitle: 'متابعة من آخر موضع', value: s.rememberPosition, onChanged: s.setRememberPosition),
          _divider(),
          _switch(context, icon: Symbols.play_arrow_rounded, title: 'تشغيل تلقائي',
              subtitle: 'تشغيل الفيديو فور الفتح', value: s.autoPlay, onChanged: s.setAutoPlay),
          _divider(),
          _choice(context, icon: Symbols.speed_rounded, title: 'سرعة التشغيل الافتراضية',
              subtitle: '${s.defaultSpeed}x', onTap: () => _speedPicker(context, s)),
        ]),
        const SizedBox(height: 20),
        _header(context, 'الصوت', Symbols.graphic_eq_rounded),
        _card(context, [
          _choice(context, icon: Symbols.audio_file_rounded, title: 'مشغل الصوت',
              subtitle: s.audioPlayerEngine, onTap: () {}),
          _divider(),
          _choice(context, icon: Symbols.speaker_group_rounded, title: 'مخرج الصوت',
              subtitle: s.audioOutput, onTap: () => _audioOutputPicker(context, s)),
          _divider(),
          _choice(context, icon: Symbols.volume_up_rounded, title: 'تضخيم الصوت الافتراضي',
              subtitle: '${s.defaultAudioBoost.round()}%', onTap: () => _boostDialog(context, s)),
          _divider(),
          _choice(context, icon: Symbols.volume_down_rounded, title: 'مستوى الصوت الافتراضي',
              subtitle: '${(s.defaultVolume * 100).round()}%', onTap: () => _volumeDialog(context, s)),
          _divider(),
          _switch(context, icon: Symbols.picture_in_picture_rounded, title: 'لوحة حجم الصوت',
              subtitle: 'إظهار مؤشر الصوت أثناء التغيير', value: s.showVolumePanel, onChanged: s.setShowVolumePanel),
          _divider(),
          _switch(context, icon: Symbols.headphones_rounded, title: 'إيقاف عند فصل السماعات',
              subtitle: 'إيقاف التشغيل مؤقتاً عند نزع السماعات', value: s.pauseOnHeadphonesDisconnect, onChanged: s.setPauseOnHeadphonesDisconnect),
          _divider(),
          _switch(context, icon: Symbols.waves_rounded, title: 'تلاشي في بداية التشغيل',
              subtitle: 'تأثير fade-in عند البدء', value: s.fadeInStart, onChanged: s.setFadeInStart),
          _divider(),
          _switch(context, icon: Symbols.search_rounded, title: 'تلاشي عند البحث',
              subtitle: 'تأثير fade-in عند التقديم/التأخير', value: s.fadeInSeek, onChanged: s.setFadeInSeek),
          _divider(),
          _choice(context, icon: Symbols.language_rounded, title: 'لغة الصوت المفضلة',
              subtitle: _langName(s.preferredAudioLanguage), onTap: () => _audioLanguagePicker(context, s)),
          _divider(),
          _choice(context, icon: Symbols.bluetooth_connected_rounded, title: 'تأخير صوت البلوتوث',
              subtitle: '${s.bluetoothAudioDelayMs.round()} ميلي ثانية', onTap: () => _btDelayDialog(context, s)),
          _divider(),
          _switch(context, icon: Symbols.cable_rounded, title: 'عبور الصوت (HDMI/USB)',
              subtitle: 'تمكين خرج الصوت الرقمي', value: s.audioPassthrough, onChanged: s.setAudioPassthrough),
          _divider(),
          _choice(context, icon: Symbols.speed_rounded, title: 'معدل الصوت',
              subtitle: '${s.audioRate}x', onTap: () => _audioRatePicker(context, s)),
        ]),
        const SizedBox(height: 20),
        _header(context, 'الترجمة', Symbols.subtitles_rounded),
        _card(context, [
          _switch(context, icon: Symbols.subtitles_rounded, title: 'إظهار الترجمة تلقائياً',
              subtitle: 'تفعيل عند بدء التشغيل', value: s.showSubtitlesByDefault, onChanged: s.setShowSubtitlesByDefault),
          _divider(),
          _choice(context, icon: Symbols.folder_open_rounded, title: 'مجلد الترجمة',
              subtitle: s.subtitleFolder.isEmpty ? 'غير محدد' : s.subtitleFolder,
              onTap: () async {
                final result = await FilePicker.getDirectoryPath();
                if (result != null) s.setSubtitleFolder(result);
              }),
          _divider(),
          _choice(context, icon: Symbols.text_fields_rounded, title: 'ترميز الأحرف',
              subtitle: s.subtitleEncoding, onTap: () => _encodingPicker(context, s)),
          _divider(),
          _choice(context, icon: Symbols.language_rounded, title: 'لغة الترجمة المفضلة',
              subtitle: _langName(s.preferredSubtitleLanguage), onTap: () => _subtitleLanguagePicker(context, s)),
          _divider(),
          _choice(context, icon: Symbols.timeline_rounded, title: 'مزامنة افتراضية',
              subtitle: '${s.defaultSubtitleSync.toStringAsFixed(1)} ثانية', onTap: () => _syncDialog(context, s)),
          _divider(),
          _switch(context, icon: Symbols.speed_rounded, title: 'تسريع HW للترجمة',
              subtitle: 'استخدام عتاد الجهاز لتحسين الترجمة', value: s.subtitleHwAcceleration, onChanged: s.setSubtitleHwAcceleration),
          _divider(),
          _choice(context, icon: Symbols.folder_rounded, title: 'مجلد الخطوط',
              subtitle: s.subtitleFontsFolder.isEmpty ? 'افتراضي' : s.subtitleFontsFolder,
              onTap: () async {
                final result = await FilePicker.getDirectoryPath();
                if (result != null) s.setSubtitleFontsFolder(result);
              }),
          _divider(),
          _switch(context, icon: Symbols.format_italic_rounded, title: 'تأثير مائل',
              subtitle: 'تفعيل الخط المائل للترجمة', value: s.subtitleItalic, onChanged: s.setSubtitleItalic),
          _divider(),
          _switch(context, icon: Symbols.format_textdirection_r_to_l_rounded, title: 'اتجاه النص',
              subtitle: s.subtitleRTL ? 'من اليمين إلى اليسار' : 'من اليسار إلى اليمين', value: s.subtitleRTL, onChanged: s.setSubtitleRTL),
        ]),
        const SizedBox(height: 20),
        _header(context, 'المكتبة', Symbols.video_library_rounded),
        _card(context, [
          _choice(context, icon: Symbols.sort_rounded, title: 'الترتيب الافتراضي',
              subtitle: _sortName(s.sortBy), onTap: () => _sortPicker(context, s)),
          _divider(),
          _switch(context, icon: Symbols.arrow_downward_rounded, title: 'ترتيب تنازلي',
              subtitle: 'من الأحدث إلى الأقدم', value: s.sortDesc, onChanged: s.setSortDesc),
          _divider(),
          _switch(context, icon: Symbols.grid_view_rounded, title: 'عرض الشبكة',
              subtitle: 'عرض الفيديوهات كبطاقات', value: s.gridView, onChanged: s.setGridView),
        ]),
        const SizedBox(height: 20),
        _header(context, 'عن التطبيق', Symbols.info_rounded),
        _card(context, [
          ListTile(
            leading: Container(width: 42, height: 42,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Icon(Symbols.play_arrow_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer)),
            title: const Text('SR Player', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('الإصدار 1.0.0'),
          ),
        ]),
        const SizedBox(height: 32),
      ]),
    );
  }

  // --- دوال اختيار القيم (نوافذ منبثقة) ---
  void _audioOutputPicker(BuildContext ctx, SettingsProvider s) {
    final outputs = ['auto', 'speaker', 'headphones', 'bluetooth'];
    showDialog(
      context: ctx,
      builder: (context) => SimpleDialog(
        title: const Text('اختر مخرج الصوت'),
        children: outputs.map((out) => RadioListTile<String>(
          title: Text(out),
          value: out,
          groupValue: s.audioOutput,
          onChanged: (v) { s.setAudioOutput(v!); Navigator.pop(context); },
        )).toList(),
      ),
    );
  }

  void _boostDialog(BuildContext ctx, SettingsProvider s) {
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('تضخيم الصوت الافتراضي (%)'),
        content: Slider(
          value: s.defaultAudioBoost,
          min: 50, max: 200, divisions: 30,
          label: '${s.defaultAudioBoost.round()}%',
          onChanged: (v) => s.setDefaultAudioBoost(v),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('موافق'))],
      ),
    );
  }

  void _volumeDialog(BuildContext ctx, SettingsProvider s) {
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('مستوى الصوت الافتراضي (%)'),
        content: Slider(
          value: s.defaultVolume * 100,
          min: 0, max: 100,
          onChanged: (v) => s.setDefaultVolume(v / 100),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('موافق'))],
      ),
    );
  }

  void _audioLanguagePicker(BuildContext ctx, SettingsProvider s) {
    final langs = {'ara':'العربية', 'eng':'الإنجليزية', 'fra':'الفرنسية', 'spa':'الإسبانية'};
    showDialog(
      context: ctx,
      builder: (context) => SimpleDialog(
        title: const Text('اختر لغة الصوت المفضلة'),
        children: langs.entries.map((e) => RadioListTile<String>(
          title: Text(e.value),
          value: e.key,
          groupValue: s.preferredAudioLanguage,
          onChanged: (v) { s.setPreferredAudioLanguage(v!); Navigator.pop(context); },
        )).toList(),
      ),
    );
  }

  void _btDelayDialog(BuildContext ctx, SettingsProvider s) {
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('تأخير البلوتوث (ميلي ثانية)'),
        content: Slider(
          value: s.bluetoothAudioDelayMs,
          min: 0, max: 500, divisions: 50,
          label: '${s.bluetoothAudioDelayMs.round()} ms',
          onChanged: (v) => s.setBluetoothAudioDelayMs(v),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('موافق'))],
      ),
    );
  }

  void _audioRatePicker(BuildContext ctx, SettingsProvider s) {
    final rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showDialog(
      context: ctx,
      builder: (context) => SimpleDialog(
        title: const Text('اختر معدل الصوت'),
        children: rates.map((r) => RadioListTile<double>(
          title: Text('${r}x'),
          value: r,
          groupValue: s.audioRate,
          onChanged: (v) { s.setAudioRate(v!); Navigator.pop(context); },
        )).toList(),
      ),
    );
  }

  void _encodingPicker(BuildContext ctx, SettingsProvider s) {
    final encodings = ['UTF-8', 'UTF-16', 'Windows-1256', 'ISO-8859-6'];
    showDialog(
      context: ctx,
      builder: (context) => SimpleDialog(
        title: const Text('اختر ترميز الأحرف'),
        children: encodings.map((enc) => RadioListTile<String>(
          title: Text(enc),
          value: enc,
          groupValue: s.subtitleEncoding,
          onChanged: (v) { s.setSubtitleEncoding(v!); Navigator.pop(context); },
        )).toList(),
      ),
    );
  }

  void _subtitleLanguagePicker(BuildContext ctx, SettingsProvider s) {
    final langs = {'ara':'العربية', 'eng':'الإنجليزية', 'fra':'الفرنسية', 'spa':'الإسبانية', 'deu':'الألمانية', 'ita':'الإيطالية'};
    showDialog(
      context: ctx,
      builder: (context) => SimpleDialog(
        title: const Text('اختر لغة الترجمة المفضلة'),
        children: langs.entries.map((e) => RadioListTile<String>(
          title: Text(e.value),
          value: e.key,
          groupValue: s.preferredSubtitleLanguage,
          onChanged: (v) { s.setPreferredSubtitleLanguage(v!); Navigator.pop(context); },
        )).toList(),
      ),
    );
  }

  void _syncDialog(BuildContext ctx, SettingsProvider s) {
    TextEditingController controller = TextEditingController(text: s.defaultSubtitleSync.toStringAsFixed(1));
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('المزامنة الافتراضية (ثواني)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'مثال: -0.5 أو 1.0'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () {
            final value = double.tryParse(controller.text);
            if (value != null) s.setDefaultSubtitleSync(value);
            Navigator.pop(context);
          }, child: const Text('موافق')),
        ],
      ),
    );
  }

  String _langName(String code) {
    const names = {'ara':'العربية', 'eng':'الإنجليزية', 'fra':'الفرنسية', 'spa':'الإسبانية', 'deu':'الألمانية', 'ita':'الإيطالية'};
    return names[code] ?? code.toUpperCase();
  }

  String _themeName(ThemeMode m) => switch(m) {
    ThemeMode.dark => 'داكن', ThemeMode.light => 'فاتح', ThemeMode.system => 'تلقائي',
  };
  String _sortName(String s) => switch(s) {
    'name' => 'الاسم', 'size' => 'الحجم', 'duration' => 'المدة', _ => 'التاريخ',
  };

  Widget _header(BuildContext ctx, String title, IconData icon) {
    final cs = Theme.of(ctx).colorScheme;
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 13)),
      ]));
  }

  Widget _card(BuildContext ctx, List<Widget> children) {
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 56);

  Widget _switch(BuildContext ctx, {required IconData icon, required String title,
      required String subtitle, required bool value, required void Function(bool) onChanged}) {
    final cs = Theme.of(ctx).colorScheme;
    return ListTile(
      leading: Container(width: 40, height: 40,
        decoration: BoxDecoration(
          color: value ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: value ? cs.onPrimaryContainer : cs.onSurfaceVariant, size: 22)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }

  Widget _choice(BuildContext ctx, {required IconData icon, required String title,
      required String subtitle, required VoidCallback onTap}) {
    final cs = Theme.of(ctx).colorScheme;
    return ListTile(
      leading: Container(width: 40, height: 40,
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: cs.onSurfaceVariant, size: 22)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant, size: 20),
      onTap: onTap,
    );
  }

  void _themePicker(BuildContext ctx, SettingsProvider s) {
    final cs = Theme.of(ctx).colorScheme;
    showModalBottomSheet(context: ctx, builder: (_) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Text('اختر المظهر', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16))),
        const Divider(height: 1),
        ...[
          (ThemeMode.dark, 'داكن', Symbols.dark_mode_rounded),
          (ThemeMode.light, 'فاتح', Symbols.light_mode_rounded),
          (ThemeMode.system, 'تلقائي', Symbols.brightness_auto_rounded),
        ].map((item) => ListTile(
          leading: Icon(item.$3),
          title: Text(item.$2),
          trailing: s.themeMode == item.$1 ? Icon(Symbols.check_rounded, color: cs.primary) : null,
          onTap: () { s.setThemeMode(item.$1); Navigator.pop(ctx); },
        )),
      ]),
    ));
  }

  void _speedPicker(BuildContext ctx, SettingsProvider s) {
    final cs = Theme.of(ctx).colorScheme;
    showModalBottomSheet(context: ctx, builder: (_) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Text('سرعة التشغيل', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16))),
        const Divider(height: 1),
        ...[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((sp) => ListTile(
          title: Text('${sp}x'),
          trailing: s.defaultSpeed == sp ? Icon(Symbols.check_rounded, color: cs.primary) : null,
          onTap: () { s.setDefaultSpeed(sp); Navigator.pop(ctx); },
        )),
      ]),
    ));
  }

  void _sortPicker(BuildContext ctx, SettingsProvider s) {
    final cs = Theme.of(ctx).colorScheme;
    showModalBottomSheet(context: ctx, builder: (_) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Text('ترتيب حسب', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16))),
        const Divider(height: 1),
        ...[
          ('date', 'التاريخ', Symbols.calendar_today_rounded),
          ('name', 'الاسم', Symbols.sort_by_alpha_rounded),
          ('size', 'الحجم', Symbols.data_usage_rounded),
          ('duration', 'المدة', Symbols.timer_rounded),
        ].map((item) => ListTile(
          leading: Icon(item.$3),
          title: Text(item.$2),
          trailing: s.sortBy == item.$1 ? Icon(Symbols.check_rounded, color: cs.primary) : null,
          onTap: () { s.setSortBy(item.$1); Navigator.pop(ctx); },
        )),
      ]),
    ));
  }
}