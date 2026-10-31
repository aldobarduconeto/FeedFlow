import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/feed.dart';
import '../../models/feed_source.dart';
import 'colors.dart';

class PodcastSubscriptionsCarousel extends StatefulWidget {
  const PodcastSubscriptionsCarousel({
    required this.sources,
    required this.episodes,
    required this.onOpen,
    required this.onManage,
    this.selectedSourceId,
    super.key,
  });
  final List<FeedSource> sources;
  final List<FeedItem> episodes;
  final ValueChanged<FeedSource> onOpen;
  final VoidCallback onManage;
  final String? selectedSourceId;

  @override
  State<PodcastSubscriptionsCarousel> createState() =>
      _PodcastSubscriptionsCarouselState();
}

class _PodcastSubscriptionsCarouselState
    extends State<PodcastSubscriptionsCarousel> {
  final _scroll = ScrollController();
  bool _canBack = false;
  bool _canForward = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateControls);
  }

  @override
  void dispose() {
    _scroll.removeListener(_updateControls);
    _scroll.dispose();
    super.dispose();
  }

  void _updateControls() {
    if (!mounted ||
        !_scroll.hasClients ||
        !_scroll.position.hasContentDimensions)
      return;
    final position = _scroll.position;
    final back = position.pixels > position.minScrollExtent + 1;
    final forward = position.pixels < position.maxScrollExtent - 1;
    if (back != _canBack || forward != _canForward) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
  }

  void _move(int direction) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final next =
        (position.pixels + position.viewportDimension * 0.85 * direction)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    _scroll.animateTo(
      next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  String _updated(DateTime? date) {
    if (date == null) return 'Sem data de publicação';
    final elapsed = DateTime.now().difference(date);
    if (elapsed.isNegative)
      return 'Publicado em ${date.day}/${date.month}/${date.year}';
    if (elapsed.inMinutes < 1) return 'Atualizado agora';
    if (elapsed.inHours < 1) return 'Atualizado há ${elapsed.inMinutes} min';
    if (elapsed.inDays < 1) return 'Atualizado há ${elapsed.inHours} h';
    if (elapsed.inDays < 30) return 'Atualizado há ${elapsed.inDays} d';
    return 'Publicado em ${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final latest = <String, DateTime>{};
    final covers = <String, String>{};
    for (final item in widget.episodes) {
      final date = item.publishedAt;
      final previous = latest[item.feedId];
      if (date != null && (previous == null || date.isAfter(previous)))
        latest[item.feedId] = date;
      if (item.hasImage) covers.putIfAbsent(item.feedId, () => item.imageUrl!);
    }
    final sources = List<FeedSource>.of(widget.sources)
      ..sort((a, b) {
        final aDate = latest[a.id];
        final bDate = latest[b.id];
        if (aDate == null && bDate != null) return 1;
        if (aDate != null && bDate == null) return -1;
        final byDate = aDate == null ? 0 : bDate!.compareTo(aDate);
        return byDate != 0
            ? byDate
            : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
      },
      child: Focus(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Suas inscrições',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: FeedFlowColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Gerenciar inscrições (${sources.length})',
                  onPressed: widget.onManage,
                  icon: const Icon(Icons.tune_rounded),
                ),
                IconButton.filledTonal(
                  tooltip: 'Ver inscrições anteriores',
                  onPressed: _canBack ? () => _move(-1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Ver mais inscrições',
                  onPressed: _canForward ? () => _move(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${sources.length} ${sources.length == 1 ? 'programa seguido' : 'programas seguidos'} · Atualizados recentemente',
              style: TextStyle(
                fontSize: 12,
                color: FeedFlowColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < 600
                    ? (constraints.maxWidth * 0.58).clamp(150.0, 220.0)
                    : 200.0;
                final scaler = MediaQuery.textScalerOf(context);
                final height =
                    width +
                    scaler.scale(15) * 2.5 +
                    scaler.scale(12) * 1.5 +
                    42;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _updateControls(),
                );
                return NotificationListener<ScrollMetricsNotification>(
                  onNotification: (_) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _updateControls(),
                    );
                    return false;
                  },
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                        PointerDeviceKind.invertedStylus,
                      },
                    ),
                    child: Scrollbar(
                      controller: _scroll,
                      thumbVisibility: _canBack || _canForward,
                      interactive: true,
                      child: SizedBox(
                        height: height,
                        child: ListView.separated(
                          controller: _scroll,
                          primary: false,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(bottom: 18, top: 2),
                          itemCount: sources.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            final source = sources[index];
                            final cover = source.imageUrl ?? covers[source.id];
                            final selected =
                                widget.selectedSourceId == source.id;
                            return SizedBox(
                              key: ValueKey(source.id),
                              width: width,
                              child: Semantics(
                                button: true,
                                label: 'Abrir podcast ${source.title}',
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => widget.onOpen(source),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: width,
                                          height: width,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            border: Border.all(
                                              width: selected ? 2 : 1,
                                              color: selected
                                                  ? FeedFlowColors.secondary
                                                  : FeedFlowColors.divider,
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: cover == null
                                              ? _placeholder()
                                              : Image.network(
                                                  cover,
                                                  fit: BoxFit.cover,
                                                  semanticLabel:
                                                      'Capa de ${source.title}',
                                                  cacheWidth:
                                                      (width *
                                                              MediaQuery.devicePixelRatioOf(
                                                                context,
                                                              ))
                                                          .round(),
                                                  errorBuilder: (_, _, _) =>
                                                      _placeholder(),
                                                ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          source.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            height: 1.25,
                                            color: FeedFlowColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          _updated(latest[source.id]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: FeedFlowColors.textSecondary,
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
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          FeedFlowColors.primary.withValues(alpha: 0.25),
          FeedFlowColors.surfaceElevated,
        ],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.podcasts_rounded,
        size: 50,
        color: FeedFlowColors.secondary,
      ),
    ),
  );
}
