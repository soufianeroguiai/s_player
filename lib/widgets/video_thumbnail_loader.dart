import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class VideoThumbnailLoader extends StatefulWidget {
  final String videoPath;
  final double width;
  final double height;

  const VideoThumbnailLoader({
    super.key,
    required this.videoPath,
    this.width = double.infinity,
    this.height = double.infinity,
  });

  @override
  State<VideoThumbnailLoader> createState() => _VideoThumbnailLoaderState();
}

class _VideoThumbnailLoaderState extends State<VideoThumbnailLoader> {
  String? _thumbnailPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final tempDir = await getTemporaryDirectory();
      // استخدام الـ hashCode لإنشاء اسم ملف فريد وآمن ومستقر ونظيف
      final fileName = 'thumb_${widget.videoPath.hashCode}.jpg';
      final targetPath = '${tempDir.path}/$fileName';
      final file = File(targetPath);

      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _thumbnailPath = targetPath;
            _isLoading = false;
          });
        }
        return;
      }

      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: widget.videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG, // تحويله لـ JPEG للحجم الخفيف والسرعة
        maxHeight: 200, // دقة ممتازة للكروت الصغير والشبكية
        quality: 60,
      );

      if (thumbnail != null) {
        final generatedFile = File(thumbnail);
        if (await generatedFile.exists()) {
          await generatedFile.rename(targetPath);
        }
      }

      if (mounted) {
        setState(() {
          _thumbnailPath = targetPath;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ في استخراج الصورة المصغرة: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _isLoading
            ? Container(
                color: Colors.grey[900],
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                  ),
                ),
              )
            : _thumbnailPath != null && File(_thumbnailPath!).existsSync()
                ? Image.file(
                    File(_thumbnailPath!),
                    fit: BoxFit.cover,
                    cacheWidth: widget.width != double.infinity ? (widget.width * 2).toInt() : 250,
                    errorBuilder: (ctx, err, stack) => const Icon(Icons.video_file, color: Colors.white54, size: 40),
                  )
                : Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.play_circle_outline, color: Colors.white54, size: 40),
                  ),
      ),
    );
  }
}
