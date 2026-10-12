import 'dart:async';

import 'package:flutter/material.dart';

import 'models/suggested_feed.dart';
import 'services/auth_service.dart';
import 'services/feed_service.dart';
import 'services/podcast_player_service.dart';
import 'services/suggestion_service.dart';
import 'views/auth_page.dart';
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
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  FeedService? _feedService;
  PodcastPlayerService? _podcastPlayer;
  SuggestionService? _suggestionService;
  bool _authLoading = true;
  bool _isReloadingData = false;
  String? _userId;
  String? _authError;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    try {
      final userId = await _authService.restoreSession();
      if (!mounted) return;
      setState(() {
        _userId = userId;
        _authLoading = false;
      });
      if (userId != null) _startFeedService(userId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _authError = error.toString();
        _authLoading = false;
      });
    }
  }

  void _startFeedService(String userId) {
    final service = FeedService(userId: userId);
    final suggestionService = SuggestionService(service);
    _podcastPlayer?.dispose();
    final player = PodcastPlayerService(feedService: service);
    setState(() {
      _userId = userId;
      _feedService = service;
      _podcastPlayer = player;
      _suggestionService = suggestionService;
      _currentIndex = 0;
    });
    unawaited(service.initialize());
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      _podcastPlayer?.dispose();
      _feedService?.dispose();
      _suggestionService?.dispose();
      if (!mounted) return;
      setState(() {
        _feedService = null;
        _podcastPlayer = null;
        _suggestionService = null;
        _userId = null;
        _currentIndex = 0;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível encerrar a sessão: $error')),
      );
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
    _feedService?.dispose();
    _suggestionService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FeedFlow',
      theme: FeedFlowTheme.dark,
      themeMode: ThemeMode.dark,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_authLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_authError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Não foi possível carregar a sessão local.'),
                const SizedBox(height: 12),
                Text(_authError!),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _authError = null;
                      _authLoading = true;
                    });
                    unawaited(_restoreSession());
                  },
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_userId == null || _feedService == null) {
      return AuthPage(
        authService: _authService,
        onAuthenticated: _startFeedService,
      );
    }

    final feedService = _feedService!;
    final podcastPlayer = _podcastPlayer!;
    return LayoutBuilder(
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
                        padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
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
                        icon: Icon(Icons.explore_outlined),
                        selectedIcon: Icon(Icons.explore),
                        label: Text('Explorar'),
                      ),
                      const NavigationDrawerDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Configurações'),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(),
                      ),
                      ListTile(
                        leading: _isReloadingData
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync_rounded),
                        title: const Text('Recarregar dados'),
                        enabled: !_isReloadingData,
                        onTap: _isReloadingData
                            ? null
                            : _reloadDataFromNavigation,
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
                                onDiscover: () =>
                                    setState(() => _currentIndex = 1),
                              ),
                              ExplorePage(
                                feedService: feedService,
                                suggestionService: _suggestionService!,
                                podcastPlayer: podcastPlayer,
                                isReloadingData: _isReloadingData,
                                onReloadData: _reloadDataFromNavigation,
                              ),
                              SettingsPage(
                                userId: _userId!,
                                authService: _authService,
                                feedService: feedService,
                                suggestionService: _suggestionService!,
                                onReloadData: _reloadData,
                                onSignOut: _signOut,
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
                  onTap: (index) => setState(() => _currentIndex = index),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home),
                      label: 'Início',
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
    );
  }
}
