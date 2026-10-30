import 'dart:async';
import 'dart:ui';

import 'widget/colors.dart';
import '../models/feed.dart';
import 'widget/add_feed_dialog.dart';
import '../models/suggested_feed.dart';
import '../services/feed_service.dart';

import 'package:flutter/material.dart';

import '../services/suggestion_service.dart';
import '../services/discovery_service.dart';

class ExplorePage extends StatefulWidget {
  ExplorePage({
    required this.feedService,
    required this.suggestionService,
    required this.discoveryService,
    required this.isReloadingData,
    required this.onReloadData,
    super.key,
  });

  final FeedService feedService;
  final SuggestionService suggestionService;
  final DiscoveryService discoveryService;
  final bool isReloadingData;
  final Future<void> Function() onReloadData;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> with WidgetsBindingObserver {
  static const _categories = FeedCategories.exploreCategories;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _categoryScrollController = ScrollController();
  final Set<String> _addingUrls = {};
  Timer? _catalogRefreshTimer;
  Timer? _searchDebounce;
  String _category = 'Tudo';
  String _catalogSort = 'Mais atualizados';
  bool _isAppResumed = true;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_refreshCatalog());
        _updateScrollButtons();
      }
    });
    _categoryScrollController.addListener(_updateScrollButtons);
    _scheduleCatalogRefresh();
  }

  void _updateScrollButtons() {
    if (!_categoryScrollController.hasClients) return;
    final pos = _categoryScrollController.position;
    final canLeft = pos.pixels > 6;
    final canRight = pos.pixels < (pos.maxScrollExtent - 6);
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      if (mounted) {
        setState(() {
          _canScrollLeft = canLeft;
          _canScrollRight = canRight;
        });
      }
    }
  }

  void _scrollCategories(bool forward) {
    if (!_categoryScrollController.hasClients) return;
    const scrollStep = 260.0;
    final target = forward
        ? (_categoryScrollController.offset + scrollStep).clamp(
            0.0,
            _categoryScrollController.position.maxScrollExtent,
          )
        : (_categoryScrollController.offset - scrollStep).clamp(
            0.0,
            _categoryScrollController.position.maxScrollExtent,
          );

    _categoryScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
    _scheduleCatalogRefresh();
    if (_isAppResumed) unawaited(_refreshCatalog());
  }

  void _scheduleCatalogRefresh() {
    _catalogRefreshTimer?.cancel();
    if (!_isAppResumed) return;
    _catalogRefreshTimer = Timer.periodic(Duration(minutes: 30), (_) {
      if (mounted) unawaited(_refreshCatalog());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _catalogRefreshTimer?.cancel();
    _searchDebounce?.cancel();
    _categoryScrollController.removeListener(_updateScrollButtons);
    _categoryScrollController.dispose();
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

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {});
      return;
    }
    _searchDebounce = Timer(Duration(milliseconds: 500), () async {
      await widget.discoveryService.searchFeeds(query);
      setState(() {});
    });
  }

  DateTime _latestPublication(SuggestedFeed feed) {
    final preview = widget.suggestionService.previews[feed.url];
    final dates = preview == null
        ? <DateTime>[]
        : preview.items.map((item) => item.publishedAt).whereType<DateTime>();
    return dates.fold<DateTime>(
      DateTime.fromMillisecondsSinceEpoch(0),
      (latest, date) => date.isAfter(latest) ? date : latest,
    );
  }

  int _recentPublicationCount(SuggestedFeed feed) {
    final cutoff = DateTime.now().subtract(Duration(days: 30));
    final preview = widget.suggestionService.previews[feed.url];
    return preview?.items
            .where(
              (item) =>
                  item.publishedAt != null && item.publishedAt!.isAfter(cutoff),
            )
            .length ??
        0;
  }

      Widget _categoryNavButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: FeedFlowColors.surfaceElevated,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: FeedFlowColors.divider.withValues(alpha: 0.8),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 20,
              color: FeedFlowColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Notícias':
        return Icons.newspaper_rounded;
      case 'Tecnologia':
        return Icons.memory_rounded;
      case 'Ciência':
        return Icons.science_rounded;
      case 'Economia & Negócios':
        return Icons.trending_up_rounded;
      case 'Cultura & Geek':
        return Icons.sports_esports_rounded;
      case 'Esportes':
        return Icons.sports_soccer_rounded;
      case 'Design & Arte':
        return Icons.palette_outlined;
      case 'Saúde & Bem-Estar':
        return Icons.favorite_outline_rounded;
      case 'Podcasts':
        return Icons.podcasts_rounded;
      default:
        return Icons.explore_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.feedService,
        widget.suggestionService,
        widget.discoveryService,
      ]),
      builder: (context, _) {
        final query = _searchController.text.trim().toLowerCase();
        final followedUrls = widget.feedService.sources
            .map((source) => source.url)
            .toSet();

        // Use external search results when searching, otherwise use local catalog
        List<SuggestedFeed> directory;
        if (query.isNotEmpty &&
            widget.discoveryService.searchResults.isNotEmpty) {
          directory = widget.discoveryService.searchResults;
        } else {
          directory = suggestedFeeds.where((feed) {
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
        }

        return SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Explorar',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: FeedFlowColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Encontre novas vozes e fontes para o seu dia.',
                        style: TextStyle(
                          fontSize: 14,
                          color: FeedFlowColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 18),
                      TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Pesquisar fontes para descobrir',
                          prefixIcon: Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Limpar pesquisa',
                                  onPressed: () {
                                    _searchController.clear();
                                    widget.discoveryService.searchResults = [];
                                    setState(() {});
                                  },
                                  icon: Icon(Icons.close_rounded),
                                )
                              : null,
                        ),
                      ),
                      SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              showAddFeedDialog(context, widget.feedService),
                          icon: Icon(Icons.add_link_rounded),
                          label: Text('Adicionar por URL'),
                        ),
                      ),
                      SizedBox(height: 12),
                      if (query.isNotEmpty) ...[
                        if (widget.discoveryService.isSearching)
                          Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Encontrando novas fontes para você…',
                                style: TextStyle(
                                  color: FeedFlowColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        else if (widget
                            .discoveryService
                            .searchResults
                            .isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: FeedFlowColors.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: FeedFlowColors.primary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.public_rounded,
                                  size: 14,
                                  color: FeedFlowColors.secondary,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '${widget.discoveryService.searchResults.length} resultados de APIs externas',
                                  style: TextStyle(
                                    color: FeedFlowColors.secondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(height: 12),
                      ] else ...[
                        _CatalogUpdateBanner(
                          updatedAt: widget.suggestionService.lastUpdatedAt,
                          isRefreshing: widget.suggestionService.isRefreshing,
                        ),
                        SizedBox(height: 18),
                      ],
                      if (query.isEmpty) ...[
                        Text(
                          'Mais novos usa a data da publicação. Mais atualizados prioriza fontes com mais publicações nos últimos 30 dias.',
                          style: TextStyle(
                            color: FeedFlowColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final sort in [
                              'Mais novos',
                              'Mais atualizados',
                            ])
                              FilterChip(
                                showCheckmark: false,
                                avatar: Icon(
                                  sort == 'Mais novos'
                                      ? Icons.fiber_new_rounded
                                      : Icons.bolt_rounded,
                                  size: 15,
                                  color: _catalogSort == sort
                                      ? FeedFlowColors.secondary
                                      : FeedFlowColors.textDisabled,
                                ),
                                label: Text(sort),
                                selected: _catalogSort == sort,
                                selectedColor: FeedFlowColors.secondary.withValues(alpha: 0.14),
                                backgroundColor: FeedFlowColors.surfaceElevated,
                                labelStyle: TextStyle(
                                  color: _catalogSort == sort
                                      ? FeedFlowColors.secondary
                                      : FeedFlowColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: _catalogSort == sort
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                                side: BorderSide(
                                  color: _catalogSort == sort
                                      ? FeedFlowColors.secondary.withValues(alpha: 0.8)
                                      : FeedFlowColors.divider.withValues(alpha: 0.6),
                                  width: _catalogSort == sort ? 1.0 : 0.6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                onSelected: (_) =>
                                    setState(() => _catalogSort = sort),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (_canScrollLeft) ...[
                              _categoryNavButton(
                                icon: Icons.chevron_left_rounded,
                                tooltip: 'Rolar categorias para esquerda',
                                onPressed: () => _scrollCategories(false),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: ScrollConfiguration(
                                behavior: ScrollConfiguration.of(context).copyWith(
                                  dragDevices: {
                                    PointerDeviceKind.touch,
                                    PointerDeviceKind.mouse,
                                    PointerDeviceKind.trackpad,
                                    PointerDeviceKind.stylus,
                                  },
                                ),
                                child: SingleChildScrollView(
                                  controller: _categoryScrollController,
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: [
                                      for (final category in _categories)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: FilterChip(
                                            showCheckmark: false,
                                            avatar: Icon(
                                              _categoryIcon(category),
                                              size: 15,
                                              color: _category == category
                                                  ? FeedFlowColors.primary
                                                  : FeedFlowColors.textSecondary,
                                            ),
                                            label: Text(category),
                                            selected: _category == category,
                                            selectedColor: FeedFlowColors.primary.withValues(alpha: 0.16),
                                            backgroundColor: FeedFlowColors.surfaceElevated,
                                            labelStyle: TextStyle(
                                              color: _category == category
                                                  ? FeedFlowColors.primary
                                                  : FeedFlowColors.textSecondary,
                                              fontSize: 12.5,
                                              fontWeight: _category == category
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                            ),
                                            side: BorderSide(
                                              color: _category == category
                                                  ? FeedFlowColors.primary
                                                  : FeedFlowColors.divider.withValues(alpha: 0.6),
                                              width: _category == category ? 1.0 : 0.6,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            onSelected: (_) =>
                                                setState(() => _category = category),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_canScrollRight) ...[
                              const SizedBox(width: 8),
                              _categoryNavButton(
                                icon: Icons.chevron_right_rounded,
                                tooltip: 'Rolar categorias para direita',
                                onPressed: () => _scrollCategories(true),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
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
        SliverFillRemaining(
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
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
        sliver: SliverList.separated(
          itemCount: feeds.length,
          separatorBuilder: (_, _) => SizedBox(height: 10),
          itemBuilder: (context, index) {
            final feed = feeds[index];
            final isFollowing = followedUrls.contains(feed.url);
            final isAdding = _addingUrls.contains(feed.url);
            return _DirectoryFeedCard(
              feed: feed,
              isFollowing: isFollowing,
              isAdding: isAdding,
              previewItems:
                  widget.suggestionService.previews[feed.url]?.items ?? [],
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
}

class _DirectoryFeedCard extends StatelessWidget {
  _DirectoryFeedCard({
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
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: FeedFlowColors.primary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: FeedFlowColors.secondary),
        ),
        title: Text(feed.name, style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Expanded(child: Text(feed.description))]),
              if (previewItems.isNotEmpty) ...[
                SizedBox(height: 10),
                Text(
                  'PUBLICAÇÕES RECENTES',
                  style: TextStyle(
                    color: FeedFlowColors.textDisabled,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 4),
                for (final item in previewItems.take(3))
                  Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      '• ${item.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: FeedFlowColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (latestPublication != null)
                  Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Text(
                      'Feed atualizado em ${_formatDateTime(latestPublication)}',
                      style: TextStyle(
                        color: FeedFlowColors.textDisabled,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ] else if (isPreviewLoading) ...[
                SizedBox(height: 10),
                Row(
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
                SizedBox(height: 8),
                Text(
                  'Prévia indisponível no momento.',
                  style: TextStyle(
                    color: FeedFlowColors.textDisabled,
                    fontSize: 12,
                  ),
                ),
              ],
              SizedBox(height: 6),
              Text(
                feed.category.toUpperCase(),
                style: TextStyle(
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
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isFollowing
            ? Icon(Icons.check_circle_rounded, color: FeedFlowColors.success)
            : IconButton.filledTonal(
                tooltip: 'Seguir ${feed.name}',
                onPressed: onFollow,
                icon: Icon(Icons.add_rounded),
              ),
      ),
    );
  }
}

class _CatalogUpdateBanner extends StatelessWidget {
  _CatalogUpdateBanner({required this.updatedAt, required this.isRefreshing});

  final DateTime? updatedAt;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final status = updatedAt == null
        ? 'Consultando feeds RSS…'
        : 'Última atualização: ${_formatDateTime(updatedAt!)}';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: FeedFlowColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
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
