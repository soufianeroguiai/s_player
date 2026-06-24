import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
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
  static const _maxConcurrent = 1;
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

      final bytes = await _ffmpegThumb(video, cacheFile.path);
      if (bytes != null && bytes.isNotEmpty) {
        if (!await cacheFile.exists()) {
          await cacheFile.writeAsBytes(bytes);
        }
        _notifiers[path]?.value = bytes;
        _errors[path]?.value = null;
      } else {
        _errors[path]?.value ??= 'فشل استخراج الصورة';
      }
    } catch (e) {
      _errors[path]?.value = 'خطأ: $e';
    } finally {
      _pending.remove(path);
    }
  }

  Future<Uint8List?> _ffmpegThumb(VideoItem video, String savePath) async {
    final videoPath = video.path;
    final file = File(videoPath);
    if (!await file.exists()) {
      _errors[videoPath]?.value = 'الملف غير موجود';
      return null;
    }

    String inputPath = videoPath;
    Link? symlink;  // ✅ استخدمنا Link بدلاً من File

    // إنشاء رابط رمزي قصير إذا كان المسار طويلاً جداً (> 200 حرف)
    if (videoPath.length > 200) {
      try {
        final tmpDir = await getTemporaryDirectory();
        final linkPath = '${tmpDir.path}/tv_${_shortHash(videoPath)}.vid';
        symlink = Link(linkPath);
        if (!await symlink.exists()) {
          await symlink.create(videoPath);  // ✅ الطريقة الصحيحة في Dart
        }
        inputPath = linkPath;
      } catch (_) {
        // إذا فشل نستمر بالمسار الأصلي
      }
    }

    try {
      final int seekSec = video.duration.inSeconds > 0
          ? (video.duration.inSeconds * 0.1).round().clamp(1, 99999)
          : 5;

      final command =
          '-y -ss $seekSec -noaccurate_seek -i "$inputPath" -vframes 1 -vf "scale=720:480" -q:v 5 -an "$savePath"';

      final completer = Completer<Uint8List?>();

      await FFmpegKit.executeAsync(
        command,
        onComplete: (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            final outputFile = File(savePath);
            if (await outputFile.exists()) {
              completer.complete(await outputFile.readAsBytes());
            } else {
              completer.complete(null);
            }
          } else {
            final output = await session.getOutput();
            _errors[videoPath]?.value = 'FFmpeg: ${output ?? "فشل"}';
            completer.complete(null);
          }
        },
      );

      return completer.future;
    } finally {
      // تنظيف الرابط المؤقت
      if (symlink != null) {
        try { await symlink.delete(); } catch (_) {}
      }
    }
  }

  /// تخزين دائم باسم قصير لا يتجاوز 12 حرفاً
  Future<File> _cacheFile(String videoPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory('${dir.path}/thumbnails');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    final name = _shortHash(videoPath);
    return File('${thumbDir.path}/$name.jpg');
  }

  /// هاش بسيط قصير يعتمد على محتوى المسار
  String _shortHash(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = (hash * 31 + input.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<void> clearCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory('${dir.path}/thumbnails');
    if (await thumbDir.exists()) {
      await thumbDir.delete(recursive: true);
    }
    _notifiers.forEach((_, n) => n.value = null);
    _notifiers.clear();
    _errors.clear();
  }
}