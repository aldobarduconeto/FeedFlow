import 'dart:async';

import 'services/appearance_service.dart';

import 'package:flutter/material.dart';

import 'models/suggested_feed.dart';
import 'services/feed_service.dart';
import 'services/podcast_player_service.dart';
import 'services/suggestion_service.dart';
import 'services/discovery_service.dart';
import 'views/explore.dart';
import 'views/news_page.dart';
import 'views/podcasts_page.dart';
import 'views/podcast_controls.dart';
import 'views/settings.dart';
import 'views/widget/colors.dart';

class App extends StatefulWidget {
  App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentIndex = 0;
  FeedService? _feedService;
  PodcastPlayerService? _podcastPlayer;
  SuggestionService? _suggestionService;
  DiscoveryService? _discoveryService;
  bool _isReloadingData = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    AppearanceService.instance.addListener(_appearanceChanged);
    unawaited(_initializeServices());
  }

  void _appearanceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeServices() async {
    final feedService = FeedService();
    final suggestionService = SuggestionService(feedService);
    final discoveryService = DiscoveryService();
    PodcastPlayerService? podcastPlayer;
    try {
      podcastPlayer = PodcastPlayerService(feedService: feedService);
      // Publish services together only after feed storage initialization finishes.
      await podcastPlayer.initializePreferences();
      await feedService.initialize();
      if (!mounted) {
        podcastPlayer.dispose();
        suggestionService.dispose();
        discoveryService.dispose();
        feedService.dispose();
        return;
      }
      setState(() {
        _feedService = feedService;
        _suggestionService = suggestionService;
        _discoveryService = discoveryService;
        _podcastPlayer = podcastPlayer;
        _initializationError = null;
      });
    } catch (error) {
      podcastPlayer?.dispose();
      suggestionService.dispose();
      discoveryService.dispose();
      feedService.dispose();
      if (!mounted) return;
      setState(() => _initializationError = error.toString());
    }
  }

  Future<void> _reloadData() async {
    if (_isReloadingData) return;
    final feedService = _feedService;
    final suggestionService = _suggestionService;
    if (feedService == null || suggestionService == null) return;
    setState(() => _isReloadingData = true);
    try {
      await Future.wait([
        feedService.refreshAll(),
        suggestionService.refresh(suggestedFeeds),
      ]);
    } finally {
      if (mounted) setState(() => _isReloadingData = false);
    }
  }

  Future<void> _reloadDataFromNavigation(BuildContext context) async {
    try {
      await _reloadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível recarregar os dados: $error')),
      );
    }
  }

  @override
  void dispose() {
    AppearanceService.instance.removeListener(_appearanceChanged);
    _podcastPlayer?.dispose();
    _suggestionService?.dispose();
    _discoveryService?.dispose();
    _feedService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedService = _feedService;
    final podcastPlayer = _podcastPlayer;
    final suggestionService = _suggestionService;
    final discoveryService = _discoveryService;
    return MaterialApp(
      title: 'FeedFlow',
      theme: FeedFlowTheme.dark,
      themeMode: ThemeMode.dark,
      home: _initializationError != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Não foi possível inicializar o FeedFlow: $_initializationError',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() => _initializationError = null);
                          unawaited(_initializeServices());
                        },
                        child: Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : (feedService == null ||
                podcastPlayer == null ||
                suggestionService == null ||
                discoveryService == null)
          ? Scaffold(body: Center(child: CircularProgressIndicator()))
          : LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final extended = constraints.maxWidth >= 1200;
                void openSettings() {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => SettingsPage(
                        feedService: feedService,
                        suggestionService: suggestionService,
                        onReloadData: _reloadData,
                      ),
                    ),
                  );
                }

                final pages = [
                  NewsPage(
                    feeds: feedService,
                    player: podcastPlayer,
                    onDiscover: () => setState(() => _currentIndex = 2),
                    onRefresh: () => _reloadDataFromNavigation(context),
                  ),
                  PodcastsPage(
                    feedService: feedService,
                    podcastPlayer: podcastPlayer,
                    isReloadingData: _isReloadingData,
                    onReloadData: () => _reloadDataFromNavigation(context),
                    onDiscover: () => setState(() => _currentIndex = 2),
                  ),
                  ExplorePage(
                    feedService: feedService,
                    suggestionService: suggestionService,
                    discoveryService: discoveryService,
                    isReloadingData: _isReloadingData,
                    onReloadData: () => _reloadDataFromNavigation(context),
                  ),
                ];
                return Scaffold(
                  appBar: AppBar(
                    toolbarHeight: 68,
                    automaticallyImplyLeading: false,
                    titleSpacing: 16,
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/icon.png',
                            width: 34,
                            height: 34,
                            semanticLabel: 'FeedFlow',
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'FeedFlow',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Atualizar conteúdos',
                        onPressed: _isReloadingData
                            ? null
                            : () => _reloadDataFromNavigation(context),
                        icon: _isReloadingData
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                      IconButton(
                        tooltip: 'Configurações',
                        onPressed: openSettings,
                        icon: const Icon(Icons.tune_rounded),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                  body: Row(
                    children: [
                      if (!compact) ...[
                        NavigationRail(
                          extended: extended,
                          minWidth: 88,
                          minExtendedWidth: 208,
                          backgroundColor: FeedFlowColors.background,
                          selectedIndex: _currentIndex,
                          labelType: extended
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
                          onDestinationSelected: (index) =>
                              setState(() => _currentIndex = index),
                          destinations: const [
                            NavigationRailDestination(
                              icon: Icon(Icons.newspaper_outlined),
                              selectedIcon: Icon(Icons.newspaper_rounded),
                              label: Text('Notícias'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.podcasts_outlined),
                              selectedIcon: Icon(Icons.podcasts_rounded),
                              label: Text('Podcasts'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.explore_outlined),
                              selectedIcon: Icon(Icons.explore_rounded),
                              label: Text('Explorar'),
                            ),
                          ],
                        ),
                        VerticalDivider(
                          width: 1,
                          color: FeedFlowColors.divider.withValues(alpha: 0.5),
                        ),
                      ],
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1160),
                            child: Column(
                              children: [
                                Expanded(
                                  child: IndexedStack(
                                    index: _currentIndex,
                                    children: pages,
                                  ),
                                ),
                                PodcastNowPlayingBar(
                                  player: podcastPlayer,
                                  feedService: feedService,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  bottomNavigationBar: compact
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: FeedFlowColors.divider.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                          child: NavigationBar(
                            height: 72,
                            selectedIndex: _currentIndex,
                            onDestinationSelected: (index) =>
                                setState(() => _currentIndex = index),
                            destinations: const [
                              NavigationDestination(
                                icon: Icon(Icons.newspaper_outlined),
                                selectedIcon: Icon(Icons.newspaper_rounded),
                                label: 'Notícias',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.podcasts_outlined),
                                selectedIcon: Icon(Icons.podcasts_rounded),
                                label: 'Podcasts',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.explore_outlined),
                                selectedIcon: Icon(Icons.explore_rounded),
                                label: 'Explorar',
                              ),
                            ],
                          ),
                        )
                      : null,
                );
              },
            ),
    );
  }
}
