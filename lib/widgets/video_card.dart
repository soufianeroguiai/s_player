import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/video_item.dart';
import 'video_thumbnail_loader.dart';

class VideoCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;

  const VideoCard({super.key, required this.video, required this.onTap, this.onMoreTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 90, height: 64,
                child: Stack(fit: StackFit.expand, children: [
                  VideoThumbnailLoader(video: video, width: 90, height: 64),
                  Positioned(
                    bottom: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(video.formattedDuration,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _Info(video: video)),
            if (onMoreTap != null)
              IconButton(
                icon: Icon(Symbols.more_vert_rounded, color: cs.onSurfaceVariant, size: 22),
                onPressed: onMoreTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
          ],
        ),
      ),
    );
  }
}

class VideoGridCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;

  const VideoGridCard({super.key, required this.video, required this.onTap, this.onMoreTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                VideoThumbnailLoader(video: video, width: double.infinity, height: double.infinity),
                Positioned(
                  bottom: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(video.formattedDuration,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(video.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(video.formattedSize, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10)),
                ])),
                if (onMoreTap != null)
                  IconButton(
                    icon: Icon(Symbols.more_vert_rounded, color: cs.onSurfaceVariant, size: 18),
                    onPressed: onMoreTap,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final VideoItem video;
  const _Info({required this.video});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(video.name,
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: cs.onSurface, fontSize: 13.5, fontWeight: FontWeight.w500, height: 1.3)),
      const SizedBox(height: 6),
      Row(children: [
        _Tag(video.formattedSize, cs),
        const SizedBox(width: 6),
        _Tag(video.extension.toUpperCase(), cs, primary: true),
        ValueListenableBuilder<List<String>>(
          valueListenable: video.subtitlesNotifier,
          builder: (context, subtitles, _) {
            if (subtitles.isEmpty) return const SizedBox.shrink();
            return Row(
              children: subtitles.map((sub) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.withOpacity(0.35)),
                  ),
                  child: Text(sub, style: const TextStyle(
                    color: Colors.green, fontSize: 8.5, fontWeight: FontWeight.w900
                  )),
                ),
              )).toList(),
            );
          },
        ),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        Icon(Symbols.folder_rounded, size: 12, color: cs.onSurfaceVariant.withOpacity(0.6)),
        const SizedBox(width: 4),
        Expanded(child: Text(video.folder,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6), fontSize: 11))),
      ]),
    ]);
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final bool primary;
  const _Tag(this.label, this.cs, {this.primary = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: primary ? cs.primaryContainer.withOpacity(0.4) : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(
        color: primary ? cs.primary : cs.onSurfaceVariant,
        fontSize: 10, fontWeight: FontWeight.w600,
      )),
    );
  }
}