import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/video_item.dart';

class InfoScreen extends StatelessWidget {
  final VideoItem video;
  const InfoScreen({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(video.name),
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [cs.primaryContainer, cs.secondaryContainer],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(Symbols.movie_rounded, color: cs.onPrimaryContainer, size: 52),
          ),
          const SizedBox(height: 16),
          Text(video.name, textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          _section(context, 'معلومات الملف', [
            _row(context, Symbols.storage_rounded, 'الحجم', video.formattedSize),
            _row(context, Symbols.folder_rounded, 'المجلد', video.folder),
            _row(context, Symbols.calendar_today_rounded, 'التاريخ', video.formattedDate),
            _row(context, Symbols.label_rounded, 'الامتداد', video.extension.toUpperCase()),
          ]),
          const SizedBox(height: 16),
          _section(context, 'معلومات الفيديو', [
            _row(context, Symbols.timer_rounded, 'المدة', video.formattedDuration),
          ]),
          const SizedBox(height: 16),
          _section(context, 'المسار', [
            Padding(padding: const EdgeInsets.all(16),
              child: SelectableText(video.path,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.5))),
          ]),
        ]),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(title, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 13))),
      Container(
        decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: List.generate(children.length, (i) => Column(children: [
          children[i],
          if (i < children.length - 1) Divider(height: 1, indent: 56, color: cs.outlineVariant),
        ]))),
      ),
    ]);
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: cs.onSurfaceVariant, size: 20)),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        const Spacer(),
        Flexible(child: Text(value, style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}