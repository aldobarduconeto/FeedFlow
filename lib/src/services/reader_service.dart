import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

abstract final class ReaderService {
  static String clean(String source, {bool articleOnly = false}) {
    final doc = html.parse(source);
    for (final element in doc.querySelectorAll(
      'script, style, noscript, nav, header, footer, aside, form, iframe, '
      'dialog, button, [role="navigation"], [role="banner"], [hidden], '
      '[aria-hidden="true"], .advertisement, .ads, .ad, .popup, .sidebar, '
      '.cookie-banner, .social-share, .related-posts',
    )) {
      element.remove();
    }
    Element? root;
    if (articleOnly) {
      final candidates = doc.querySelectorAll(
        'article, [itemprop="articleBody"], main, [role="main"]',
      );
      candidates.sort((a, b) => b.text.length.compareTo(a.text.length));
      if (candidates.isNotEmpty) root = candidates.first;
      // Fall back to the container holding the most paragraph text.
      if (root == null) {
        final scores = <Element, int>{};
        for (final p in doc.querySelectorAll('p')) {
          final parent = p.parent;
          if (parent != null)
            scores[parent] = (scores[parent] ?? 0) + p.text.length;
        }
        for (final entry in scores.entries) {
          if (root == null || entry.value > (scores[root] ?? 0))
            root = entry.key;
        }
      }
      if (root == null) return '';
    }
    root ??= doc.body;
    final buffer = StringBuffer();
    void visit(Node node) {
      if (node is Text) {
        buffer.write(node.text);
        return;
      }
      if (node is! Element) return;
      final block = [
        'p',
        'div',
        'section',
        'h1',
        'h2',
        'h3',
        'h4',
        'blockquote',
        'li',
      ].contains(node.localName);
      if (block) buffer.write('\n\n');
      if (node.localName == 'br') buffer.write('\n');
      if (node.localName == 'li') buffer.write('• ');
      for (final child in node.nodes) {
        visit(child);
      }
      if (block) buffer.write('\n\n');
    }

    if (root != null) visit(root);
    return buffer
        .toString()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static Future<String> load(String url) async {
    final uri = Uri.parse(url);
    if (!['http', 'https'].contains(uri.scheme))
      throw const FormatException('URL inválida.');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200)
      throw const FormatException('Artigo indisponível.');
    final text = clean(response.body, articleOnly: true);
    if (text.length < 100)
      throw const FormatException(
        'O site não disponibilizou texto suficiente.',
      );
    return text;
  }
}
