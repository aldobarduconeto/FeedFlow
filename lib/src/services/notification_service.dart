import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feed.dart';
import '../models/feed_notification.dart';
import '../models/feed_source.dart';

class NotificationService extends ChangeNotifier {
  static const _storageKey = 'feedflow.notifications.v1';
  static const _settingsKey = 'feedflow.notifications.enabled.v1';
  static const _maxStoredNotifications = 60;

  // Canais de Notificação para Android 8.0+ (Oreo+)
  static const AndroidNotificationChannel _newsChannel =
      AndroidNotificationChannel(
    'feedflow_news_channel',
    'FeedFlow - Notícias e Artigos',
    description: 'Avisos instantâneos quando novos artigos e notícias forem publicados',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _podcastsChannel =
      AndroidNotificationChannel(
    'feedflow_podcasts_channel',
    'FeedFlow - Novos Episódios',
    description: 'Avisos quando novos episódios de podcasts inscritos forem lançados',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final List<FeedNotification> _notifications = [];
  final _inAppNotificationController =
      StreamController<FeedNotification>.broadcast();
  final _systemNotificationTapController =
      StreamController<FeedNotification>.broadcast();

  bool _notificationsEnabled = true;
  bool _isInitialized = false;

  List<FeedNotification> get notifications =>
      List.unmodifiable(_notifications);

  /// Eventos para apresentação imediata da barra in-app quando o app está aberto
  Stream<FeedNotification> get onInAppNotification =>
      _inAppNotificationController.stream;

  /// Eventos disparados quando o usuário clica em uma notificação nativa do sistema
  Stream<FeedNotification> get onSystemNotificationTapped =>
      _systemNotificationTapController.stream;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get notificationsEnabled => _notificationsEnabled;

  /// Inicializa o serviço de notificações, configurações persistidas
  /// e o plugin de notificações nativas (Android, iOS, macOS, Linux)
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool(_settingsKey) ?? true;
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _notifications.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _notifications.add(FeedNotification.fromMap(item));
          }
        }
      }

      await _initLocalNotificationsPlugin();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao inicializar NotificationService: $e');
      _isInitialized = true;
    }
  }

  /// Configura o plugin nativo flutter_local_notifications
  Future<void> _initLocalNotificationsPlugin() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Abrir notificação',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      // Cria os canais de alta prioridade no Android
      final androidPlatform = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.createNotificationChannel(_newsChannel);
        await androidPlatform.createNotificationChannel(_podcastsChannel);
      }
    } catch (e) {
      debugPrint('Erro ao inicializar flutter_local_notifications: $e');
    }
  }

  /// Trata a resposta do clique na notificação do sistema
  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final notification = FeedNotification.fromMap(data);
      _systemNotificationTapController.add(notification);
    } catch (e) {
      debugPrint('Erro ao decodificar payload da notificação: $e');
    }
  }

  /// Solicita autorização de notificação diretamente via plugin nativo
  Future<bool> requestSystemNotificationPermission() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlatform = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted =
            await androidPlatform?.requestNotificationsPermission();
        return granted ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosPlatform = _localNotifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosPlatform?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macPlatform = _localNotifications
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>();
        final granted = await macPlatform?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Erro ao solicitar permissão no plugin de notificações: $e');
      return false;
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_settingsKey, enabled);
    } catch (e) {
      debugPrint('Erro ao salvar preferência de notificações: $e');
    }
    notifyListeners();
  }

  /// Notifica quando uma nova notícia ou podcast é publicado.
  /// Dispara tanto a notificação nativa do sistema quanto o banner in-app.
  Future<void> notifyItemPublished({
    required FeedItem item,
    required FeedSource source,
  }) async {
    if (!_notificationsEnabled) return;

    // Evita duplicar notificação do mesmo item
    if (_notifications.any((n) => n.itemId == item.id)) {
      return;
    }

    final publisherName = source.title.trim().isNotEmpty
        ? source.title.trim()
        : 'FeedFlow';

    final notification = FeedNotification(
      id: '${item.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: item.title.trim(),
      publisher: publisherName,
      feedId: source.id,
      itemId: item.id,
      isPodcast: item.isPodcast,
      publishedAt: item.publishedAt ?? DateTime.now(),
      receivedAt: DateTime.now(),
      imageUrl: item.imageUrl ?? source.imageUrl,
      audioUrl: item.audioUrl,
    );

    _notifications.insert(0, notification);
    if (_notifications.length > _maxStoredNotifications) {
      _notifications.removeRange(
        _maxStoredNotifications,
        _notifications.length,
      );
    }

    // Emite o evento para apresentação in-app
    _inAppNotificationController.add(notification);
    notifyListeners();
    await _persist();

    // Dispara a notificação nativa do sistema
    await _showSystemNotification(notification);
  }

  /// Exibe a notificação no painel de notificações do sistema operacional
  Future<void> _showSystemNotification(FeedNotification notification) async {
    try {
      final channel =
          notification.isPodcast ? _podcastsChannel : _newsChannel;

      final bigTextStyle = BigTextStyleInformation(
        notification.title,
        contentTitle: notification.publisher,
        summaryText: notification.isPodcast
            ? 'Novo Episódio de Podcast'
            : 'Nova Notícia',
      );

      final androidDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        styleInformation: bigTextStyle,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      final int notificationId = notification.id.hashCode & 0x7FFFFFFF;

      await _localNotifications.show(
        id: notificationId,
        title: notification.publisher,
        body: notification.title,
        notificationDetails: notificationDetails,
        payload: jsonEncode(notification.toMap()),
      );
    } catch (e) {
      debugPrint('Erro ao exibir notificação nativa do sistema: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
      await _persist();
    }
  }

  Future<void> markAllAsRead() async {
    bool changed = false;
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      await _persist();
    }
  }

  Future<void> removeNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    notifyListeners();
    await _persist();
  }

  /// Dispara uma notificação nativa e in-app de demonstração/teste para validação do usuário
  Future<void> sendTestNotification({required bool isPodcast}) async {
    final now = DateTime.now();
    final testNotification = FeedNotification(
      id: 'test_${now.millisecondsSinceEpoch}',
      title: isPodcast
          ? 'Episódio Especial: Inteligência Artificial e o Futuro do FeedFlow'
          : 'FeedFlow Notícias: As atualizações mais recentes chegam instantaneamente',
      publisher: isPodcast ? 'FeedFlow Podcasts' : 'FeedFlow Redação',
      feedId: 'test_feed',
      itemId: 'test_item_${now.millisecondsSinceEpoch}',
      isPodcast: isPodcast,
      publishedAt: now,
      receivedAt: now,
    );

    _notifications.insert(0, testNotification);
    if (_notifications.length > _maxStoredNotifications) {
      _notifications.removeRange(
        _maxStoredNotifications,
        _notifications.length,
      );
    }
    _inAppNotificationController.add(testNotification);
    notifyListeners();
    await _persist();

    // Dispara a notificação nativa no sistema operacional
    await _showSystemNotification(testNotification);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapped = _notifications.map((n) => n.toMap()).toList();
      await prefs.setString(_storageKey, jsonEncode(mapped));
    } catch (e) {
      debugPrint('Erro ao persistir notificações: $e');
    }
  }

  @override
  void dispose() {
    _inAppNotificationController.close();
    _systemNotificationTapController.close();
    super.dispose();
  }
}
