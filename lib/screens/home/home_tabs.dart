import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/video_item.dart';
import '../../widgets/video_card.dart';

class AllTab extends StatelessWidget {
  final List<VideoItem> videos;
  final String? selectedFolder;
  final Set<String> folders;
  final void Function(String?) onFolderChanged;
  final void Function(VideoItem) onOpen;
  final void Function(VideoItem) onMore;
  final bool gridView;
  final bool loading;

  const AllTab({
    super.key,
    required this.videos,
    required this.selectedFolder,
    required this.folders,
    required this.onFolderChanged,
    required this.onOpen,
    required this.onMore,
    required this.gridView,
    this.loading = false,
  });

  List<VideoItem> get filtered =>
      selectedFolder == null ? videos : videos.where((v) => v.folder == selectedFolder).toList();

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    return Column(children: [
      if (folders.isNotEmpty) FolderChips(folders: folders, selected: selectedFolder, onChanged: onFolderChanged),
      if (loading && videos.isNotEmpty) LinearProgressIndicator(color: Theme.of(context).colorScheme.primary),
      Expanded(
        child: list.isEmpty && !loading
            ? const EmptyState('ما لقينا فيديوهات', Symbols.video_library_rounded)
            : gridView
                ? GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, childAspectRatio: 0.78, crossAxisSpacing: 10, mainAxisSpacing: 10),
                    itemCount: list.length,
                    itemBuilder: (_, i) =>
                        VideoGridCard(video: list[i], onTap: () => onOpen(list[i]), onMoreTap: () => onMore(list[i])))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 90),
                    itemCount: list.length,
                    itemBuilder: (_, i) =>
                        VideoCard(video: list[i], onTap: () => onOpen(list[i]), onMoreTap: () => onMore(list[i]))),
      ),
    ]);
  }
}

class FolderChips extends StatelessWidget {
  final Set<String> folders;
  final String? selected;
  final void Function(String?) onChanged;
  const FolderChips({super.key, required this.folders, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = folders.toList()..sort();
    return Container(
      height: 48,
      color: cs.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        children: [
          _chip('الكل', selected == null, () => onChanged(null), cs),
          ...list.map((f) => _chip(f, selected == f, () => onChanged(selected == f ? null : f), cs)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap, ColorScheme cs) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? cs.secondaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: sel ? cs.onSecondaryContainer : cs.onSurfaceVariant,
              fontSize: 13,
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
        ),
      ),
    );
  }
}

class RecentTab extends StatelessWidget {
  final List<String> paths;
  final List<VideoItem> all;
  final void Function(String) onOpen;
  final VoidCallback onClear;
  const RecentTab({super.key, required this.paths, required this.all, required this.onOpen, required this.onClear});

  List<VideoItem> get list {
    final map = {for (final v in all) v.path: v};
    return paths
        .map((p) {
          if (map.containsKey(p)) return map[p]!;
          try {
            if (!File(p).existsSync()) return null;
            final stat = File(p).statSync();
            return VideoItem.fromPath(path: p, size: stat.size, modified: stat.modified);
          } catch (_) {
            return null;
          }
        })
        .whereType<VideoItem>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = list;
    if (items.isEmpty) return const EmptyState('ما شفتي فيديو بعد', Symbols.history_rounded);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
        child: Row(children: [
          Icon(Symbols.history_rounded, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('${items.length} ملف', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const Spacer(),
          TextButton.icon(
              onPressed: onClear,
              icon: Icon(Symbols.delete_sweep_rounded, size: 16, color: cs.error),
              label: Text('مسح', style: TextStyle(color: cs.error, fontSize: 12)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10))),
        ]),
      ),
      Expanded(
          child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: items.length,
              itemBuilder: (_, i) => VideoCard(video: items[i], onTap: () => onOpen(items[i].path)))),
    ]);
  }
}

class FoldersTab extends StatelessWidget {
  final Map<String, List<VideoItem>> byFolder;
  final void Function(String) onTap;
  const FoldersTab({super.key, required this.byFolder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keys = byFolder.keys.toList()..sort();
    if (keys.isEmpty) return const EmptyState('ما لقينا مجلدات', Symbols.folder_off_rounded);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final folder = keys[i];
        final videos = byFolder[folder]!;
        final total = videos.fold<int>(0, (s, v) => s + v.size);
        final size = total < 1024 * 1024 * 1024
            ? '${(total / (1024 * 1024)).toStringAsFixed(0)} MB'
            : '${(total / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(14)),
                child: Icon(Symbols.folder_rounded, color: cs.onSecondaryContainer, size: 28)),
            title: Text(folder, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: Text('${videos.length} فيديو  •  $size', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            trailing: Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant),
            onTap: () => onTap(folder),
          ),
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  final String msg;
  final IconData icon;
  const EmptyState(this.msg, this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: cs.surfaceContainerHigh, shape: BoxShape.circle),
            child: Icon(icon, size: 48, color: cs.onSurfaceVariant)),
        const SizedBox(height: 20),
        Text(msg, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('اضغط "فتح ملف" لاختيار فيديو', style: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6), fontSize: 13)),
      ]),
    );
  }
}
