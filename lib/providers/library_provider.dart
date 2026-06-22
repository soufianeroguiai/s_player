import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_item.dart';
import '../services/recent_files_service.dart';
import '../services/thumbnail_service.dart';

class LibraryProvider extends ChangeNotifier {
  List<VideoItem> _videos = [];
  List<String> _recentPaths = [];
  bool _loading = false;
  String? _error;

  List<VideoItem> get videos => _videos;
  List<String> get recentPaths => _recentPaths;
  bool get loading => _loading;
  String? get error => _error;

  Map<String, List<VideoItem>> _cachedByFolder = {};
  Map<String, List<VideoItem>> get byFolder => _cachedByFolder;

  void _updateByFolder() {
    final map = <String, List<VideoItem>>{};
    for (final v in _videos) {
      map.putIfAbsent(v.folder, () => []).add(v);
    }
    _cachedByFolder = map;
  }

  Future<void> loadCachedVideos() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/video_cache.json');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);
        _videos = jsonList.map((e) => VideoItem.fromJson(e as Map<String, dynamic>)).toList();
        _updateByFolder();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Cache load error: $e');
    }
  }

  Future<void> _saveVideosToCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/video_cache.json');
      final jsonList = _videos.map((v) => v.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('Cache save error: $e');
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
        if (dotIndex != -1) name = name.substring(0, dotIndex);
        if (name.length < 2) name = '$albumName ${asset.id}';
      }
      return VideoItem(
        id: asset.id,
        path: file.path,
        name: name,
        size: file.lengthSync(),
        modified: asset.modifiedDateTime,
        folder: albumName,
        duration: asset.videoDuration,
        subtitleTypes: [],
      );
    } catch (e) {
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
          final items = await Future.wait(batch.map((asset) => _buildVideoItem(asset, album.name)));
          result.addAll(items.whereType<VideoItem>());
        }
      }
      result.sort((a, b) => b.modified.compareTo(a.modified));
      _videos = result;
      _updateByFolder();
      await _saveVideosToCache();
    } catch (e) {
      _error = 'فشل المسح: $e';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadRecent() async {
    _recentPaths = await RecentFilesService.get();
    notifyListeners();
  }

  Future<void> addRecent(String path) async {
    await RecentFilesService.add(path);
    _recentPaths = await RecentFilesService.get();
    notifyListeners();
  }

  Future<void> clearRecent() async {
    await RecentFilesService.clear();
    _recentPaths = [];
    notifyListeners();
  }

  Future<void> savePosition(String path, Duration pos) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'pos_${Uri.encodeComponent(path)}';
    await prefs.setInt(key, pos.inMilliseconds);
  }

  Future<Duration?> getPosition(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'pos_${Uri.encodeComponent(path)}';
    final ms = prefs.getInt(key);
    if (ms == null || ms == 0) return null;
    return Duration(milliseconds: ms);
  }
}