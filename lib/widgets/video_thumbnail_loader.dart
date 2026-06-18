import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';

class VideoThumbnailLoader extends StatefulWidget {
  final String videoPath;
  final double width;
  final double height;

  const VideoThumbnailLoader({
    super.key,
    required this.videoPath,
    this.width = 120,
    this.height = 80,
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
      final fileName = widget.videoPath.hashCode.toString();
      final targetPath = '${tempDir.path}/$fileName.png';
      final file = File(targetPath);

      // 1. استخدام المخبأ إن وجد
      if (await file.exists()) {
        if (mounted) setState(() { _thumbnailPath = targetPath; _isLoading = false; });
        return;
      }

      // 2. محاولة video_thumbnail
      String? thumbPath;
      try {
        thumbPath = await VideoThumbnail.thumbnailFile(
          video: widget.videoPath,
          thumbnailPath: tempDir.path,
          imageFormat: ImageFormat.PNG,
          maxHeight: 250,
          quality: 50,
        );
      } catch (_) {}

      if (thumbPath != null && File(thumbPath).existsSync()) {
        // نجحت video_thumbnail
        if (mounted) setState(() { _thumbnailPath = thumbPath; _isLoading = false; });
        return;
      }

      // 3. fallback: استخراج إطار باستخدام media_kit
      final player = Player();
      await player.open(Media(widget.videoPath), play: false);
      await Future.delayed(const Duration(milliseconds: 500));
      final screenshot = await player.screenshot(format: 'image/png');
      await player.dispose();

      if (screenshot != null && screenshot.isNotEmpty) {
        await file.writeAsBytes(screenshot);
        if (mounted) setState(() { _thumbnailPath = targetPath; _isLoading = false; });
        return;
      }

      // فشل كل المحاولات
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("فشل استخراج الصورة المصغرة: $e");
      if (mounted) setState(() => _isLoading = false);
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
                  child: SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                ),
              )
            : _thumbnailPath != null
                ? Image.file(File(_thumbnailPath!), fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => _fallbackIcon())
                : _fallbackIcon(),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      color: Colors.grey[900],
      child: const Icon(Icons.video_file, color: Colors.white54, size: 40),
    );
  }
}