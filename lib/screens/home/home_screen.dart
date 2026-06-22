import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/video_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../player/player_screen.dart';
import '../settings/settings_screen.dart';
import '../info_screen.dart';
import 'home_tabs.dart';
import 'home_search_delegate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _selectedFolder;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _openPlayer(VideoItem video) async {
    await context.read<LibraryProvider>().addRecent(video.path);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(video: video)));
  }

  Future<void> _openByPath(String path) async {
    if (!File(path).existsSync()) return;
    final stat = File(path).statSync();
    await _openPlayer(VideoItem.fromPath(path: path, size: stat.size, modified: stat.modified));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    if (result?.files.single.path != null) await _openByPath(result!.files.single.path!);
  }

  List<VideoItem> _sorted(List<VideoItem> list) {
    final s = context.read<SettingsProvider>();
    final sorted = List<VideoItem>.from(list);
    switch (s.sortBy) {
      case 'name':
        sorted.sort((a, b) => a.name.compareTo(b.name));
      case 'size':
        sorted.sort((a, b) => a.size.compareTo(b.size));
      case 'duration':
        sorted.sort((a, b) => a.duration.compareTo(b.duration));
      default:
        sorted.sort((a, b) => a.modified.compareTo(b.modified));
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
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
              child: Icon(Symbols.play_arrow_rounded, color: cs.onPrimaryContainer, size: 22)),
          const SizedBox(width: 10),
          const Text('SR Player'),
        ]),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'الكل'),
          Tab(text: 'الأخيرة'),
          Tab(text: 'المجلدات'),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Symbols.search_rounded),
              onPressed: () => showSearch(
                  context: context,
                  delegate: VideoSearchDelegate(context.read<LibraryProvider>().videos, _openPlayer))),
          IconButton(
              icon: Icon(settings.gridView ? Symbols.view_list_rounded : Symbols.grid_view_rounded),
              onPressed: () => settings.setGridView(!settings.gridView)),
          IconButton(icon: const Icon(Symbols.sort_rounded), onPressed: () => _sortSheet(settings)),
          IconButton(
              icon: const Icon(Symbols.settings_rounded),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      body: Consumer<LibraryProvider>(builder: (_, lib, __) {
        if (lib.loading && lib.videos.isEmpty) {
          return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 16),
            Text('جاري البحث...', style: TextStyle(color: cs.onSurfaceVariant)),
          ]));
        }
        if (lib.error != null && lib.videos.isEmpty) {
          return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Symbols.error_rounded, size: 56, color: cs.error),
            const SizedBox(height: 12),
            Text(lib.error!, style: TextStyle(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: () => _initLibrary(),
                icon: const Icon(Symbols.refresh_rounded),
                label: const Text('إعادة المحاولة')),
          ]));
        }

        return TabBarView(controller: _tabs, children: [
          RefreshIndicator(
            onRefresh: _refreshLibrary,
            child: AllTab(
              videos: _sorted(lib.videos),
              selectedFolder: _selectedFolder,
              folders: lib.byFolder.keys.toSet(),
              onFolderChanged: (f) => setState(() => _selectedFolder = f),
              onOpen: _openPlayer,
              onMore: (v) => _menu(v),
              gridView: settings.gridView,
              loading: lib.loading,
            ),
          ),
          RefreshIndicator(
            onRefresh: _refreshLibrary,
            child:
                RecentTab(paths: lib.recentPaths, all: lib.videos, onOpen: _openByPath, onClear: lib.clearRecent),
          ),
          RefreshIndicator(
            onRefresh: _refreshLibrary,
            child: FoldersTab(
                byFolder: lib.byFolder,
                onTap: (f) {
                  setState(() => _selectedFolder = f);
                  _tabs.animateTo(0);
                }),
          ),
        ]);
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickFile,
        icon: const Icon(Symbols.folder_open_rounded),
        label: const Text('فتح ملف'),
      ),
    );
  }

  void _sortSheet(SettingsProvider s) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
        context: context,
        builder: (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                    child: Text('ترتيب حسب',
                        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16))),
                const Divider(height: 1),
                ...[
                  ('date', 'التاريخ', Symbols.calendar_today_rounded),
                  ('name', 'الاسم', Symbols.sort_by_alpha_rounded),
                  ('size', 'الحجم', Symbols.data_usage_rounded),
                  ('duration', 'المدة', Symbols.timer_rounded)
                ].map((e) => ListTile(
                    leading: Icon(e.$3),
                    title: Text(e.$2),
                    trailing: s.sortBy == e.$1 ? Icon(Symbols.check_rounded, color: cs.primary) : null,
                    onTap: () {
                      s.sortBy == e.$1 ? s.setSortDesc(!s.sortDesc) : s.setSortBy(e.$1);
                      Navigator.pop(context);
                    })),
                const Divider(height: 1),
                ListTile(
                    leading: Icon(s.sortDesc ? Symbols.arrow_downward_rounded : Symbols.arrow_upward_rounded),
                    title: Text(s.sortDesc ? 'تنازلي' : 'تصاعدي'),
                    onTap: () {
                      s.setSortDesc(!s.sortDesc);
                      Navigator.pop(context);
                    }),
              ]),
            ));
  }

  void _menu(VideoItem video) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
        context: context,
        builder: (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Text(video.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500, fontSize: 14))),
                const Divider(height: 1),
                ListTile(
                    leading: _mIcon(Symbols.play_arrow_rounded, cs.primaryContainer, cs.onPrimaryContainer),
                    title: const Text('تشغيل'),
                    onTap: () {
                      Navigator.pop(context);
                      _openPlayer(video);
                    }),
                ListTile(
                    leading: _mIcon(Symbols.info_rounded, cs.secondaryContainer, cs.onSecondaryContainer),
                    title: const Text('معلومات'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => InfoScreen(video: video)));
                    }),
                ListTile(
                    leading: _mIcon(Symbols.share_rounded, cs.tertiaryContainer, cs.onTertiaryContainer),
                    title: const Text('مشاركة'),
                    onTap: () {
                      Navigator.pop(context);
                      Share.shareXFiles([XFile(video.path)], subject: video.name);
                    }),
              ]),
            ));
  }

  Widget _mIcon(IconData icon, Color bg, Color fg) => Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: fg, size: 22));
}
