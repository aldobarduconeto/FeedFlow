import 'dart:async';

import 'package:flutter/material.dart';

import 'models/suggested_feed.dart';
import 'services/feed_service.dart';
import 'services/podcast_player_service.dart';
import 'services/suggestion_service.dart';
import 'views/explore.dart';
import 'views/home.dart';
import 'views/podcast_controls.dart';
import 'views/settings.dart';
import 'views/widget/colors.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentIndex = 0;
  FeedService? _feedService;
  PodcastPlayerService? _podcastPlayer;
  SuggestionService? _suggestionService;
  bool _isReloadingData = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeServices());
  }

  Future<void> _initializeServices() async {
    final feedService = FeedService();
    final suggestionService = SuggestionService(feedService);
    final podcastPlayer = PodcastPlayerService(feedService: feedService);

    try {
      // Publish services together only after feed storage initialization finishes.
      await feedService.initialize();
      if (!mounted) {
        podcastPlayer.dispose();
        suggestionService.dispose();
        feedService.dispose();
        return;
      }
      setState(() {
        _feedService = feedService;
        _suggestionService = suggestionService;
        _podcastPlayer = podcastPlayer;
        _initializationError = null;
      });
    } catch (error) {
      podcastPlayer.dispose();
      suggestionService.dispose();
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

  Future<void> _reloadDataFromNavigation() async {
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
    _podcastPlayer?.dispose();
    _suggestionService?.dispose();
    _feedService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedService = _feedService;
    final podcastPlayer = _podcastPlayer;
    final suggestionService = _suggestionService;
    return MaterialApp(
      title: 'FeedFlow',
      theme: FeedFlowTheme.dark,
      themeMode: ThemeMode.dark,
      home: _initializationError != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Não foi possível inicializar o FeedFlow: $_initializationError',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() => _initializationError = null);
                          unawaited(_initializeServices());
                        },
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : (feedService == null ||
                podcastPlayer == null ||
                suggestionService == null)
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape =
                    MediaQuery.orientationOf(context) == Orientation.landscape;
                final isCompact = constraints.maxWidth < 700 && !isLandscape;
                return Scaffold(
                  appBar: isCompact
                      ? AppBar(
                          automaticallyImplyLeading: false,
                          leading: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              'assets/icon.png',
                              fit: BoxFit.contain,
                              semanticLabel: 'Logo FeedFlow',
                            ),
                          ),
                          title: const Text('FeedFlow'),
                        )
                      : null,
                  body: Row(
                    children: [
                      if (!isCompact) ...[
                        SizedBox(
                          width: 280,
                          child: NavigationDrawer(
                            selectedIndex: _currentIndex,
                            onDestinationSelected: (index) {
                              setState(() => _currentIndex = index);
                            },
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  20,
                                  16,
                                  20,
                                ),
                                child: Row(
                                  children: [
                                    Image.asset(
                                      'assets/icon.png',
                                      width: 40,
                                      height: 40,
                                      semanticLabel: 'Logo FeedFlow',
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'FeedFlow',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const NavigationDrawerDestination(
                                icon: Icon(Icons.home_outlined),
                                selectedIcon: Icon(Icons.home),
                                label: Text('Início'),
                              ),
                              const NavigationDrawerDestination(
                                icon: Icon(Icons.subscriptions_outlined),
                                selectedIcon: Icon(Icons.subscriptions),
                                label: Text('Inscrições'),
                              ),
                              const NavigationDrawerDestination(
                                icon: Icon(Icons.explore_outlined),
                                selectedIcon: Icon(Icons.explore),
                                label: Text('Explorar'),
                              ),
                              const NavigationDrawerDestination(
                                icon: Icon(Icons.settings_outlined),
                                selectedIcon: Icon(Icons.settings),
                                label: Text('Configurações'),
                              ),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 1),
                      ],
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isCompact ? double.infinity : 1440,
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: IndexedStack(
                                    index: _currentIndex,
                                    children: [
                                      HomePage(
                                        feedService: feedService,
                                        podcastPlayer: podcastPlayer,
                                        isReloadingData: _isReloadingData,
                                        onReloadData: _reloadDataFromNavigation,
                                      ),
                                      SubscriptionsPage(
                                        feedService: feedService,
                                        podcastPlayer: podcastPlayer,
                                        isReloadingData: _isReloadingData,
                                        onReloadData: _reloadDataFromNavigation,
                                        onDiscover: () =>
                                            setState(() => _currentIndex = 2),
                                      ),
                                      ExplorePage(
                                        feedService: feedService,
                                        suggestionService: suggestionService,
                                        isReloadingData: _isReloadingData,
                                        onReloadData: _reloadDataFromNavigation,
                                      ),
                                      SettingsPage(
                                        feedService: feedService,
                                        suggestionService: suggestionService,
                                        onReloadData: _reloadData,
                                      ),
                                    ],
                                  ),
                                ),
                                PodcastNowPlayingBar(player: podcastPlayer),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  bottomNavigationBar: isCompact
                      ? BottomNavigationBar(
                          currentIndex: _currentIndex,
                          onTap: (index) =>
                              setState(() => _currentIndex = index),
                          items: const [
                            BottomNavigationBarItem(
                              icon: Icon(Icons.home),
                              label: 'Início',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.subscriptions),
                              label: 'Inscrições',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.explore),
                              label: 'Explorar',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.settings),
                              label: 'Configurações',
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
    );
  }
}
