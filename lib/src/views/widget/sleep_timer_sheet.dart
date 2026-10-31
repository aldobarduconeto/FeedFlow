import 'package:flutter/material.dart';
import '../../services/podcast_player_service.dart';
import 'colors.dart';
import 'liquid_container.dart';

Future<void> showSleepTimerSheet(
  BuildContext context,
  PodcastPlayerService player,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _SleepTimerSheet(player: player),
  );
}

class _SleepTimerSheet extends StatelessWidget {
  final PodcastPlayerService player;

  const _SleepTimerSheet({required this.player});

  String _formatTimer(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LiquidContainer(
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          backgroundColor: FeedFlowColors.surfaceElevated.withValues(alpha: 0.88),
          blurSigma: 24,
          child: AnimatedBuilder(
            animation: player,
            builder: (context, _) {
              final active = player.isSleepTimerActive;
              final remaining = player.sleepTimerRemaining;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: FeedFlowColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.bedtime_rounded,
                          color: FeedFlowColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Temporizador de Sono',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: FeedFlowColors.textPrimary,
                              ),
                            ),
                            Text(
                              active && remaining != null
                                  ? 'Desliga em ${_formatTimer(remaining)}'
                                  : 'Pausa o áudio suavemente após o tempo',
                              style: TextStyle(
                                fontSize: 12,
                                color: active
                                    ? FeedFlowColors.primary
                                    : FeedFlowColors.textSecondary,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (active)
                        TextButton(
                          onPressed: () {
                            player.cancelSleepTimer();
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: FeedFlowColors.error,
                          ),
                          child: const Text('Desativar'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final minutes in [15, 30, 45, 60])
                        _timerChip(
                          context,
                          label: '$minutes minutos',
                          duration: Duration(minutes: minutes),
                          isSelected: active &&
                              remaining != null &&
                              (remaining.inMinutes - minutes).abs() <= 1,
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _timerChip(
    BuildContext context, {
    required String label,
    required Duration duration,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        player.setSleepTimer(duration);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? FeedFlowColors.primary.withValues(alpha: 0.18)
              : FeedFlowColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? FeedFlowColors.primary
                : FeedFlowColors.divider.withValues(alpha: 0.6),
            width: isSelected ? 1.0 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 15,
              color: isSelected
                  ? FeedFlowColors.primary
                  : FeedFlowColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? FeedFlowColors.primary
                    : FeedFlowColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
