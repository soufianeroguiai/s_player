import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail_gen/video_thumbnail_gen.dart';
import '../models/video_item.dart';

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final Map<String, ValueNotifier<Uint8List?>> _notifiers = {};
  final Map<String, ValueNotifier<String?>> _errors = {}; // ✅ خطأ مخصص لكل فيديو
  final Set<String> _pending = {};
  int _active = 0;
  static const _maxConcurrent = 3;
  final List<Future<void> Function()> _queue = [];

  /// يرجع notifier للصورة المصغرة
  ValueNotifier<Uint8List?> getNotifier(VideoItem video) {
    final path = video.path;
    if (!_notifiers.containsKey(path)) {
      _notifiers[path] = ValueNotifier(null);
      _errors[path] = ValueNotifier(null);
      _enqueue(video);
    }
    return _notifiers[path]!;
  }

  /// يرجع notifier لآخر خطأ (إن وجد)
  ValueNotifier<String?> getErrorNotifier(VideoItem video) {
    final path = video.path;
    if (!_errors.containsKey(path)) {
      _errors[path] = ValueNotifier(null);
    }
    return _errors[path]!;
  }

  void _enqueue(VideoItem video) {
    _queue.add(() => _generate(video));
    _drain();
  }

  void _drain() {
    while (_active < _maxConcurrent && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      _active++;
      task().whenComplete(() {
        _active--;
        _drain();
      });
    }
  }

  Future<void> _generate(VideoItem video) async {
    final path = video.path;
    if (_pending.contains(path)) return;
    _pending.add(path);

    // إعادة تعيين الخطأ في البداية
    _errors[path]?.value = null;

    try {
      final cacheFile = await _cacheFile(path);
      if (await cacheFile.exists()) {
        final bytes = await cacheFile.readAsBytes();
        if (bytes.isNotEmpty) {
          _notifiers[path]?.value = bytes;
          return;
        }
      }

      Uint8List? bytes;

      if (video.id != path) {
        try {
          bytes = await _fromPhotoManager(video.id);
        } catch (e) {
          _errors[path]?.value = 'photo_manager: $e';
        }
      }

      bytes ??= await _fromVideoThumbnailGen(path, cacheFile.path);

      if (bytes != null && bytes.isNotEmpty) {
        if (!await cacheFile.exists()) {
          await cacheFile.writeAsBytes(bytes);
        }
        _notifiers[path]?.value = bytes;
      } else {
        // إذا لم نضع خطأ بعد، فهذا يعني أن الطرق كلها فشلت بصمت
        if (_errors[path]?.value == null) {
          _errors[path]?.value = 'All methods returned null';
        }
      }
    } catch (e) {
      _errors[path]?.value = 'ThumbnailService: $e';
    } finally {
      _pending.remove(path);
    }
  }

  Future<Uint8List?> _fromPhotoManager(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return await asset.thumbnailDataWithSize(
      const ThumbnailSize(360, 240),
      quality: 85,
    );
  }

  Future<Uint8List?> _fromVideoThumbnailGen(String videoPath, String savePath) async {
    // ✅ نرجع الخطأ مباشرة إذا الملف غير موجود أو فشل
    final file = File(videoPath);
    if (!await file.exists()) {
      _errors[videoPath]?.value = 'File not found: $videoPath';
      return null;
    }

    try {
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: savePath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 360,
        quality: 85,
        timeMs: 5000,
      );
      if (thumbPath == null) {
        _errors[videoPath]?.value = 'video_thumbnail_gen returned null (timeMs may be > duration?)';
        return null;
      }
      final thumbFile = File(thumbPath);
      if (!await thumbFile.exists()) {
        _errors[videoPath]?.value = 'Thumbnail file not created: $thumbPath';
        return null;
      }
      return await thumbFile.readAsBytes();
    } catch (e) {
      _errors[videoPath]?.value = 'video_thumbnail_gen error: $e';
      return null;
    }
  }

  Future<File> _cacheFile(String videoPath) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/thumb_${videoPath.hashCode}.jpg');
  }

  Future<void> clearCache() async {
    final dir = await getTemporaryDirectory();
    final files = dir.listSync().where((f) => f.path.contains('thumb_'));
    for (final f in files) {
      try { f.deleteSync(); } catch (_) {}
    }
    _notifiers.forEach((_, n) => n.value = null);
    _notifiers.clear();
    _errors.clear();
  }
}