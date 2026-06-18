import 'dart:io';
import 'package:flutter/material.dart';
import '../services/thumbnail_manager.dart';

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
  late Future<File?> _future;

  @override
  void initState() {
    super.initState();
    _future = ThumbnailManager.getThumbnail(widget.videoPath);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<File?>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return Container(
                color: Colors.grey[900],
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                ),
              );
            }

            return Image.file(
              snapshot.data!,
              fit: BoxFit.cover,
              width: widget.width,
              height: widget.height,
              errorBuilder: (ctx, err, stack) => const Icon(
                Icons.video_file,
                color: Colors.white54,
                size: 40,
              ),
            );
          },
        ),
      ),
    );
  }
}