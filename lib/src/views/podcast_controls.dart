import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../services/feed_service.dart';
import '../services/podcast_player_service.dart';
import 'widget/colors.dart';

class PodcastPlayButton extends StatelessWidget {
  const PodcastPlayButton({
    required this.item,
    required this.player,
    super.key,
  });

  final FeedItem item;
  final PodcastPlayerService player;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final isCurrent = player.isCurrent(item);
        final isLoading = isCurrent && player.isLoading;
        final isPlaying = isCurrent && player.isPlaying;

        return IconButton.filledTonal(
          tooltip: isPlaying ? 'Pausar episódio' : 'Ouvir episódio',
          onPressed: isLoading
              ? null
              : () async {
                  try {
                    await player.toggle(item);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Falha ao reproduzir o podcast: $error',
                          ),
                        ),
                      );
                    }
                  }
                },
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
        );
      },
    );
  }
}

class PodcastDownloadButton extends StatelessWidget {
  const PodcastDownloadButton({
    required this.item,
    required this.feedService,
    super.key,
  });

  final FeedItem item;
  final FeedService feedService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: feedService,
      builder: (context, _) {
        final isDownloading = feedService.downloadingItems.contains(item.id);
        final isDownloaded = item.downloadedAudioPath != null;
        return IconButton(
          tooltip: isDownloaded
              ? 'Disponível offline'
              : 'Baixar para ouvir offline',
          onPressed: isDownloading || isDownloaded
              ? null
              : () async {
                  try {
                    await feedService.downloadPodcast(item);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Podcast salvo neste dispositivo para ouvir offline.',
                          ),
                        ),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Falha ao baixar o podcast: $error'),
                        ),
                      );
                    }
                  }
                },
          icon: isDownloading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  isDownloaded
                      ? Icons.download_done_rounded
                      : Icons.download_rounded,
                ),
        );
      },
    );
  }
}

class PodcastNowPlayingBar extends StatelessWidget {
  const PodcastNowPlayingBar({required this.player, super.key});

  final PodcastPlayerService player;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final item = player.currentItem;
        if (item == null) return const SizedBox.shrink();

        final totalMilliseconds =
            player.duration?.inMilliseconds.toDouble() ?? 0;
        final currentMilliseconds = player.position.inMilliseconds
            .toDouble()
            .clamp(0, totalMilliseconds)
            .toDouble();

        return Material(
          color: FeedFlowColors.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.podcasts_rounded,
                        color: FeedFlowColors.secondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOCANDO AGORA',
                              style: TextStyle(
                                color: FeedFlowColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (player.isLoading)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        IconButton(
                          tooltip: player.isPlaying
                              ? 'Pausar episódio'
                              : 'Continuar episódio',
                          onPressed: () async {
                            try {
                              await player.toggle(item);
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Falha ao controlar o podcast: $error',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          icon: Icon(
                            player.isPlaying
                                ? Icons.pause_rounded
                                : player.playerState == PlayerState.completed
                                ? Icons.replay_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                    ],
                  ),
                  if (player.error case final error?)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error,
                        style: const TextStyle(
                          color: FeedFlowColors.error,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Row(
                    children: [
                      Text(
                        _formatDuration(player.position),
                        style: const TextStyle(
                          color: FeedFlowColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: currentMilliseconds,
                          max: totalMilliseconds > 0 ? totalMilliseconds : 1,
                          onChanged: totalMilliseconds <= 0 || player.isLoading
                              ? null
                              : (value) {
                                  player.seek(
                                    Duration(milliseconds: value.round()),
                                  );
                                },
                        ),
                      ),
                      Text(
                        _formatDuration(player.duration ?? item.audioDuration),
                        style: const TextStyle(
                          color: FeedFlowColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}
