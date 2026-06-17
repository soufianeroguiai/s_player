import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_item.dart';

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

  Future<void> scan() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // طلب الصلاحية من photo_manager (تتعامل مع Android 13+ تلقائياً)
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) {
        _error = 'لم يتم منح الإذن للوصول إلى الوسائط.\nالرجاء منح الصلاحية من إعدادات التطبيق.';
        _loading = false;
        notifyListeners();
        return;
      }

      // جلب ألبومات الفيديو فقط
      final albums = await PhotoManager.getAssetPathList(type: RequestType.video);
      final List<VideoItem> result = [];

      for (final album in albums) {
        final count = await album.assetCountAsync;
        // استخدام getAssetListPaged لتحميل تدريجي (أحدث وأكفأ)
        final assets = await album.getAssetListPaged(page: 0, size: count);
        for (final asset in assets) {
          // استخدام getMediaUrl للحصول على مسار يمكن قراءته (content://)
          final mediaUrl = await asset.getMediaUrl();
          if (mediaUrl == null) continue;

          result.add(VideoItem(
            id: asset.id,
            path: mediaUrl,
            name: asset.title ?? 'فيديو ${asset.id}',
            size: asset.size,
            modified: asset.modifiedDateTime,
            folder: album.name,
            duration: asset.videoDuration,
          ));
        }
      }

      result.sort((a, b) => b.modified.compareTo(a.modified));
      _videos = result;
    } catch (e) {
      _error = 'فشل المسح: $e';
    }

    _loading = false;
    notifyListeners();
    _loadThumbnails();
  }

  Future<void> _loadThumbnails() async {
    final videosToProcess = List<VideoItem>.from(_videos);
    try {
      for (final album in await PhotoManager.getAssetPathList(type: RequestType.video)) {
        final count = await album.assetCountAsync;
        final assets = await album.getAssetListPaged(page: 0, size: count);
        for (final video in videosToProcess) {
          if (!_videos.contains(video)) continue;
          try {
            final asset = assets.firstWhere((a) => a.id == video.id,
                orElse: () => assets.first);
            final thumb = await asset.thumbnailDataWithSize(
              const ThumbnailSize(180, 120),
              quality: 75,
            );
            if (thumb != null) {
              video.thumbnail = thumb.toList();
              notifyListeners();
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
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
    await p.setInt('pos_${path.hashCode}', pos.inMilliseconds);
  }

  Future<Duration?> getPosition(String path) async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt('pos_${path.hashCode}');
    if (ms == null || ms == 0) return null;
    return Duration(milliseconds: ms);
  }
}