import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/video_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../player/player_screen.dart';
import '../settings/settings_screen.dart';
import '../info_screen.dart';
import '../favorites_screen.dart';
import '../playlist_screen.dart';
import 'home_tabs.dart';
import 'home_search_delegate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  String? _browsingFolder;

  late AnimationController _rotateController;
  late Animation<double> _rotateAnimation;

  final List<String> _favorites = [];
  final List<String> _playlist = [];

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLibrary();
      _loadFavorites();
    });
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final p = await SharedPreferences.getInstance();
    final favs = p.getStringList('favorite_paths') ?? [];
    setState(() => _favorites.addAll(favs));
  }

  Future<void> _saveFavorites() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('favorite_paths', _favorites);
  }

  bool _isFavorite(String path) => _favorites.contains(path);

  void _toggleFavorite(String path) {
    setState(() {
      if (_isFavorite(path)) {
        _favorites.remove(path);
      } else {
        _favorites.add(path);
      }
    });
    _saveFavorites();
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
              Text('grid'.tr(), style: TextStyle(fontWeight: currentGrid ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'list',
          child: Row(
            children: [
              Icon(Symbols.view_list_rounded, color: !currentGrid ? cs.primary : null),
              const SizedBox(width: 12),
              Text('list'.tr(), style: TextStyle(fontWeight: !currentGrid ? FontWeight.bold : FontWeight.normal)),
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
              Text('date'.tr(), style: TextStyle(fontWeight: settings.sortBy == 'date' ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'name',
          child: Row(
            children: [
              Icon(Symbols.sort_by_alpha_rounded, color: settings.sortBy == 'name' ? cs.primary : null),
              const SizedBox(width: 12),
              Text('name'.tr(), style: TextStyle(fontWeight: settings.sortBy == 'name' ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'size',
          child: Row(
            children: [
              Icon(Symbols.data_usage_rounded, color: settings.sortBy == 'size' ? cs.primary : null),
              const SizedBox(width: 12),
              Text('size'.tr(), style: TextStyle(fontWeight: settings.sortBy == 'size' ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'duration',
          child: Row(
            children: [
              Icon(Symbols.timer_rounded, color: settings.sortBy == 'duration' ? cs.primary : null),
              const SizedBox(width: 12),
              Text('duration'.tr(), style: TextStyle(fontWeight: settings.sortBy == 'duration' ? FontWeight.bold : FontWeight.normal)),
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
              Text(settings.sortDesc ? 'descending'.tr() : 'ascending'.tr()),
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

  void _showMoreMenu() {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 50,
        MediaQuery.of(context).size.height - 100,
        MediaQuery.of(context).size.width,
        0,
      ),
      items: [
        PopupMenuItem(
          value: 'settings',
          child: Row(children: [
            Icon(Symbols.settings_rounded),
            const SizedBox(width: 12),
            Text('settings'.tr()),
          ]),
        ),
        PopupMenuItem(
          value: 'favorites',
          child: Row(children: [
            Icon(Symbols.star_rounded),
            const SizedBox(width: 12),
            Text('المفضلة'),
          ]),
        ),
        PopupMenuItem(
          value: 'playlist',
          child: Row(children: [
            Icon(Symbols.playlist_play_rounded),
            const SizedBox(width: 12),
            Text('قائمة التشغيل'),
          ]),
        ),
        PopupMenuItem(
          value: 'hidden',
          child: Row(children: [
            Icon(Symbols.visibility_off_rounded),
            const SizedBox(width: 12),
            Text('الملفات المخفية'),
          ]),
        ),
      ],
    ).then((value) {
      if (value == 'settings') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
      } else if (value == 'favorites') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
      } else if (value == 'playlist') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: _playlist)));
      } else if (value == 'hidden') {
        _showHiddenVideos();
      }
    });
  }

  void _openInFileManager(VideoItem video) async {
    final folderPath = File(video.path).parent.path;
    final uri = Uri.parse('file://$folderPath');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح مدير الملفات')),
      );
    }
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
              tooltip: 'view_options'.tr(),
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
          RefreshIndicator(
            onRefresh: _refreshLibrary,
            child: LibraryTab(
              videos: _sorted(lib.videos),
              gridView: settings.libraryGridView,
              onOpen: _openPlayer,
              onMore: (v) => _buildVideoOptionsSheet(v),
              loading: lib.loading,
            ),
          ),
          _buildFoldersTab(lib, settings),
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
            _showMoreMenu();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Symbols.video_library_rounded),
            label: 'library'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Symbols.folder_rounded),
            label: 'folders'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Symbols.history_rounded),
            label: 'recents'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Symbols.more_horiz_rounded),
            label: 'more'.tr(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickFile,
        icon: const Icon(Symbols.folder_open_rounded),
        label: Text('open_file'.tr()),
      ),
    );
  }

  Widget _buildFoldersTab(LibraryProvider lib, SettingsProvider settings) {
    if (_browsingFolder != null) {
      final folderVideos = _sorted(
        lib.videos.where((v) => v.folder == _browsingFolder).toList(),
      );

      return Column(
        children: [
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
              gridView: settings.foldersGridView,
              onOpen: _openPlayer,
              onMore: (v) => _buildVideoOptionsSheet(v),
              loading: false,
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshLibrary,
      child: FoldersTab(
        byFolder: lib.byFolder,
        gridView: settings.foldersGridView,
        onTap: (folder) => setState(() => _browsingFolder = folder),
        onMore: _buildFolderOptionsSheet,
      ),
    );
  }

  void _buildFolderOptionsSheet(String folderName, List<VideoItem> folderVideos) {
    final cs = Theme.of(context).colorScheme;
    final lib = context.read<LibraryProvider>();
    final totalSize = folderVideos.fold<int>(0, (s, v) => s + v.size);
    final sizeStr = totalSize < 1024 * 1024 * 1024
        ? '${(totalSize / (1024 * 1024)).toStringAsFixed(0)} MB'
        : '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';

    final bool allHidden = folderVideos.every((v) => lib.hiddenPaths.contains(v.path));

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    children: [
                      Text(folderName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('${folderVideos.length} فيديو  •  $sizeStr',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _sheetTile(
                  icon: Symbols.play_arrow_rounded,
                  title: 'تشغيل الكل',
                  iconBg: cs.primaryContainer,
                  iconColor: cs.onPrimaryContainer,
                  onTap: () {
                    Navigator.pop(context);
                    if (folderVideos.isNotEmpty) _openPlayer(folderVideos.first);
                  },
                ),
                _sheetTile(
                  icon: Symbols.shuffle_rounded,
                  title: 'تشغيل عشوائي',
                  iconBg: cs.tertiaryContainer,
                  iconColor: cs.onTertiaryContainer,
                  onTap: () {
                    Navigator.pop(context);
                    if (folderVideos.isNotEmpty) {
                      folderVideos.shuffle();
                      _openPlayer(folderVideos.first);
                    }
                  },
                ),
                const Divider(height: 1),
                _sheetTile(
                  icon: Symbols.info_rounded,
                  title: 'خصائص المجلد',
                  iconBg: cs.secondaryContainer,
                  iconColor: cs.onSecondaryContainer,
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(folderName),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoRow('عدد الملفات', '${folderVideos.length}'),
                            _infoRow('الحجم الإجمالي', sizeStr),
                            _infoRow('أول ملف', folderVideos.isNotEmpty ? folderVideos.first.modified.toString() : '-'),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('موافق')),
                        ],
                      ),
                    );
                  },
                ),
                _sheetTile(
                  icon: _isFavorite(folderName) ? Symbols.star_rounded : Symbols.star_outline_rounded,
                  title: _isFavorite(folderName) ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                  iconBg: cs.tertiaryContainer,
                  iconColor: cs.onTertiaryContainer,
                  onTap: () {
                    Navigator.pop(context);
                    _toggleFavorite(folderName);
                  },
                ),
                const Divider(height: 1),
                _sheetTile(
                  icon: allHidden ? Symbols.visibility_rounded : Symbols.visibility_off_rounded,
                  title: allHidden ? 'إظهار الكل' : 'إخفاء الكل',
                  iconBg: cs.errorContainer,
                  iconColor: cs.onErrorContainer,
                  onTap: () {
                    Navigator.pop(context);
                    for (final v in folderVideos) {
                      if (allHidden) {
                        lib.unhideVideo(v.path);
                      } else {
                        lib.hideVideo(v.path);
                      }
                    }
                  },
                ),
                _sheetTile(
                  icon: Symbols.delete_rounded,
                  title: 'delete'.tr(),
                  iconBg: cs.errorContainer,
                  iconColor: cs.onErrorContainer,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteFolder(folderVideos);
                  },
                ),
                const Divider(height: 1),
                _sheetTile(
                  icon: Symbols.swap_horiz_rounded,
                  title: 'تحويل الكل (${'close'.tr()})',
                  enabled: false,
                ),
                _sheetTile(
                  icon: Symbols.music_note_rounded,
                  title: 'استخراج الصوت (${'close'.tr()})',
                  enabled: false,
                ),
                _sheetTile(
                  icon: Symbols.image_rounded,
                  title: 'إعادة توليد الصور (${'close'.tr()})',
                  enabled: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _buildVideoOptionsSheet(VideoItem video) {
    final cs = Theme.of(context).colorScheme;
    final lib = context.read<LibraryProvider>();
    final isHidden = lib.hiddenPaths.contains(video.path);

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(video.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500, fontSize: 14)),
                ),
                const Divider(height: 1),
                _sheetTile(
                  icon: Symbols.play_arrow_rounded,
                  title: 'تشغيل',
                  iconBg: cs.primaryContainer,
                  iconColor: cs.onPrimaryContainer,
                  onTap: () {
                    Navigator.pop(context);
                    _openPlayer(video);
                  },
                ),
                _sheetTile(
                  icon: Symbols.info_rounded,
                  title: 'معلومات',
                  iconBg: cs.secondaryContainer,
                  iconColor: cs.onSecondaryContainer,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => InfoScreen(video: video)));
                  },
                ),
                const Divider(height: 1),
                _sheetTile(
                  icon: Symbols.content_cut_rounded,
                  title: 'قص الفيديو (${'close'.tr()})',
                  enabled: false,
                ),
                _sheetTile(
                  icon: Symbols.swap_horiz_rounded,
                  title: 'تحويل صيغة (${'close'.tr()})',
                  enabled: false,
                ),
                _sheetTile(
                  icon: Symbols.music_note_rounded,
                  title: 'استخراج الصوت (${'close'.tr()})',
                  enabled: false,
                ),
                _sheetTile(
                  icon: Symbols.gif_rounded,
                  title: 'صورة متحركة GIF (${'close'.tr()})',
                  enabled: false,
                ),
                const Divider(height: 1),
                _sheetTile(
                  icon: _isFavorite(video.path) ? Symbols.star_rounded : Symbols.star_outline_rounded,
                  title: _isFavorite(video.path) ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                  iconBg: cs.tertiaryContainer,
                  iconColor: cs.onTertiaryContainer,
                  onTap: () {
                    Navigator.pop(context);
                    _toggleFavorite(video.path);
                  },
                ),
                _sheetTile(
                  icon: Symbols.playlist_add_rounded,
                  title: 'إضافة إلى قائمة التشغيل',
                  iconBg: cs.tertiaryContainer,
                  iconColor: cs.onTertiaryContainer,
                  onTap: () {
                    Navigator.pop(context);
                    if (!_playlist.contains(video.path)) {
                      _playlist.add(video.path);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تمت الإضافة إلى قائمة التشغيل')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الملف موجود مسبقاً في القائمة')),
                      );
                    }
                  },
                ),
                _sheetTile(
                  icon: Symbols.drive_file_rename_outline_rounded,
                  title: 'تغيير الاسم',
                  iconBg: cs.surfaceContainerHighest,
                  iconColor: cs.onSurfaceVariant,
                  onTap: () {
                    Navigator.pop(context);
                    _renameFile(video);
                  },
                ),
                const Divider(height: 1),
                _sheetTile(
                  icon: Symbols.share_rounded,
                  title: 'مشاركة',
                  iconBg: cs.tertiaryContainer,
                  iconColor: cs.onTertiaryContainer,
                  onTap: () {
                    Navigator.pop(context);
                    Share.shareXFiles([XFile(video.path)], subject: video.name);
                  },
                ),
                _sheetTile(
                  icon: Symbols.content_copy_rounded,
                  title: 'نسخ المسار',
                  iconBg: cs.surfaceContainerHighest,
                  iconColor: cs.onSurfaceVariant,
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: video.path));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ المسار')),
                    );
                  },
                ),
                _sheetTile(
                  icon: Symbols.folder_open_rounded,
                  title: 'فتح في مدير الملفات',
                  iconBg: cs.surfaceContainerHighest,
                  iconColor: cs.onSurfaceVariant,
                  onTap: () {
                    Navigator.pop(context);
                    _openInFileManager(video);
                  },
                ),
                const Divider(height: 1),
                _sheetTile(
                  icon: Symbols.image_rounded,
                  title: 'إعادة توليد الصورة (${'close'.tr()})',
                  enabled: false,
                ),
                _sheetTile(
                  icon: Symbols.subtitles_rounded,
                  title: 'استخراج الترجمة (${'close'.tr()})',
                  enabled: false,
                ),
                _sheetTile(
                  icon: Symbols.bar_chart_rounded,
                  title: 'خصائص الترميز (${'close'.tr()})',
                  enabled: false,
                ),
                const Divider(height: 1),
                _sheetTile(
                  icon: isHidden ? Symbols.visibility_rounded : Symbols.visibility_off_rounded,
                  title: isHidden ? 'إلغاء الإخفاء' : 'إخفاء',
                  iconBg: isHidden ? cs.secondaryContainer : cs.errorContainer,
                  iconColor: isHidden ? cs.onSecondaryContainer : cs.onErrorContainer,
                  onTap: () {
                    Navigator.pop(context);
                    if (isHidden) {
                      lib.unhideVideo(video.path);
                    } else {
                      lib.hideVideo(video.path);
                    }
                  },
                ),
                _sheetTile(
                  icon: Symbols.delete_rounded,
                  title: 'delete'.tr(),
                  iconBg: cs.errorContainer,
                  iconColor: cs.onErrorContainer,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteFile(video);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required String title,
    Color? iconBg,
    Color? iconColor,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    final bg = iconBg ?? cs.surfaceContainerHighest;
    final fg = iconColor ?? cs.onSurfaceVariant;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: fg, size: 22),
        ),
        title: Text(title, style: TextStyle(color: enabled ? cs.onSurface : cs.onSurfaceVariant, fontSize: 14)),
        onTap: enabled
            ? onTap
            : () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('close'.tr()))),
      ),
    );
  }

  void _renameFile(VideoItem video) {
    final controller = TextEditingController(text: video.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغيير الاسم'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'الاسم الجديد'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != video.name) {
                final oldFile = File(video.path);
                final newPath = '${oldFile.parent.path}/$newName.${video.extension}';
                try {
                  oldFile.renameSync(newPath);
                  context.read<LibraryProvider>().scan();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تغيير الاسم بنجاح')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل تغيير الاسم: $e')),
                  );
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFile(VideoItem video) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete'.tr()),
        content: Text('${'confirm_delete_file'.tr()} "${video.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr())),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final file = File(video.path);
              if (file.existsSync()) {
                file.deleteSync();
                context.read<LibraryProvider>().scan();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم حذف "${video.name}"')),
                );
              }
            },
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(List<VideoItem> videos) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete'.tr()),
        content: Text('${'confirm_delete_file'.tr()} ${videos.length} فيديو؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr())),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (final v in videos) {
                final file = File(v.path);
                if (file.existsSync()) file.deleteSync();
              }
              context.read<LibraryProvider>().scan();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم حذف ${videos.length} فيديو')),
              );
            },
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
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
}