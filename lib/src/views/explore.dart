import 'dart:async';

import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../models/feed_source.dart';
import '../models/suggested_feed.dart';
import '../services/feed_service.dart';
import '../services/podcast_player_service.dart';
import '../services/suggestion_service.dart';
import 'add_feed_dialog.dart';
import 'podcast_controls.dart';
import 'widget/colors.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    required this.feedService,
    required this.suggestionService,
    required this.podcastPlayer,
    required this.isReloadingData,
    required this.onReloadData,
    super.key,
  });

  final FeedService feedService;
  final SuggestionService suggestionService;
  final PodcastPlayerService podcastPlayer;
  final bool isReloadingData;
  final Future<void> Function() onReloadData;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> with WidgetsBindingObserver {
  static const _categories = [
    'Tudo',
    'Notícias',
    'Tecnologia',
    'Ciência',
    'Podcasts',
  ];

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _addingUrls = {};
  Timer? _catalogRefreshTimer;
  String _category = 'Tudo';
  String _catalogSort = 'Mais atualizados';
  bool _showFollowing = false;
  bool _isAppResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshCatalog());
    });
    _scheduleCatalogRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
    _scheduleCatalogRefresh();
    if (_isAppResumed && !_showFollowing) unawaited(_refreshCatalog());
  }

  void _scheduleCatalogRefresh() {
    _catalogRefreshTimer?.cancel();
    if (!_isAppResumed || _showFollowing) return;
    _catalogRefreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (mounted) unawaited(_refreshCatalog());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _catalogRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _follow(SuggestedFeed feed) async {
    if (!_addingUrls.add(feed.url)) return;
    setState(() {});
    try {
      await widget.feedService.addFeed(feed.url, category: feed.category);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${feed.name} foi adicionado às suas fontes.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível adicionar ${feed.name}: $error'),
          ),
        );
      }
    } finally {
      _addingUrls.remove(feed.url);
      if (mounted) setState(() {});
    }
  }

  Future<void> _refreshCatalog() async {
    await widget.suggestionService.refresh(suggestedFeeds);
  }

  DateTime _latestPublication(SuggestedFeed feed) {
    final preview = widget.suggestionService.previews[feed.url];
    final dates = preview == null
        ? const <DateTime>[]
        : preview.items.map((item) => item.publishedAt).whereType<DateTime>();
    return dates.fold<DateTime>(
      DateTime.fromMillisecondsSinceEpoch(0),
      (latest, date) => date.isAfter(latest) ? date : latest,
    );
  }

  int _recentPublicationCount(SuggestedFeed feed) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final preview = widget.suggestionService.previews[feed.url];
    return preview?.items
            .where(
              (item) =>
                  item.publishedAt != null && item.publishedAt!.isAfter(cutoff),
            )
            .length ??
        0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.feedService,
        widget.suggestionService,
      ]),
      builder: (context, _) {
        final query = _searchController.text.trim().toLowerCase();
        final followedUrls = widget.feedService.sources
            .map((source) => source.url)
            .toSet();
        final directory = suggestedFeeds.where((feed) {
          final matchesCategory =
              _category == 'Tudo' || feed.category == _category;
          final matchesQuery =
              query.isEmpty ||
              feed.name.toLowerCase().contains(query) ||
              feed.description.toLowerCase().contains(query) ||
              feed.category.toLowerCase().contains(query);
          return matchesCategory && matchesQuery;
        }).toList();
        directory.sort((a, b) {
          if (_catalogSort == 'Mais novos') {
            return _latestPublication(b).compareTo(_latestPublication(a));
          }
          final activityOrder = _recentPublicationCount(b)
              .compareTo(_recentPublicationCount(a));
          return activityOrder != 0
              ? activityOrder
              : _latestPublication(b).compareTo(_latestPublication(a));
        });

        final allSources = widget.feedService.sources;
        final sourceById = {for (final source in allSources) source.id: source};
        final sources = allSources.where((source) {
          return query.isEmpty ||
              source.title.toLowerCase().contains(query) ||
              source.url.toLowerCase().contains(query) ||
              source.category.toLowerCase().contains(query);
        }).toList();
        final items = widget.feedService.items;
        final itemCountsByFeed = <String, int>{};
        for (final item in items) {
          itemCountsByFeed.update(
            item.feedId,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
        final podcasts = items.where((item) {
          final source = sourceById[item.feedId];
          return item.isPodcast &&
              (query.isEmpty ||
                  item.title.toLowerCase().contains(query) ||
                  (item.description?.toLowerCase().contains(query) ?? false) ||
                  (source?.title.toLowerCase().contains(query) ?? false));
        }).toList();

        return SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _showFollowing ? 'Seguindo' : 'Explorar',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: FeedFlowColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Recarregar dados',
                            onPressed: widget.isReloadingData
                                ? null
                                : widget.onReloadData,
                            icon: widget.isReloadingData
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sync_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _showFollowing
                            ? 'Gerencie suas fontes e encontre os episódios novos.'
                            : 'Notícias e podcasts recentes, atualizados automaticamente.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: FeedFlowColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              icon: Icon(Icons.explore_rounded),
                              label: Text('Explorar'),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: Icon(Icons.rss_feed_rounded),
                              label: Text('Seguindo'),
                            ),
                          ],
                          selected: {_showFollowing},
                          onSelectionChanged: (selection) {
                            setState(() => _showFollowing = selection.first);
                            _scheduleCatalogRefresh();
                            if (!_showFollowing) {
                              unawaited(_refreshCatalog());
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: _showFollowing
                              ? 'Pesquisar suas fontes e episódios'
                              : 'Pesquisar fontes para descobrir',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Limpar pesquisa',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              showAddFeedDialog(context, widget.feedService),
                          icon: const Icon(Icons.add_link_rounded),
                          label: const Text('Adicionar por URL'),
                        ),
                      ),
                      if (!_showFollowing) ...[
                        const SizedBox(height: 12),
                        _CatalogUpdateBanner(
                          updatedAt: widget.suggestionService.lastUpdatedAt,
                          isRefreshing: widget.suggestionService.isRefreshing,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Mais novos usa a data da publicação. Mais atualizados prioriza fontes com mais publicações nos últimos 30 dias.',
                          style: TextStyle(
                            color: FeedFlowColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final sort in [
                              'Mais novos',
                              'Mais atualizados',
                            ])
                              ChoiceChip(
                                label: Text(sort),
                                selected: _catalogSort == sort,
                                onSelected: (_) =>
                                    setState(() => _catalogSort = sort),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final category in _categories)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(category),
                                    selected: _category == category,
                                    onSelected: (_) =>
                                        setState(() => _category = category),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_showFollowing)
                ..._followingSlivers(
                  sources,
                  podcasts,
                  itemCountsByFeed,
                  sourceById,
                  query,
                )
              else
                ..._directorySlivers(directory, followedUrls),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _directorySlivers(
    List<SuggestedFeed> feeds,
    Set<String> followedUrls,
  ) {
    if (feeds.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Nenhuma fonte encontrada. Tente outra busca ou categoria.',
                textAlign: TextAlign.center,
                style: TextStyle(color: FeedFlowColors.textSecondary),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        sliver: SliverList.separated(
          itemCount: feeds.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final feed = feeds[index];
            final isFollowing = followedUrls.contains(feed.url);
            final isAdding = _addingUrls.contains(feed.url);
            return _DirectoryFeedCard(
              feed: feed,
              isFollowing: isFollowing,
              isAdding: isAdding,
              previewItems:
                  widget.suggestionService.previews[feed.url]?.items ??
                  const [],
              isPreviewLoading:
                  widget.suggestionService.isRefreshing &&
                  !widget.suggestionService.previews.containsKey(feed.url),
              hasPreviewError:
                  widget.suggestionService.previews[feed.url]?.hasError ??
                  false,
              onFollow: isFollowing || isAdding ? null : () => _follow(feed),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _followingSlivers(
    List<FeedSource> sources,
    List<FeedItem> podcasts,
    Map<String, int> itemCountsByFeed,
    Map<String, FeedSource> sourceById,
    String query,
  ) {
    if (widget.feedService.sources.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.rss_feed_rounded,
                    size: 48,
                    color: FeedFlowColors.secondary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Você ainda não segue fontes',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => setState(() => _showFollowing = false),
                    icon: const Icon(Icons.explore_rounded),
                    label: const Text('Explorar fontes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    final result = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Suas fontes (${sources.length})',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ];

    if (sources.isEmpty && query.isNotEmpty) {
      result.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Nenhuma fonte encontrada.',
              style: TextStyle(color: FeedFlowColors.textSecondary),
            ),
          ),
        ),
      );
    } else {
      result.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          sliver: SliverList.separated(
            itemCount: sources.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final source = sources[index];
              final count = itemCountsByFeed[source.id] ?? 0;
              return Card(
                child: ListTile(
                  leading: Icon(
                    source.isPodcast
                        ? Icons.podcasts_rounded
                        : Icons.rss_feed_rounded,
                    color: FeedFlowColors.secondary,
                  ),
                  title: Text(source.title),
                  subtitle: Text(
                    '${source.category} • $count publicações',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    result.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Podcasts (${podcasts.length})',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
    if (podcasts.isEmpty) {
      result.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Text(
              query.isEmpty
                  ? 'Os episódios das fontes que você segue aparecerão aqui.'
                  : 'Nenhum episódio encontrado.',
              style: const TextStyle(color: FeedFlowColors.textSecondary),
            ),
          ),
        ),
      );
    } else {
      result.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList.separated(
            itemCount: podcasts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = podcasts[index];
              final source = sourceById[item.feedId];
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.podcasts_rounded,
                    color: FeedFlowColors.secondary,
                  ),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (source != null) source.title,
                      if (item.publishedAt != null)
                        '${item.publishedAt!.day}/${item.publishedAt!.month}/${item.publishedAt!.year}',
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PodcastPlayButton(
                        item: item,
                        player: widget.podcastPlayer,
                      ),
                      PodcastDownloadButton(
                        item: item,
                        feedService: widget.feedService,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    return result;
  }
}

class _DirectoryFeedCard extends StatelessWidget {
  const _DirectoryFeedCard({
    required this.feed,
    required this.isFollowing,
    required this.isAdding,
    required this.previewItems,
    required this.isPreviewLoading,
    required this.hasPreviewError,
    required this.onFollow,
  });

  final SuggestedFeed feed;
  final bool isFollowing;
  final bool isAdding;
  final List<FeedItem> previewItems;
  final bool isPreviewLoading;
  final bool hasPreviewError;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final latestPublication = previewItems
        .map((item) => item.publishedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, value) {
          if (latest == null || value.isAfter(latest)) return value;
          return latest;
        });
    final icon = switch (feed.category) {
      'Podcasts' => Icons.podcasts_rounded,
      'Tecnologia' => Icons.memory_rounded,
      'Ciência' => Icons.science_outlined,
      _ => Icons.article_outlined,
    };

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: FeedFlowColors.primary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: FeedFlowColors.secondary),
        ),
        title: Text(
          feed.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Expanded(child: Text(feed.description))]),
              if (previewItems.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'PUBLICAÇÕES RECENTES',
                  style: TextStyle(
                    color: FeedFlowColors.textDisabled,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                for (final item in previewItems.take(3))
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '• ${item.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FeedFlowColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (latestPublication != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      'Feed atualizado em ${_formatDateTime(latestPublication)}',
                      style: const TextStyle(
                        color: FeedFlowColors.textDisabled,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ] else if (isPreviewLoading) ...[
                const SizedBox(height: 10),
                const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Buscando publicações recentes…',
                      style: TextStyle(
                        color: FeedFlowColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ] else if (hasPreviewError) ...[
                const SizedBox(height: 8),
                const Text(
                  'Prévia indisponível no momento.',
                  style: TextStyle(
                    color: FeedFlowColors.textDisabled,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                feed.category.toUpperCase(),
                style: const TextStyle(
                  color: FeedFlowColors.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        trailing: isAdding
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isFollowing
            ? const Icon(
                Icons.check_circle_rounded,
                color: FeedFlowColors.success,
              )
            : IconButton.filledTonal(
                tooltip: 'Seguir ${feed.name}',
                onPressed: onFollow,
                icon: const Icon(Icons.add_rounded),
              ),
      ),
    );
  }
}

class _CatalogUpdateBanner extends StatelessWidget {
  const _CatalogUpdateBanner({
    required this.updatedAt,
    required this.isRefreshing,
  });

  final DateTime? updatedAt;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final status = updatedAt == null
        ? 'Consultando feeds RSS…'
        : 'Última atualização: ${_formatDateTime(updatedAt!)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FeedFlowColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: FeedFlowColors.secondary.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isRefreshing ? Icons.sync_rounded : Icons.update_rounded,
            color: FeedFlowColors.secondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: const TextStyle(
                    color: FeedFlowColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Atualização automática a cada 30 minutos',
                  style: TextStyle(
                    color: FeedFlowColors.textSecondary,
                    fontSize: 11,
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

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} às $hour:$minute';
}
