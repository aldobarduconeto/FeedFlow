import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/feed.dart';
import '../models/feed_source.dart';
import '../services/feed_service.dart';
import '../services/podcast_player_service.dart';
import '../services/reader_service.dart';
import 'podcast_controls.dart';
import 'podcast_player_page.dart';
import 'widget/cover_background.dart';

class PodcastShowPage extends StatefulWidget {
  const PodcastShowPage({
    required this.source,
    required this.feedService,
    required this.player,
    super.key,
  });
  final FeedSource source;
  final FeedService feedService;
  final PodcastPlayerService player;
  @override
  State<PodcastShowPage> createState() => _PodcastShowPageState();
}

class _PodcastShowPageState extends State<PodcastShowPage> {
  String _filter = 'all';
  bool _newestFirst = true;
  bool _expandedDescription = false;
  bool _changingFollow = false;
  static const _muted = Color(0xFFCBD5E1);

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openEpisode(FeedItem item) async {
    try {
      if (!widget.player.isCurrent(item) || !widget.player.isPlaying) {
        await widget.player.toggle(item);
      }
      if (!item.isRead) await widget.feedService.toggleRead(item);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PodcastPlayerPage(
            player: widget.player,
            feedService: widget.feedService,
            source: widget.source,
          ),
        ),
      );
    } catch (error) {
      _message('Não foi possível abrir o episódio: $error');
    }
  }

  Future<void> _toggleEpisode(FeedItem item) async {
    try {
      await widget.player.toggle(item);
      if (!item.isRead) await widget.feedService.toggleRead(item);
    } catch (error) {
      _message('Falha na reprodução: $error');
    }
  }

  Future<void> _toggleFollow(bool followed, FeedSource source) async {
    if (_changingFollow) return;
    if (followed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deixar de seguir este programa?'),
          content: const Text(
            'O programa e seus episódios serão removidos da biblioteca local.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deixar de seguir'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _changingFollow = true);
    try {
      if (followed) {
        await widget.feedService.removeFeed(source.id);
      } else {
        await widget.feedService.addFeed(source.url, category: source.category);
      }
    } catch (error) {
      _message('Não foi possível atualizar a assinatura: $error');
    } finally {
      if (mounted) setState(() => _changingFollow = false);
    }
  }

  Future<void> _episodeAction(String action, FeedItem item) async {
    try {
      switch (action) {
        case 'next':
          widget.player.enqueue(item, next: true);
          _message('Episódio adicionado a seguir.');
          break;
        case 'last':
          widget.player.enqueue(item);
          _message('Episódio adicionado ao fim da fila.');
          break;
        case 'download':
          await widget.feedService.downloadPodcast(item);
          _message('Episódio disponível offline.');
          break;
        case 'favorite':
          await widget.feedService.toggleFavorite(item);
          break;
        case 'read':
          await widget.feedService.toggleRead(item);
          break;
      }
    } catch (error) {
      _message('Não foi possível concluir a ação: $error');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.feedService, widget.player]),
    builder: (context, _) {
      final matches = widget.feedService.sources.where(
        (s) =>
            s.id == widget.source.id ||
            Uri.parse(s.url).removeFragment() ==
                Uri.parse(widget.source.url).removeFragment(),
      );
      final followed = matches.isNotEmpty;
      final source = followed ? matches.first : widget.source;
      final episodes = widget.feedService.items
          .where((item) => item.feedId == source.id && item.isPodcast)
          .toList();
      final latest = episodes.isEmpty ? null : episodes.first;
      final imageItems = episodes.where((item) => item.hasImage);
      final cover =
          source.imageUrl ??
          (imageItems.isEmpty ? null : imageItems.first.imageUrl);
      final selected = episodes.where((item) {
        if (_filter == 'unplayed') return !item.isRead;
        if (_filter == 'downloaded') return item.downloadedAudioPath != null;
        return true;
      }).toList();
      final ordered = _newestFirst ? selected : selected.reversed.toList();
      final downloaded = ordered
          .where((item) => item.downloadedAudioPath != null)
          .toList();
      final online = ordered
          .where((item) => item.downloadedAudioPath == null)
          .toList();
      final description = ReaderService.clean(source.description);
      final theme = ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Color(0xFF142033),
          surface: Color(0xFF182238),
          onSurface: Colors.white,
        ),
      );
      return Theme(
        data: theme,
        child: Scaffold(
          backgroundColor: const Color(0xFF142033),
          bottomNavigationBar: PodcastNowPlayingBar(
            player: widget.player,
            feedService: widget.feedService,
          ),
          body: CoverBackground(
            imageUrl: cover,
            immersive: true,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _glass(
                                    IconButton(
                                      tooltip: 'Voltar',
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  _glass(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        PopupMenuButton<String>(
                                          tooltip: 'Filtrar episódios',
                                          icon: const Icon(
                                            Icons.filter_list_rounded,
                                            color: Colors.white,
                                          ),
                                          initialValue: _filter,
                                          onSelected: (value) =>
                                              setState(() => _filter = value),
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'all',
                                              child: Text('Todos os episódios'),
                                            ),
                                            PopupMenuItem(
                                              value: 'unplayed',
                                              child: Text('Não ouvidos'),
                                            ),
                                            PopupMenuItem(
                                              value: 'downloaded',
                                              child: Text('Baixados'),
                                            ),
                                          ],
                                        ),
                                        PopupMenuButton<bool>(
                                          tooltip: 'Ordenar episódios',
                                          icon: const Icon(
                                            Icons.swap_vert_rounded,
                                            color: Colors.white,
                                          ),
                                          initialValue: _newestFirst,
                                          onSelected: (value) => setState(
                                            () => _newestFirst = value,
                                          ),
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: true,
                                              child: Text(
                                                'Mais recentes primeiro',
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: false,
                                              child: Text(
                                                'Mais antigos primeiro',
                                              ),
                                            ),
                                          ],
                                        ),
                                        PopupMenuButton<String>(
                                          tooltip: 'Opções do programa',
                                          icon: const Icon(
                                            Icons.more_horiz_rounded,
                                            color: Colors.white,
                                          ),
                                          onSelected: (value) async {
                                            if (value == 'copy') {
                                              await Clipboard.setData(
                                                ClipboardData(text: source.url),
                                              );
                                              _message('Link do feed copiado.');
                                            }
                                            if (value == 'follow')
                                              await _toggleFollow(
                                                followed,
                                                source,
                                              );
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'copy',
                                              child: Text(
                                                'Copiar link do feed',
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'follow',
                                              enabled: !_changingFollow,
                                              child: Text(
                                                followed
                                                    ? 'Deixar de seguir'
                                                    : 'Seguir programa',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              Center(
                                child: LayoutBuilder(
                                  builder: (context, constraints) => Container(
                                    width: (constraints.maxWidth * 0.65).clamp(
                                      180.0,
                                      320.0,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 38,
                                          offset: const Offset(0, 18),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(22),
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: cover == null
                                            ? _coverFallback()
                                            : Image.network(
                                                cover,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    _coverFallback(),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 26),
                              Center(
                                child: Text(
                                  source.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.8,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: FilledButton.icon(
                                      onPressed:
                                          latest == null ||
                                              !latest.hasAudio ||
                                              widget.player.isLoading
                                          ? null
                                          : () => _openEpisode(latest),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(
                                          0xFF142033,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 16,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                      ),
                                      label: const Text(
                                        'Último episódio',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _glass(
                                    IconButton(
                                      tooltip: followed
                                          ? 'Seguindo · toque para deixar de seguir'
                                          : 'Seguir programa',
                                      onPressed: _changingFollow
                                          ? null
                                          : () =>
                                                _toggleFollow(followed, source),
                                      icon: Icon(
                                        followed
                                            ? Icons.check_rounded
                                            : Icons.add_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 26),
                              if (description.isNotEmpty) ...[
                                Text(
                                  description,
                                  maxLines: _expandedDescription ? null : 3,
                                  overflow: _expandedDescription
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.55,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(
                                    () => _expandedDescription =
                                        !_expandedDescription,
                                  ),
                                  child: Text(
                                    _expandedDescription
                                        ? 'Mostrar menos'
                                        : 'Sobre o programa',
                                    style: const TextStyle(color: _muted),
                                  ),
                                ),
                              ],
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    source.category,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '· ${episodes.length} episódios',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (latest?.publishedAt != null)
                                    Text(
                                      '· Atualizado em ${_date(latest!.publishedAt!)}',
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              const Text(
                                'Episódios',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_filter == 'unplayed'
                                    ? 'Não ouvidos'
                                    : _filter == 'downloaded'
                                    ? 'Baixados'
                                    : 'Todos os episódios'} · ${_newestFirst ? 'Mais recentes' : 'Mais antigos'}',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (selected.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Text(
                                    'Nenhum episódio disponível para esta seleção.',
                                    style: TextStyle(color: _muted),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (downloaded.isNotEmpty) ...[
                        _sectionTitle(
                          'Baixados · ${downloaded.length}',
                          Icons.offline_pin_rounded,
                        ),
                        _episodeList(downloaded),
                      ],
                      if (online.isNotEmpty) ...[
                        if (downloaded.isNotEmpty)
                          _sectionTitle(
                            'Na biblioteca · ${online.length}',
                            Icons.podcasts_rounded,
                          ),
                        _episodeList(online),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 36)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _glass(Widget child) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(40),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    child: child,
  );
  Widget _coverFallback() => const ColoredBox(
    color: Color(0xFF243B69),
    child: Center(
      child: Icon(Icons.podcasts_rounded, size: 80, color: Colors.white70),
    ),
  );
  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  Widget _sectionTitle(String title, IconData icon) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
      child: Row(
        children: [
          Icon(icon, color: _muted, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
  Widget _episodeList(List<FeedItem> items) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    sliver: SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final current = widget.player.isCurrent(item);
        final playing = current && widget.player.isPlaying;
        final loading = current && widget.player.isLoading;
        final downloading = widget.feedService.downloadingItems.contains(
          item.id,
        );
        final summary = ReaderService.clean(
          item.description ?? item.content ?? '',
        );
        final duration = item.audioDuration;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.publishedAt != null)
                Text(
                  _date(item.publishedAt!),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 7),
              InkWell(
                onTap: () => _openEpisode(item),
                child: Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: !item.hasAudio || loading
                        ? null
                        : () => _toggleEpisode(item),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 18,
                    ),
                    label: Text(
                      loading
                          ? 'Carregando…'
                          : playing
                          ? 'Pausar'
                          : duration != null
                          ? '${duration.inMinutes} min'
                          : 'Ouvir',
                    ),
                  ),
                  if (item.downloadedAudioPath != null)
                    const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Icon(
                        Icons.offline_pin_rounded,
                        size: 17,
                        color: _muted,
                      ),
                    ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Opções do episódio',
                    icon: const Icon(Icons.more_horiz_rounded, color: _muted),
                    onSelected: (action) => _episodeAction(action, item),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'next',
                        enabled: item.hasAudio && !current,
                        child: const Text('Reproduzir a seguir'),
                      ),
                      PopupMenuItem(
                        value: 'last',
                        enabled: item.hasAudio && !current,
                        child: const Text('Adicionar ao fim da fila'),
                      ),
                      PopupMenuItem(
                        value: 'download',
                        enabled:
                            item.hasAudio &&
                            item.downloadedAudioPath == null &&
                            !downloading,
                        child: Text(
                          downloading
                              ? 'Baixando…'
                              : item.downloadedAudioPath != null
                              ? 'Disponível offline'
                              : 'Baixar episódio',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'favorite',
                        child: Text(
                          item.isFavorite
                              ? 'Remover dos favoritos'
                              : 'Favoritar',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'read',
                        child: Text(
                          item.isRead
                              ? 'Marcar como não ouvido'
                              : 'Marcar como ouvido',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.15)),
            ],
          ),
        );
      },
    ),
  );
}
