import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final Map<String, ValueNotifier<Uint8List?>> _notifiers = {};
  final Set<String> _pendingPaths = {};
  int _activeJobs = 0;
  static const int _maxConcurrent = 2;

  ValueNotifier<Uint8List?> getNotifier(String videoPath) {
    if (!_notifiers.containsKey(videoPath)) {
      _notifiers[videoPath] = ValueNotifier(null);
      _generate(videoPath);
    }
    return _notifiers[videoPath]!;
  }

  Future<void> _generate(String videoPath) async {
    if (_pendingPaths.contains(videoPath)) return;
    final cacheFile = await _cacheFile(videoPath);
    if (await cacheFile.exists()) {
      _notifiers[videoPath]?.value = await cacheFile.readAsBytes();
      return;
    }
    _pendingPaths.add(videoPath);
    _activeJobs++;
    try {
      final thumbnailData = await compute(_generateThumbnail, videoPath);
      if (thumbnailData != null) {
        await cacheFile.writeAsBytes(thumbnailData);
        _notifiers[videoPath]?.value = thumbnailData;
      }
    } catch (e) {
      debugPrint('Thumbnail generation failed: $e');
    } finally {
      _pendingPaths.remove(videoPath);
      _activeJobs--;
    }
  }

  static Future<Uint8List?> _generateThumbnail(String videoPath) async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 256,
        quality: 75,
        timeMs: 1000, // إطار من الثانية الأولى
      );
      return uint8list;
    } catch (_) {
      return null;
    }
  }

  Future<File> _cacheFile(String videoPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeName = Uri.encodeComponent(videoPath);
    return File('${dir.path}/thumb_$safeName.jpg');
  }

  Future<void> clearCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync().where((f) => f.path.contains('thumb_'));
    for (final f in files) {
      if (f is File) await f.delete();
    }
    _notifiers.clear();
  }
}