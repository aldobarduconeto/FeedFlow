import 'dart:async';

import 'package:flutter/material.dart';

import 'models/feed.dart';
import 'models/feed_notification.dart';
import 'models/suggested_feed.dart';
import 'services/appearance_service.dart';
import 'package:flutter/services.dart';
import 'services/discovery_service.dart';
import 'services/feed_service.dart';
import 'services/notification_service.dart';
import 'services/podcast_player_service.dart';
import 'services/suggestion_service.dart';
import 'views/article_reader.dart';
import 'views/explore.dart';
import 'views/news_page.dart';
import 'views/notifications_page.dart';
import 'views/podcast_controls.dart';
import 'views/podcast_player_page.dart';
import 'views/podcasts_page.dart';
import 'views/settings.dart';
import 'views/widget/colors.dart';
import 'views/widget/in_app_notification_banner.dart';
import 'views/widget/liquid_container.dart';
import 'services/permission_service.dart';
import 'views/permissions_onboarding_dialog.dart';

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
  DiscoveryService? _discoveryService;
  NotificationService? _notificationService;
  StreamSubscription<FeedNotification>? _notificationSubscription;
  FeedNotification? _activeInAppNotification;
  final PermissionService _permissionService = PermissionService();
  bool _showPermissionsOnboarding = false;
  bool _isReloadingData = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    AppearanceService.instance.addListener(_appearanceChanged);
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    unawaited(_initializeServices());
  }

  void _appearanceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeServices() async {
    final notificationService = NotificationService();
    await notificationService.initialize();

    final feedService = FeedService(notificationService: notificationService);
    final suggestionService = SuggestionService(feedService);
    final discoveryService = DiscoveryService();
    PodcastPlayerService? podcastPlayer;

    try {
      podcastPlayer = PodcastPlayerService(feedService: feedService);
      await podcastPlayer.initializePreferences();
      await feedService.initialize();

      if (!mounted) {
        podcastPlayer.dispose();
        suggestionService.dispose();
        discoveryService.dispose();
        feedService.dispose();
        notificationService.dispose();
        return;
      }

      _notificationSubscription =
          notificationService.onInAppNotification.listen((notif) {
        if (mounted) {
          setState(() {
            _activeInAppNotification = notif;
          });
        }
      });

      final isFirstLaunch = await _permissionService.isFirstLaunch();

      setState(() {
        _notificationService = notificationService;
        _feedService = feedService;
        _suggestionService = suggestionService;
        _discoveryService = discoveryService;
        _podcastPlayer = podcastPlayer;
        _showPermissionsOnboarding = isFirstLaunch;
        _initializationError = null;
      });
    } catch (error) {
      podcastPlayer?.dispose();
      suggestionService.dispose();
      discoveryService.dispose();
      feedService.dispose();
      notificationService.dispose();
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

  void _handleNotificationTap(FeedNotification notif) {
    final feedService = _feedService;
    final podcastPlayer = _podcastPlayer;
    _notificationService?.markAsRead(notif.id);
    setState(() => _activeInAppNotification = null);

    if (feedService == null || podcastPlayer == null) return;

    final items = feedService.items;
    final itemMatches = items.where((i) => i.id == notif.itemId);
    final FeedItem? item = itemMatches.isNotEmpty ? itemMatches.first : null;

    final sources = feedService.sources;
    final sourceMatches = sources.where((s) => s.id == notif.feedId);
    final source = sourceMatches.isNotEmpty ? sourceMatches.first : null;

    if (item != null) {
      if (item.isPodcast) {
        podcastPlayer.play(item);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PodcastPlayerPage(
              player: podcastPlayer,
              feedService: feedService,
            ),
          ),
        );
      } else {
        if (!item.isRead) feedService.toggleRead(item);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ArticleReaderPage(
              item: item,
              source: source,
              feedService: feedService,
            ),
          ),
        );
      }
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationsPage(
            notificationService: _notificationService!,
            feedService: feedService,
            podcastPlayer: podcastPlayer,
          ),
        ),
      );
    }
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;

    // Atalhos globais de mídia para TV e controles
    final player = _podcastPlayer;
    if (player != null && player.currentItem != null) {
      if (key == LogicalKeyboardKey.mediaPlayPause ||
          key == LogicalKeyboardKey.mediaPlay ||
          key == LogicalKeyboardKey.mediaPause) {
        player.toggle(player.currentItem!);
        return true;
      }
      if (key == LogicalKeyboardKey.mediaRewind) {
        player.skipBackward(const Duration(seconds: 15));
        return true;
      }
      if (key == LogicalKeyboardKey.mediaFastForward) {
        player.skipForward(const Duration(seconds: 30));
        return true;
      }
      if (key == LogicalKeyboardKey.mediaTrackNext) {
        player.playNext();
        return true;
      }
    }

    // Troca de abas no controle de TV / Gamepad (PageUp/Down, Channel+/-, L1/R1)
    if (key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.gameButtonLeft1) {
      if (mounted) {
        setState(() => _currentIndex = (_currentIndex - 1).clamp(0, 2));
      }
      return true;
    }
    if (key == LogicalKeyboardKey.channelDown ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.gameButtonRight1) {
      if (mounted) {
        setState(() => _currentIndex = (_currentIndex + 1).clamp(0, 2));
      }
      return true;
    }

    // Atalhos numéricos 1, 2, 3 para abas
    if (key == LogicalKeyboardKey.digit1) {
      if (mounted) setState(() => _currentIndex = 0);
      return true;
    }
    if (key == LogicalKeyboardKey.digit2) {
      if (mounted) setState(() => _currentIndex = 1);
      return true;
    }
    if (key == LogicalKeyboardKey.digit3) {
      if (mounted) setState(() => _currentIndex = 2);
      return true;
    }

    return false;
  }

  @override
  void dispose() {
    AppearanceService.instance.removeListener(_appearanceChanged);
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _notificationSubscription?.cancel();
    _notificationService?.dispose();
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
    final notificationService = _notificationService;

    return MaterialApp(
      title: 'FeedFlow',
      theme: FeedFlowTheme.current,
      darkTheme: FeedFlowTheme.dark,
      themeMode: AppearanceService.instance.themeMode,
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
                  suggestionService == null ||
                  discoveryService == null ||
                  notificationService == null)
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              : _showPermissionsOnboarding
                  ? Scaffold(
                      backgroundColor: FeedFlowColors.background.withValues(alpha: 0.85),
                      body: Center(
                        child: PermissionsOnboardingDialog(
                          permissionService: _permissionService,
                          onCompleted: () => setState(
                            () => _showPermissionsOnboarding = false,
                          ),
                        ),
                      ),
                    )
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
                            notificationService: notificationService,
                            onReloadData: _reloadData,
                          ),
                        ),
                      );
                    }

                    void openNotifications() {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => NotificationsPage(
                            notificationService: notificationService,
                            feedService: feedService,
                            podcastPlayer: podcastPlayer,
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
                        toolbarHeight: 64,
                        automaticallyImplyLeading: false,
                        titleSpacing: 20,
                        backgroundColor: FeedFlowColors.background.withValues(alpha: 0.85),
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/icon.png',
                                width: 32,
                                height: 32,
                                semanticLabel: 'FeedFlow',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'FeedFlow',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                                color: FeedFlowColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          // Botão de Notificações com Badge Clean
                          AnimatedBuilder(
                            animation: notificationService,
                            builder: (context, _) {
                              final unread = notificationService.unreadCount;
                              return IconButton(
                                tooltip: unread > 0
                                    ? '$unread notificações não lidas'
                                    : 'Notificações',
                                onPressed: openNotifications,
                                icon: Badge(
                                  isLabelVisible: unread > 0,
                                  label: Text(
                                    unread > 9 ? '9+' : '$unread',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: FeedFlowColors.primary,
                                  child: Icon(
                                    unread > 0
                                        ? Icons.notifications_rounded
                                        : Icons.notifications_none_rounded,
                                    color: unread > 0
                                        ? FeedFlowColors.primary
                                        : FeedFlowColors.textSecondary,
                                    size: 22,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Atualizar conteúdos',
                            onPressed: _isReloadingData
                                ? null
                                : () => _reloadDataFromNavigation(context),
                            icon: _isReloadingData
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: FeedFlowColors.secondary,
                                    ),
                                  )
                                : Icon(
                                    Icons.refresh_rounded,
                                    color: FeedFlowColors.textSecondary,
                                    size: 22,
                                  ),
                          ),
                          IconButton(
                            tooltip: 'Configurações',
                            onPressed: openSettings,
                            icon: Icon(
                              Icons.tune_rounded,
                              color: FeedFlowColors.textSecondary,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ),
                      body: Stack(
                        children: [
                          const LiquidBackgroundOrbs(),
                          Row(
                            children: [
                              if (!compact) ...[
                                NavigationRail(
                                  extended: extended,
                                  minWidth: 80,
                                  minExtendedWidth: 200,
                                  backgroundColor: FeedFlowColors.background.withValues(alpha: 0.85),
                                  selectedIndex: _currentIndex,
                                  labelType: extended
                                      ? NavigationRailLabelType.none
                                      : NavigationRailLabelType.all,
                                  onDestinationSelected: (index) =>
                                      setState(() => _currentIndex = index),
                                  destinations: const [
                                    NavigationRailDestination(
                                      icon: Icon(Icons.newspaper_outlined),
                                      selectedIcon:
                                          Icon(Icons.newspaper_rounded),
                                      label: Text('Notícias'),
                                    ),
                                    NavigationRailDestination(
                                      icon: Icon(Icons.podcasts_outlined),
                                      selectedIcon:
                                          Icon(Icons.podcasts_rounded),
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
                                  color: FeedFlowColors.divider
                                      .withValues(alpha: 0.5),
                                ),
                              ],
                              Expanded(
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 1160),
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
                          // Toast Banner suspenso de Notificação In-App
                          if (_activeInAppNotification != null)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: InAppNotificationBanner(
                                notification: _activeInAppNotification!,
                                onTap: () => _handleNotificationTap(
                                  _activeInAppNotification!,
                                ),
                                onDismiss: () => setState(
                                  () => _activeInAppNotification = null,
                                ),
                              ),
                            ),
                        ],
                      ),
                      bottomNavigationBar: compact
                          ? SafeArea(
                              top: false,
                              child: LiquidFloatingDock(
                                selectedIndex: _currentIndex,
                                onItemSelected: (index) =>
                                    setState(() => _currentIndex = index),
                                items: const [
                                  LiquidDockItem(
                                    icon: Icons.newspaper_outlined,
                                    selectedIcon: Icons.newspaper_rounded,
                                    label: 'Notícias',
                                  ),
                                  LiquidDockItem(
                                    icon: Icons.podcasts_outlined,
                                    selectedIcon: Icons.podcasts_rounded,
                                    label: 'Podcasts',
                                  ),
                                  LiquidDockItem(
                                    icon: Icons.explore_outlined,
                                    selectedIcon: Icons.explore_rounded,
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
