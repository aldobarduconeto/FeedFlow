import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../models/feed_notification.dart';
import '../services/feed_service.dart';
import '../services/notification_service.dart';
import '../services/podcast_player_service.dart';
import 'article_reader.dart';
import 'podcast_player_page.dart';
import 'podcast_show_page.dart';
import 'widget/colors.dart';

class NotificationsPage extends StatefulWidget {
  final NotificationService notificationService;
  final FeedService feedService;
  final PodcastPlayerService podcastPlayer;

  const NotificationsPage({
    super.key,
    required this.notificationService,
    required this.feedService,
    required this.podcastPlayer,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String _filter = 'all'; // 'all', 'articles', 'podcasts'

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Agora mesmo';
    } else if (difference.inMinutes < 60) {
      return 'Há ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Há ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Há ${difference.inDays} dias';
    } else {
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}';
    }
  }

  void _openItem(FeedNotification notification) async {
    await widget.notificationService.markAsRead(notification.id);

    // Encontra o item correspondente no feedService
    final items = widget.feedService.items;
    final itemMatches = items.where((i) => i.id == notification.itemId);
    final FeedItem? item = itemMatches.isNotEmpty ? itemMatches.first : null;

    final sources = widget.feedService.sources;
    final sourceMatches = sources.where((s) => s.id == notification.feedId);
    final source = sourceMatches.isNotEmpty ? sourceMatches.first : null;

    if (!mounted) return;

    if (item != null) {
      if (item.isPodcast) {
        await widget.podcastPlayer.play(item);
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PodcastPlayerPage(
              player: widget.podcastPlayer,
              feedService: widget.feedService,
            ),
          ),
        );
      } else {
        if (!item.isRead) await widget.feedService.toggleRead(item);
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ArticleReaderPage(
              item: item,
              source: source,
              feedService: widget.feedService,
            ),
          ),
        );
      }
    } else if (source != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PodcastShowPage(
            source: source,
            feedService: widget.feedService,
            player: widget.podcastPlayer,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Item da notificação não está mais disponível no feed.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FeedFlowColors.background,
      appBar: AppBar(
        title: Text(
          'Notificações',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: FeedFlowColors.textPrimary,
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: widget.notificationService,
            builder: (context, _) {
              final unread = widget.notificationService.unreadCount;
              final total = widget.notificationService.notifications.length;
              if (total == 0) return const SizedBox.shrink();

              return PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: FeedFlowColors.textSecondary,
                ),
                tooltip: 'Mais opções',
                offset: const Offset(0, 42),
                elevation: 10,
                onSelected: (value) {
                  if (value == 'read_all') {
                    widget.notificationService.markAllAsRead();
                  } else if (value == 'clear_all') {
                    widget.notificationService.clearAll();
                  }
                },
                itemBuilder: (context) => [
                  if (unread > 0)
                    PopupMenuItem(
                      value: 'read_all',
                      child: Row(
                        children: [
                          Icon(
                            Icons.done_all_rounded,
                            size: 18,
                            color: FeedFlowColors.primary,
                          ),
                          const SizedBox(width: 10),
                          const Text('Marcar todas como lidas'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_sweep_outlined,
                          size: 18,
                          color: FeedFlowColors.error,
                        ),
                        const SizedBox(width: 10),
                        const Text('Limpar histórico'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.notificationService,
        builder: (context, _) {
          final allNotifications = widget.notificationService.notifications;
          final filtered = allNotifications.where((n) {
            if (_filter == 'articles') return !n.isPodcast;
            if (_filter == 'podcasts') return n.isPodcast;
            return true;
          }).toList();

          if (allNotifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: FeedFlowColors.surfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 36,
                        color: FeedFlowColors.textDisabled,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tudo em dia',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: FeedFlowColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quando novas notícias e episódios de podcasts forem publicados pelas suas fontes, eles aparecerão aqui com o título e a publisher.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: FeedFlowColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () {
                        widget.notificationService.sendTestNotification(
                          isPodcast: false,
                        );
                      },
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Enviar notificação de teste'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Filtros minimalistas
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    _filterChip(
                      'Todas',
                      'all',
                      allNotifications.length,
                      icon: Icons.notifications_active_outlined,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      'Notícias',
                      'articles',
                      allNotifications.where((n) => !n.isPodcast).length,
                      icon: Icons.newspaper_rounded,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      'Podcasts',
                      'podcasts',
                      allNotifications.where((n) => n.isPodcast).length,
                      icon: Icons.podcasts_rounded,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma notificação nesta categoria.',
                          style: TextStyle(
                            color: FeedFlowColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 68),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isPodcast = item.isPodcast;
                          final accent = isPodcast
                              ? FeedFlowColors.primary
                              : FeedFlowColors.secondary;

                          return Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: FeedFlowColors.error.withValues(alpha: 0.15),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: FeedFlowColors.error,
                              ),
                            ),
                            onDismissed: (_) {
                              widget.notificationService.removeNotification(item.id);
                            },
                            child: Material(
                              color: item.isRead
                                  ? Colors.transparent
                                  : accent.withValues(alpha: 0.04),
                              child: InkWell(
                                onTap: () => _openItem(item),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Indicador de não lida + Ícone
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: FeedFlowColors.surfaceElevated,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: FeedFlowColors.divider,
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Icon(
                                              isPodcast
                                                  ? Icons.podcasts_rounded
                                                  : Icons.newspaper_rounded,
                                              color: accent,
                                              size: 20,
                                            ),
                                          ),
                                          if (!item.isRead)
                                            Positioned(
                                              top: -2,
                                              right: -2,
                                              child: Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: accent,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: FeedFlowColors.background,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                      // Título e Publisher (Subtítulo)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.publisher,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: accent,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  _formatTime(item.publishedAt),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: FeedFlowColors
                                                        .textDisabled,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: item.isRead
                                                    ? FontWeight.w500
                                                    : FontWeight.w600,
                                                color: item.isRead
                                                    ? FeedFlowColors
                                                        .textSecondary
                                                    : FeedFlowColors.textPrimary,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(
    String label,
    String value,
    int count, {
    required IconData icon,
  }) {
    final selected = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? FeedFlowColors.primary.withValues(alpha: 0.15)
              : FeedFlowColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? FeedFlowColors.primary
                : FeedFlowColors.divider.withValues(alpha: 0.7),
            width: selected ? 1.0 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? FeedFlowColors.primary
                  : FeedFlowColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? FeedFlowColors.primary
                    : FeedFlowColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? FeedFlowColors.primary.withValues(alpha: 0.25)
                    : FeedFlowColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? FeedFlowColors.primary
                      : FeedFlowColors.textDisabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
