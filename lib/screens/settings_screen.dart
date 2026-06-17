import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/settings_provider.dart';

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
        _header(context, 'الترجمة', Symbols.subtitles_rounded),
        _card(context, [
          _switch(context, icon: Symbols.subtitles_rounded, title: 'إظهار الترجمة تلقائياً',
              subtitle: 'تفعيل عند بدء التشغيل', value: s.showSubtitlesByDefault, onChanged: s.setShowSubtitlesByDefault),
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
