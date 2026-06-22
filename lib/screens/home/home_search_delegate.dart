import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/video_item.dart';
import '../../widgets/video_card.dart';

class VideoSearchDelegate extends SearchDelegate<VideoItem?> {
  final List<VideoItem> videos;
  final Future<void> Function(VideoItem) onOpen;
  VideoSearchDelegate(this.videos, this.onOpen);

  @override
  String get searchFieldLabel => 'ابحث عن فيديو...';

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty) IconButton(icon: const Icon(Symbols.close_rounded), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final results =
        query.isEmpty ? videos : videos.where((v) => v.name.toLowerCase().contains(query.toLowerCase())).toList();
    if (results.isEmpty) return Center(child: Text('ما لقينا نتائج', style: TextStyle(color: cs.onSurfaceVariant)));
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) => VideoCard(
        video: results[i],
        onTap: () {
          close(context, results[i]);
          onOpen(results[i]);
        },
      ),
    );
  }
}
