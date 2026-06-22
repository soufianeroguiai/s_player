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
    final notifier = ThumbnailService().getNotifier(video);

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ValueListenableBuilder<Uint8List?>(
          valueListenable: notifier,
          builder: (context, bytes, child) {
            if (bytes == null) {
              return _placeholder();
            }
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _placeholder(),
            );
          },
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.video_file_rounded, color: Colors.white30, size: 36),
      ),
    );
  }
}
