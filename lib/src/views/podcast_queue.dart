import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../services/podcast_player_service.dart';
import 'widget/colors.dart';

class PodcastQueueButton extends StatelessWidget {
  PodcastQueueButton({required this.item, required this.player, super.key});
  final FeedItem item;
  final PodcastPlayerService player;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Adicionar à fila',
    icon: Icon(Icons.playlist_add_rounded),
    enabled: item.hasAudio && !player.isCurrent(item),
    onSelected: (value) {
      player.enqueue(item, next: value == 'next');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value == 'next'
                ? 'Episódio será reproduzido a seguir.'
                : 'Episódio adicionado ao fim da fila.',
          ),
        ),
      );
    },
    itemBuilder: (_) => [
      PopupMenuItem(value: 'next', child: Text('Reproduzir a seguir')),
      PopupMenuItem(value: 'last', child: Text('Adicionar ao fim da fila')),
    ],
  );
}

class PodcastQueueSection extends StatelessWidget {
  PodcastQueueSection({required this.player, super.key});
  final PodcastPlayerService player;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: player,
    builder: (context, _) {
      final queue = player.queue;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.queue_music_rounded),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'A seguir (${queue.length})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              if (queue.isNotEmpty)
                TextButton(onPressed: player.clearQueue, child: Text('Limpar')),
            ],
          ),
          if (queue.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Sua fila está vazia. Adicione episódios pelo menu de fila.',
                style: TextStyle(color: FeedFlowColors.textSecondary),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: queue.length,
              onReorderItem: player.reorderQueue,
              itemBuilder: (context, index) {
                final item = queue[index];
                return ListTile(
                  key: ValueKey(item.id),
                  contentPadding: EdgeInsets.zero,
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: Tooltip(
                      message: 'Arraste para ordenar',
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle_rounded),
                      ),
                    ),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'Remover da fila',
                    onPressed: () => player.removeFromQueue(item.id),
                    icon: Icon(Icons.close_rounded),
                  ),
                );
              },
            ),
          if (queue.isNotEmpty)
            TextButton.icon(
              onPressed: player.isLoading
                  ? null
                  : () async {
                      try {
                        await player.playNext();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                player.error ?? 'Falha ao reproduzir episódio.',
                              ),
                            ),
                          );
                        }
                      }
                    },
              icon: Icon(Icons.skip_next_rounded),
              label: Text('Reproduzir próximo'),
            ),
        ],
      );
    },
  );
}
