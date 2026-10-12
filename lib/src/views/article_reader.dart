import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../models/feed_source.dart';
import 'widget/colors.dart';

class ArticleReaderPage extends StatelessWidget {
  const ArticleReaderPage({
    required this.item,
    required this.source,
    super.key,
  });

  final FeedItem item;
  final FeedSource? source;

  @override
  Widget build(BuildContext context) {
    final body = _readableText(item.content ?? item.description ?? '');
    final date = item.publishedAt;
    final metadata = [
      if (source != null) source!.title,
      if (date != null) '${date.day}/${date.month}/${date.year}',
      if (item.author?.isNotEmpty == true) item.author!,
    ].join(' • ');

    return Scaffold(
      appBar: AppBar(title: const Text('Leitura')),
      body: SafeArea(
        top: false,
        child: SelectionArea(
          child: SingleChildScrollView(
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

  static String _readableText(String html) {
    var text = html.replaceAll(
      RegExp(r'<(script|style)\b[^>]*>[\s\S]*?</\1\s*>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(
      RegExp(r'<li\b[^>]*>', caseSensitive: false),
      '\n• ',
    );
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
