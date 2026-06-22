import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_item.dart';

/// يدير مكتبة الفيديوهات: المسح عبر photo_manager، التخزين المؤقت
/// المحلي، قائمة "الأخيرة"، ومواضع الاستئناف لكل فيديو.
class LibraryProvider extends ChangeNotifier {
  List<VideoItem> _videos = [];
  List<String> _recentPaths = [];
  bool _loading = false;
  String? _error;

  List<VideoItem> get videos => _videos;
  List<String> get recentPaths => _recentPaths;
  bool get loading => _loading;
  String? get error => _error;

  Map<String, List<VideoItem>> get byFolder {
    final map = <String, List<VideoItem>>{};
    for (final v in _videos) {
      map.putIfAbsent(v.folder, () => []).add(v);
    }
    return map;
  }

  Future<void> loadCachedVideos() async {
    try {
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
    } catch (e) {
      debugPrint('فشل تحميل الذاكرة المؤقتة: $e');
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

  /// يحفظ آخر موضع تشغيل لملف معيّن. يُستخدم مسار الملف نفسه كجزء
  /// من المفتاح (بدل الاعتماد فقط على hashCode) لتفادي أي احتمال
  /// تصادم أو عدم ثبات بين تشغيلات مختلفة لتطبيق دارت.
  Future<void> savePosition(String path, Duration pos) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('pos_$path', pos.inMilliseconds);
  }

  Future<Duration?> getPosition(String path) async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt('pos_$path');
    if (ms == null || ms == 0) return null;
    return Duration(milliseconds: ms);
  }
}
