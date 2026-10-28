import 'dart:async';

import '../services/appearance_service.dart';
import '../services/reader_service.dart';
import 'appearance_controls.dart';
import 'widget/colors.dart';
import '../models/feed.dart';
import '../models/feed_source.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/feed_service.dart';

class ArticleReaderPage extends StatefulWidget {
  ArticleReaderPage({
    required this.item,
    required this.source,
    required this.feedService,
    super.key,
  });

  final FeedItem item;
  final FeedSource? source;
  final FeedService feedService;

  @override
  State<ArticleReaderPage> createState() => _ArticleReaderPageState();
}

class _ArticleReaderPageState extends State<ArticleReaderPage>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  String? _fullText;
  bool _fetching = false;
  String? _readerError;
  double _readingProgress = 0;
  double get _fontSize => AppearanceService.instance.fontSize;
  bool get _useSerif => AppearanceService.instance.serif;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    AppearanceService.instance.addListener(_appearanceChanged);
    _readingProgress = widget.item.readingProgress ?? 0;
    _isFavorite = widget.item.isFavorite;
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_updateProgress);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || _readingProgress <= 0) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        _scrollController.jumpTo(maxScroll * _readingProgress);
      }
    });
  }

  Future<void> _loadFullArticle() async {
    final url = widget.item.url;
    if (url == null || _fetching) return;
    setState(() {
      _fetching = true;
      _readerError = null;
    });
    try {
      final text = await ReaderService.load(url);
      if (mounted) setState(() => _fullText = text);
    } catch (_) {
      if (mounted)
        setState(
          () => _readerError = 'Não foi possível extrair o texto do site. O conteúdo do feed continua disponível.',
        );
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  void _appearanceChanged() {
    if (mounted) setState(() {});
  }

  void _updateProgress() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    final progress = (position.pixels / position.maxScrollExtent)
        .clamp(0.0, 1.0)
        .toDouble();
    if ((progress - _readingProgress).abs() > 0.01) {
      setState(() {
        _readingProgress = progress;
      });
    }
  }

  void _saveProgress() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    var progress = (position.pixels / position.maxScrollExtent)
        .clamp(0.0, 1.0)
        .toDouble();
    if (progress >= 0.95) progress = 1.0;
    unawaited(widget.feedService.saveReadingProgress(widget.item, progress));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _saveProgress();
  }

  @override
  void dispose() {
    AppearanceService.instance.removeListener(_appearanceChanged);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_updateProgress);
    _saveProgress();
    _scrollController.dispose();
    super.dispose();
  }

  void _openTypographySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: AppearanceControls(),
        ),
      ),
    );
  }

  void _copyLink() {
    final url = widget.item.url;
    if (url != null && url.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link do artigo copiado para a área de transferência!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final body =
        _fullText ??
        ReaderService.clean(item.content ?? item.description ?? '');
    final date = item.publishedAt;
    final wordCount = body
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .length;
    final readingTimeMinutes = (wordCount / 200).ceil().clamp(1, 60);

    final textStyle = TextStyle(
      color: FeedFlowColors.textPrimary,
      fontSize: _fontSize,
      height: 1.8,
      letterSpacing: 0.2,
      fontFamily: _useSerif ? 'Georgia' : null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.source?.title ?? 'Leitura',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Reading progress percent badge
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: FeedFlowColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${(_readingProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: FeedFlowColors.secondary,
                ),
              ),
            ),
          ),
          // Typography adjustment button
          IconButton(
            tooltip: 'Ajustar texto',
            icon: Icon(Icons.format_size_rounded),
            onPressed: _openTypographySheet,
          ),
          // Favorite button
          IconButton(
            tooltip: _isFavorite ? 'Remover dos favoritos' : 'Favoritar',
            icon: Icon(
              _isFavorite
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: _isFavorite ? FeedFlowColors.secondary : null,
            ),
            onPressed: () async {
              await widget.feedService.toggleFavorite(item);
              setState(() {
                _isFavorite = !_isFavorite;
              });
            },
          ),
          // Share / Copy link button
          if (item.url != null && item.url!.isNotEmpty)
            IconButton(
              tooltip: 'Copiar link',
              icon: Icon(Icons.share_outlined),
              onPressed: _copyLink,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: _readingProgress,
            minHeight: 3,
            backgroundColor: FeedFlowColors.surfaceHighlight.withValues(
              alpha: 0.5,
            ),
            valueColor: AlwaysStoppedAnimation<Color>(FeedFlowColors.secondary),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SelectionArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              AppearanceService.instance.margin,
              16,
              AppearanceService.instance.margin,
              48,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Article Hero Image
                    if (item.hasImage) ...[
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _ImageFallback(),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                    ],

                    // Source and Tags Row
                    Row(
                      children: [
                        if (widget.source != null)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: FeedFlowColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: FeedFlowColors.primary.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.rss_feed_rounded,
                                  size: 13,
                                  color: FeedFlowColors.secondary,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  widget.source!.title.toUpperCase(),
                                  style: TextStyle(
                                    color: FeedFlowColors.secondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(width: 8),
                        // Reading Time
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: FeedFlowColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: FeedFlowColors.textSecondary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '$readingTimeMinutes min de leitura',
                                style: TextStyle(
                                  color: FeedFlowColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Article Title
                    Text(
                      item.title,
                      style: TextStyle(
                        color: FeedFlowColors.textPrimary,
                        fontSize: 27,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        fontFamily: _useSerif ? 'Georgia' : null,
                      ),
                    ),

                    SizedBox(height: 14),

                    // Author & Date metadata
                    Row(
                      children: [
                        if (item.author?.isNotEmpty == true) ...[
                          Icon(
                            Icons.person_outline_rounded,
                            size: 15,
                            color: FeedFlowColors.textDisabled,
                          ),
                          SizedBox(width: 4),
                          Text(
                            item.author!,
                            style: TextStyle(
                              color: FeedFlowColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 12),
                        ],
                        if (date != null) ...[
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: FeedFlowColors.textDisabled,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${date.day}/${date.month}/${date.year}',
                            style: TextStyle(
                              color: FeedFlowColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),

                    SizedBox(height: 20),
                    Divider(),
                    SizedBox(height: 24),

                    if (item.url != null && _fullText == null)
                      TextButton.icon(
                        onPressed: _fetching ? null : _loadFullArticle,
                        icon: Icon(Icons.article_outlined),
                        label: Text(
                          _fetching
                              ? 'Carregando artigo…'
                              : 'Ler texto completo do site',
                        ),
                      ),
                    if (_readerError != null) Text(_readerError!),
                    // Article Body Content
                    if (body.isEmpty)
                      Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: FeedFlowColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: FeedFlowColors.secondary,
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Esta fonte não forneceu o corpo completo do artigo no feed RSS.',
                                style: TextStyle(
                                  color: FeedFlowColors.textSecondary,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _ArticleBody(body: body, textStyle: textStyle),

                    SizedBox(height: 36),
                    Divider(),
                    SizedBox(height: 28),

                    // Reading completion card
                    _ReadingCompletionCard(
                      item: item,
                      feedService: widget.feedService,
                      onShare: _copyLink,
                      onToggleFavorite: () async {
                        await widget.feedService.toggleFavorite(item);
                        setState(() {
                          _isFavorite = !_isFavorite;
                        });
                      },
                      isFavorite: _isFavorite,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleBody extends StatelessWidget {
  _ArticleBody({required this.body, required this.textStyle});

  final String body;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final paragraphs = body
        .split('\n\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < paragraphs.length; i++) ...[
          if (paragraphs[i].startsWith('• '))
            _BulletParagraph(text: paragraphs[i], textStyle: textStyle)
          else
            Text(
              paragraphs[i],
              textAlign: AppearanceService.instance.alignment,
              style: i == 0
                  ? textStyle.copyWith(
                      fontSize: textStyle.fontSize! + 1.5,
                      height: 1.85,
                      fontWeight: FontWeight.w400,
                    )
                  : textStyle,
            ),
          if (i < paragraphs.length - 1) SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _BulletParagraph extends StatelessWidget {
  _BulletParagraph({required this.text, required this.textStyle});

  final String text;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final items = text.split('\n').where((s) => s.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: EdgeInsets.only(bottom: 8, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 8, right: 10),
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: FeedFlowColors.secondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    item.replaceFirst(RegExp(r'^[•\-\*]\s*'), ''),
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReadingCompletionCard extends StatelessWidget {
  _ReadingCompletionCard({
    required this.item,
    required this.feedService,
    required this.onShare,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  final FeedItem item;
  final FeedService feedService;
  final VoidCallback onShare;
  final VoidCallback onToggleFavorite;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: FeedFlowColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FeedFlowColors.divider),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FeedFlowColors.success.withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 32,
              color: FeedFlowColors.success,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Você concluiu este artigo!',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Seu progresso foi registrado automaticamente no FeedFlow.',
            style: TextStyle(fontSize: 13, color: FeedFlowColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onToggleFavorite,
                icon: Icon(
                  isFavorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 18,
                  color: isFavorite ? FeedFlowColors.secondary : null,
                ),
                label: Text(isFavorite ? 'Salvo' : 'Salvar'),
              ),
              SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.arrow_back_rounded, size: 18),
                label: Text('Voltar ao feed'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: FeedFlowColors.surfaceElevated,
    child: Center(child: Icon(Icons.image_not_supported_outlined, size: 40)),
  );
}
