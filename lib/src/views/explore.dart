import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/catalog_entry.dart';
import '../models/feed.dart';
import '../models/suggested_feed.dart';
import '../services/discovery_service.dart';
import '../services/feed_service.dart';
import '../services/online_catalog_service.dart';
import '../services/suggestion_service.dart';
import 'widget/add_feed_dialog.dart';
import 'widget/catalog_locale_dialogs.dart';
import 'widget/colors.dart';
import 'widget/liquid_container.dart';
import 'widget/tv_focusable.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({
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
  final TextEditingController _onlineSearchController = TextEditingController();
  final ScrollController _categoryScrollController = ScrollController();
  final Set<String> _addingUrls = {};

  Timer? _catalogRefreshTimer;
  Timer? _searchDebounce;
  String _category = 'Tudo';
  String _catalogSort = 'Mais atualizados';
  int _exploreMode = 0; // 0: Sugestões Locais, 1: Catálogo InfoBubble (por país)
  String _onlineFilterType = 'all'; // 'all', 'channels', 'podcasts'

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
    _catalogRefreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
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
    _onlineSearchController.dispose();
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

  Future<void> _followCatalogFeed(CatalogFeedLink feed, String host) async {
    if (!_addingUrls.add(feed.url)) return;
    setState(() {});
    try {
      await widget.feedService.addFeed(
        feed.url,
        category: feed.categoryName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Feed de $host adicionado ao seu FeedFlow!'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível adicionar $host: $error'),
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
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
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

  Widget _buildModeTab({
    required String title,
    required IconData icon,
    String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? FeedFlowColors.primary.withValues(alpha: 0.16)
              : FeedFlowColors.surfaceElevated.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? FeedFlowColors.primary
                : FeedFlowColors.divider.withValues(alpha: 0.7),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (badge != null) ...[
              Text(badge, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
            ] else ...[
              Icon(
                icon,
                size: 17,
                color: isSelected
                    ? FeedFlowColors.primary
                    : FeedFlowColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? FeedFlowColors.primary
                    : FeedFlowColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.feedService,
        widget.suggestionService,
        widget.discoveryService,
        OnlineCatalogService.instance,
      ]),
      builder: (context, _) {
        final query = _searchController.text.trim().toLowerCase();
        final followedUrls =
            widget.feedService.sources.map((source) => source.url).toSet();
        final onlineService = OnlineCatalogService.instance;

        // Diretório local
        List<SuggestedFeed> directory;
        if (query.isNotEmpty &&
            widget.discoveryService.searchResults.isNotEmpty) {
          directory = widget.discoveryService.searchResults;
        } else {
          directory = suggestedFeeds.where((feed) {
            final matchesCategory =
                _category == 'Tudo' || feed.category == _category;
            final matchesQuery = query.isEmpty ||
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
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
                      const SizedBox(height: 6),
                      Text(
                        'Descubra novos canais, notícias e podcasts locais e globais.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: FeedFlowColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Alternador de Abas: Destaques vs Catálogo Online InfoBubble
                      Row(
                        children: [
                          Expanded(
                            child: _buildModeTab(
                              title: 'Sugestões',
                              icon: Icons.auto_awesome_rounded,
                              isSelected: _exploreMode == 0,
                              onTap: () => setState(() => _exploreMode = 0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildModeTab(
                              title:
                                  'Catálogo (${onlineService.selectedCountryDisplay})',
                              icon: Icons.travel_explore_rounded,
                              badge: OnlineCatalogService.countryFlag(
                                onlineService.selectedCountry,
                              ),
                              isSelected: _exploreMode == 1,
                              onTap: () => setState(() => _exploreMode = 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Renderiza cabeçalho de acordo com o modo
                      if (_exploreMode == 0) ...[
                        TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Pesquisar fontes para descobrir',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    tooltip: 'Limpar pesquisa',
                                    onPressed: () {
                                      _searchController.clear();
                                      widget.discoveryService.searchResults =
                                          [];
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () => showAddFeedDialog(
                              context,
                              widget.feedService,
                            ),
                            icon: const Icon(Icons.add_link_rounded),
                            label: const Text('Adicionar por URL'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (query.isNotEmpty) ...[
                          if (widget.discoveryService.isSearching)
                            Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Encontrando novas fontes para você…',
                                  style: TextStyle(
                                    color: FeedFlowColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          else if (widget.discoveryService.searchResults
                              .isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
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
                                  const SizedBox(width: 6),
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
                          const SizedBox(height: 12),
                        ] else ...[
                          _CatalogUpdateBanner(
                            updatedAt: widget.suggestionService.lastUpdatedAt,
                            isRefreshing: widget.suggestionService.isRefreshing,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (query.isEmpty) ...[
                          Text(
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
                                  selectedColor: FeedFlowColors.secondary
                                      .withValues(alpha: 0.14),
                                  backgroundColor:
                                      FeedFlowColors.surfaceElevated,
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
                                        ? FeedFlowColors.secondary
                                            .withValues(alpha: 0.8)
                                        : FeedFlowColors.divider
                                            .withValues(alpha: 0.6),
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
                                  behavior:
                                      ScrollConfiguration.of(context).copyWith(
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
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: FilterChip(
                                              showCheckmark: false,
                                              avatar: Icon(
                                                _categoryIcon(category),
                                                size: 15,
                                                color: _category == category
                                                    ? FeedFlowColors.primary
                                                    : FeedFlowColors
                                                        .textSecondary,
                                              ),
                                              label: Text(category),
                                              selected: _category == category,
                                              selectedColor: FeedFlowColors
                                                  .primary
                                                  .withValues(alpha: 0.16),
                                              backgroundColor: FeedFlowColors
                                                  .surfaceElevated,
                                              labelStyle: TextStyle(
                                                color: _category == category
                                                    ? FeedFlowColors.primary
                                                    : FeedFlowColors
                                                        .textSecondary,
                                                fontSize: 12.5,
                                                fontWeight: _category == category
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                              ),
                                              side: BorderSide(
                                                color: _category == category
                                                    ? FeedFlowColors.primary
                                                    : FeedFlowColors.divider
                                                        .withValues(alpha: 0.6),
                                                width: _category == category
                                                    ? 1.0
                                                    : 0.6,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              onSelected: (_) => setState(
                                                () => _category = category,
                                              ),
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
                          const SizedBox(height: 12),
                        ],
                      ] else ...[
                        // Cabeçalho do Catálogo Online InfoBubble
                        _buildOnlineCatalogHeader(context, onlineService),
                      ],
                    ],
                  ),
                ),
              ),

              // Slivers do Conteúdo Principal
              if (_exploreMode == 0)
                ..._directorySlivers(directory, followedUrls)
              else
                ..._onlineCatalogSlivers(onlineService, followedUrls),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOnlineCatalogHeader(
    BuildContext context,
    OnlineCatalogService service,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LiquidContainer(
          padding: const EdgeInsets.all(14),
          backgroundColor: FeedFlowColors.surfaceElevated.withValues(alpha: 0.65),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.public_rounded,
                    color: FeedFlowColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catálogo InfoBubble: ${service.selectedCountryDisplay}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: FeedFlowColors.textPrimary,
                          ),
                        ),
                        Text(
                          'https://infobubble.github.io/infobubble-support/catalog.html',
                          style: TextStyle(
                            fontSize: 11,
                            color: FeedFlowColors.textDisabled,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: Text(
                      OnlineCatalogService.countryFlag(
                        service.selectedCountry,
                      ),
                      style: const TextStyle(fontSize: 15),
                    ),
                    label: Text(
                      'País: ${service.selectedCountryDisplay}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => showCountryPickerDialog(context),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.translate_rounded, size: 16),
                    label: Text(
                      'Idioma: ${service.selectedLanguageDisplay}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => showLanguagePickerDialog(context),
                  ),
                  Chip(
                    avatar: const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text(
                      'Sob Demanda (Sem Persistência)',
                      style: TextStyle(fontSize: 11),
                    ),
                    backgroundColor:
                        FeedFlowColors.surfaceHighlight.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Barra de busca do catálogo online se já consultado
        if (service.hasConsulted && !service.isLoading) ...[
          TextField(
            controller: _onlineSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Filtrar por portal, tema ou descrição...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _onlineSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _onlineSearchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilterChip(
                label: Text('Todos (${service.domains.length})'),
                selected: _onlineFilterType == 'all',
                onSelected: (_) => setState(() => _onlineFilterType = 'all'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.newspaper_rounded, size: 15),
                label: const Text('Notícias'),
                selected: _onlineFilterType == 'channels',
                onSelected: (_) =>
                    setState(() => _onlineFilterType = 'channels'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.podcasts_rounded, size: 15),
                label: const Text('Podcasts'),
                selected: _onlineFilterType == 'podcasts',
                onSelected: (_) =>
                    setState(() => _onlineFilterType = 'podcasts'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Recarregar consulta',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () => service.consultCatalog(force: true),
              ),
              IconButton(
                tooltip: 'Limpar da memória',
                icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                onPressed: () => service.clearMemory(),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  List<Widget> _onlineCatalogSlivers(
    OnlineCatalogService service,
    Set<String> followedUrls,
  ) {
    if (service.isLoading) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Consultando fontes de ${service.selectedCountryDisplay} sob demanda…',
                  style: TextStyle(
                    color: FeedFlowColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Buscando dados no catálogo oficial InfoBubble',
                  style: TextStyle(
                    color: FeedFlowColors.textDisabled,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (service.error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 44,
                    color: FeedFlowColors.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    service.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FeedFlowColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => service.consultCatalog(force: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    if (!service.hasConsulted) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: LiquidContainer(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.travel_explore_rounded,
                      size: 52,
                      color: FeedFlowColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Consultar Catálogo de ${service.selectedCountryDisplay}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: FeedFlowColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Visualize jornais, canais e podcasts catalogados em ${service.selectedCountryDisplay}. Conforme solicitado, os links e dados são mantidos exclusivamente em memória volátil e consultados apenas quando você desejar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: FeedFlowColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => service.consultCatalog(),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(
                        'Consultar Fontes de ${service.selectedCountryDisplay}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ];
    }

    // Filtragem em memória
    final searchQuery = _onlineSearchController.text.trim().toLowerCase();
    final domains = service.domains.where((d) {
      if (_onlineFilterType == 'channels' && d.channelCount == 0) return false;
      if (_onlineFilterType == 'podcasts' && d.podcastCount == 0) return false;
      if (searchQuery.isNotEmpty && !d.matchesQuery(searchQuery)) return false;
      return true;
    }).toList();

    if (domains.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Nenhuma fonte encontrada para o filtro atual.',
                style: TextStyle(color: FeedFlowColors.textSecondary),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        sliver: SliverList.separated(
          itemCount: domains.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final domain = domains[index];
            return _CatalogDomainCard(
              domain: domain,
              followedUrls: followedUrls,
              addingUrls: _addingUrls,
              onFollow: (feed) => _followCatalogFeed(feed, domain.host),
            );
          },
        ),
      ),
    ];
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
              padding: const EdgeInsets.all(28),
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
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
                  widget.suggestionService.previews[feed.url]?.items ?? [],
              isPreviewLoading: widget.suggestionService.isRefreshing &&
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

class _CatalogDomainCard extends StatelessWidget {
  const _CatalogDomainCard({
    required this.domain,
    required this.followedUrls,
    required this.addingUrls,
    required this.onFollow,
  });

  final CatalogDomainEntry domain;
  final Set<String> followedUrls;
  final Set<String> addingUrls;
  final void Function(CatalogFeedLink feed) onFollow;

  @override
  Widget build(BuildContext context) {
    final flag = OnlineCatalogService.countryFlag(domain.countryName);

    return TvFocusable(
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        domain.host,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: FeedFlowColors.textPrimary,
                        ),
                      ),
                      if (domain.rank != null)
                        Text(
                          'Tráfego Global: #${domain.rank}',
                          style: TextStyle(
                            fontSize: 11,
                            color: FeedFlowColors.textDisabled,
                          ),
                        ),
                    ],
                  ),
                ),
                if (domain.podcastCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: FeedFlowColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.podcasts_rounded,
                          size: 13,
                          color: FeedFlowColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${domain.podcastCount}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: FeedFlowColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (domain.summary != null && domain.summary!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                domain.summary!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: FeedFlowColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
            if (domain.categories.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final cat in domain.categories)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: FeedFlowColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: FeedFlowColors.divider.withValues(alpha: 0.7),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: FeedFlowColors.textDisabled,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Lista de feeds RSS / Podcasts deste portal
            for (final feed in domain.feeds) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      feed.isPodcast
                          ? Icons.podcasts_rounded
                          : Icons.rss_feed_rounded,
                      size: 16,
                      color: feed.isPodcast
                          ? FeedFlowColors.secondary
                          : FeedFlowColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feed.categoryName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: FeedFlowColors.textPrimary,
                            ),
                          ),
                          Text(
                            feed.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: FeedFlowColors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (followedUrls.contains(feed.url))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: FeedFlowColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: FeedFlowColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Seguindo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: FeedFlowColors.success,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (addingUrls.contains(feed.url))
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 32),
                        ),
                        onPressed: () => onFollow(feed),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 14),
                            SizedBox(width: 4),
                            Text('Seguir', style: TextStyle(fontSize: 11)),
                          ],
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
    );
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

    return TvFocusable(
      onPressed: isFollowing || isAdding ? null : onFollow,
      borderRadius: BorderRadius.circular(16),
      child: Card(
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
        title: Text(feed.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Expanded(child: Text(feed.description))]),
              if (previewItems.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
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
                      style: TextStyle(
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
                      style: TextStyle(
                        color: FeedFlowColors.textDisabled,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ] else if (isPreviewLoading) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
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
                Text(
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
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isFollowing
                ? Icon(Icons.check_circle_rounded, color: FeedFlowColors.success)
                : IconButton.filledTonal(
                    tooltip: 'Seguir ${feed.name}',
                    onPressed: onFollow,
                    icon: const Icon(Icons.add_rounded),
                  ),
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
                  style: TextStyle(
                    color: FeedFlowColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
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
