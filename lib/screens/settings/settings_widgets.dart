import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

Widget settingsHeader(BuildContext ctx, String title, IconData icon) {
  final cs = Theme.of(ctx).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Row(children: [
      Icon(icon, size: 18, color: cs.primary),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 13)),
    ]),
  );
}

Widget settingsCard(BuildContext ctx, List<Widget> children) {
  final cs = Theme.of(ctx).colorScheme;
  return Container(
    decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

Widget settingsDivider() => const Divider(height: 1, indent: 56);

Widget settingsSwitchTile(
  BuildContext ctx, {
  required IconData icon,
  required String title,
  required String subtitle,
  required bool value,
  required void Function(bool) onChanged,
}) {
  final cs = Theme.of(ctx).colorScheme;
  return ListTile(
    leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: value ? cs.primaryContainer : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: value ? cs.onPrimaryContainer : cs.onSurfaceVariant, size: 22)),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: Switch(value: value, onChanged: onChanged),
    onTap: () => onChanged(!value),
  );
}

Widget settingsChoiceTile(
  BuildContext ctx, {
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  final cs = Theme.of(ctx).colorScheme;
  return ListTile(
    leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: cs.onSurfaceVariant, size: 22)),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant, size: 20),
    onTap: onTap,
  );
}

String langName(String code) {
  const names = {
    'ara': 'العربية',
    'eng': 'الإنجليزية',
    'fra': 'الفرنسية',
    'spa': 'الإسبانية',
    'deu': 'الألمانية',
    'ita': 'الإيطالية',
  };
  return names[code] ?? code.toUpperCase();
}

String themeName(ThemeMode m) => switch (m) {
      ThemeMode.dark => 'داكن',
      ThemeMode.light => 'فاتح',
      ThemeMode.system => 'تلقائي',
    };

String sortName(String s) => switch (s) {
      'name' => 'الاسم',
      'size' => 'الحجم',
      'duration' => 'المدة',
      _ => 'التاريخ',
    };

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
              trailing: currentValue == item.$1 ? Icon(Symbols.check_rounded, color: cs.primary) : null,
              onTap: () {
                onSelected(item.$1);
                Navigator.pop(ctx);
              },
            )),
      ]),
    ),
  );
}
