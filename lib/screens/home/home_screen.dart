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

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // 0: المكتبة, 1: المجلدات, 2: الأخيرة

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
    final lib = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SR Player'),
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
        actions: [
          // أيقونة تبديل العرض (شبكة/قائمة)
          IconButton(
            icon: Icon(settings.gridView ? Symbols.view_list_rounded : Symbols.grid_view_rounded),
            onPressed: () => settings.setGridView(!settings.gridView),
            tooltip: settings.gridView ? 'عرض القائمة' : 'عرض الشبكة',
          ),
          // أيقونة البحث
          IconButton(
            icon: const Icon(Symbols.search_rounded),
            onPressed: () => showSearch(
                context: context,
                delegate: VideoSearchDelegate(lib.videos, _openPlayer)),
          ),
          // أيقونة القائمة الجانبية (Drawer)
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Symbols.menu_rounded),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: cs.primaryContainer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Symbols.play_arrow_rounded, color: cs.onPrimaryContainer, size: 40),
                  const SizedBox(height: 8),
                  Text('SR Player', style: TextStyle(color: cs.onPrimaryContainer, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Symbols.settings_rounded),
              title: const Text('الإعدادات'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Symbols.visibility_off_rounded),
              title: const Text('الملفات المخفية'),
              onTap: () {
                Navigator.pop(context);
                _showHiddenVideos();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Symbols.sort_rounded),
              title: const Text('الفرز'),
              onTap: () {
                Navigator.pop(context);
                _sortSheet(settings);
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // المكتبة
          RefreshIndicator(
            onRefresh: _refreshLibrary,
            child: LibraryTab(
              videos: _sorted(lib.videos),
              gridView: settings.gridView,
              onOpen: _openPlayer,
              onMore: (v) => _menu(v),
              loading: lib.loading,
            ),
          ),
          // المجلدات
          RefreshIndicator(
            onRefresh: _refreshLibrary,
            child: FoldersTab(
                byFolder: lib.byFolder,
                onTap: (folder) {
                  // سنضبطه لاحقاً ليفلتر المكتبة
                }),
          ),
          // الأخيرة
          RefreshIndicator(
            onRefresh: _refreshLibrary,
            child: RecentTab(
                paths: lib.recentPaths, all: lib.videos, onOpen: _openByPath, onClear: lib.clearRecent),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Symbols.video_library_rounded),
            label: 'المكتبة',
          ),
          NavigationDestination(
            icon: Icon(Symbols.folder_rounded),
            label: 'المجلدات',
          ),
          NavigationDestination(
            icon: Icon(Symbols.history_rounded),
            label: 'الأخيرة',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickFile,
        icon: const Icon(Symbols.folder_open_rounded),
        label: const Text('فتح ملف'),
      ),
    );
  }

  // ─── دوال مساعدة (بقيت كما هي) ───

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
    final lib = context.read<LibraryProvider>();
    final isHidden = lib.hiddenPaths.contains(video.path);

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
                ListTile(
                    leading: _mIcon(
                      isHidden ? Symbols.visibility_rounded : Symbols.visibility_off_rounded,
                      isHidden ? cs.secondaryContainer : cs.errorContainer,
                      isHidden ? cs.onSecondaryContainer : cs.onErrorContainer,
                    ),
                    title: Text(isHidden ? 'إلغاء الإخفاء' : 'إخفاء'),
                    subtitle: Text(
                      isHidden ? 'سيظهر في المكتبة مجدداً' : 'لن يظهر في القائمة الرئيسية',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (isHidden) {
                        lib.unhideVideo(video.path);
                      } else {
                        lib.hideVideo(video.path);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('تم إخفاء الفيديو'),
                            action: SnackBarAction(
                              label: 'تراجع',
                              onPressed: () => lib.unhideVideo(video.path),
                            ),
                          ),
                        );
                      }
                    }),
              ]),
            ));
  }

  void _showHiddenVideos() {
    final lib = context.read<LibraryProvider>();
    final hidden = lib.allVideos.where((v) => lib.hiddenPaths.contains(v.path)).toList();
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scroll) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Icon(Symbols.visibility_off_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text('الملفات المخفية (${hidden.length})',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: cs.onSurface)),
              const Spacer(),
              if (hidden.isNotEmpty)
                TextButton(
                  onPressed: () {
                    lib.clearHidden();
                    Navigator.pop(ctx);
                  },
                  child: const Text('إظهار الكل'),
                ),
            ]),
          ),
          const Divider(height: 1),
          if (hidden.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Symbols.visibility_rounded, size: 48, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('لا يوجد ملفات مخفية', style: TextStyle(color: cs.onSurfaceVariant)),
                ]),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: hidden.length,
                itemBuilder: (_, i) {
                  final v = hidden[i];
                  return ListTile(
                    leading: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Symbols.video_file_rounded, color: cs.onSurfaceVariant),
                    ),
                    title: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(v.formattedSize, style: const TextStyle(fontSize: 12)),
                    trailing: TextButton(
                      onPressed: () => lib.unhideVideo(v.path),
                      child: const Text('إظهار'),
                    ),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }

  Widget _mIcon(IconData icon, Color bg, Color fg) => Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: fg, size: 22));
}