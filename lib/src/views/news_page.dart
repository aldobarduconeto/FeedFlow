import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../models/feed_source.dart';
import '../services/feed_service.dart';
import '../services/podcast_player_service.dart';
import 'article_reader.dart';
import 'widget/add_feed_dialog.dart';
import 'widget/colors.dart';
import 'widget/feed_content_card.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({
    required this.feeds,
    required this.player,
    required this.onDiscover,
    required this.onRefresh,
    super.key,
  });
  final FeedService feeds;
  final PodcastPlayerService player;
  final VoidCallback onDiscover;
  final Future<void> Function() onRefresh;
  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final _search = TextEditingController();
  String _filter = 'all';
  String? _sourceId;
  String? _categoryFilter;
  static const _labels = {
    'all': 'Mais recentes',
    'unread': 'Não lidas',
    'saved': 'Salvas',
    'progress': 'Continuar leitura',
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FeedSource> get _sources {
    final ids = widget.feeds.items
        .where((item) => !item.isPodcast)
        .map((item) => item.feedId)
        .toSet();
    return widget.feeds.sources
        .where(
          (source) =>
              ids.contains(source.id) ||
              (!source.isPodcast &&
                  source.category.toLowerCase() != 'podcasts'),
        )
        .toList();
  }

  Set<String> get _availableCategories {
    return _sources
        .map((s) => s.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet();
  }

  Future<void> _open(FeedItem item) async {
    try {
      if (!item.isRead) await widget.feeds.toggleRead(item);
      if (!mounted) return;
      final matches = widget.feeds.sources.where(
        (source) => source.id == item.feedId,
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ArticleReaderPage(
            item: item,
            source: matches.isEmpty ? null : matches.first,
            feedService: widget.feeds,
          ),
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir a notícia: $error')),
        );
    }
  }

  void _manageSources() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: AnimatedBuilder(
            animation: widget.feeds,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                const Text(
                  'Suas fontes de notícias',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (_sources.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Adicione fontes para começar a receber notícias.',
                    ),
                  ),
                for (final source in _sources)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.rss_feed_rounded,
                      color: FeedFlowColors.secondary,
                    ),
                    title: Text(source.title),
                    subtitle: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: FeedFlowColors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            source.category,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: FeedFlowColors.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• Toque para alterar',
                          style: TextStyle(fontSize: 11, color: FeedFlowColors.textDisabled),
                        ),
                      ],
                    ),
                    onTap: () {
                      showEditCategoryDialog(context, source, widget.feeds);
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Alterar categoria',
                          icon: const Icon(Icons.label_outline_rounded, size: 20),
                          onPressed: () {
                            showEditCategoryDialog(context, source, widget.feeds);
                          },
                        ),
                        IconButton(
                          tooltip: 'Remover ${source.title}',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () async {
                            try {
                              await widget.feeds.removeFeed(source.id);
                              if (mounted && _sourceId == source.id)
                                setState(() => _sourceId = null);
                            } catch (error) {
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Falha ao remover fonte: $error'),
                                  ),
                                );
                            }
                          },
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
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.feeds,
    builder: (context, _) {
      final sources = {
        for (final source in widget.feeds.sources) source.id: source,
      };
      final query = _search.text.trim().toLowerCase();
      final items = widget.feeds.items.where((item) {
        if (item.isPodcast) return false;
        if (_sourceId != null && item.feedId != _sourceId) return false;
        if (_categoryFilter != null &&
            sources[item.feedId]?.category != _categoryFilter) {
          return false;
        }
        if (_filter == 'unread' && item.isRead) return false;
        if (_filter == 'saved' && !item.isFavorite) return false;
        final progress = item.readingProgress ?? 0;
        if (_filter == 'progress' && !(progress > 0 && progress < 1))
          return false;
        return query.isEmpty ||
            '${item.title} ${item.description ?? ''} ${item.author ?? ''} ${sources[item.feedId]?.title ?? ''}'
                .toLowerCase()
                .contains(query);
      }).toList();
      return SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: CustomScrollView(
                key: const PageStorageKey('news-timeline'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Notícias',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.6,
                                        color: FeedFlowColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Suas fontes e leituras em fluxo contínuo',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: FeedFlowColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Gerenciar fontes',
                                onPressed: _manageSources,
                                icon: const Icon(Icons.tune_rounded),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'Adicionar fonte',
                                onPressed: () =>
                                    showAddFeedDialog(context, widget.feeds),
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Buscar nas suas notícias',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Limpar busca',
                                      onPressed: () =>
                                          setState(() => _search.clear()),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              PopupMenuButton<String>(
                                tooltip: 'Filtrar status da notícia',
                                initialValue: _filter,
                                offset: const Offset(0, 42),
                                elevation: 10,
                                onSelected: (value) =>
                                    setState(() => _filter = value),
                                itemBuilder: (_) => _labels.entries
                                    .map(
                                      (entry) => _buildPopupItem(
                                        value: entry.key,
                                        label: entry.value,
                                        isSelected: _filter == entry.key,
                                        icon: entry.key == 'unread'
                                            ? Icons.mark_email_unread_outlined
                                            : entry.key == 'saved'
                                                ? Icons.bookmark_outline_rounded
                                                : entry.key == 'progress'
                                                    ? Icons.auto_stories_outlined
                                                    : Icons.access_time_rounded,
                                      ),
                                    )
                                    .toList(),
                                child: _filterPill(
                                  _labels[_filter]!,
                                  Icons.filter_list_rounded,
                                  isActive: _filter != 'all',
                                ),
                              ),
                              if (_availableCategories.isNotEmpty)
                                PopupMenuButton<String>(
                                  tooltip: 'Filtrar por categoria',
                                  initialValue: _categoryFilter ?? 'all',
                                  offset: const Offset(0, 42),
                                  elevation: 10,
                                  onSelected: (value) => setState(
                                    () => _categoryFilter =
                                        value == 'all' ? null : value,
                                  ),
                                  itemBuilder: (_) => [
                                    _buildPopupItem(
                                      value: 'all',
                                      label: 'Todas as categorias',
                                      isSelected: _categoryFilter == null,
                                      icon: Icons.apps_rounded,
                                    ),
                                    for (final cat in _availableCategories)
                                      _buildPopupItem(
                                        value: cat,
                                        label: cat,
                                        isSelected: _categoryFilter == cat,
                                        icon: Icons.label_outline_rounded,
                                      ),
                                  ],
                                  child: _filterPill(
                                    _categoryFilter ?? 'Categorias',
                                    Icons.category_outlined,
                                    isActive: _categoryFilter != null,
                                  ),
                                ),
                              PopupMenuButton<String>(
                                tooltip: 'Filtrar por fonte',
                                initialValue: _sourceId ?? 'all',
                                offset: const Offset(0, 42),
                                elevation: 10,
                                onSelected: (value) => setState(
                                  () =>
                                      _sourceId = value == 'all' ? null : value,
                                ),
                                itemBuilder: (_) => [
                                  _buildPopupItem(
                                    value: 'all',
                                    label: 'Todas as fontes',
                                    isSelected: _sourceId == null,
                                    icon: Icons.rss_feed_rounded,
                                  ),
                                  for (final source in _sources)
                                    _buildPopupItem(
                                      value: source.id,
                                      label: source.title,
                                      isSelected: _sourceId == source.id,
                                      icon: Icons.radio_button_checked_rounded,
                                    ),
                                ],
                                child: _filterPill(
                                  sources[_sourceId]?.title ??
                                      'Todas as fontes',
                                  Icons.rss_feed_rounded,
                                  isActive: _sourceId != null,
                                ),
                              ),
                              Text(
                                '${items.length} ${items.length == 1 ? 'notícia' : 'notícias'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: FeedFlowColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (widget.feeds.isRefreshing)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: LinearProgressIndicator(),
                            ),
                          if (widget.feeds.startupError != null)
                            _error(widget.feeds.startupError!),
                          for (final error
                              in widget.feeds.refreshErrors.entries)
                            _error(
                              'Falha ao atualizar ${sources[error.key]?.title ?? 'uma fonte'}: ${error.value}',
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 12, 32, 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_stories_outlined,
                              size: 50,
                              color: FeedFlowColors.secondary,
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Seu próximo assunto começa aqui',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              query.isNotEmpty ||
                                      _filter != 'all' ||
                                      _sourceId != null
                                  ? 'Nenhuma notícia para esta seleção. Ajuste os filtros ou a busca.'
                                  : 'Siga fontes no Explorar ou adicione um feed para montar sua leitura.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: FeedFlowColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (query.isNotEmpty ||
                                _filter != 'all' ||
                                _sourceId != null)
                              FilledButton.tonal(
                                onPressed: () => setState(() {
                                  _filter = 'all';
                                  _sourceId = null;
                                  _search.clear();
                                }),
                                child: const Text('Limpar filtros'),
                              )
                            else
                              FilledButton.icon(
                                onPressed: widget.onDiscover,
                                icon: const Icon(Icons.explore_outlined),
                                label: const Text('Explorar fontes'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 22),
                          child: FeedContentCard(
                            key: ValueKey(item.id),
                            item: item,
                            source: sources[item.feedId],
                            feeds: widget.feeds,
                            player: widget.player,
                            onOpen: () => _open(item),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  PopupMenuItem<String> _buildPopupItem({
    required String value,
    required String label,
    required bool isSelected,
    IconData? icon,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 42,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 17,
              color: isSelected
                  ? FeedFlowColors.primary
                  : FeedFlowColors.textSecondary,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? FeedFlowColors.primary
                    : FeedFlowColors.textPrimary,
              ),
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: 16,
              color: FeedFlowColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _filterPill(
    String text,
    IconData icon, {
    bool isActive = false,
  }) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
    decoration: BoxDecoration(
      color: isActive
          ? FeedFlowColors.primary.withValues(alpha: 0.14)
          : FeedFlowColors.surfaceElevated,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isActive
            ? FeedFlowColors.primary.withValues(alpha: 0.8)
            : FeedFlowColors.divider.withValues(alpha: 0.7),
        width: isActive ? 1.0 : 0.8,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isActive ? FeedFlowColors.primary : FeedFlowColors.secondary,
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive
                  ? FeedFlowColors.primary
                  : FeedFlowColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.expand_more_rounded,
          size: 14,
          color: isActive
              ? FeedFlowColors.primary
              : FeedFlowColors.textDisabled,
        ),
      ],
    ),
  );
  Widget _error(String message) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      message,
      style: TextStyle(color: FeedFlowColors.error, fontSize: 12),
    ),
  );
}
