import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../models/podcast_chapter.dart';
import '../services/chapter_service.dart';
import '../services/podcast_player_service.dart';

class PodcastChapters extends StatefulWidget {
  PodcastChapters({required this.item, required this.player, super.key});
  final FeedItem item;
  final PodcastPlayerService player;
  @override
  State<PodcastChapters> createState() => _PodcastChaptersState();
}

class _PodcastChaptersState extends State<PodcastChapters> {
  late Future<List<PodcastChapter>> _chapters;
  @override
  void initState() {
    super.initState();
    _chapters = ChapterService.load(widget.item);
  }

  @override
  void didUpdateWidget(PodcastChapters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id)
      _chapters = ChapterService.load(widget.item);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PodcastChapter>>(
    future: _chapters,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return LinearProgressIndicator();
      if (snapshot.hasError)
        return TextButton.icon(
          onPressed: () =>
              setState(() => _chapters = ChapterService.load(widget.item)),
          icon: Icon(Icons.refresh),
          label: Text('Tentar carregar capítulos novamente'),
        );
      final chapters = snapshot.data ?? [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capítulos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (chapters.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Este episódio não publicou capítulos ou horários na descrição.',
              ),
            ),
          for (var i = 0; i < chapters.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              selected:
                  widget.player.position >= chapters[i].start &&
                  (i == chapters.length - 1 ||
                      widget.player.position < chapters[i + 1].start),
              leading: Icon(Icons.play_circle_outline),
              title: Text(chapters[i].title),
              subtitle: Text(chapters[i].start.toString().split('.').first),
              onTap: () async {
                try {
                  await widget.player.seek(chapters[i].start);
                } catch (error) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Falha ao navegar: $error')),
                    );
                }
              },
            ),
        ],
      );
    },
  );
}
