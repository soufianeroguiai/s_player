import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../services/thumbnail_service.dart';

class VideoThumbnailLoader extends StatelessWidget {
  final VideoItem video;
  final double width;
  final double height;

  const VideoThumbnailLoader({
    super.key,
    required this.video,
    this.width = 120,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailService = ThumbnailService();
    thumbnailService.prioritize(video);          // ✅ إعطاء أولوية عالية لهذه الصورة
    final thumbnailNotifier = thumbnailService.getNotifier(video);
    final errorNotifier = thumbnailService.getErrorNotifier(video);

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ValueListenableBuilder<Uint8List?>(
          valueListenable: thumbnailNotifier,
          builder: (context, bytes, child) {
            if (bytes != null) {
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) =>
                    _buildPlaceholder('فشل تحميل الصورة'),
              );
            }
            return ValueListenableBuilder<String?>(
              valueListenable: errorNotifier,
              builder: (context, errorText, _) =>
                  _buildPlaceholder(errorText),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String? errorText) {
    if (errorText != null && errorText.isNotEmpty) {
      return Container(
        color: const Color(0xFF1A1A1A),
        padding: const EdgeInsets.all(4),
        alignment: Alignment.center,
        child: Text(
          errorText,
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 8,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.video_file_rounded,
            color: Colors.white30, size: 36),
      ),
    );
  }
}