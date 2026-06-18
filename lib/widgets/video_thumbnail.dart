import 'dart:io';
import 'package:flutter/material.dart';
import '../services/thumbnail_manager.dart';

class VideoThumbnail extends StatelessWidget {
  final String videoPath;
  final double width;
  final double height;

  const VideoThumbnail({
    super.key,
    required this.videoPath,
    this.width = 120,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: ThumbnailManager.getThumbnail(videoPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _shimmer();
        }
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          );
        }
        return _placeholder();
      },
    );
  }

  Widget _shimmer() {
    return Container(
      color: Colors.grey[900]!.withOpacity(0.4),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[900],
      child: const Icon(Icons.video_file_rounded, color: Colors.white30, size: 36),
    );
  }
}