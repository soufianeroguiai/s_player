import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/library_provider.dart';
import '../widgets/video_card.dart';
import 'player/player_screen.dart';

class PlaylistScreen extends StatelessWidget {
  final List<String> playlist;
  const PlaylistScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final videos = playlist
        .map((path) => lib.allVideos.where((v) => v.path == path).firstOrNull)
        .whereType<VideoItem>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة التشغيل'),
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: videos.isEmpty
          ? const Center(child: Text('قائمة التشغيل فارغة'))
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 90),
              itemCount: videos.length,
              itemBuilder: (_, i) => VideoCard(
                video: videos[i],
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => PlayerScreen(video: videos[i]))),
                onMoreTap: null,
              ),
            ),
    );
  }
}