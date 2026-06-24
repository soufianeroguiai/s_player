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
    return _errors.putIfAbsent(video.path, () => ValueNotifier(null));
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
        await cacheFile.delete();
      }

      final bytes = await _ffmpegThumb(video, cacheFile.path);
      if (bytes != null && bytes.isNotEmpty) {
        await cacheFile.writeAsBytes(bytes);
        _notifiers[path]?.value = bytes;
      } else {
        _errors[path]?.value ??= 'تعذّر استخراج الصورة';
      }
    } catch (e) {
      _errors[path]?.value = 'خطأ: $e';
      debugPrint('ThumbnailService._generate: $e');
    } finally {
      _pending.remove(path);
    }
  }

  Future<Uint8List?> _ffmpegThumb(VideoItem video, String savePath) async {
    final videoPath = video.path;
    if (!await File(videoPath).exists()) {
      _errors[videoPath]?.value = 'الملف غير موجود';
      return null;
    }

    String inputPath = videoPath;
    Link? symlink;
    if (videoPath.length > 200) {
      try {
        final tmp = await getTemporaryDirectory();
        final linkPath = '${tmp.path}/sv_${_shortHash(videoPath)}.vid';
        symlink = Link(linkPath);
        if (!await symlink.exists()) {
          await symlink.create(videoPath);
        }
        inputPath = linkPath;
      } catch (_) {}
    }

    try {
      final seekSec = video.duration.inSeconds > 0
          ? (video.duration.inSeconds * 0.1).round().clamp(2, 99999)
          : 5;

      final cmd = '-y -ss $seekSec -noaccurate_seek -i "$inputPath"'
          ' -vframes 1'
          ' -vf "scale=720:-2"'
          ' -q:v 4'
          ' -threads 1'
          ' "$savePath"';

      // ✅ استخدام execute() مباشرة مع Future.timeout بدلاً من .timeout على session
      final session = await FFmpegKit.execute(cmd);

      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        final out = File(savePath);
        if (await out.exists()) {
          final bytes = await out.readAsBytes();
          if (bytes.isNotEmpty) return bytes;
        }
        _errors[videoPath]?.value = 'الملف الناتج فارغ';
      } else {
        final log = await session.getOutput();
        _errors[videoPath]?.value = 'FFmpeg فشل (${rc?.getValue()})';
        debugPrint('ThumbnailService FFmpeg log:\n$log');
      }
      return null;
    } catch (e) {
      _errors[videoPath]?.value = 'استثناء: $e';
      debugPrint('ThumbnailService._ffmpegThumb: $e');
      return null;
    } finally {
      if (symlink != null) {
        try { await symlink.delete(); } catch (_) {}
      }
    }
  }

  Future<File> _cacheFile(String videoPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory('${dir.path}/thumbnails');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    return File('${thumbDir.path}/${_shortHash(videoPath)}.jpg');
  }

  String _shortHash(String input) {
    int h = 5381;
    for (int i = 0; i < input.length; i++) {
      h = ((h << 5) + h + input.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  Future<void> clearCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory('${dir.path}/thumbnails');
    if (await thumbDir.exists()) await thumbDir.delete(recursive: true);
    _notifiers.forEach((_, n) => n.value = null);
    _notifiers.clear();
    _errors.clear();
    _pending.clear();
    _queue.clear();
    _active = 0;
  }
}