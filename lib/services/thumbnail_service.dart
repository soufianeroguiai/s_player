import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_item.dart';

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final Map<String, ValueNotifier<Uint8List?>> _notifiers = {};
  final Map<String, ValueNotifier<String?>> _errors = {};
  final Set<String> _pending = {};
  int _active = 0;
  static const _maxConcurrent = 2;
  final List<Future<void> Function()> _queue = [];

  ValueNotifier<Uint8List?> getNotifier(VideoItem video) {
    final path = video.path;
    if (!_notifiers.containsKey(path)) {
      _notifiers[path] = ValueNotifier(null);
      _errors[path] = ValueNotifier(null);
      _enqueue(video);
    }
    return _notifiers[path]!;
  }

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

      // 1. photo_manager (سريع)
      if (video.id != path) {
        try {
          bytes = await _fromPhotoManager(video.id);
        } catch (_) {}
      }

      // 2. media_kit
      if (bytes == null) {
        final result = await _fromMediaKit(video.path, cacheFile.path);
        if (result.error != null) {
          _errors[path]?.value = result.error;
        } else {
          bytes = result.bytes;
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        if (!await cacheFile.exists()) {
          await cacheFile.writeAsBytes(bytes);
        }
        _notifiers[path]?.value = bytes;
        _errors[path]?.value = null; // نجاح
      } else {
        _errors[path]?.value ??= 'تعذر إنشاء صورة مصغرة';
      }
    } catch (e) {
      _errors[path]?.value = 'خطأ عام: $e';
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

  Future<({Uint8List? bytes, String? error})> _fromMediaKit(
      String videoPath, String savePath) async {
    final player = Player();
    try {
      await player.open(Media(videoPath), play: false);

      final duration = player.state.duration;
      final bool hasDuration = duration.inMilliseconds > 0;

      // إذا كانت المدة معروفة، ننتقل إلى الثانية 5 أو 30% من المدة
      if (hasDuration) {
        final seekPos = duration.inSeconds > 10
            ? const Duration(seconds: 5)
            : duration * 0.3;
        await player.seek(seekPos);
      } else {
        // بدون مدة، نعتمد على التشغيل المباشر
        // نبدأ اللعب فوراً (بدون تقديم) ونتوقف بسرعة
        await player.play();
        await Future.delayed(const Duration(milliseconds: 300));
        await player.pause();
      }

      // انتظار لتحضير الإطار
      await Future.delayed(const Duration(milliseconds: 500));

      // التقاط لقطة JPEG
      Uint8List? screenshotBytes;
      try {
        screenshotBytes = await player.screenshot(format: 'image/jpeg');
      } catch (_) {}

      if (screenshotBytes != null && screenshotBytes.isNotEmpty) {
        final file = File(savePath);
        await file.writeAsBytes(screenshotBytes);
        return (bytes: screenshotBytes, error: null);
      }

      // الخطة البديلة: إذا لم تنجح اللقطة الأولى، نجرب تشغيل-إيقاف-لقطة
      if (!hasDuration || screenshotBytes == null) {
        await player.play();
        await Future.delayed(const Duration(milliseconds: 300));
        await player.pause();
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          screenshotBytes = await player.screenshot(format: 'image/jpeg');
        } catch (_) {}
        if (screenshotBytes != null && screenshotBytes.isNotEmpty) {
          final file = File(savePath);
          await file.writeAsBytes(screenshotBytes);
          return (bytes: screenshotBytes, error: null);
        }
      }

      return (bytes: null, error: 'تعذر التقاط إطار (حاول مجدداً)');
    } catch (e) {
      return (bytes: null, error: 'media_kit: $e');
    } finally {
      player.dispose();
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