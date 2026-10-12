import 'dart:async';

import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../models/feed_source.dart';
import '../services/feed_service.dart';
import 'widget/colors.dart';

class ArticleReaderPage extends StatefulWidget {
  const ArticleReaderPage({
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
  double _readingProgress = 0;

  @override
  void initState() {
    super.initState();
    _readingProgress = widget.item.readingProgress ?? 0;
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

  void _updateProgress() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    _readingProgress = (position.pixels / position.maxScrollExtent)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  void _saveProgress() {
    if (!_scrollController.hasClients) return;
    _updateProgress();
    if (_readingProgress >= 0.98) _readingProgress = 1;
    unawaited(
      widget.feedService.saveReadingProgress(widget.item, _readingProgress),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _saveProgress();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_updateProgress);
    _saveProgress();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final body = _readableText(item.content ?? item.description ?? '');
    final date = item.publishedAt;
    final metadata = [
      if (widget.source != null) widget.source!.title,
      if (date != null) '${date.day}/${date.month}/${date.year}',
      if (item.author?.isNotEmpty == true) item.author!,
    ].join(' • ');

    return Scaffold(
      appBar: AppBar(title: const Text('Leitura')),
      body: SafeArea(
        top: false,
        child: SelectionArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.hasImage) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const _ImageFallback(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      metadata.isEmpty ? 'ARTIGO' : metadata.toUpperCase(),
                      style: const TextStyle(
                        color: FeedFlowColors.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: FeedFlowColors.textPrimary,
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    if (body.isEmpty)
                      const Text(
                        'Esta fonte não forneceu o texto do artigo.',
                        style: TextStyle(
                          color: FeedFlowColors.textSecondary,
                          fontSize: 16,
                          height: 1.7,
                        ),
                      )
                    else
                      Text(
                        body,
                        style: const TextStyle(
                          color: FeedFlowColors.textPrimary,
                          fontSize: 16,
                          height: 1.8,
                        ),
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

String _readableText(String html) {
  var text = html.replaceAll(
    RegExp(r'<(script|style)\b[^>]*>[\s\S]*?</\1\s*>', caseSensitive: false),
    '',
  );
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<li\b[^>]*>', caseSensitive: false), '\n• ');
  text = text.replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n');
  text = text.replaceAll(
    RegExp(
      r'</(p|div|section|article|h[1-6]|blockquote|tr)\s*>',
      caseSensitive: false,
    ),
    '\n\n',
  );
  text = text.replaceAll(RegExp(r'<[^>]*>'), '');

  const entities = {
    'amp': '&',
    'apos': "'",
    'bull': '•',
    'hellip': '…',
    'ldquo': '“',
    'lsquo': '‘',
    'mdash': '—',
    'nbsp': ' ',
    'ndash': '–',
    'quot': '"',
    'rdquo': '”',
    'rsquo': '’',
  };
  text = text.replaceAllMapped(
    RegExp(r'&(#x[0-9a-f]+|#\d+|[a-z]+);?', caseSensitive: false),
    (match) {
      final entity = match.group(1)!;
      if (entity.startsWith('#x') || entity.startsWith('#X')) {
        final codePoint = int.tryParse(entity.substring(2), radix: 16);
        return codePoint == null || codePoint > 0x10ffff
            ? match.group(0)!
            : String.fromCharCode(codePoint);
      }
      if (entity.startsWith('#')) {
        final codePoint = int.tryParse(entity.substring(1));
        return codePoint == null || codePoint > 0x10ffff
            ? match.group(0)!
            : String.fromCharCode(codePoint);
      }
      return entities[entity.toLowerCase()] ?? match.group(0)!;
    },
  );

  return text
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n[ \t]+'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: FeedFlowColors.surfaceElevated,
      child: Center(
        child: Icon(
          Icons.article_outlined,
          size: 40,
          color: FeedFlowColors.secondary,
        ),
      ),
    );
  }
}
