import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/settings_provider.dart';

void showLanguagePicker(BuildContext ctx, SettingsProvider s) {
  showDialog(
    context: ctx,
    builder: (context) => SimpleDialog(
      title: Text('language'.tr()),
      children: [
        RadioListTile<Locale>(
          title: Text('arabic'.tr()),
          value: const Locale('ar'),
          groupValue: s.locale,
          onChanged: (v) {
            s.setLocale(v!);
            Navigator.pop(context);
          },
        ),
        RadioListTile<Locale>(
          title: Text('english'.tr()),
          value: const Locale('en'),
          groupValue: s.locale,
          onChanged: (v) {
            s.setLocale(v!);
            Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}

void showBoostDialog(BuildContext ctx, SettingsProvider s) {
  showDialog(
    context: ctx,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('تضخيم الصوت الافتراضي (%)'),
        content: Slider(
          value: s.defaultAudioBoost,
          min: 50,
          max: 200,
          divisions: 30,
          label: '${s.defaultAudioBoost.round()}%',
          onChanged: (v) {
            s.setDefaultAudioBoost(v);
            setDialogState(() {});
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('موافق'))],
      ),
    ),
  );
}

void showAudioLanguagePicker(BuildContext ctx, SettingsProvider s) {
  final langs = {'ara': 'العربية', 'eng': 'الإنجليزية', 'fra': 'الفرنسية', 'spa': 'الإسبانية'};
  showDialog(
    context: ctx,
    builder: (context) => SimpleDialog(
      title: const Text('اختر لغة الصوت المفضلة'),
      children: langs.entries
          .map((e) => RadioListTile<String>(
                title: Text(e.value),
                value: e.key,
                groupValue: s.preferredAudioLanguage,
                onChanged: (v) {
                  s.setPreferredAudioLanguage(v!);
                  Navigator.pop(context);
                },
              ))
          .toList(),
    ),
  );
}

void showEncodingPicker(BuildContext ctx, SettingsProvider s) {
  const encodings = ['UTF-8', 'UTF-16', 'Windows-1256', 'ISO-8859-6'];
  showDialog(
    context: ctx,
    builder: (context) => SimpleDialog(
      title: const Text('اختر ترميز الأحرف'),
      children: encodings
          .map((enc) => RadioListTile<String>(
                title: Text(enc),
                value: enc,
                groupValue: s.subtitleEncoding,
                onChanged: (v) {
                  s.setSubtitleEncoding(v!);
                  Navigator.pop(context);
                },
              ))
          .toList(),
    ),
  );
}

void showSubtitleLanguagePicker(BuildContext ctx, SettingsProvider s) {
  final langs = {
    'ara': 'العربية',
    'eng': 'الإنجليزية',
    'fra': 'الفرنسية',
    'spa': 'الإسبانية',
    'deu': 'الألمانية',
    'ita': 'الإيطالية',
  };
  showDialog(
    context: ctx,
    builder: (context) => SimpleDialog(
      title: const Text('اختر لغة الترجمة المفضلة'),
      children: langs.entries
          .map((e) => RadioListTile<String>(
                title: Text(e.value),
                value: e.key,
                groupValue: s.preferredSubtitleLanguage,
                onChanged: (v) {
                  s.setPreferredSubtitleLanguage(v!);
                  Navigator.pop(context);
                },
              ))
          .toList(),
    ),
  );
}

void showSyncDialog(BuildContext ctx, SettingsProvider s) {
  final controller = TextEditingController(text: s.defaultSubtitleSync.toStringAsFixed(1));
  showDialog(
    context: ctx,
    builder: (context) => AlertDialog(
      title: const Text('المزامنة الافتراضية (ثواني)'),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: const InputDecoration(hintText: 'مثال: -0.5 أو 1.0'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null) s.setDefaultSubtitleSync(value);
              Navigator.pop(context);
            },
            child: const Text('موافق')),
      ],
    ),
  );
}

void showThemePicker(BuildContext ctx, SettingsProvider s) {
  showBottomPicker<ThemeMode>(
    ctx,
    title: 'اختر المظهر',
    currentValue: s.themeMode,
    items: const [
      (ThemeMode.dark, 'داكن', Icons.dark_mode_rounded),
      (ThemeMode.light, 'فاتح', Icons.light_mode_rounded),
      (ThemeMode.system, 'تلقائي', Icons.brightness_auto_rounded),
    ],
    onSelected: s.setThemeMode,
  );
}

void showSpeedPicker(BuildContext ctx, SettingsProvider s) {
  final cs = Theme.of(ctx).colorScheme;
  showModalBottomSheet(
    context: ctx,
    builder: (_) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text('سرعة التشغيل',
                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16))),
        const Divider(height: 1),
        ...[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((sp) => ListTile(
              title: Text('${sp}x'),
              trailing: s.defaultSpeed == sp ? Icon(Icons.check_rounded, color: cs.primary) : null,
              onTap: () {
                s.setDefaultSpeed(sp);
                Navigator.pop(ctx);
              },
            )),
      ]),
    ),
  );
}

void showSortPicker(BuildContext ctx, SettingsProvider s) {
  showBottomPicker<String>(
    ctx,
    title: 'ترتيب حسب',
    currentValue: s.sortBy,
    items: const [
      ('date', 'التاريخ', Icons.calendar_today_rounded),
      ('name', 'الاسم', Icons.sort_by_alpha_rounded),
      ('size', 'الحجم', Icons.data_usage_rounded),
      ('duration', 'المدة', Icons.timer_rounded),
    ],
    onSelected: s.setSortBy,
  );
}

void showBottomPicker<T>(
  BuildContext ctx, {
  required String title,
  required List<(T, String, IconData)> items,
  required T currentValue,
  required void Function(T) onSelected,
}) {
  final cs = Theme.of(ctx).colorScheme;
  showModalBottomSheet(
    context: ctx,
    builder: (_) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text(title, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16))),
        const Divider(height: 1),
        ...items.map((item) => ListTile(
              leading: Icon(item.$3),
              title: Text(item.$2),
              trailing: currentValue == item.$1 ? Icon(Icons.check_rounded, color: cs.primary) : null,
              onTap: () {
                onSelected(item.$1);
                Navigator.pop(ctx);
              },
            )),
      ]),
    ),
  );
}