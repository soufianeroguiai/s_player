import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_item.dart';

/// يولّد ويخزّن الصور المصغّرة لفيديوهات المكتبة.
///
/// المصدر الأساسي هو [AssetEntity.thumbnailDataWithSize] من photo_manager:
/// استخراج native سريع لا يفتح أي مشغل فيديو ولا ينتظر أي مهلة يدوية.
/// يُستخدم استخراج لقطة عبر media_kit فقط كحل بديل نادر للملفات
/// المفتوحة يدوياً (زر "فتح ملف") التي لا تملك AssetEntity مقابل في
/// مكتبة الوسائط، وبالتالي لا تمر بالمسار السريع.
class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final Map<String, ValueNotifier<Uint8List?>> _notifiers = {};
  final Set<String> _pendingPaths = {};

  ValueNotifier<Uint8List?> getNotifier(VideoItem video) {
    final path = video.path;
    if (!_notifiers.containsKey(path)) {
      _notifiers[path] = ValueNotifier(null);
      _generate(video);
    }
    return _notifiers[path]!;
  }

  Future<void> _generate(VideoItem video) async {
    final path = video.path;
    if (_pendingPaths.contains(path)) return;
    _pendingPaths.add(path);

    try {
      final cacheFile = await _cacheFile(path);
      if (await cacheFile.exists()) {
        _notifiers[path]?.value = await cacheFile.readAsBytes();
        return;
      }

      // video.id يساوي المسار نفسه فقط للفيديوهات المفتوحة يدوياً
      // (انظر VideoItem.fromPath)، بينما فيديوهات المكتبة الممسوحة
      // عبر LibraryProvider.scan() لها asset.id حقيقي من photo_manager.
      final bytes = video.id != path
          ? await _fromAssetEntity(video.id)
          : await _fromMediaKitScreenshot(path);

      if (bytes != null) {
        await cacheFile.writeAsBytes(bytes);
        _notifiers[path]?.value = bytes;
      }
    } catch (e) {
      debugPrint('تعذّر توليد الصورة المصغّرة لـ $path: $e');
    } finally {
      _pendingPaths.remove(path);
    }
  }

  Future<Uint8List?> _fromAssetEntity(String assetId) async {
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return null;
      return await asset.thumbnailDataWithSize(
        const ThumbnailSize(360, 240),
        quality: 80,
      );
    } catch (e) {
      debugPrint('فشل استخراج صورة مصغّرة عبر photo_manager: $e');
      return null;
    }
  }

  /// حل بديل فقط لملف فُتح يدوياً وليس جزءاً من مكتبة الوسائط الممسوحة.
  /// نادر الاستخدام مقارنة بالمسار الأساسي، لذا التكلفة (فتح مشغل
  /// مؤقت) مقبولة هنا.
  Future<Uint8List?> _fromMediaKitScreenshot(String path) async {
    Player? player;
    try {
      player = Player();
      await player.open(Media(path), play: false);
      await Future.delayed(const Duration(milliseconds: 400));
      final shot = await player.screenshot(format: 'image/jpeg');
      return (shot != null && shot.isNotEmpty) ? shot : null;
    } catch (e) {
      debugPrint('فشل استخراج لقطة عبر media_kit: $e');
      return null;
    } finally {
      await player?.dispose();
    }
  }

  Future<File> _cacheFile(String videoPath) async {
    final dir = await getTemporaryDirectory();
    // hashCode هنا مجرد اسم ملف مؤقت غير حساس (وليس معرّفاً دائماً)؛
    // في أسوأ الأحوال نادرة الحدوث يُعاد توليد الصورة، وهو غير ضار.
    return File('${dir.path}/thumb_${videoPath.hashCode}.jpg');
  }
}
