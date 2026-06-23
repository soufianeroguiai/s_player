import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_item.dart';

/// يولّد ويخزّن الصور المصغّرة لفيديوهات المكتبة.
///
/// استراتيجية ثلاثية الطبقات:
///   1. Cache محلي   → أسرع (قراءة ملف موجود مسبقاً)
///   2. photo_manager → native سريع (يعمل مع MP4/WebM بشكل ممتاز)
///   3. media_kit    → fallback شامل (يعمل مع MKV/HEVC/AV1 وكل الصيغ)
///
/// المشكلة الأصلية: photo_manager يفشل صامتاً مع HEVC داخل MKV على
/// كثير من أجهزة Android لأن MediaStore لا يولّد thumbnail لها تلقائياً.
/// الحل: نجرب photo_manager أولاً، وعند إرجاع null نتحول تلقائياً
/// لـ media_kit الذي يفتح الملف مباشرة بغض النظر عن الصيغة.
class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final Map<String, ValueNotifier<Uint8List?>> _notifiers = {};
  final Set<String> _pending = {};

  // نحدد التزامن بـ 2 عمليات متوازية بحد أقصى — مع media_kit screenshots
  // أي عدد أكبر يستنزف الذاكرة بشكل ملحوظ (كل player يحجز ~50-100MB)
  int _active = 0;
  static const _maxConcurrent = 2;
  final _queue = <Future<void> Function()>[];

  ValueNotifier<Uint8List?> getNotifier(VideoItem video) {
    final path = video.path;
    if (!_notifiers.containsKey(path)) {
      _notifiers[path] = ValueNotifier(null);
      _enqueue(() => _generate(video));
    }
    return _notifiers[path]!;
  }

  void _enqueue(Future<void> Function() task) {
    if (_active < _maxConcurrent) {
      _active++;
      _run(task);
    } else {
      _queue.add(task);
    }
  }

  void _run(Future<void> Function() task) async {
    try {
      await task();
    } finally {
      _active--;
      if (_queue.isNotEmpty) {
        final next = _queue.removeAt(0);
        _active++;
        _run(next);
      }
    }
  }

  Future<void> _generate(VideoItem video) async {
    final path = video.path;
    if (_pending.contains(path)) return;
    _pending.add(path);

    try {
      // ── طبقة 1: Cache محلي ──
      final cacheFile = await _cacheFile(path);
      if (await cacheFile.exists()) {
        final data = await cacheFile.readAsBytes();
        if (data.isNotEmpty) {
          _notifiers[path]?.value = data;
          return;
        }
        // الملف موجود لكن فارغ (فشل سابق) → نحاول من جديد
        await cacheFile.delete();
      }

      Uint8List? bytes;

      // ── طبقة 2: photo_manager (سريع للصيغ المدعومة) ──
      if (video.id != path) {
        bytes = await _fromAssetEntity(video.id);
      }

      // ── طبقة 3: media_kit (شامل لكل الصيغ بما فيها MKV/HEVC) ──
      // يُفعَّل تلقائياً إذا:
      //   • الملف ليس له AssetEntity (مفتوح يدوياً)
      //   • OR أرجع photo_manager null (HEVC/MKV غير مدعومة من MediaStore)
      bytes ??= await _fromMediaKit(path);

      if (bytes != null && bytes.isNotEmpty) {
        await cacheFile.writeAsBytes(bytes);
        _notifiers[path]?.value = bytes;
      }
    } catch (e) {
      debugPrint('ThumbnailService: فشل $path → $e');
    } finally {
      _pending.remove(path);
    }
  }

  Future<Uint8List?> _fromAssetEntity(String assetId) async {
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return null;
      final bytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(400, 225),
        quality: 82,
      );
      // photo_manager قد يرجع Uint8List فارغ مع MKV/HEVC بدل null
      return (bytes != null && bytes.isNotEmpty) ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _fromMediaKit(String path) async {
    Player? player;
    try {
      player = Player();
      // نستخدم المسار المباشر بدون file:// — media_kit على Android
      // يدعم كلا الصيغتين لكن بعض الصيغ (MKV/HEVC) تحتاج المسار الخام.
      // play: true ثم pause فوري أفضل من play: false مع HEVC/MKV
      // لأن بعض decoders لا تحمّل الـ metadata بدون بدء التشغيل فعلاً.
      await player.open(Media(path), play: true);
      await Future.delayed(const Duration(milliseconds: 100));
      await player.pause();

      // ننتظر حتى تُحمَّل مدة الفيديو (بحد أقصى 4 ثواني)
      const timeout = Duration(seconds: 4);
      final start = DateTime.now();
      while (player.state.duration == Duration.zero) {
        if (DateTime.now().difference(start) > timeout) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // انتقل إلى 8-12% من الفيديو للحصول على لقطة تمثيلية
      final dur = player.state.duration;
      if (dur > const Duration(seconds: 5)) {
        final seekTo = Duration(milliseconds: (dur.inMilliseconds * 0.09).toInt());
        await player.seek(seekTo);
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        await Future.delayed(const Duration(milliseconds: 400));
      }

      final shot = await player.screenshot(format: 'image/jpeg');
      return (shot != null && shot.isNotEmpty) ? shot : null;
    } catch (e) {
      debugPrint('ThumbnailService/media_kit: $e');
      return null;
    } finally {
      try { await player?.dispose(); } catch (_) {}
    }
  }

  Future<File> _cacheFile(String videoPath) async {
    final dir = await getTemporaryDirectory();
    // نستخدم hashCode كاسم ملف مؤقت فقط (ليس معرفاً دائماً)
    return File('${dir.path}/srthumb_${videoPath.hashCode}.jpg');
  }

  /// مسح كل الـ cache لإعادة التوليد (مفيد عند تغيير الجودة)
  Future<void> clearCache() async {
    final dir = await getTemporaryDirectory();
    final files = dir.listSync().where((f) => f.path.contains('srthumb_'));
    for (final f in files) {
      try { await f.delete(); } catch (_) {}
    }
    _notifiers.clear();
  }
}
