import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
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

  /// تحميل الفيديوهات المخزنة سابقاً (سريع جداً)
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

  /// حفظ الفيديوهات الحالية إلى ملف مؤقت
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
      final mediaUrl = await asset.getMediaUrl();
      if (mediaUrl == null) return null;

      int fileSize = 0;
      try {
        final file = await asset.file;
        if (file != null) fileSize = file.lengthSync();
      } catch (_) {
        fileSize = 0;
      }

      return VideoItem(
        id: asset.id,
        path: mediaUrl,
        name: asset.title ?? 'فيديو ${asset.id}',
        size: fileSize,
        modified: asset.modifiedDateTime,
        folder: albumName,
        duration: asset.videoDuration,
      );
    } catch (_) {
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
        _error = 'لم يتم منح الإذن للوصول إلى الوسائط.\nالرجاء منح الصلاحية من إعدادات التطبيق.';
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
      await _saveVideosToCache(); // حفظ القائمة بعد المسح الناجح
    } catch (e) {
      _error = 'فشل المسح: $e';
    }

    _loading = false;
    notifyListeners();
    _loadThumbnails();
  }

  Future<void> _loadThumbnails() async {
    final videosToProcess = List<VideoItem>.from(_videos);
    if (videosToProcess.isEmpty) return;

    try {
      final assetMap = <String, AssetEntity>{};
      final albums = await PhotoManager.getAssetPathList(type: RequestType.video);
      for (final album in albums) {
        final count = await album.assetCountAsync;
        final assets = await album.getAssetListRange(start: 0, end: count);
        for (final asset in assets) {
          assetMap[asset.id] = asset;
        }
      }

      for (final video in videosToProcess) {
        if (!_videos.contains(video)) continue;

        final asset = assetMap[video.id];
        if (asset == null) {
          await _generateThumbnailFromVideo(video);
          continue;
        }

        try {
          final thumb = await asset.thumbnailDataWithSize(
            const ThumbnailSize(180, 120),
            quality: 75,
          );
          if (thumb != null && thumb.isNotEmpty) {
            video.thumbnail = thumb.toList();
            notifyListeners();
            continue;
          }
        } catch (_) {}

        await _generateThumbnailFromVideo(video);
      }
    } catch (_) {}
  }

  Future<void> _generateThumbnailFromVideo(VideoItem video) async {
    try {
      final player = Player();
      await player.open(Media(video.path), play: false);
      await Future.delayed(const Duration(milliseconds: 500));
      final screenshot = await player.screenshot(format: 'image/jpeg');
      if (screenshot != null && screenshot.isNotEmpty) {
        video.thumbnail = screenshot.toList();
        notifyListeners();
      }
      await player.dispose();
    } catch (e) {
      debugPrint('فشل استخراج صورة مصغرة بالفيديو: $e');
    }
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