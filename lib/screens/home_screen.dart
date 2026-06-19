import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:share_plus/share_plus.dart';
import '../models/video_item.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/video_card.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'info_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _selectedFolder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLibrary());
  }

  Future<void> _initLibrary() async {
    final lib = context.read<LibraryProvider>();
    await lib.loadCachedVideos();
    if (!mounted) return;
    await lib.scan();
    await lib.loadRecent();
  }

  Future<void> _refreshLibrary() async {
    await context.read<LibraryProvider>().scan();
    await context.read<LibraryProvider>().loadRecent();
  }

  Future<void> _openPlayer(VideoItem video) async {
    await context.read<LibraryProvider>().addRecent(video.path);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(video: video)));
  }

  Future<void> _openByPath(String path) async {
    if (!File(path).existsSync()) return;
    final stat = File(path).statSync();
    final parts = path.split('/');
    await _openPlayer(VideoItem(
      id: path.hashCode.toString(), path: path,
      name: parts.last, size: stat.size, modified: stat.modified,
      folder: parts.length > 1 ? parts[parts.length - 2] : '', duration: Duration.zero,
    ));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    if (result?.files.single.path != null) await _openByPath(result!.files.single.path!);
  }

  List<VideoItem> _sorted(List<VideoItem> list) {
    final s = context.read<SettingsProvider>();
    final sorted = List<VideoItem>.from(list);
    switch (s.sortBy) {
      case 'name': sorted.sort((a, b) => a.name.compareTo(b.name));
      case 'size': sorted.sort((a, b) => a.size.compareTo(b.size));
      case 'duration': sorted.sort((a, b) => a.duration.compareTo(b.duration));
      default: sorted.sort((a, b) => a.modified.compareTo(b.modified));
    }
    return s.sortDesc ? sorted.reversed.toList() : sorted;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width: 34, height: 34,
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
            child: Icon(Symbols.play_arrow_rounded, color: cs.onPrimaryContainer, size: 22)),
          const SizedBox(width: 10),
          const Text('SR Player'),
        ]),
        actions: [
          IconButton(icon: const Icon(Symbols.search_rounded),
            onPressed: () => showSearch(context: context,
              delegate: _SearchDelegate(context.read<LibraryProvider>().videos, _openPlayer))),
          IconButton(
            icon: Icon(settings.gridView ? Symbols.view_list_rounded : Symbols.grid_view_rounded),
            onPressed: () => settings.setGridView(!settings.gridView)),
          IconButton(icon: const Icon(Symbols.sort_rounded), onPressed: () => _sortSheet(settings)),
          // زر فتح الملف موجود هنا في الأعلى
          IconButton(icon: const Icon(Symbols.folder_open_rounded), onPressed: _pickFile, tooltip: 'فتح ملف'),
          IconButton(icon: const Icon(Symbols.settings_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      body: Consumer<LibraryProvider>(builder: (_, lib, __) {
        if (lib.loading && lib.videos.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 16),
            Text('جاري البحث...', style: TextStyle(color: cs.onSurfaceVariant)),
          ]));
        }
        if (lib.error != null && lib.videos.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Symbols.error_rounded, size: 56, color: cs.error),
            const SizedBox(height: 12),
            Text(lib.error!, style: TextStyle(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => _initLibrary(),
              icon: const Icon(Symbols.refresh_rounded), label: const Text('إعادة المحاولة')),
          ]));
        }

        // استخدام IndexedStack بدلاً من TabBarView للحفاظ على حالة القوائم
        return IndexedStack(
          index: _currentIndex,
          children: [
            _AllTab(
              videos: _sorted(lib.videos),
              selectedFolder: _selectedFolder,
              folders: lib.byFolder.keys.toSet(),
              onFolderChanged: (f) => setState(() => _selectedFolder = f),
              onOpen: _openPlayer,
              onMore: (v) => _menu(v),
              gridView: settings.gridView,
              loading: lib.loading,
            ),
            _RecentTab(paths: lib.recentPaths, all: lib.videos, onOpen: _openByPath, onClear: lib.clearRecent),
            _FoldersTab(byFolder: lib.byFolder, onTap: (f) { setState(() => _selectedFolder = f); _currentIndex = 0; }),
          ],
        );
      }),
      // الشريط السفلي العائم (SalomonBottomBar)
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        height: 70,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: SalomonBottomBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          itemShape: const StadiumBorder(),
          unselectedItemColor: cs.onSurfaceVariant,
          selectedItemColor: cs.primary,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          itemPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          // ✅ تم إصلاح الأخطاء بإضافة const أمام كل عنصر
          items: const [
            const SalomonBottomBarItem(
              icon: const Icon(Symbols.home_rounded),
              title: const Text('الكل'),
            ),
            const SalomonBottomBarItem(
              icon: const Icon(Symbols.history_rounded),
              title: const Text('الأخيرة'),
            ),
            const SalomonBottomBarItem(
              icon: const Icon(Symbols.folder_rounded),
              title: const Text('المجلدات'),
            ),
          ],
        ),
      ),
      // تم حذف FloatingActionButton لأن الزر أصبح في الأعلى
      floatingActionButton: null,
    );
  }

  void _sortSheet(SettingsProvider s) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(context: context, builder: (_) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Text('ترتيب حسب', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16))),
        const Divider(height: 1),
        ...[('date','التاريخ',Symbols.calendar_today_rounded),('name','الاسم',Symbols.sort_by_alpha_rounded),
            ('size','الحجم',Symbols.data_usage_rounded),('duration','المدة',Symbols.timer_rounded)].map((e) =>
          ListTile(leading: Icon(e.$3), title: Text(e.$2),
            trailing: s.sortBy == e.$1 ? Icon(Symbols.check_rounded, color: cs.primary) : null,
            onTap: () { s.sortBy == e.$1 ? s.setSortDesc(!s.sortDesc) : s.setSortBy(e.$1); Navigator.pop(context); })),
        const Divider(height: 1),
        ListTile(
          leading: Icon(s.sortDesc ? Symbols.arrow_downward_rounded : Symbols.arrow_upward_rounded),
          title: Text(s.sortDesc ? 'تنازلي' : 'تصاعدي'),
          onTap: () { s.setSortDesc(!s.sortDesc); Navigator.pop(context); }),
      ]),
    ));
  }

  void _menu(VideoItem video) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(context: context, builder: (_) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text(video.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500, fontSize: 14))),
        const Divider(height: 1),
        ListTile(
          leading: _mIcon(Symbols.play_arrow_rounded, cs.primaryContainer, cs.onPrimaryContainer),
          title: const Text('تشغيل'),
          onTap: () { Navigator.pop(context); _openPlayer(video); }),
        ListTile(
          leading: _mIcon(Symbols.info_rounded, cs.secondaryContainer, cs.onSecondaryContainer),
          title: const Text('معلومات'),
          onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => InfoScreen(video: video))); }),
        ListTile(
          leading: _mIcon(Symbols.share_rounded, cs.tertiaryContainer, cs.onTertiaryContainer),
          title: const Text('مشاركة'),
          onTap: () { Navigator.pop(context); Share.shareXFiles([XFile(video.path)], subject: video.name); }),
      ]),
    ));
  }

  Widget _mIcon(IconData icon, Color bg, Color fg) => Container(
    width: 42, height: 42,
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Icon(icon, color: fg, size: 22));
}

// ------------------- المكونات الفرعية -------------------

class _AllTab extends StatelessWidget {
  final List<VideoItem> videos;
  final String? selectedFolder;
  final Set<String> folders;
  final void Function(String?) onFolderChanged;
  final void Function(VideoItem) onOpen;
  final void Function(VideoItem) onMore;
  final bool gridView;
  final bool loading;
  const _AllTab({
    required this.videos, required this.selectedFolder, required this.folders,
    required this.onFolderChanged, required this.onOpen, required this.onMore,
    required this.gridView, this.loading = false,
  });

  List<VideoItem> get filtered =>
      selectedFolder == null ? videos : videos.where((v) => v.folder == selectedFolder).toList();

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    return Column(children: [
      if (folders.isNotEmpty) _Chips(folders: folders, selected: selectedFolder, onChanged: onFolderChanged),
      if (loading && videos.isNotEmpty)
        LinearProgressIndicator(color: Theme.of(context).colorScheme.primary),
      Expanded(
        child: list.isEmpty && !loading
            ? _Empty('ما لقينا فيديوهات', Symbols.video_library_rounded)
            : gridView
                ? GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.78, crossAxisSpacing: 10, mainAxisSpacing: 10),
                    itemCount: list.length,
                    itemBuilder: (_, i) => VideoGridCard(video: list[i], onTap: () => onOpen(list[i]), onMoreTap: () => onMore(list[i])))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 90),
                    itemCount: list.length,
                    itemBuilder: (_, i) => VideoCard(video: list[i], onTap: () => onOpen(list[i]), onMoreTap: () => onMore(list[i]))),
      ),
    ]);
  }
}

class _Chips extends StatelessWidget {
  final Set<String> folders;
  final String? selected;
  final void Function(String?) onChanged;
  const _Chips({required this.folders, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = folders.toList()..sort();
    return Container(height: 48, color: cs.surface,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        children: [
          _chip('الكل', selected == null, () => onChanged(null), cs),
          ...list.map((f) => _chip(f, selected == f, () => onChanged(selected == f ? null : f), cs)),
        ]));
  }

  Widget _chip(String label, bool sel, VoidCallback onTap, ColorScheme cs) {
    return GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? cs.secondaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(
          color: sel ? cs.onSecondaryContainer : cs.onSurfaceVariant,
          fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.normal))));
  }
}

class _RecentTab extends StatefulWidget {
  final List<String> paths;
  final List<VideoItem> all;
  final void Function(String) onOpen;
  final VoidCallback onClear;
  const _RecentTab({required this.paths, required this.all, required this.onOpen, required this.onClear});

  @override
  State<_RecentTab> createState() => _RecentTabState();
}

class _RecentTabState extends State<_RecentTab> {
  Future<List<VideoItem>> _loadItems() async {
    final map = {for (final v in widget.all) v.path: v};
    final List<VideoItem> items = [];
    for (final p in widget.paths) {
      if (map.containsKey(p)) {
        items.add(map[p]!);
      } else {
        try {
          if (File(p).existsSync()) {
            final stat = await File(p).stat();
            final parts = p.split('/');
            items.add(VideoItem(
              id: p.hashCode.toString(), path: p, name: parts.last,
              size: stat.size, modified: stat.modified,
              folder: parts.length > 1 ? parts[parts.length - 2] : '', duration: Duration.zero,
            ));
          }
        } catch (_) {}
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<List<VideoItem>>(
      future: _loadItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) return _Empty('ما شفتي فيديو بعد', Symbols.history_rounded);
        return Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(children: [
              Icon(Symbols.history_rounded, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('${items.length} ملف', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              const Spacer(),
              TextButton.icon(onPressed: widget.onClear,
                icon: Icon(Symbols.delete_sweep_rounded, size: 16, color: cs.error),
                label: Text('مسح', style: TextStyle(color: cs.error, fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10))),
            ])),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 90),
            itemCount: items.length,
            itemBuilder: (_, i) => VideoCard(video: items[i], onTap: () => widget.onOpen(items[i].path)))),
        ]);
      }
    );
  }
}

class _FoldersTab extends StatelessWidget {
  final Map<String, List<VideoItem>> byFolder;
  final void Function(String) onTap;
  const _FoldersTab({required this.byFolder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keys = byFolder.keys.toList()..sort();
    if (keys.isEmpty) return _Empty('ما لقينا مجلدات', Symbols.folder_off_rounded);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final folder = keys[i];
        final videos = byFolder[folder]!;
        final total = videos.fold<int>(0, (s, v) => s + v.size);
        final size = total < 1024*1024*1024
            ? '${(total/(1024*1024)).toStringAsFixed(0)} MB'
            : '${(total/(1024*1024*1024)).toStringAsFixed(1)} GB';
        return Card(margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(width: 50, height: 50,
              decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Icon(Symbols.folder_rounded, color: cs.onSecondaryContainer, size: 28)),
            title: Text(folder, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: Text('${videos.length} فيديو  •  $size', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            trailing: Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant),
            onTap: () => onTap(folder),
          ));
      });
  }
}

class _Empty extends StatelessWidget {
  final String msg;
  final IconData icon;
  const _Empty(this.msg, this.icon);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 96, height: 96,
        decoration: BoxDecoration(color: cs.surfaceContainerHigh, shape: BoxShape.circle),
        child: Icon(icon, size: 48, color: cs.onSurfaceVariant)),
      const SizedBox(height: 20),
      Text(msg, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('اضغط "فتح ملف" لاختيار فيديو', style: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6), fontSize: 13)),
    ]));
  }
}

// Search Delegate مع debounce Timer
class _SearchDelegate extends SearchDelegate<VideoItem?> {
  final List<VideoItem> videos;
  final Future<void> Function(VideoItem) onOpen;
  Timer? _debounceTimer;

  _SearchDelegate(this.videos, this.onOpen);

  @override
  String get searchFieldLabel => 'ابحث عن فيديو...';

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty) IconButton(icon: const Icon(Symbols.close_rounded), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) =>
    IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (context.mounted) {
        (context as Element).markNeedsBuild();
      }
    });
    return _list(context);
  }

  Widget _list(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final results = query.isEmpty ? videos
        : videos.where((v) => v.name.toLowerCase().contains(query.toLowerCase())).toList();
    if (results.isEmpty) return Center(child: Text('ما لقينا نتائج', style: TextStyle(color: cs.onSurfaceVariant)));
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) => VideoCard(video: results[i],
        onTap: () { close(context, results[i]); onOpen(results[i]); }));
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}