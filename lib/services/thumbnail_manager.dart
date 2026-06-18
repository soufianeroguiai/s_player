import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ThumbnailManager {
  static final Map<String, File?> _cache = {};

  static Future<Directory> _thumbDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory('${dir.path}/thumbnails');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    return thumbDir;
  }

  static String _fileName(String videoPath) {
    return videoPath.hashCode.toString();
  }

  /// يُرجع File الصورة المصغرة (من الكاش أو القرص أو يولّدها)
  static Future<File?> getThumbnail(String videoPath) async {
    // 1. الذاكرة
    if (_cache.containsKey(videoPath)) {
      return _cache[videoPath];
    }

    final dir = await _thumbDir();
    final file = File('${dir.path}/${_fileName(videoPath)}.jpg');

    // 2. القرص
    if (await file.exists()) {
      _cache[videoPath] = file;
      return file;
    }

    // 3. توليد
    try {
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        maxWidth: 300,
      );

      if (thumbPath != null) {
        final generated = File(thumbPath);
        await generated.copy(file.path);
        _cache[videoPath] = file;
        return file;
      }
    } catch (e) {
      return null;
    }

    return null;
  }

  /// تحميل مسبق
  static Future<void> preload(String videoPath) async {
    if (!_cache.containsKey(videoPath)) {
      _cache[videoPath] = await getThumbnail(videoPath);
    }
  }
}