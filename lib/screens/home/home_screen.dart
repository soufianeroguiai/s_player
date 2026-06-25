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
  int _currentIndex = 0;
  String? _browsingFolder;   // ✅ مجلد التصفح الحالي داخل تبويب المجلدات

  late AnimationController _rotateController;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLibrary());
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
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

  void _onViewOptionsPressed() {
    _rotateController.forward().then((_) => _rotateController.reverse());
    _showViewOptionsPopup();
  }

  void _showViewOptionsPopup() {
    final settings = context.read<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;

    bool currentGrid;
    if (_currentIndex == 0) {
      currentGrid = settings.libraryGridView;
    } else if (_currentIndex == 1) {
      currentGrid = settings.foldersGridView;
    } else {
      currentGrid = settings.recentGridView;
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 50,
        80,
        MediaQuery.of(context).size.width,
        0,
      ),
      items: [
        PopupMenuItem(
          value: 'grid',
          child: Row(
            children: [
              Icon(Symbols.grid_view_rounded, color: currentGrid ? cs.primary : null),
              const SizedBox(width: 12),
              Text('شبكة', style: TextStyle(fontWeight: currentGrid ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'list',
          child: Row(
            children: [
              Icon(Symbols.view_list_rounded, color: !currentGrid ? cs.primary : null),
              const SizedBox(width: 12),
              Text('قائمة', style: TextStyle(fontWeight: !currentGrid ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'date',
          child: Row(
            children: [
              Icon(Symbols.calendar_today_rounded, color: settings.sortBy == 'date' ? cs.primary : null),
              const SizedBox(width: 12),
              Text('التاريخ', style: TextStyle(fontWeight: settings.sortBy == 'date' ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'name',
          child: Row(
            children: [
              Icon(Symbols.sort_by_alpha_rounded, color: settings.sortBy == 'name' ? cs.primary : null),
              const SizedBox(width: 12),
              Text('الاسم', style: TextStyle(fontWeight: settings.sortBy == 'name' ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'size',
          child: Row(
            children: [
              Icon(Symbols.data_usage_rounded, color: settings.sortBy == 'size' ? cs.primary : null),
              const SizedBox(width: 12),
              Text('الحجم', style: TextStyle(fontWeight: settings.sortBy == 'size' ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'duration',
          child: Row(
            children: [
              Icon(Symbols.timer_rounded, color: settings.sortBy == 'duration' ? cs.primary : null),
              const SizedBox(width: 12),
              Text('المدة', style: TextStyle(fontWeight: settings.sortBy == 'duration' ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'toggle_order',
          child: Row(
            children: [
              Icon(settings.sortDesc ? Symbols.arrow_downward_rounded : Symbols.arrow_upward_rounded),
              const SizedBox(width: 12),
              Text(settings.sortDesc ? 'تنازلي' : 'تصاعدي'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      if (value == 'grid') {
        if (_currentIndex == 0) {
          settings.setLibraryGridView(true);
        } else if (_currentIndex == 1) {
          settings.setFoldersGridView(true);
        } else {
          settings.setRecentGridView(true);
        }
      } else if (value == 'list') {
        if (_currentIndex == 0) {
          settings.setLibraryGridView(false);
        } else if (_currentIndex == 1) {
          settings.setFoldersGridView(false);
        } else {
          settings.setRecentGridView(false);
        }
      } else if (value == 'toggle_order') {
        settings.setSortDesc(!settings.sortDesc);
      } else {
        settings.setSortBy(value!);
      }
    });
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
          AnimatedBuilder(
            animation: _rotateAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateAnimation.value * 3.14159,
                child: child,
              );
            },
            child: IconButton(
              icon: const Icon(Symbols.grid_view_rounded),
              onPressed: _onViewOptionsPressed,
              tooltip: 'خيارات العرض والفرز',
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.search_rounded),
            onPressed: () => showSearch(
                context: context,
                delegate: VideoSearchDelegate(lib.videos, _openPlayer)),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 0: المكتبة
          RefreshIndicator(
            onRefresh: _refreshLibrary,
            child: LibraryTab(
              videos: _sorted(lib.videos),
              gridView: settings.libraryGridView,
              onOpen: _openPlayer,
              onMore: (v) => _menu(v),
              loading: lib.loading,
            ),
          ),
          // 1: المجلدات – يدعم التصفح الهرمي
          _buildFoldersTab(lib, settings),
          // 2: الأخيرة
          RefreshIndicator(
            onRefresh: _refreshLibrary,
            child: RecentTab(
              paths: lib.recentPaths,
              all: lib.videos,
              gridView: settings.recentGridView,
              onOpen: _openByPath,
              onClear: lib.clearRecent,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          } else {
            setState(() {
              _currentIndex = index;
              // عند مغادرة تبويب المجلدات نلغي التصفح
              if (index != 1) _browsingFolder = null;
            });
          }
        },
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
          NavigationDestination(
            icon: Icon(Symbols.more_horiz_rounded),
            label: 'المزيد',
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

  /// يبني محتوى تبويب المجلدات (قائمة مجلدات أو فيديوهات مجلد معين)
  Widget _buildFoldersTab(LibraryProvider lib, SettingsProvider settings) {
    // إذا كنا داخل مجلد
    if (_browsingFolder != null) {
      final folderVideos = _sorted(
        lib.videos.where((v) => v.folder == _browsingFolder).toList(),
      );

      return Column(
        children: [
          // شريط التنقل داخل المجلد
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Symbols.arrow_back_rounded),
                  onPressed: () => setState(() => _browsingFolder = null),
                  tooltip: 'رجوع إلى المجلدات',
                ),
                const SizedBox(width: 4),
                Text(
                  _browsingFolder!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                // عدد الفيديوهات
                Text(
                  '${folderVideos.length} فيديو',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LibraryTab(
              videos: folderVideos,
              gridView: settings.foldersGridView, // يستخدم إعداد العرض الخاص بالمجلدات
              onOpen: _openPlayer,
              onMore: (v) => _menu(v),
              loading: false,
            ),
          ),
        ],
      );
    }

    // قائمة المجلدات العادية
    return RefreshIndicator(
      onRefresh: _refreshLibrary,
      child: FoldersTab(
        byFolder: lib.byFolder,
        gridView: settings.foldersGridView,
        onTap: (folder) => setState(() => _browsingFolder = folder),
      ),
    );
  }

  // ─── الدوال المساعدة (بقيت كما هي) ───
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