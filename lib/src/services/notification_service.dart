import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feed.dart';
import '../models/feed_notification.dart';
import '../models/feed_source.dart';

class NotificationService extends ChangeNotifier {
  static const _storageKey = 'feedflow.notifications.v1';
  static const _settingsKey = 'feedflow.notifications.enabled.v1';
  static const _maxStoredNotifications = 60;

  final List<FeedNotification> _notifications = [];
  final _inAppNotificationController =
      StreamController<FeedNotification>.broadcast();
  bool _notificationsEnabled = true;
  bool _isInitialized = false;

  List<FeedNotification> get notifications =>
      List.unmodifiable(_notifications);
  Stream<FeedNotification> get onInAppNotification =>
      _inAppNotificationController.stream;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get notificationsEnabled => _notificationsEnabled;

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
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao inicializar NotificationService: $e');
      _isInitialized = true;
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
  /// Contém o título e o publisher como subtítulo.
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

    // Emite o evento para apresentação imediata in-app
    _inAppNotificationController.add(notification);
    notifyListeners();
    await _persist();
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

  /// Dispara uma notificação de demonstração/teste para validação do usuário
  Future<void> sendTestNotification({required bool isPodcast}) async {
    final now = DateTime.now();
    final testNotification = FeedNotification(
      id: 'test_${now.millisecondsSinceEpoch}',
      title: isPodcast
          ? 'Episódio Especial: Tendências do Futuro'
          : 'Novo artigo publicado: As inovações que transformam o fluxo de informação',
      publisher: isPodcast ? 'Tech Podcast Hub' : 'Jornal Digital',
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
    super.dispose();
  }
}
