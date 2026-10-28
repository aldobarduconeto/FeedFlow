import 'dart:async';

import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../models/feed_source.dart';
import '../services/feed_service.dart';
import '../services/podcast_player_service.dart';
import 'widget/add_feed_dialog.dart';
import 'widget/cover_background.dart';
import 'podcast_player_page.dart';
import 'podcast_queue.dart';
import 'podcast_show_page.dart';
import 'widget/colors.dart';
import 'widget/feed_content_card.dart';
import 'widget/podcast_subscriptions_carousel.dart';

class PodcastsPage extends StatefulWidget {
  PodcastsPage({
    required this.feedService,
    required this.podcastPlayer,
    required this.isReloadingData,
    required this.onReloadData,
    required this.onDiscover,
    super.key,
  });

  final FeedService feedService;
  final PodcastPlayerService podcastPlayer;
  final bool isReloadingData;
  final Future<void> Function() onReloadData;
  final VoidCallback onDiscover;

  @override
  State<PodcastsPage> createState() => _PodcastsPageState();
}

class _PodcastsPageState extends State<PodcastsPage> {
  String? _selectedSourceId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.feedService, widget.podcastPlayer]),
      builder: (context, _) {
        final allSources = widget.feedService.sources;
        final sourcesMap = {for (final s in allSources) s.id: s};

        // All podcast items (items with audio)
        final allPodcastItems = widget.feedService.items.where((item) {
          return item.isPodcast;
        }).toList();

        // Sources that have podcast items
        final podcastSources = allSources.where((source) {
          return source.isPodcast ||
              source.category.toLowerCase() == 'podcasts' ||
              allPodcastItems.any((item) => item.feedId == source.id);
        }).toList();

        // Apply the program filter to both library and offline sections.
        final selectedEpisodes = allPodcastItems.where((item) {
          return _selectedSourceId == null || item.feedId == _selectedSourceId;
        }).toList();
        final downloadedEpisodes = selectedEpisodes.where((item) {
          return item.downloadedAudioPath != null;
        }).toList();
        final libraryEpisodes = selectedEpisodes.where((item) {
          return item.downloadedAudioPath == null;
        }).toList();
        final inProgressEpisodes = libraryEpisodes.where((item) {
          final pos = item.playbackPosition;
          final dur = item.audioDuration;
          return pos != null &&
              pos > Duration.zero &&
              (dur == null || pos < dur);
        }).toList();

        final continuingIds = inProgressEpisodes.map((item) => item.id).toSet();
        final filteredEpisodes = libraryEpisodes
            .where((item) => !continuingIds.contains(item.id))
            .toList();

        final hasPodcasts =
            podcastSources.isNotEmpty || allPodcastItems.isNotEmpty;

        final coverItems = allPodcastItems.where(
          (item) => item.feedId == _selectedSourceId && item.hasImage,
        );
        return CoverBackground(
          imageUrl: coverItems.isEmpty ? null : coverItems.first.imageUrl,
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Podcasts',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Dê play no que faz parte do seu dia.',
                            style: TextStyle(
                              color: FeedFlowColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Adicionar podcast RSS',
                      onPressed: () =>
                          showAddFeedDialog(context, widget.feedService),
                      icon: Icon(Icons.add_rounded),
                    ),
                    IconButton(
                      tooltip: 'Abrir fila de reprodução',
                      onPressed: _openQueue,
                      icon: Badge(
                        isLabelVisible: widget.podcastPlayer.queue.isNotEmpty,
                        label: Text('${widget.podcastPlayer.queue.length}'),
                        child: const Icon(Icons.queue_music_rounded),
                      ),
                    ),
                  ],
                ),

                if (widget.feedService.isRefreshing)
                  Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 12),
                    child: LinearProgressIndicator(),
                  ),

                if (!hasPodcasts) ...[
                  SizedBox(height: 24),
                  _EmptyPodcastsView(
                    onDiscover: widget.onDiscover,
                    onAddUrl: () =>
                        showAddFeedDialog(context, widget.feedService),
                  ),
                ] else ...[
                  SizedBox(height: 16),

                  if (podcastSources.isNotEmpty) ...[
                    PodcastSubscriptionsCarousel(
                      sources: podcastSources,
                      episodes: allPodcastItems,
                      selectedSourceId: _selectedSourceId,
                      onManage: () =>
                          _managePodcastSources(context, podcastSources),
                      onOpen: (source) async {
                        setState(() => _selectedSourceId = source.id);
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => PodcastShowPage(
                              source: source,
                              feedService: widget.feedService,
                              player: widget.podcastPlayer,
                            ),
                          ),
                        );
                        if (!mounted) return;
                        if (!widget.feedService.sources.any(
                          (saved) => saved.id == source.id,
                        )) {
                          setState(() => _selectedSourceId = null);
                        }
                      },
                    ),
                    if (_selectedSourceId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: InputChip(
                          label: Text(
                            'Filtrando: ${sourcesMap[_selectedSourceId]?.title ?? 'programa'}',
                          ),
                          onDeleted: () =>
                              setState(() => _selectedSourceId = null),
                          deleteButtonTooltipMessage:
                              'Mostrar todos os programas',
                          avatar: const Icon(
                            Icons.filter_list_rounded,
                            size: 16,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],

                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      key: const PageStorageKey('podcast-downloads'),
                      leading: Icon(
                        Icons.offline_pin_rounded,
                        color: FeedFlowColors.success,
                      ),
                      title: Text(
                        'Episódios baixados (${downloadedEpisodes.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Sua biblioteca offline',
                        style: TextStyle(fontSize: 12),
                      ),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        if (downloadedEpisodes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _selectedSourceId == null
                                  ? 'Baixe episódios para ouvir sem internet.'
                                  : 'Nenhum episódio baixado deste programa.',
                              style: TextStyle(
                                color: FeedFlowColors.textSecondary,
                              ),
                            ),
                          )
                        else
                          for (final item in downloadedEpisodes)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PodcastCard(
                                item: item,
                                source: sourcesMap[item.feedId],
                                feedService: widget.feedService,
                                podcastPlayer: widget.podcastPlayer,
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // In-Progress Section
                  if (inProgressEpisodes.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 20,
                          color: FeedFlowColors.secondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Continue ouvindo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: FeedFlowColors.primary.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${inProgressEpisodes.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: FeedFlowColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    for (final item in inProgressEpisodes)
                      Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: _PodcastCard(
                          item: item,
                          source: sourcesMap[item.feedId],
                          feedService: widget.feedService,
                          podcastPlayer: widget.podcastPlayer,
                        ),
                      ),
                    SizedBox(height: 18),
                  ],

                  // All Episodes Section
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle_outline_rounded,
                        size: 20,
                        color: FeedFlowColors.secondary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedSourceId != null
                              ? 'Episódios de ${sourcesMap[_selectedSourceId]?.title ?? 'este programa'}'
                              : 'Episódios recentes',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FeedFlowColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${filteredEpisodes.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: FeedFlowColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  if (filteredEpisodes.isEmpty)
                    Container(
                      padding: EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: FeedFlowColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: FeedFlowColors.divider),
                      ),
                      child: Center(
                        child: Text(
                          downloadedEpisodes.isNotEmpty
                              ? 'Confira seus episódios na seção de baixados ou em Continue ouvindo.'
                              : 'Nenhum episódio recente disponível para esta seleção.',
                          style: TextStyle(color: FeedFlowColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    for (final item in filteredEpisodes)
                      Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: _PodcastCard(
                          item: item,
                          source: sourcesMap[item.feedId],
                          feedService: widget.feedService,
                          podcastPlayer: widget.podcastPlayer,
                        ),
                      ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _openQueue() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: PodcastQueueSection(player: widget.podcastPlayer),
          ),
        ),
      ),
    );
  }

  Future<void> _managePodcastSources(
    BuildContext context,
    List<FeedSource> sources,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: FeedFlowColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Text(
                'Programas de Podcast Seguidos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final source in sources)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: FeedFlowColors.surfaceHighlight,
                  child: Icon(
                    Icons.podcasts_rounded,
                    color: FeedFlowColors.secondary,
                  ),
                ),
                title: Text(source.title),
                subtitle: Text(source.url, maxLines: 1),
                trailing: IconButton(
                  tooltip: 'Deixar de seguir ${source.title}',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: FeedFlowColors.error,
                  ),
                  onPressed: () async {
                    await widget.feedService.removeFeed(source.id);
                    if (_selectedSourceId == source.id) {
                      setState(() => _selectedSourceId = null);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PodcastCard extends StatelessWidget {
  _PodcastCard({
    required this.item,
    required this.source,
    required this.feedService,
    required this.podcastPlayer,
  });

  final FeedItem item;
  final FeedSource? source;
  final FeedService feedService;
  final PodcastPlayerService podcastPlayer;

  Future<void> _openPlayer(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) => FeedContentCard(
    item: item,
    source: source,
    feeds: feedService,
    player: podcastPlayer,
    onOpen: () {
      _openPlayer(context);
    },
  );
}

class _EmptyPodcastsView extends StatelessWidget {
  _EmptyPodcastsView({required this.onDiscover, required this.onAddUrl});

  final VoidCallback onDiscover;
  final VoidCallback onAddUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: FeedFlowColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: FeedFlowColors.divider),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FeedFlowColors.primary.withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.podcasts_rounded,
              size: 52,
              color: FeedFlowColors.secondary,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Seu hub de Podcasts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'Todos os podcasts que você seguir aparecerão reunidos nesta aba para você ouvir e baixar.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: FeedFlowColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onDiscover,
              icon: Icon(Icons.explore_rounded),
              label: Text('Descobrir podcasts no catálogo'),
            ),
          ),
          SizedBox(height: 10),
          TextButton.icon(
            onPressed: onAddUrl,
            icon: Icon(Icons.add_link_rounded),
            label: Text('Adicionar feed de podcast por URL'),
          ),
        ],
      ),
    );
  }
}
