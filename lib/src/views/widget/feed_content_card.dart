import 'package:flutter/material.dart';

import '../../models/feed.dart';
import '../../models/feed_source.dart';
import '../../services/feed_service.dart';
import '../../services/podcast_player_service.dart';
import '../../services/reader_service.dart';
import '../podcast_controls.dart';
import '../podcast_queue.dart';
import '../podcast_show_page.dart';
import 'colors.dart';

/// Shared editorial cards for the home, subscriptions and podcast library.
class FeedContentCard extends StatefulWidget {
  const FeedContentCard({
    required this.item,
    required this.source,
    required this.feeds,
    required this.player,
    required this.onOpen,
    super.key,
  });
  final FeedItem item;
  final FeedSource? source;
  final FeedService feeds;
  final PodcastPlayerService player;
  final VoidCallback onOpen;

  @override
  State<FeedContentCard> createState() => _FeedContentCardState();
}

class _FeedContentCardState extends State<FeedContentCard> {
  FeedItem get item => widget.item;
  FeedSource? get source => widget.source;
  FeedService get feeds => widget.feeds;
  PodcastPlayerService get player => widget.player;
  VoidCallback get onOpen => widget.onOpen;
  late String _summary;
  late int _readingMinutes;

  @override
  void initState() {
    super.initState();
    _resolveText();
  }

  @override
  void didUpdateWidget(FeedContentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.content != item.content ||
        oldWidget.item.description != item.description) {
      _resolveText();
    }
  }

  void _resolveText() {
    _summary = ReaderService.clean(item.description ?? item.content ?? '');
    final body = ReaderService.clean(item.content ?? item.description ?? '');
    _readingMinutes = (body.split(RegExp(r'\s+')).length / 200).ceil().clamp(
      1,
      99,
    );
  }

  String _duration(Duration duration) {
    final minutes = duration.inMinutes;
    return minutes >= 60
        ? '${duration.inHours} h ${minutes.remainder(60)} min'
        : '$minutes min';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: player,
    builder: (context, _) {
      final podcast = item.isPodcast;
      final current = player.isCurrent(item);
      final playing = current && player.isPlaying;
      final position = current
          ? player.position
          : item.playbackPosition ?? Duration.zero;
      final duration = current
          ? player.duration ?? item.audioDuration
          : item.audioDuration;
      final progress = podcast
          ? duration != null && duration.inMilliseconds > 0
                ? position.inMilliseconds / duration.inMilliseconds
                : 0.0
          : item.readingProgress ?? 0;
      final summary = _summary;
      final date = item.publishedAt;
      final accent = podcast
          ? FeedFlowColors.primary
          : FeedFlowColors.secondary;
      final metadata = [
        if (date != null)
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
        if (podcast && duration != null) _duration(duration),
        if (!podcast) '${_readingMinutes} min de leitura',
      ].join(' · ');
      if (!podcast) return _newsCard(metadata);
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: FeedFlowColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: playing
                ? accent.withValues(alpha: 0.6)
                : FeedFlowColors.divider.withValues(alpha: 0.6),
            width: playing ? 1.2 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!podcast && item.hasImage)
                  LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                      width: double.infinity,
                      height: (constraints.maxWidth * 9 / 16).clamp(
                        160.0,
                        280.0,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _artwork(),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x66000000),
                                  Colors.transparent,
                                  Color(0x33000000),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            left: 16,
                            child: _badge(
                              'NOTÍCIA',
                              Icons.article_outlined,
                              Colors.white,
                              Colors.black.withValues(alpha: 0.3),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _favorite(onImage: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (podcast || !item.hasImage) ...[
                            _badge(
                              podcast ? 'PODCAST' : 'NOTÍCIA',
                              podcast
                                  ? Icons.graphic_eq_rounded
                                  : Icons.article_outlined,
                              accent,
                              accent.withValues(alpha: 0.12),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: InkWell(
                              onTap: source == null
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => PodcastShowPage(
                                          source: source!,
                                          feedService: feeds,
                                          player: player,
                                        ),
                                      ),
                                    ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  source?.title ??
                                      (podcast ? 'Seu podcast' : 'Seu feed'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: FeedFlowColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (podcast || !item.hasImage) _favorite(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (podcast) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: SizedBox(
                                width: 88,
                                height: 88,
                                child: _artwork(),
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: podcast ? 18 : 21,
                                    height: 1.25,
                                    letterSpacing: -0.4,
                                    fontWeight: FontWeight.w700,
                                    color: FeedFlowColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  metadata,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.4,
                                    color: FeedFlowColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.55,
                            color: FeedFlowColors.textSecondary,
                          ),
                        ),
                      ],
                      if (progress > 0) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 3,
                            backgroundColor: FeedFlowColors.surfaceHighlight,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          podcast
                              ? '${_duration(position)} ouvidos'
                              : '${(progress.clamp(0, 1) * 100).round()}% lido',
                          style: TextStyle(
                            fontSize: 11,
                            color: FeedFlowColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Divider(
                        height: 1,
                        color: FeedFlowColors.divider.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: onOpen,
                              icon: Icon(
                                playing
                                    ? Icons.equalizer_rounded
                                    : podcast
                                    ? Icons.headphones_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(
                                playing
                                    ? 'Tocando agora'
                                    : podcast
                                    ? 'Abrir episódio'
                                    : progress > 0 && progress < 1
                                    ? 'Continuar leitura'
                                    : 'Ler notícia',
                              ),
                            ),
                            if (podcast && item.hasAudio)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PodcastQueueButton(
                                    item: item,
                                    player: player,
                                  ),
                                  PodcastDownloadButton(
                                    item: item,
                                    feedService: feeds,
                                  ),
                                  PodcastPlayButton(
                                    item: item,
                                    player: player,
                                    onPlay: item.isRead
                                        ? null
                                        : () => feeds.toggleRead(item),
                                  ),
                                ],
                              )
                            else if (item.isRead)
                              _badge(
                                'LIDO',
                                Icons.check_rounded,
                                FeedFlowColors.success,
                                FeedFlowColors.success.withValues(alpha: 0.1),
                              ),
                          ],
                        ),
                      ),
                      if (podcast && item.downloadedAudioPath != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.offline_pin_rounded,
                                size: 13,
                                color: FeedFlowColors.success,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Disponível offline',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: FeedFlowColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _newsCard(String metadata) {
    final progress = (item.readingProgress ?? 0).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: FeedFlowColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FeedFlowColors.divider.withValues(alpha: 0.65),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.hasImage)
                LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    width: double.infinity,
                    height: (constraints.maxWidth * 9 / 16).clamp(160.0, 300.0),
                    child: _artwork(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: FeedFlowColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (source?.category ?? 'Notícias').toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                              color: FeedFlowColors.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            source?.title ?? 'FeedFlow',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: FeedFlowColors.textSecondary,
                            ),
                          ),
                        ),
                        _favorite(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18.5,
                        height: 1.3,
                        letterSpacing: -0.4,
                        fontWeight: FontWeight.w700,
                        color: FeedFlowColors.textPrimary,
                      ),
                    ),
                    if (_summary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: FeedFlowColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          metadata,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: FeedFlowColors.textDisabled,
                          ),
                        ),
                        if (item.author?.isNotEmpty == true) ...[
                          Text(
                            ' · Por ${item.author}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: FeedFlowColors.textDisabled,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (item.isRead)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.check_circle_outline_rounded,
                              size: 15,
                              color: FeedFlowColors.success,
                            ),
                          ),
                        Text(
                          progress > 0 && progress < 1
                              ? '${(progress * 100).round()}% lido'
                              : 'Ler',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FeedFlowColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: FeedFlowColors.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (progress > 0 && progress < 1)
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  color: FeedFlowColors.secondary,
                  backgroundColor: FeedFlowColors.surfaceHighlight,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _favorite({bool onImage = false}) => IconButton(
    tooltip: item.isFavorite ? 'Remover dos favoritos' : 'Favoritar',
    style: onImage
        ? IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.3),
            foregroundColor: Colors.white,
          )
        : null,
    onPressed: () => feeds.toggleFavorite(item),
    icon: Icon(
      item.isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      color: onImage
          ? Colors.white
          : item.isFavorite
          ? FeedFlowColors.secondary
          : FeedFlowColors.textSecondary,
      size: 21,
    ),
  );
  Widget _badge(String label, IconData icon, Color color, Color background) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
  Widget _artwork() {
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FeedFlowColors.primary.withValues(alpha: 0.35),
            FeedFlowColors.surfaceElevated,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          item.isPodcast ? Icons.podcasts_rounded : Icons.article_outlined,
          size: 34,
          color: FeedFlowColors.secondary,
        ),
      ),
    );
    return item.hasImage
        ? Image.network(
            item.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;
  }
}
