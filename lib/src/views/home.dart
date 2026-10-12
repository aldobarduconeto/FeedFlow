import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../models/feed_source.dart';
import '../services/feed_service.dart';
import '../services/podcast_player_service.dart';
import 'add_feed_dialog.dart';
import 'podcast_controls.dart';
import 'article_reader.dart';
import 'widget/colors.dart';
import 'widget/feed_image_leading.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.feedService,
    required this.podcastPlayer,
    required this.onDiscover,
    super.key,
  });

  final FeedService feedService;
  final PodcastPlayerService podcastPlayer;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: feedService,
      builder: (context, _) {
        final items = feedService.items;
        final sources = {
          for (final source in feedService.sources) source.id: source,
        };
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Seu feed',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Adicionar fonte RSS',
                    onPressed: () => showAddFeedDialog(context, feedService),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              if (feedService.isRefreshing)
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              if (feedService.startupError case final error?)
                _ErrorCard(message: error),
              for (final error in feedService.refreshErrors.entries)
                _ErrorCard(
                  message:
                      'Falha ao atualizar '
                      '${sources[error.key]?.title ?? 'uma fonte'}: '
                      '${error.value}',
                ),
              if (feedService.sources.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SourcesCard(
                  sources: feedService.sources,
                  feedService: feedService,
                ),
                const SizedBox(height: 20),
              ],
              if (feedService.isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                _EmptyFeed(
                  hasSources: feedService.sources.isNotEmpty,
                  onAdd: () => showAddFeedDialog(context, feedService),
                  onDiscover: onDiscover,
                )
              else ...[
                const Text(
                  'ARTIGOS E EPISÓDIOS',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FeedItemCard(
                      item: item,
                      source: sources[item.feedId],
                      feedService: feedService,
                      podcastPlayer: podcastPlayer,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({
    required this.hasSources,
    required this.onAdd,
    required this.onDiscover,
  });

  final bool hasSources;
  final VoidCallback onAdd;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: FeedFlowColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: FeedFlowColors.divider),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.rss_feed_rounded,
            size: 48,
            color: FeedFlowColors.secondary,
          ),
          const SizedBox(height: 18),
          Text(
            hasSources ? 'Nenhum artigo encontrado' : 'Seu feed começa aqui',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            hasSources ? 'Atualize as fontes ou tente novamente mais tarde.' : 'Adicione fontes RSS para reunir artigos, notícias e podcasts.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: FeedFlowColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (!hasSources) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar fonte RSS'),
              ),
            ),
            TextButton(
              onPressed: onDiscover,
              child: const Text('Ver fontes seguidas'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourcesCard extends StatelessWidget {
  const _SourcesCard({required this.sources, required this.feedService});

  final List<FeedSource> sources;
  final FeedService feedService;

  Future<void> _manageSources(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: FeedFlowColors.surface,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Fontes adicionadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final source in sources)
              ListTile(
                leading: Icon(
                  source.isPodcast
                      ? Icons.podcasts_rounded
                      : Icons.rss_feed_rounded,
                ),
                title: Text(source.title),
                subtitle: Text(source.url, maxLines: 1),
                trailing: IconButton(
                  tooltip: 'Remover ${source.title}',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    await feedService.removeFeed(source.id);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.rss_feed_rounded),
        title: Text('${sources.length} fontes adicionadas'),
        subtitle: const Text('Toque para gerenciar suas assinaturas'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _manageSources(context),
      ),
    );
  }
}

class _FeedItemCard extends StatelessWidget {
  const _FeedItemCard({
    required this.item,
    required this.source,
    required this.feedService,
    required this.podcastPlayer,
  });

  final FeedItem item;
  final FeedSource? source;
  final FeedService feedService;
  final PodcastPlayerService podcastPlayer;

  @override
  Widget build(BuildContext context) {
    final date = item.publishedAt;
    final details = [
      source?.title ?? 'Fonte RSS',
      if (date != null) '${date.day}/${date.month}/${date.year}',
    ].join(' • ');
    return Card(
      child: ListTile(
        onTap: () async {
          if (!item.isRead) await feedService.toggleRead(item);
          if (!context.mounted || item.isPodcast) return;
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ArticleReaderPage(item: item, source: source),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: FeedImageLeading(item: item),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w700,
                  color: item.isRead ? FeedFlowColors.textSecondary : null,
                ),
              ),
            ),
            IconButton(
              tooltip: item.isFavorite ? 'Remover dos favoritos' : 'Favoritar',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              onPressed: () => feedService.toggleFavorite(item),
              icon: Icon(
                item.isFavorite
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: item.isFavorite ? FeedFlowColors.secondary : null,
                size: 20,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$details${item.description == null ? '' : '\n${item.description}'}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        isThreeLine: item.description != null,
        trailing: item.isPodcast && item.hasAudio
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PodcastPlayButton(item: item, player: podcastPlayer),
                  PodcastDownloadButton(item: item, feedService: feedService),
                ],
              )
            : null,
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: FeedFlowColors.error.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          message,
          style: const TextStyle(color: FeedFlowColors.error),
        ),
      ),
    );
  }
}
