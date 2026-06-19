import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/thumbnail_service.dart';

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
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await ThumbnailService().get(widget.videoPath);
    if (mounted) setState(() { _bytes = bytes; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _loading
            ? _shimmer()
            : _bytes != null
                ? Image.memory(_bytes!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
      ),
    );
  }

  Widget _shimmer() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 0.9),
      duration: const Duration(milliseconds: 900),
      builder: (_, v, __) => Container(color: Colors.grey[900]!.withValues(alpha: v)),
      onEnd: () => setState(() {}),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[900],
      child: const Icon(Icons.video_file_rounded, color: Colors.white30, size: 36),
    );
  }
}