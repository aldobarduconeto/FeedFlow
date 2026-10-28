import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../models/feed_source.dart';
import '../services/feed_service.dart';
import '../services/podcast_player_service.dart';
import 'widget/colors.dart';
import 'widget/cover_background.dart';
import 'podcast_queue.dart';
import 'podcast_chapters.dart';

class PodcastPlayerPage extends StatelessWidget {
  PodcastPlayerPage({
    required this.player,
    required this.feedService,
    this.source,
    super.key,
  });

  final PodcastPlayerService player;
  final FeedService feedService;
  final FeedSource? source;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([player, feedService]),
      builder: (context, _) {
        final item = player.currentItem;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: Text(
                'Nenhum episódio em reprodução no momento.',
                style: TextStyle(color: FeedFlowColors.textSecondary),
              ),
            ),
          );
        }

        final resolvedSource =
            (source?.id == item.feedId ? source : null) ??
            feedService.sources.cast<FeedSource?>().firstWhere(
              (s) => s?.id == item.feedId,
              orElse: () => null,
            );

        final totalMilliseconds =
            player.duration?.inMilliseconds.toDouble() ??
            item.audioDuration?.inMilliseconds.toDouble() ??
            0;
        final currentMilliseconds = player.position.inMilliseconds
            .toDouble()
            .clamp(0, totalMilliseconds > 0 ? totalMilliseconds : 1)
            .toDouble();

        final isDownloaded = item.downloadedAudioPath != null;
        final isDownloading = feedService.downloadingItems.contains(item.id);

        return Scaffold(
          body: CoverBackground(
            imageUrl: item.imageUrl,
            child: SafeArea(
              child: Column(
                children: [
                  // Top Navigation Bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Minimizar reprodutor',
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 32,
                            color: FeedFlowColors.textPrimary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'TOCANDO AGORA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.6,
                                  color: FeedFlowColors.secondary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                resolvedSource?.title ?? 'Podcast',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: FeedFlowColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: item.isFavorite
                              ? 'Remover dos favoritos'
                              : 'Favoritar episódio',
                          icon: Icon(
                            item.isFavorite
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: item.isFavorite
                                ? FeedFlowColors.secondary
                                : FeedFlowColors.textSecondary,
                          ),
                          onPressed: () => feedService.toggleFavorite(item),
                        ),
                      ],
                    ),
                  ),

                  // Main Player Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 580),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: 12),
                              // Album Artwork
                              _ArtworkView(item: item),
                              SizedBox(height: 28),

                              // Episode Title and Source
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: FeedFlowColors.textPrimary,
                                            height: 1.25,
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          [
                                            if (resolvedSource != null)
                                              resolvedSource.title,
                                            if (item.publishedAt != null)
                                              '${item.publishedAt!.day}/${item.publishedAt!.month}/${item.publishedAt!.year}',
                                          ].join(' • '),
                                          style: TextStyle(
                                            color: FeedFlowColors.textSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  // Download Button
                                  IconButton.filledTonal(
                                    tooltip: isDownloaded
                                        ? 'Disponível offline'
                                        : 'Baixar episódio',
                                    style: IconButton.styleFrom(
                                      backgroundColor: isDownloaded
                                          ? FeedFlowColors.success.withValues(
                                              alpha: 0.2,
                                            )
                                          : FeedFlowColors.surfaceElevated,
                                      foregroundColor: isDownloaded
                                          ? FeedFlowColors.success
                                          : FeedFlowColors.textSecondary,
                                    ),
                                    onPressed: isDownloading || isDownloaded
                                        ? null
                                        : () async {
                                            try {
                                              await feedService.downloadPodcast(
                                                item,
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Episódio salvo no dispositivo.',
                                                        ),
                                                      ),
                                                    );
                                              }
                                            } catch (error) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Falha no download: $error',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                    icon: isDownloading
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(
                                            isDownloaded
                                                ? Icons.check_circle_rounded
                                                : Icons.download_rounded,
                                          ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 20),

                              // Progress Slider
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: RoundSliderThumbShape(
                                    enabledThumbRadius: 7,
                                  ),
                                  overlayShape: RoundSliderOverlayShape(
                                    overlayRadius: 16,
                                  ),
                                  activeTrackColor: FeedFlowColors.secondary,
                                  inactiveTrackColor:
                                      FeedFlowColors.surfaceHighlight,
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  value: currentMilliseconds,
                                  max: totalMilliseconds > 0
                                      ? totalMilliseconds
                                      : 1,
                                  onChanged:
                                      totalMilliseconds <= 0 || player.isLoading
                                      ? null
                                      : (value) {
                                          player.seek(
                                            Duration(
                                              milliseconds: value.round(),
                                            ),
                                          );
                                        },
                                ),
                              ),

                              // Time Indicators
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(player.position),
                                      style: TextStyle(
                                        color: FeedFlowColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (isDownloaded)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: FeedFlowColors.success
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.offline_pin_rounded,
                                              size: 13,
                                              color: FeedFlowColors.success,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Offline',
                                              style: TextStyle(
                                                color: FeedFlowColors.success,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Text(
                                      _formatDuration(
                                        player.duration ?? item.audioDuration,
                                      ),
                                      style: TextStyle(
                                        color: FeedFlowColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 20),

                              // Controls Row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Playback Speed Button
                                  _SpeedButton(
                                    currentSpeed: player.playbackSpeed,
                                    onSelectSpeed: (speed) =>
                                        player.setPlaybackSpeed(speed),
                                  ),

                                  // Skip Backward 10s
                                  IconButton(
                                    tooltip: 'Voltar 10 segundos',
                                    iconSize: 36,
                                    color: FeedFlowColors.textPrimary,
                                    onPressed: player.isLoading
                                        ? null
                                        : () => player.skipBackward(
                                            Duration(seconds: 10),
                                          ),
                                    icon: Icon(Icons.replay_10_rounded),
                                  ),

                                  // Play / Pause Central Button
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          FeedFlowColors.primary,
                                          FeedFlowColors.secondary,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: FeedFlowColors.primary
                                              .withValues(alpha: 0.35),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        customBorder: CircleBorder(),
                                        onTap: () async {
                                          try {
                                            await player.toggle(item);
                                          } catch (error) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Falha ao reproduzir áudio: $error',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: Center(
                                          child: player.isLoading
                                              ? SizedBox(
                                                  width: 28,
                                                  height: 28,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 3,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                )
                                              : Icon(
                                                  player.isPlaying
                                                      ? Icons.pause_rounded
                                                      : player.playerState ==
                                                            PlayerState
                                                                .completed
                                                      ? Icons.replay_rounded
                                                      : Icons
                                                            .play_arrow_rounded,
                                                  size: 40,
                                                  color: Colors.white,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Skip Forward 30s
                                  IconButton(
                                    tooltip: 'Avançar 30 segundos',
                                    iconSize: 36,
                                    color: FeedFlowColors.textPrimary,
                                    onPressed: player.isLoading
                                        ? null
                                        : () => player.skipForward(),
                                    icon: Icon(Icons.forward_30_rounded),
                                  ),

                                  // Audio Source Indicator
                                  IconButton(
                                    tooltip: 'Informações do áudio',
                                    iconSize: 26,
                                    color: FeedFlowColors.textSecondary,
                                    onPressed: () {
                                      _showAudioInfo(
                                        context,
                                        item,
                                        resolvedSource,
                                      );
                                    },
                                    icon: Icon(Icons.info_outline_rounded),
                                  ),
                                ],
                              ),

                              if (player.error case final error?) ...[
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: FeedFlowColors.error.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: FeedFlowColors.error.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        color: FeedFlowColors.error,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          error,
                                          style: TextStyle(
                                            color: FeedFlowColors.error,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              SizedBox(height: 28),

                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Aprimorar diálogo'),
                                subtitle: Text(
                                  player.supportsDialogue
                                      ? 'Realça a voz e reduz graves durante a reprodução.'
                                      : 'Esta fonte não permite aplicar o efeito neste dispositivo.',
                                ),
                                value: player.enhanceDialogue,
                                onChanged:
                                    !player.supportsDialogue || player.isLoading
                                    ? null
                                    : (enabled) async {
                                        try {
                                          await player.setEnhanceDialogue(
                                            enabled,
                                          );
                                        } catch (error) {
                                          if (context.mounted)
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Não foi possível aplicar o efeito: $error',
                                                ),
                                              ),
                                            );
                                        }
                                      },
                              ),
                              PodcastChapters(item: item, player: player),
                              SizedBox(height: 24),
                              PodcastQueueSection(player: player),
                              SizedBox(height: 24),

                              // Episode Notes / Description Card
                              if (item.description != null ||
                                  item.content != null)
                                _EpisodeDescriptionCard(item: item),
                            ],
                          ),
                        ),
                      ),
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

  void _showAudioInfo(BuildContext context, FeedItem item, FeedSource? source) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FeedFlowColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.podcasts_rounded, color: FeedFlowColors.secondary),
                  SizedBox(width: 12),
                  Text(
                    'Detalhes do Episódio',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(bottomSheetContext).pop(),
                  ),
                ],
              ),
              Divider(height: 24),
              _DetailRow(
                label: 'Programa',
                value: source?.title ?? 'Desconhecido',
              ),
              if (item.author != null && item.author!.isNotEmpty)
                _DetailRow(label: 'Autor / Apresentador', value: item.author!),
              _DetailRow(
                label: 'Status de Reprodução',
                value: item.downloadedAudioPath != null
                    ? 'Armazenado localmente (offline)'
                    : 'Transmissão em fluxo (online)',
              ),
              if (item.audioUrl != null)
                _DetailRow(
                  label: 'URL do Áudio',
                  value: item.audioUrl!,
                  maxLines: 2,
                ),
            ],
          ),
        ),
      ),
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

class _ArtworkView extends StatelessWidget {
  _ArtworkView({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final artworkDimension = (size.width * 0.72).clamp(200.0, 320.0);

    return Container(
      width: artworkDimension,
      height: artworkDimension,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: FeedFlowColors.primary.withValues(alpha: 0.28),
            blurRadius: 36,
            spreadRadius: 4,
            offset: Offset(0, 14),
          ),
          BoxShadow(
            color: Color(0x60000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: item.hasImage
            ? Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _ArtworkPlaceholder(),
              )
            : _ArtworkPlaceholder(),
      ),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E3267), Color(0xFF1E2442), Color(0xFF111827)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.podcasts_rounded,
          size: 72,
          color: FeedFlowColors.secondary,
        ),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  _SpeedButton({required this.currentSpeed, required this.onSelectSpeed});
  final double currentSpeed;
  final Future<void> Function(double) onSelectSpeed;
  @override
  Widget build(BuildContext context) => TextButton(
    child: Text('${currentSpeed.toStringAsFixed(2)}x'),
    onPressed: () async {
      var selected = currentSpeed;
      final speed = await showDialog<double>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text('Velocidade deste podcast'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${selected.toStringAsFixed(2)}x'),
                Slider(
                  value: selected,
                  min: 0.8,
                  max: 2,
                  divisions: 24,
                  onChanged: (value) => update(() => selected = value),
                ),
                Text('A preferência será lembrada para este programa.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: Text('Aplicar'),
              ),
            ],
          ),
        ),
      );
      if (speed == null) return;
      try {
        await onSelectSpeed(speed);
      } catch (error) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Não foi possível alterar a velocidade: $error'),
            ),
          );
      }
    },
  );
}

class _EpisodeDescriptionCard extends StatefulWidget {
  _EpisodeDescriptionCard({required this.item});

  final FeedItem item;

  @override
  State<_EpisodeDescriptionCard> createState() =>
      _EpisodeDescriptionCardState();
}

class _EpisodeDescriptionCardState extends State<_EpisodeDescriptionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = _cleanHtml(
      widget.item.content ?? widget.item.description ?? '',
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FeedFlowColors.surfaceElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: FeedFlowColors.divider.withValues(alpha: 0.7),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: 18,
                    color: FeedFlowColors.secondary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Sobre o episódio',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: FeedFlowColors.textPrimary,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: FeedFlowColors.textSecondary,
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                text.isEmpty ? 'Sem descrição disponível.' : text,
                maxLines: _expanded ? null : 3,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(
                  color: FeedFlowColors.textSecondary,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              if (!_expanded && text.length > 150)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Toque para ler mais',
                    style: TextStyle(
                      color: FeedFlowColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _cleanHtml(String html) {
    var text = html.replaceAll(
      RegExp(r'<(script|style)\b[^>]*>[\s\S]*?</\1\s*>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}

class _DetailRow extends StatelessWidget {
  _DetailRow({required this.label, required this.value, this.maxLines = 1});

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: FeedFlowColors.textDisabled,
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: FeedFlowColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
