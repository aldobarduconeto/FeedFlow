import 'dart:async';

import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../models/feed_source.dart';
import '../services/feed_service.dart';
import '../services/podcast_player_service.dart';
import 'widget/add_feed_dialog.dart';
import 'podcast_player_page.dart';
import 'article_reader.dart';
import 'widget/colors.dart';
import 'widget/feed_content_card.dart';

class HomePage extends StatelessWidget {
  HomePage({
    required this.feedService,
    required this.podcastPlayer,
    required this.isReloadingData,
    required this.onReloadData,
    super.key,
  });

  final FeedService feedService;
  final PodcastPlayerService podcastPlayer;
  final bool isReloadingData;
  final Future<void> Function() onReloadData;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: feedService,
      builder: (context, _) {
        final items = feedService.items;
        final sources = {
          for (final source in feedService.sources) source.id: source,
        };
        final continuing = items.where((item) {
          if (!item.isPodcast) {
            final progress = item.readingProgress ?? 0;
            return progress > 0 && progress < 1;
          }
          final position = item.playbackPosition;
          final duration = item.audioDuration;
          return position != null &&
              position > Duration.zero &&
              (duration == null || position < duration);
        }).toList();
        final continuingIds = continuing.map((item) => item.id).toSet();
        final updates = items
            .where((item) => !item.isRead && !continuingIds.contains(item.id))
            .toList();
        return SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Início',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Recarregar dados',
                    onPressed: isReloadingData ? null : onReloadData,
                    icon: isReloadingData
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.sync_rounded),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Retome seus conteúdos e veja as novidades.',
                  style: TextStyle(color: FeedFlowColors.textSecondary),
                ),
              ),
              if (feedService.isRefreshing)
                Padding(
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
              SizedBox(height: 16),
              _ContentSectionHeader(
                title: 'Continue de onde parou',
                subtitle: 'Artigos e podcasts com progresso salvo',
                count: continuing.length,
                icon: Icons.history_rounded,
              ),
              if (continuing.isEmpty)
                _EmptySectionMessage(
                  message:
                      'Seus artigos e episódios em andamento aparecerão aqui.',
                )
              else
                for (final item in continuing)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _FeedItemCard(
                      item: item,
                      source: sources[item.feedId],
                      feedService: feedService,
                      podcastPlayer: podcastPlayer,
                    ),
                  ),
              SizedBox(height: 20),
              _ContentSectionHeader(
                title: 'Atualizações',
                subtitle: updates.isEmpty
                    ? 'Você já abriu todas as novidades.'
                    : 'Conteúdos recentes que você ainda não abriu',
                count: updates.length,
                icon: Icons.auto_awesome_rounded,
              ),
              if (updates.isEmpty)
                _EmptySectionMessage(
                  message: 'Novas publicações aparecerão aqui após a recarga.',
                )
              else
                for (final item in updates)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _FeedItemCard(
                      item: item,
                      source: sources[item.feedId],
                      feedService: feedService,
                      podcastPlayer: podcastPlayer,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _ContentSectionHeader extends StatelessWidget {
  _ContentSectionHeader({
    required this.title,
    required this.subtitle,
    this.count,
    this.icon,
  });

  final String title;
  final String subtitle;
  final int? count;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: EdgeInsets.only(top: 2, right: 10),
              child: Icon(icon, size: 22, color: FeedFlowColors.secondary),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (count != null && count! > 0) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FeedFlowColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: FeedFlowColors.primary.withValues(
                              alpha: 0.35,
                            ),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: FeedFlowColors.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: FeedFlowColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  _EmptySectionMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Text(
        message,
        style: TextStyle(color: FeedFlowColors.textSecondary),
      ),
    );
  }
}

class SubscriptionsPage extends StatelessWidget {
  SubscriptionsPage({
    required this.feedService,
    required this.podcastPlayer,
    required this.isReloadingData,
    required this.onReloadData,
    required this.onDiscover,
    this.onPodcasts,
    super.key,
  });

  final FeedService feedService;
  final PodcastPlayerService podcastPlayer;
  final bool isReloadingData;
  final Future<void> Function() onReloadData;
  final VoidCallback onDiscover;
  final VoidCallback? onPodcasts;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: feedService,
      builder: (context, _) {
        final items = feedService.items.where((i) => !i.isPodcast).toList();
        final sourcesWithArticles = feedService.sources.where((source) {
          return feedService.items.any(
            (item) => item.feedId == source.id && !item.isPodcast,
          );
        }).toList();
        final podcastItems = feedService.items
            .where((i) => i.isPodcast)
            .toList();
        final podcastSources = feedService.sources.where((source) {
          return feedService.items.any(
            (item) => item.feedId == source.id && item.isPodcast,
          );
        }).toList();
        final sources = {
          for (final source in feedService.sources) source.id: source,
        };
        return SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Inscrições',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Adicionar fonte RSS',
                    onPressed: () => showAddFeedDialog(context, feedService),
                    icon: Icon(Icons.add_rounded),
                  ),
                  IconButton(
                    tooltip: 'Recarregar dados',
                    onPressed: isReloadingData ? null : onReloadData,
                    icon: isReloadingData
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.sync_rounded),
                  ),
                ],
              ),
              if (feedService.isRefreshing)
                Padding(
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
              if (sourcesWithArticles.isNotEmpty) ...[
                SizedBox(height: 16),
                _SourcesCard(
                  sources: sourcesWithArticles,
                  feedService: feedService,
                ),
                SizedBox(height: 16),
              ],
              if (podcastSources.isNotEmpty && onPodcasts != null) ...[
                InkWell(
                  onTap: onPodcasts,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FeedFlowColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: FeedFlowColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.podcasts_rounded,
                          color: FeedFlowColors.secondary,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aba Podcasts',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: FeedFlowColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${podcastSources.length} programa(s) e ${podcastItems.length} episódio(s)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: FeedFlowColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: FeedFlowColors.secondary,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
              if (feedService.isLoading)
                Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                _EmptyFeed(
                  hasSources: sourcesWithArticles.isNotEmpty,
                  onAdd: () => showAddFeedDialog(context, feedService),
                  onDiscover: onDiscover,
                )
              else ...[
                Text(
                  'ARTIGOS RECENTES',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 12),
                for (final item in items)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10),
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
  _EmptyFeed({
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
      margin: EdgeInsets.only(top: 28),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: FeedFlowColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: FeedFlowColors.divider),
      ),
      child: Column(
        children: [
          Icon(
            Icons.rss_feed_rounded,
            size: 48,
            color: FeedFlowColors.secondary,
          ),
          SizedBox(height: 18),
          Text(
            hasSources ? 'Nenhum artigo encontrado' : 'Seu feed começa aqui',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            hasSources ? 'Atualize as fontes ou tente novamente mais tarde.' : 'Adicione fontes RSS para reunir artigos, notícias e podcasts.',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: FeedFlowColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (!hasSources) ...[
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: Icon(Icons.add_rounded),
                label: Text('Adicionar fonte RSS'),
              ),
            ),
            TextButton(onPressed: onDiscover, child: Text('Explorar fontes')),
          ],
        ],
      ),
    );
  }
}

class _SourcesCard extends StatelessWidget {
  _SourcesCard({required this.sources, required this.feedService});

  final List<FeedSource> sources;
  final FeedService feedService;

  Future<void> _manageSources(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: FeedFlowColors.surface,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
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
                  icon: Icon(Icons.delete_outline_rounded),
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
        leading: Icon(Icons.rss_feed_rounded),
        title: Text('${sources.length} fontes adicionadas'),
        subtitle: Text('Toque para gerenciar suas assinaturas'),
        trailing: Icon(Icons.chevron_right_rounded),
        onTap: () => _manageSources(context),
      ),
    );
  }
}

class _FeedItemCard extends StatelessWidget {
  _FeedItemCard({
    required this.item,
    required this.source,
    required this.feedService,
    required this.podcastPlayer,
  });

  final FeedItem item;
  final FeedSource? source;
  final FeedService feedService;
  final PodcastPlayerService podcastPlayer;

  Future<void> _openPodcastPlayer(BuildContext context) async {
    if (!item.hasAudio) return;
    if (!podcastPlayer.isCurrent(item)) {
      try {
        await podcastPlayer.toggle(item);
      } catch (_) {}
    }
    if (!item.isRead) {
      unawaited(feedService.toggleRead(item));
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PodcastPlayerPage(
              player: podcastPlayer,
              feedService: feedService,
              source: source,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final begin = Offset(0.0, 1.0);
          final end = Offset.zero;
          final curve = Curves.easeOutCubic;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _openArticleReader(BuildContext context) async {
    if (!item.isRead) await feedService.toggleRead(item);
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ArticleReaderPage(
          item: item,
          source: source,
          feedService: feedService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FeedContentCard(
    item: item,
    source: source,
    feeds: feedService,
    player: podcastPlayer,
    onOpen: () {
      item.isPodcast
          ? _openPodcastPlayer(context)
          : _openArticleReader(context);
    },
  );
}

class _ErrorCard extends StatelessWidget {
  _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: FeedFlowColors.error.withValues(alpha: 0.12),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Text(message, style: TextStyle(color: FeedFlowColors.error)),
      ),
    );
  }
}
