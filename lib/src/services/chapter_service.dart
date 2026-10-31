import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../models/feed.dart';
import '../models/podcast_chapter.dart';

abstract final class ChapterService {
  static Duration? timestamp(String text) {
    final parts = text.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final values = parts.map(num.tryParse).toList();
    if (values.any((v) => v == null || !v.isFinite || v < 0)) return null;
    if (values.skip(1).any((v) => v! >= 60)) return null;
    final seconds = values.fold<num>(0, (total, v) => total * 60 + v!);
    return Duration(milliseconds: (seconds * 1000).round());
  }

  static List<PodcastChapter> fromDescription(String text) {
    final fragment = html.parseFragment(
      text.replaceAll(
        RegExp(r'<(?:br\s*/?|/p|/div|/li)>', caseSensitive: false),
        '\n',
      ),
    );
    final plain = fragment.text ?? '';
    final result = <PodcastChapter>[];
    for (final line in plain.split('\n')) {
      final match = RegExp(
        r'^\s*[\[(]?(\d{1,3}:\d{2}(?::\d{2})?)[\])]?[ \t]*(?:[-–—|][ \t]*)?(.+)$',
      ).firstMatch(line);
      if (match == null) continue;
      final start = timestamp(match.group(1)!);
      if (start != null)
        result.add(PodcastChapter(start: start, title: match.group(2)!.trim()));
    }
    return normalize(result);
  }

  static List<PodcastChapter> normalize(Iterable<PodcastChapter> chapters) {
    final result = chapters.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final seen = <int>{};
    return result.where((c) => seen.add(c.start.inMilliseconds)).toList();
  }

  static Future<List<PodcastChapter>> load(FeedItem item) async {
    if (item.chapters.isNotEmpty) return item.chapters;
    if (item.chaptersUrl != null) {
      final uri = Uri.parse(item.chaptersUrl!);
      if (!['http', 'https'].contains(uri.scheme))
        throw const FormatException('URL de capítulos inválida.');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200)
        throw const FormatException('Capítulos indisponíveis.');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final chapters = (data['chapters'] as List)
          .whereType<Map<String, dynamic>>()
          .where((map) => map['toc'] != false)
          .map(PodcastChapter.fromMap)
          .whereType<PodcastChapter>();
      return normalize(chapters);
    }
    return fromDescription(item.content ?? item.description ?? '');
  }
}
