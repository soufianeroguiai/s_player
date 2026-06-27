import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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

  bool _isFabVisible = true;
  Timer? _showFabTimer;
  
  final Set<VideoItem> _selectedVideos = {};

  final List<Map<String, dynamic>> _tabs = const [
    {'icon': Symbols.video_library_rounded, 'label': 'مكتبة'},
    {'icon': Symbols.folder_rounded, 'label': 'ملفاتي'},
    {'icon': Symbols.history_rounded, 'label': 'الأخيرة'},
    {'icon': Symbols.more_horiz_rounded, 'label': 'المزيد'},
  ];

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
    _showFabTimer?.cancel();
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

  void _playLastVideo() {
    final lib = context.read<LibraryProvider>();
    final recent = lib.recentPaths;
    if (recent.isNotEmpty) {
      _openByPath(recent.first);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد فيديو سابق')),
      );
    }
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
        const PopupMenuItem(
          value: 'settings',
          child: Row(children: [
            Icon(Symbols.settings_rounded),
            SizedBox(width: 12),
            Text('الإعدادات'),
          ]),
        ),
        const PopupMenuItem(
          value: 'favorites',
          child: Row(children: [
            Icon(Symbols.star_rounded),
            SizedBox(width: 12),
            Text('المفضلة'),
          ]),
        ),
        const PopupMenuItem(
          value: 'playlist',
          child: Row(children: [
            Icon(Symbols.playlist_play_rounded),
            SizedBox(width: 12),
            Text('قائمة التشغيل'),
          ]),
        ),
        const PopupMenuItem(
          value: 'hidden',
          child: Row(children: [
            Icon(Symbols.visibility_off_rounded),
            SizedBox(width: 12),
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

  void _toggleSelection(VideoItem video) {
    setState(() {
      if (_selectedVideos.contains(video)) {
        _selectedVideos.remove(video);
      } else {
        _selectedVideos.add(video);
      }
    });
  }

  void _enterSelectionMode(VideoItem video) {
    _toggleSelection(video);
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final cs = Theme.of(context).colorScheme;
    final lib = context.read<LibraryProvider>();
    final totalCount = lib.videos.length;
    final selectedCount = _selectedVideos.length;
    final isSingle = selectedCount == 1;
    final firstVideo = _selectedVideos.first;

    return AppBar(
      backgroundColor: cs.primaryContainer,
      leading: IconButton(
        icon: Icon(Symbols.close_rounded, color: cs.onPrimaryContainer),
        onPressed: () => setState(() => _selectedVideos.clear()),
      ),
      title: Text(
        '$selectedCount / $totalCount محدد',
        style: TextStyle(color: cs.onPrimaryContainer, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: Icon(Symbols.play_arrow_rounded, color: cs.onPrimaryContainer),
          tooltip: 'تشغيل',
          onPressed: () {
            if (_selectedVideos.isNotEmpty) {
              _openPlayer(firstVideo);
              _selectedVideos.clear();
            }
          },
        ),
        IconButton(
          icon: Icon(Symbols.share_rounded, color: cs.onPrimaryContainer),
          tooltip: 'مشاركة',
          onPressed: () {
            if (_selectedVideos.isNotEmpty) {
              Share.shareXFiles(
                _selectedVideos.map((v) => XFile(v.path)).toList(),
                subject: 'مشاركة ملفات',
              );
              _selectedVideos.clear();
            }
          },
        ),
        IconButton(
          icon: Icon(Symbols.delete_rounded, color: cs.onPrimaryContainer),
          tooltip: 'حذف',
          onPressed: () {
            _confirmDeleteMultiple(_selectedVideos.toList());
            _selectedVideos.clear();
          },
        ),
        if (isSingle)
          IconButton(
            icon: Icon(Symbols.info_rounded, color: cs.onPrimaryContainer),
            tooltip: 'معلومات',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => InfoScreen(video: firstVideo)));
              _selectedVideos.clear();
            },
          ),
        PopupMenuButton<String>(
          icon: Icon(Symbols.more_vert_rounded, color: cs.onPrimaryContainer),
          tooltip: 'المزيد',
          onSelected: (value) {
            if (value == 'rename') {
              if (isSingle) {
                _renameFile(firstVideo);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن إعادة تسمية عناصر متعددة')));
              }
            } else if (value == 'hide') {
              for (final v in _selectedVideos) {
                context.read<LibraryProvider>().hideVideo(v.path);
              }
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إخفاء ${_selectedVideos.length} ملف')));
            } else if (value == 'move') {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ميزة نقل الملف (قريباً)')));
            }
            _selectedVideos.clear();
          },
          itemBuilder: (context) => [
            if (isSingle) const PopupMenuItem(value: 'rename', child: Text('إعادة تسمية')),
            const PopupMenuItem(value: 'hide', child: Text('إخفاء')),
            const PopupMenuItem(value: 'move', child: Text('نقل ملف')),
          ],
        ),
      ],
    );
  }

  void _confirmDeleteMultiple(List<VideoItem> videos) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملفات'),
        content: Text('هل أنت متأكد من حذف ${videos.length} فيديو؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (final v in videos) {
                final file = File(v.path);
                if (file.existsSync()) file.deleteSync();
              }
              context.read<LibraryProvider>().scan();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف ${videos.length} فيديو')));
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final totalWidth = width - 32;
    final tabWidth = totalWidth / _tabs.length;
    final pillWidth = tabWidth - 16;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.90),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                left: (_currentIndex == 3 ? _currentIndex : _currentIndex) * tabWidth + 8,
                top: 8,
                bottom: 8,
                width: pillWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  int newIndex = (details.localPosition.dx / tabWidth).floor().clamp(0, 3);
                  if (newIndex != _currentIndex && newIndex != 3) {
                    setState(() => _currentIndex = newIndex);
                  }
                },
                onHorizontalDragEnd: (details) {
                  int finalIndex = (details.localPosition.dx / tabWidth).floor().clamp(0, 3);
                  if (finalIndex == 3) {
                    _showMoreMenu();
                  }
                },
                child: Row(
                  children: List.generate(_tabs.length, (index) {
                    final tab = _tabs[index];
                    final isActive = _currentIndex == index;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (index == 3) {
                            _showMoreMenu();
                            return;
                          }
                          setState(() => _currentIndex = index);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              tab['icon'],
                              color: isActive ? cs.primary : cs.onSurfaceVariant,
                              size: isActive ? 26 : 24,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tab['label'],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                color: isActive ? cs.primary : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onScrollUpdate(double delta) {
    if (delta < -10) {
      if (_isFabVisible) setState(() => _isFabVisible = false);
      _showFabTimer?.cancel();
    }
    else if (delta > 10) {
      if (!_isFabVisible) setState(() => _isFabVisible = true);
      _showFabTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final lib = context.watch<LibraryProvider>();
    final bool isSelectionMode = _selectedVideos.isNotEmpty;

    return Scaffold(
      extendBody: true,
      appBar: isSelectionMode
          ? _buildSelectionAppBar()
          : AppBar(
              title: const Text('SR Player'),
              centerTitle: false,
              titleTextStyle: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 22),
              actions: [
                AnimatedBuilder(
                  animation: _rotateAnimation,
                  builder: (context, child) => Transform.rotate(angle: _rotateAnimation.value * 3.14159, child: child),
                  child: IconButton(icon: const Icon(Symbols.grid_view_rounded), onPressed: _onViewOptionsPressed, tooltip: 'خيارات العرض والفرز'),
                ),
                IconButton(icon: const Icon(Symbols.search_rounded), onPressed: () => showSearch(context: context, delegate: VideoSearchDelegate(lib.videos, _openPlayer))),
              ],
            ),
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          if (notification.dragDetails != null) {
            _onScrollUpdate(notification.dragDetails!.delta.dy);
          }
          return false;
        },
        child: GestureDetector(
          onTap: () {
            if (isSelectionMode) {
              setState(() => _selectedVideos.clear());
            }
          },
          child: IndexedStack(
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
                  selectedVideos: _selectedVideos,
                  onSelectionToggle: _toggleSelection,
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
                  selectedVideos: _selectedVideos,
                  onSelectionToggle: _toggleSelection,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildFloatingNavBar(),
      floatingActionButton: _isFabVisible && !isSelectionMode
          ? FloatingActionButton(
              onPressed: _playLastVideo,
              backgroundColor: cs.primary,
              shape: const CircleBorder(),
              child: const Icon(Symbols.play_arrow_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildFoldersTab(LibraryProvider lib, SettingsProvider settings) {
    if (_browsingFolder != null) {
      final folderVideos = _sorted(lib.videos.where((v) => v.folder == _browsingFolder).toList());
      return Column(children: [
        Container(color: Theme.of(context).colorScheme.surface, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: Row(children: [
          IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => setState(() => _browsingFolder = null), tooltip: 'رجوع إلى المجلدات'),
          const SizedBox(width: 4),
          Text(_browsingFolder!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
          const Spacer(),
          Text('${folderVideos.length} فيديو', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(width: 8),
        ])),
        const Divider(height: 1),
        Expanded(child: LibraryTab(
          videos: folderVideos,
          gridView: settings.foldersGridView,
          onOpen: _openPlayer,
          onMore: (v) => _buildVideoOptionsSheet(v),
          loading: false,
          selectedVideos: _selectedVideos,
          onSelectionToggle: _toggleSelection,
        )),
      ]);
    }
    return RefreshIndicator(onRefresh: _refreshLibrary, child: FoldersTab(byFolder: lib.byFolder, gridView: settings.foldersGridView, onTap: (folder) => setState(() => _browsingFolder = folder), onMore: _buildFolderOptionsSheet));
  }

  void _buildVideoOptionsSheet(VideoItem video) {
    final cs = Theme.of(context).colorScheme;
    final lib = context.read<LibraryProvider>();
    final isHidden = lib.hiddenPaths.contains(video.path);
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), child: Text(video.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500, fontSize: 14))),
      const Divider(height: 1),
      _sheetTile(icon: Symbols.play_arrow_rounded, title: 'تشغيل', iconBg: cs.primaryContainer, iconColor: cs.onPrimaryContainer, onTap: () { Navigator.pop(context); _openPlayer(video); }),
      _sheetTile(icon: Symbols.info_rounded, title: 'معلومات', iconBg: cs.secondaryContainer, iconColor: cs.onSecondaryContainer, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => InfoScreen(video: video))); }),
      const Divider(height: 1),
      _sheetTile(icon: _isFavorite(video.path) ? Symbols.star_rounded : Symbols.star_outline_rounded, title: _isFavorite(video.path) ? 'إزالة من المفضلة' : 'إضافة للمفضلة', iconBg: cs.tertiaryContainer, iconColor: cs.onTertiaryContainer, onTap: () { Navigator.pop(context); _toggleFavorite(video.path); }),
      _sheetTile(icon: Symbols.playlist_add_rounded, title: 'إضافة إلى قائمة التشغيل', iconBg: cs.tertiaryContainer, iconColor: cs.onTertiaryContainer, onTap: () { Navigator.pop(context); if (!_playlist.contains(video.path)) { _playlist.add(video.path); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الإضافة إلى قائمة التشغيل'))); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الملف موجود مسبقاً في القائمة'))); } }),
      _sheetTile(icon: Symbols.drive_file_rename_outline_rounded, title: 'تغيير الاسم', iconBg: cs.surfaceContainerHighest, iconColor: cs.onSurfaceVariant, onTap: () { Navigator.pop(context); _renameFile(video); }),
      const Divider(height: 1),
      _sheetTile(icon: Symbols.share_rounded, title: 'مشاركة', iconBg: cs.tertiaryContainer, iconColor: cs.onTertiaryContainer, onTap: () { Navigator.pop(context); Share.shareXFiles([XFile(video.path)], subject: video.name); }),
      _sheetTile(icon: Symbols.content_copy_rounded, title: 'نسخ المسار', iconBg: cs.surfaceContainerHighest, iconColor: cs.onSurfaceVariant, onTap: () { Navigator.pop(context); Clipboard.setData(ClipboardData(text: video.path)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ المسار'))); }),
      _sheetTile(icon: Symbols.folder_open_rounded, title: 'فتح في مدير الملفات', iconBg: cs.surfaceContainerHighest, iconColor: cs.onSurfaceVariant, onTap: () { Navigator.pop(context); _openInFileManager(video); }),
      const Divider(height: 1),
      _sheetTile(icon: isHidden ? Symbols.visibility_rounded : Symbols.visibility_off_rounded, title: isHidden ? 'إلغاء الإخفاء' : 'إخفاء', iconBg: isHidden ? cs.secondaryContainer : cs.errorContainer, iconColor: isHidden ? cs.onSecondaryContainer : cs.onErrorContainer, onTap: () { Navigator.pop(context); if (isHidden) { lib.unhideVideo(video.path); } else { lib.hideVideo(video.path); } }),
      _sheetTile(icon: Symbols.delete_rounded, title: 'حذف', iconBg: cs.errorContainer, iconColor: cs.onErrorContainer, onTap: () { Navigator.pop(context); _confirmDeleteFile(video); }),
    ])))));
  }

  void _buildFolderOptionsSheet(String folderName, List<VideoItem> folderVideos) {
    final cs = Theme.of(context).colorScheme;
    final lib = context.read<LibraryProvider>();
    final totalSize = folderVideos.fold<int>(0, (s, v) => s + v.size);
    final sizeStr = totalSize < 1024 * 1024 * 1024 ? '${(totalSize / (1024 * 1024)).toStringAsFixed(0)} MB' : '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    final bool allHidden = folderVideos.every((v) => lib.hiddenPaths.contains(v.path));
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), child: Column(children: [Text(folderName, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500, fontSize: 14)), const SizedBox(height: 4), Text('${folderVideos.length} فيديو  •  $sizeStr', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))])),
      const Divider(height: 1),
      _sheetTile(icon: Symbols.play_arrow_rounded, title: 'تشغيل الكل', iconBg: cs.primaryContainer, iconColor: cs.onPrimaryContainer, onTap: () { Navigator.pop(context); if (folderVideos.isNotEmpty) _openPlayer(folderVideos.first); }),
      _sheetTile(icon: Symbols.shuffle_rounded, title: 'تشغيل عشوائي', iconBg: cs.tertiaryContainer, iconColor: cs.onTertiaryContainer, onTap: () { Navigator.pop(context); if (folderVideos.isNotEmpty) { folderVideos.shuffle(); _openPlayer(folderVideos.first); } }),
      const Divider(height: 1),
      _sheetTile(icon: Symbols.info_rounded, title: 'خصائص المجلد', iconBg: cs.secondaryContainer, iconColor: cs.onSecondaryContainer, onTap: () { Navigator.pop(context); showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(folderName), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [_infoRow('عدد الملفات', '${folderVideos.length}'), _infoRow('الحجم الإجمالي', sizeStr), _infoRow('أول ملف', folderVideos.isNotEmpty ? folderVideos.first.modified.toString() : '-')]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('موافق'))])); }),
      _sheetTile(icon: _isFavorite(folderName) ? Symbols.star_rounded : Symbols.star_outline_rounded, title: _isFavorite(folderName) ? 'إزالة من المفضلة' : 'إضافة للمفضلة', iconBg: cs.tertiaryContainer, iconColor: cs.onTertiaryContainer, onTap: () { Navigator.pop(context); _toggleFavorite(folderName); }),
      const Divider(height: 1),
      _sheetTile(icon: allHidden ? Symbols.visibility_rounded : Symbols.visibility_off_rounded, title: allHidden ? 'إظهار الكل' : 'إخفاء الكل', iconBg: cs.errorContainer, iconColor: cs.onErrorContainer, onTap: () { Navigator.pop(context); for (final v in folderVideos) { if (allHidden) { lib.unhideVideo(v.path); } else { lib.hideVideo(v.path); } } }),
      _sheetTile(icon: Symbols.delete_rounded, title: 'حذف المجلد', iconBg: cs.errorContainer, iconColor: cs.onErrorContainer, onTap: () { Navigator.pop(context); _confirmDeleteFolder(folderVideos); }),
      const Divider(height: 1),
      _sheetTile(icon: Symbols.swap_horiz_rounded, title: 'تحويل الكل (قريباً)', enabled: false),
      _sheetTile(icon: Symbols.music_note_rounded, title: 'استخراج الصوت (قريباً)', enabled: false),
      _sheetTile(icon: Symbols.image_rounded, title: 'إعادة توليد الصور (قريباً)', enabled: false),
    ])))));
  }

  Widget _sheetTile({required IconData icon, required String title, Color? iconBg, Color? iconColor, VoidCallback? onTap, bool enabled = true}) {
    final cs = Theme.of(context).colorScheme;
    final bg = iconBg ?? cs.surfaceContainerHighest;
    final fg = iconColor ?? cs.onSurfaceVariant;
    return Opacity(opacity: enabled ? 1.0 : 0.5, child: ListTile(leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: fg, size: 22)), title: Text(title, style: TextStyle(color: enabled ? cs.onSurface : cs.onSurfaceVariant, fontSize: 14)), onTap: enabled ? onTap : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('قريباً')))));
  }

  void _renameFile(VideoItem video) {
    final controller = TextEditingController(text: video.name);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('تغيير الاسم'), content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'الاسم الجديد'), autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), TextButton(onPressed: () { final newName = controller.text.trim(); if (newName.isNotEmpty && newName != video.name) { final oldFile = File(video.path); final newPath = '${oldFile.parent.path}/$newName.${video.extension}'; try { oldFile.renameSync(newPath); context.read<LibraryProvider>().scan(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير الاسم بنجاح'))); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تغيير الاسم: $e'))); } } Navigator.pop(ctx); }, child: const Text('موافق'))]));
  }

  void _confirmDeleteFile(VideoItem video) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('حذف الملف'), content: Text('هل أنت متأكد من حذف "${video.name}"؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), TextButton(onPressed: () { Navigator.pop(ctx); final file = File(video.path); if (file.existsSync()) { file.deleteSync(); context.read<LibraryProvider>().scan(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف "${video.name}"'))); } }, child: const Text('حذف', style: TextStyle(color: Colors.red)))]));
  }

  void _confirmDeleteFolder(List<VideoItem> videos) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('حذف المجلد'), content: Text('هل أنت متأكد من حذف ${videos.length} فيديو؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), TextButton(onPressed: () { Navigator.pop(ctx); for (final v in videos) { final file = File(v.path); if (file.existsSync()) file.deleteSync(); } context.read<LibraryProvider>().scan(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف ${videos.length} فيديو'))); }, child: const Text('حذف', style: TextStyle(color: Colors.red)))]));
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value),
      ]),
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
                      width: 48,
                      height: 48,
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