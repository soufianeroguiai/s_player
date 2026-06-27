import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_item.dart';

class LibraryProvider extends ChangeNotifier {
  List<VideoItem> _videos = [];
  List<String> _recentPaths = [];
  Set<String> _hiddenPaths = {};
  bool _loading = false;
  String? _error;

  final Map<String, int> _positions = {};

  List<VideoItem> get videos => _videos.where((v) => !_hiddenPaths.contains(v.path)).toList();
  List<VideoItem> get allVideos => _videos;
  List<String> get recentPaths => _recentPaths;
  Set<String> get hiddenPaths => _hiddenPaths;
  bool get loading => _loading;
  String? get error => _error;

  Map<String, List<VideoItem>> get byFolder {
    final map = <String, List<VideoItem>>{};
    for (final v in videos) {
      map.putIfAbsent(v.folder, () => []).add(v);
    }
    return map;
  }

  Future<void> loadHidden() async {
    final p = await SharedPreferences.getInstance();
    _hiddenPaths = Set<String>.from(p.getStringList('hidden_paths') ?? []);
    notifyListeners();
  }

  Future<void> hideVideo(String path) async {
    _hiddenPaths.add(path);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('hidden_paths', _hiddenPaths.toList());
    notifyListeners();
  }

  Future<void> unhideVideo(String path) async {
    _hiddenPaths.remove(path);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('hidden_paths', _hiddenPaths.toList());
    notifyListeners();
  }

  Future<void> clearHidden() async {
    _hiddenPaths.clear();
    final p = await SharedPreferences.getInstance();
    await p.remove('hidden_paths');
    notifyListeners();
  }

  Future<void> loadCachedVideos() async {
    try {
      await loadHidden();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/video_cache.json');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);
        _videos = jsonList
            .map((e) => VideoItem.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
      await _loadPositions();
    } catch (e) {
      debugPrint('فشل تحميل الذاكرة المؤقتة: $e');
    }
  }

  Future<void> _loadPositions() async {
    final p = await SharedPreferences.getInstance();
    for (final video in _videos) {
      final ms = p.getInt('pos_${video.path}');
      if (ms != null && ms > 0) {
        _positions[video.path] = ms;
      }
    }
  }

  Future<void> _saveVideosToCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/video_cache.json');
      final jsonList = _videos.map((v) => v.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('فشل حفظ الذاكرة المؤقتة: $e');
    }
  }

  Future<VideoItem?> _buildVideoItem(AssetEntity asset, String albumName) async {
    try {
      final file = await asset.file;
      if (file == null) return null;

      String name = asset.title ?? '';
      if (name.isEmpty || name.length < 2) {
        name = file.path.split('/').last;
        final dotIndex = name.lastIndexOf('.');
        if (dotIndex != -1) {
          name = name.substring(0, dotIndex);
        }
        if (name.length < 2) {
          name = '$albumName ${asset.id}';
        }
      }

      return VideoItem(
        id: asset.id,
        path: file.path,
        name: name,
        size: file.lengthSync(),
        modified: asset.modifiedDateTime,
        folder: albumName,
        duration: asset.videoDuration,
        subtitleTypes: const [],
      );
    } catch (e) {
      debugPrint('خطأ في بناء عنصر الفيديو: $e');
      return null;
    }
  }

  Future<void> scan() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) {
        _error = 'لم يتم منح الإذن للوصول إلى الوسائط.';
        _loading = false;
        notifyListeners();
        return;
      }

      final albums = await PhotoManager.getAssetPathList(type: RequestType.video);
      final List<VideoItem> result = [];

      const batchSize = 12;
      for (final album in albums) {
        // تجاهل الألبومات الافتراضية مثل "Recent" لتفادي التكرار
        if (album.name == 'Recent' || album.isVirtual) continue;

        final count = await album.assetCountAsync;
        final assets = await album.getAssetListRange(start: 0, end: count);

        for (var i = 0; i < assets.length; i += batchSize) {
          final batch = assets.skip(i).take(batchSize);
          final items = await Future.wait(
            batch.map((asset) => _buildVideoItem(asset, album.name)),
          );
          result.addAll(items.whereType<VideoItem>());
        }
      }

      result.sort((a, b) => b.modified.compareTo(a.modified));
      _videos = result;
      await _saveVideosToCache();
      await _loadPositions();
    } catch (e) {
      _error = 'فشل المسح: $e';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> loadRecent() async {
    final p = await SharedPreferences.getInstance();
    _recentPaths = p.getStringList('recent_paths') ?? [];
    notifyListeners();
  }

  Future<void> addRecent(String path) async {
    _recentPaths.remove(path);
    _recentPaths.insert(0, path);
    if (_recentPaths.length > 30) _recentPaths.removeLast();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('recent_paths', _recentPaths);
    notifyListeners();
  }

  Future<void> clearRecent() async {
    _recentPaths.clear();
    final p = await SharedPreferences.getInstance();
    await p.remove('recent_paths');
    notifyListeners();
  }

  Future<void> savePosition(String path, Duration pos) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('pos_$path', pos.inMilliseconds);
    _positions[path] = pos.inMilliseconds;
    notifyListeners();
  }

  Duration? getCachedPosition(String path) {
    final ms = _positions[path];
    if (ms == null || ms <= 0) return null;
    return Duration(milliseconds: ms);
  }

  Future<Duration?> getPosition(String path) async {
    return getCachedPosition(path) ?? (await _loadPositionFromPrefs(path));
  }

  Future<Duration?> _loadPositionFromPrefs(String path) async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt('pos_$path');
    if (ms == null || ms == 0) return null;
    _positions[path] = ms;
    return Duration(milliseconds: ms);
  }
}