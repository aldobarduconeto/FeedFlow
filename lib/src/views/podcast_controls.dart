import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../services/feed_service.dart';
import '../services/podcast_player_service.dart';
import 'podcast_player_page.dart';
import 'widget/colors.dart';

class PodcastPlayButton extends StatelessWidget {
  PodcastPlayButton({
    required this.item,
    required this.player,
    this.onPlay,
    super.key,
  });

  final FeedItem item;
  final PodcastPlayerService player;
  final Future<void> Function()? onPlay;

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
                    await onPlay?.call();
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
              ? SizedBox(
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
  PodcastDownloadButton({
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
                        SnackBar(
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
              ? SizedBox(
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
  PodcastNowPlayingBar({required this.player, this.feedService, super.key});

  final PodcastPlayerService player;
  final FeedService? feedService;

  void _openFullScreen(BuildContext context) {
    if (feedService == null) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PodcastPlayerPage(player: player, feedService: feedService!),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final begin = Offset(0.0, 1.0);
          final end = Offset.zero;
          final curve = Curves.easeOutCubic;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final item = player.currentItem;
        if (item == null) return SizedBox.shrink();

        final totalMilliseconds =
            player.duration?.inMilliseconds.toDouble() ??
            item.audioDuration?.inMilliseconds.toDouble() ??
            0;
        final currentMilliseconds = player.position.inMilliseconds
            .toDouble()
            .clamp(0, totalMilliseconds > 0 ? totalMilliseconds : 1)
            .toDouble();
        final progressFraction = totalMilliseconds > 0
            ? (currentMilliseconds / totalMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        return Material(
          color: FeedFlowColors.surfaceElevated,
          child: InkWell(
            onTap: feedService != null ? () => _openFullScreen(context) : null,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Linear progress bar at top of mini bar
                  LinearProgressIndicator(
                    value: progressFraction,
                    minHeight: 2.5,
                    backgroundColor: FeedFlowColors.surfaceHighlight.withValues(
                      alpha: 0.5,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      FeedFlowColors.secondary,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, 8, 8, 8),
                    child: Row(
                      children: [
                        // Episode Artwork thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 44,
                            height: 44,
                            color: FeedFlowColors.surfaceHighlight,
                            child: item.hasImage
                                ? Image.network(
                                    item.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                          Icons.podcasts_rounded,
                                          color: FeedFlowColors.secondary,
                                          size: 22,
                                        ),
                                  )
                                : Icon(
                                    Icons.podcasts_rounded,
                                    color: FeedFlowColors.secondary,
                                    size: 22,
                                  ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // Title and Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: FeedFlowColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    _formatDuration(player.position),
                                    style: TextStyle(
                                      color: FeedFlowColors.secondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    ' • Toque para tela cheia',
                                    style: TextStyle(
                                      color: FeedFlowColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Quick 30s skip
                        IconButton(
                          tooltip: 'Avançar 30s',
                          visualDensity: VisualDensity.compact,
                          iconSize: 22,
                          color: FeedFlowColors.textSecondary,
                          onPressed: player.isLoading
                              ? null
                              : () => player.skipForward(),
                          icon: Icon(Icons.forward_30_rounded),
                        ),
                        // Play/Pause button
                        if (player.isLoading)
                          Padding(
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
                            visualDensity: VisualDensity.compact,
                            color: FeedFlowColors.textPrimary,
                            iconSize: 28,
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
                        // Expand Full Screen icon
                        if (feedService != null)
                          IconButton(
                            tooltip: 'Expandir para tela cheia',
                            visualDensity: VisualDensity.compact,
                            iconSize: 20,
                            color: FeedFlowColors.textSecondary,
                            onPressed: () => _openFullScreen(context),
                            icon: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 26,
                            ),
                          ),
                      ],
                    ),
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
