import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final Map<String, Uint8List?> _memoryCache = {};
  final Set<String> _pendingPaths = {};
  final List<String> _queue = [];
  int _activeJobs = 0;
  static const int _maxConcurrent = 3;

  Future<Uint8List?> get(String videoPath) async {
    // 1. من الذاكرة
    if (_memoryCache.containsKey(videoPath)) {
      return _memoryCache[videoPath];
    }

    // 2. من القرص
    final cacheFile = await _cacheFile(videoPath);
    if (await cacheFile.exists()) {
      final bytes = await cacheFile.readAsBytes();
      _memoryCache[videoPath] = bytes;
      return bytes;
    }

    // 3. إضافة للقائمة
    if (!_pendingPaths.contains(videoPath)) {
      _pendingPaths.add(videoPath);
      _queue.add(videoPath);
      _processQueue();
    }

    // انتظار النتيجة
    final completer = Completer<Uint8List?>();
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_memoryCache.containsKey(videoPath)) {
        timer.cancel();
        completer.complete(_memoryCache[videoPath]);
      }
    });
    return await completer.future;
  }

  void _processQueue() async {
    while (_queue.isNotEmpty && _activeJobs < _maxConcurrent) {
      _activeJobs++;
      final path = _queue.removeAt(0);
      try {
        final player = Player();
        await player.open(Media(path), play: false);
        await Future.delayed(const Duration(milliseconds: 500));
        final screenshot = await player.screenshot(format: 'image/jpeg');
        await player.dispose();

        if (screenshot != null && screenshot.isNotEmpty) {
          final cacheFile = await _cacheFile(path);
          await cacheFile.writeAsBytes(screenshot);
          _memoryCache[path] = screenshot;
        }
      } catch (_) {
        _memoryCache[path] = null;
      } finally {
        _pendingPaths.remove(path);
        _activeJobs--;
      }
    }
  }

  Future<File> _cacheFile(String videoPath) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/thumb_${videoPath.hashCode}.jpg');
  }
}