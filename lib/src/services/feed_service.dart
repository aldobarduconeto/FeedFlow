import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html;

import 'chapter_service.dart';
import '../models/podcast_chapter.dart';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/feed.dart';
import '../models/feed_source.dart';
import 'notification_service.dart';

class FeedService extends ChangeNotifier {
  FeedService({http.Client? client, NotificationService? notificationService})
    : _client = client ?? http.Client(),
      _notificationService = notificationService,
      _dataKey = 'feedflow.data.v1.local';
  static const _timeout = Duration(seconds: 20);
  final http.Client _client;
  NotificationService? _notificationService;
  final String _dataKey;

  NotificationService? get notificationService => _notificationService;
  set notificationService(NotificationService? service) {
    _notificationService = service;
  }
  final List<FeedSource> _sources = [];
  final List<FeedItem> _items = [];
  final Map<String, String> refreshErrors = {};
  final Set<String> downloadingItems = {};
  bool isRefreshing = false;
  bool isLoading = true;
  String? startupError;
  bool _loaded = false;
  Future<void>? _loadOperation;
  Future<void>? _refreshOperation;

  List<FeedSource> get sources => List.unmodifiable(_sources);
  List<FeedItem> get items {
    final result = List<FeedItem>.of(_items);
    result.sort((a, b) {
      final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return List.unmodifiable(result);
  }

  Future<void> initialize() async {
    try {
      await _load();
      await refreshAll();
    } catch (error) {
      startupError = error.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() {
    final currentOperation = _refreshOperation;
    if (currentOperation != null) return currentOperation;
    final operation = _refreshAll();
    _refreshOperation = operation;
    return operation.whenComplete(() {
      if (identical(_refreshOperation, operation)) _refreshOperation = null;
    });
  }

  Future<void> _refreshAll() async {
    await _load();
    isRefreshing = true;
    refreshErrors.clear();
    notifyListeners();

    final itemIndexes = {
      for (var index = 0; index < _items.length; index++)
        _items[index].id: index,
    };
    try {
      for (final source in List<FeedSource>.of(_sources)) {
        try {
          await _updateSource(source, itemIndexes);
        } catch (error) {
          refreshErrors[source.id] = error.toString();
        }
      }
      isLoading = false;
      await _persist();
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<FeedSource> addFeed(
    String input, {
    String category = 'Personalizados',
  }) async {
    await _load();
    final uri = await discoverFeed(input);
    final url = _canonicalUrl(uri);
    final existingIndex = _sources.indexWhere(
      (source) => _canonicalUrl(Uri.parse(source.url)) == url,
    );
    if (existingIndex != -1) {
      throw const FormatException('Esta fonte já foi adicionada.');
    }

    final source = FeedSource(
      id: url,
      url: url,
      title: uri.host,
      category: category,
    );
    final result = await _fetchFeed(source);
    _sources.add(result.source);
    _items.addAll(result.items);
    await _persist();
    notifyListeners();
    return result.source;
  }

  Future<Uri> discoverFeed(String input) async {
    final uri = _validatedUri(input);
    if ((uri.host == 'youtube.com' ||
            uri.host.endsWith('.youtube.com') ||
            uri.host == 'www.youtube.com') &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'channel') {
      return Uri.https('www.youtube.com', '/feeds/videos.xml', {
        'channel_id': uri.pathSegments[1],
      });
    }
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw HttpException(
        'Não foi possível abrir a URL (HTTP ${response.statusCode}).',
      );
    }
    final document = html.parse(response.body);
    if (document.querySelector('rss, feed') != null ||
        response.body.trimLeft().startsWith('<?xml'))
      return uri;
    for (final link in document.querySelectorAll('link[rel]')) {
      final rel = (link.attributes['rel'] ?? '').toLowerCase().split(' ');
      final type = (link.attributes['type'] ?? '').toLowerCase();
      final href = link.attributes['href'];
      if (rel.contains('alternate') &&
          href != null &&
          (type.contains('rss') || type.contains('atom'))) {
        return _validatedUri(uri.resolve(href).toString());
      }
    }
    // YouTube channel pages publish a channel ID even for @handle URLs.
    if (uri.host == 'youtube.com' || uri.host.endsWith('.youtube.com')) {
      final match = RegExp(r'"(?:channelId|externalId)"\s*:\s*"(UC[\w-]+)"')
          .firstMatch(response.body);
      if (match != null) {
        return Uri.https('www.youtube.com', '/feeds/videos.xml', {
          'channel_id': match.group(1)!,
        });
      }
    }
    // Let the XML parser validate feed URLs without HTML discovery links.
    return uri;
  }

  Future<List<FeedItem>> previewFeed(String input) async {
    final uri = _validatedUri(input);
    final url = _canonicalUrl(uri);
    final previewSource = FeedSource(id: url, url: url, title: uri.host);
    final result = await _fetchFeed(previewSource);
    final previewItems = List<FeedItem>.of(result.items)
      ..sort((a, b) {
        final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    // Keep enough recent entries to rank recommendations by posting cadence.
    return List.unmodifiable(previewItems.take(30));
  }

  Future<void> removeFeed(String feedId) async {
    await _load();
    _sources.removeWhere((source) => source.id == feedId);
    _items.removeWhere((item) => item.feedId == feedId);
    refreshErrors.remove(feedId);
    await _persist();
    notifyListeners();
  }

  Future<void> updateSourceCategory(String sourceId, String newCategory) async {
    await _load();
    final index = _sources.indexWhere((source) => source.id == sourceId);
    if (index != -1) {
      _sources[index] = _sources[index].copyWith(category: newCategory);
      await _persist();
      notifyListeners();
    }
  }

  Future<void> savePlaybackPosition(FeedItem item, Duration position) async {
    await _load();
    final index = _items.indexWhere((savedItem) => savedItem.id == item.id);
    if (index == -1) {
      throw StateError('O episódio não existe mais neste feed.');
    }
    _items[index] = _items[index].copyWith(playbackPosition: position);
    await _persist();
  }

  Future<void> saveReadingProgress(FeedItem item, double progress) async {
    await _load();
    final index = _items.indexWhere((savedItem) => savedItem.id == item.id);
    if (index == -1) return;
    final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();
    final currentProgress = _items[index].readingProgress ?? 0;
    if ((normalizedProgress - currentProgress).abs() < 0.02 &&
        normalizedProgress < 1) {
      return;
    }
    _items[index] = _items[index].copyWith(readingProgress: normalizedProgress);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleRead(FeedItem item) async {
    await _updateItemFlag(item, isRead: !item.isRead);
  }

  Future<void> toggleFavorite(FeedItem item) async {
    await _updateItemFlag(item, isFavorite: !item.isFavorite);
  }

  Future<void> _updateItemFlag(
    FeedItem item, {
    bool? isRead,
    bool? isFavorite,
  }) async {
    await _load();
    final index = _items.indexWhere((savedItem) => savedItem.id == item.id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(
      isRead: isRead,
      isFavorite: isFavorite,
    );
    await _persist();
    notifyListeners();
  }

  Future<String> downloadPodcast(FeedItem item) async {
    if (!item.isPodcast || !item.hasAudio) {
      throw const FormatException(
        'Este episódio não possui áudio para baixar.',
      );
    }
    if (item.downloadedAudioPath case final existingPath?
        when await File(existingPath).exists()) {
      return existingPath;
    }
    if (!downloadingItems.add(item.id)) {
      throw StateError('Este episódio já está sendo baixado.');
    }
    notifyListeners();

    File? partialFile;
    try {
      final uri = _validatedUri(item.audioUrl!);
      final directory = await getApplicationDocumentsDirectory();
      final extension = path.extension(uri.path);
      final safeExtension = RegExp(r'^\.[a-zA-Z0-9]{1,8}$').hasMatch(extension)
          ? extension
          : '.audio';
      final name = '${_stableHash(item.id)}$safeExtension';
      final target = File(path.join(directory.path, 'podcasts', name));
      await target.parent.create(recursive: true);
      partialFile = File('${target.path}.part');

      final request = http.Request('GET', uri);
      final response = await _client.send(request).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'O servidor retornou HTTP ${response.statusCode} ao baixar o episódio.',
          uri: uri,
        );
      }

      final sink = partialFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      final savedFile = await partialFile.rename(target.path);
      _replaceItem(item.copyWith(downloadedAudioPath: savedFile.path));
      await _persist();
      return savedFile.path;
    } catch (_) {
      if (partialFile != null && await partialFile.exists()) {
        await partialFile.delete();
      }
      rethrow;
    } finally {
      downloadingItems.remove(item.id);
      notifyListeners();
    }
  }

  Future<void> _load() async {
    if (_loaded) return;
    final currentOperation = _loadOperation;
    if (currentOperation != null) {
      await currentOperation;
      return;
    }
    final operation = _readStoredData();
    _loadOperation = operation;
    try {
      await operation;
    } finally {
      _loadOperation = null;
    }
  }

  Future<void> _readStoredData() async {
    final preferences = await SharedPreferences.getInstance();
    final storedData = preferences.getString(_dataKey);
    if (storedData != null) {
      final decoded = jsonDecode(storedData) as Map<String, dynamic>;
      final storedSources = decoded['sources'] as List<dynamic>? ?? [];
      _sources.addAll(
        storedSources.map(
          (value) => FeedSource.fromMap(value as Map<String, dynamic>),
        ),
      );
      final storedItems = decoded['items'] as List<dynamic>? ?? [];
      _items.addAll(
        storedItems.map(
          (value) => FeedItem.fromMap(value as Map<String, dynamic>),
        ),
      );
    }
    _loaded = true;
    isLoading = false;
    notifyListeners();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _dataKey,
      jsonEncode({
        'sources': _sources.map((source) => source.toMap()).toList(),
        'items': _items.map((item) => item.toMap()).toList(),
      }),
    );
    if (!saved) {
      throw StateError('Não foi possível salvar as fontes e os artigos.');
    }
  }

  Future<void> _updateSource(
    FeedSource source,
    Map<String, int> itemIndexes,
  ) async {
    final result = await _fetchFeed(source);
    for (final item in result.items) {
      final index = itemIndexes[item.id];
      final previous = index == null ? null : _items[index];
      final updated = previous == null
          ? item
          : item.copyWith(
              isRead: previous.isRead,
              isFavorite: previous.isFavorite,
              playbackPosition: previous.playbackPosition,
              readingProgress: previous.readingProgress,
              downloadedAudioPath: previous.downloadedAudioPath,
            );
      if (index == null) {
        itemIndexes[item.id] = _items.length;
        _items.add(updated);
        if (_loaded) {
          _notificationService?.notifyItemPublished(
            item: updated,
            source: result.source,
          );
        }
      } else {
        _items[index] = updated;
      }
    }
    final index = _sources.indexWhere((value) => value.id == source.id);
    if (index != -1) _sources[index] = result.source;
    refreshErrors.remove(source.id);
  }

  Future<_ParsedFeed> _fetchFeed(FeedSource source) async {
    final uri = _validatedUri(source.url);
    final response = await _client
        .get(
          uri,
          headers: const {
            'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml',
          },
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'O servidor retornou HTTP ${response.statusCode} ao consultar o feed.',
        uri: uri,
      );
    }

    final document = XmlDocument.parse(response.body);
    final root = document.rootElement;
    final channel = _child(root, 'channel') ?? root;
    final entryElements = _descendants(root, 'item').toList();
    if (entryElements.isEmpty) {
      entryElements.addAll(_descendants(root, 'entry'));
    }
    if (!_looksLikeFeed(root, channel)) {
      throw const FormatException(
        'A URL não contém um feed RSS ou Atom válido com artigos.',
      );
    }

    final feedTitle =
        _text(channel, 'title') ?? _text(root, 'title') ?? source.title;
    final feedDescription =
        _text(channel, 'description') ??
        _text(channel, 'subtitle') ??
        source.description;
    final imageUrl =
        _text(_child(channel, 'image'), 'url') ??
        _attribute(_child(channel, 'image'), 'href') ??
        _attribute(_child(channel, 'image'), 'url');
    final parsedItems = <FeedItem>[];
    for (final entry in entryElements) {
      final item = _parseItem(entry, source.id, uri);
      if (item != null) parsedItems.add(item);
    }
    return _ParsedFeed(
      source: source.copyWith(
        title: feedTitle,
        description: feedDescription,
        imageUrl: _resolveUrl(uri, imageUrl),
        type: parsedItems.any((item) => item.isPodcast)
            ? FeedType.podcast
            : source.type,
      ),
      items: parsedItems
          .map(
            (item) => item.copyWith(
              imageUrl: item.imageUrl ?? _resolveUrl(uri, imageUrl),
            ),
          )
          .toList(),
    );
  }

  FeedItem? _parseItem(XmlElement element, String feedId, Uri baseUri) {
    final title = _text(element, 'title');
    if (title == null || title.isEmpty) return null;

    final linkElement = _child(element, 'link');
    final linkElements = element.childElements
        .where((child) => child.name.local.toLowerCase() == 'link')
        .toList();
    final enclosureLink = linkElements.cast<XmlElement?>().firstWhere(
      (node) => _attribute(node, 'rel') == 'enclosure',
      orElse: () => null,
    );
    final alternateLink = linkElements.cast<XmlElement?>().firstWhere(
      (node) =>
          _attribute(node, 'rel') == null ||
          _attribute(node, 'rel') == 'alternate',
      orElse: () => null,
    );
    final link =
        _text(element, 'link') ??
        _attribute(alternateLink, 'href') ??
        (_attribute(linkElement, 'rel') == null
            ? _attribute(linkElement, 'href')
            : null);
    final resolvedLink = _resolveUrl(baseUri, link);
    final guid = _text(element, 'guid') ?? _text(element, 'id');
    final enclosure = _child(element, 'enclosure');
    final mediaContent = _descendants(element, 'content').firstWhere(
      (node) => _attribute(node, 'url') != null,
      orElse: () => element,
    );
    final enclosureUrl =
        _attribute(enclosure, 'url') ??
        _attribute(enclosureLink, 'href') ??
        _attribute(mediaContent, 'url');
    final mediaType =
        _attribute(enclosure, 'type') ??
        _attribute(enclosureLink, 'type') ??
        _attribute(mediaContent, 'type');
    final candidateAudioUrl = _resolveUrl(baseUri, enclosureUrl);
    final audioUrl = _isAudio(mediaType, candidateAudioUrl)
        ? candidateAudioUrl
        : null;
    final imageUrl = _itemImageUrl(element, baseUri);
    final description =
        _text(element, 'encoded') ??
        _text(element, 'description') ??
        _text(element, 'summary');
    final content = _text(element, 'content') ?? description;
    final idValue = guid?.isNotEmpty == true
        ? guid!
        : resolvedLink ?? '$title|${_text(element, 'pubDate') ?? ''}';
    final publishedAt =
        DateTime.tryParse(_text(element, 'pubDate') ?? '') ??
        DateTime.tryParse(_text(element, 'published') ?? '') ??
        DateTime.tryParse(_text(element, 'updated') ?? '') ??
        _parseRssDate(_text(element, 'pubDate') ?? '');

    return FeedItem(
      id: _stableHash('$feedId|$idValue'),
      feedId: feedId,
      title: title,
      description: description,
      content: content,
      url: resolvedLink,
      author:
          _text(element, 'creator') ??
          _text(element, 'author') ??
          _text(_child(element, 'author'), 'name'),
      publishedAt: publishedAt,
      imageUrl: imageUrl,
      type: audioUrl == null ? FeedType.article : FeedType.podcast,
      audioUrl: audioUrl,
      audioDuration: _parseDuration(_text(element, 'duration')),
      chaptersUrl: _resolveUrl(
        baseUri,
        _attribute(_child(element, 'chapters'), 'url'),
      ),
      chapters: ChapterService.normalize(
        _descendants(element, 'chapter').map((node) {
          final start = ChapterService.timestamp(
            _attribute(node, 'start') ?? '',
          );
          return start == null
              ? null
              : PodcastChapter(
                  start: start,
                  title: _attribute(node, 'title') ?? 'Capítulo',
                );
        }).whereType<PodcastChapter>(),
      ),
    );
  }

  static String? _itemImageUrl(XmlElement element, Uri baseUri) {
    final candidates = element.descendants.whereType<XmlElement>().where((
      node,
    ) {
      final name = node.name.local.toLowerCase();
      if (name == 'link' && _attribute(node, 'rel') != 'enclosure') {
        return false;
      }
      return const {
        'thumbnail',
        'image',
        'content',
        'enclosure',
        'link',
      }.contains(name);
    }).toList();
    candidates.sort((a, b) {
      final aThumbnail = a.name.local.toLowerCase() == 'thumbnail';
      final bThumbnail = b.name.local.toLowerCase() == 'thumbnail';
      return aThumbnail == bThumbnail ? 0 : (aThumbnail ? -1 : 1);
    });

    for (final candidate in candidates) {
      final name = candidate.name.local.toLowerCase();
      final mediaType = _attribute(candidate, 'type')?.toLowerCase();
      final value =
          _attribute(candidate, 'url') ??
          _attribute(candidate, 'href') ??
          (name == 'image' ? _text(candidate, 'url') : null);
      final url = _resolveUrl(baseUri, value);
      if (url == null || _isAudio(mediaType, url)) continue;
      final hasImageType = mediaType?.startsWith('image/') == true;
      final isImageElement = name == 'thumbnail' || name == 'image';
      final extension = path.extension(Uri.parse(url).path).toLowerCase();
      final hasImageExtension = const {
        '.avif',
        '.bmp',
        '.gif',
        '.jpeg',
        '.jpg',
        '.png',
        '.webp',
      }.contains(extension);
      if (hasImageType || isImageElement || hasImageExtension) return url;
    }

    final html =
        _text(element, 'encoded') ??
        _text(element, 'description') ??
        _text(element, 'summary');
    final imageTag = html == null
        ? null
        : RegExp(
            r'''<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']''',
            caseSensitive: false,
          ).firstMatch(html);
    return _resolveUrl(baseUri, imageTag?.group(1));
  }

  static bool _isAudio(String? mediaType, String? url) {
    if (mediaType?.toLowerCase().startsWith('audio/') == true) return true;
    if (url == null) return false;
    final extension = path.extension(Uri.parse(url).path).toLowerCase();
    return const {
      'mp3',
      'm4a',
      'm4b',
      'aac',
      'ogg',
      'opus',
      'wav',
      'flac',
    }.contains(extension.replaceFirst('.', ''));
  }

  static Duration? _parseDuration(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.every((part) => int.tryParse(part) != null)) {
      final seconds = parts.fold<int>(
        0,
        (total, part) => total * 60 + int.parse(part),
      );
      return Duration(seconds: seconds);
    }
    final seconds = int.tryParse(value);
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static bool _looksLikeFeed(XmlElement root, XmlElement channel) {
    final name = root.name.local.toLowerCase();
    return name == 'rss' ||
        name == 'feed' ||
        name == 'rdf' ||
        _child(channel, 'item') != null ||
        _child(channel, 'entry') != null;
  }

  static Iterable<XmlElement> _descendants(XmlElement element, String name) =>
      element.descendants.whereType<XmlElement>().where(
        (node) => node.name.local.toLowerCase() == name.toLowerCase(),
      );

  static XmlElement? _child(XmlElement? element, String name) {
    if (element == null) return null;
    for (final child in element.childElements) {
      if (child.name.local.toLowerCase() == name.toLowerCase()) return child;
    }
    return null;
  }

  static String? _text(XmlElement? element, String name) {
    if (element == null) return null;
    final child = _child(element, name);
    final value = child?.innerText.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? _attribute(XmlElement? element, String name) {
    if (element == null) return null;
    for (final attribute in element.attributes) {
      if (attribute.name.local.toLowerCase() == name.toLowerCase()) {
        final value = attribute.value.trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  static String? _resolveUrl(Uri base, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return null;
    final resolved = uri.hasScheme ? uri : base.resolveUri(uri);
    return resolved.hasScheme &&
            (resolved.scheme == 'http' || resolved.scheme == 'https')
        ? resolved.toString()
        : null;
  }

  static Uri _validatedUri(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException(
        'Informe uma URL válida começando com http:// ou https://.',
      );
    }
    return uri;
  }

  static String _canonicalUrl(Uri uri) => uri.removeFragment().toString();

  static DateTime? _parseRssDate(String input) {
    if (input.isEmpty) return null;

    // RSS pubDate commonly uses RFC 822 dates, such as
    // "Sun, 11 Oct 2026 18:00:00 +0000". HttpDate.parse only accepts HTTP
    // date formats, so parse the RSS form before falling back to it.
    final match = RegExp(
      r'^(?:[A-Za-z]{3,9},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{2,4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s+([+-]\d{4}|[A-Za-z]{1,5})$',
    ).firstMatch(input.trim());
    if (match != null) {
      const months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      const namedOffsets = {
        'UT': 0,
        'UTC': 0,
        'GMT': 0,
        'EST': -300,
        'EDT': -240,
        'CST': -360,
        'CDT': -300,
        'MST': -420,
        'MDT': -360,
        'PST': -480,
        'PDT': -420,
      };

      final day = int.parse(match.group(1)!);
      final month = months[match.group(2)!.toLowerCase()];
      var year = int.parse(match.group(3)!);
      final hour = int.parse(match.group(4)!);
      final minute = int.parse(match.group(5)!);
      final second = int.tryParse(match.group(6) ?? '0')!;
      final zone = match.group(7)!;
      if (year < 100) year += year < 50 ? 2000 : 1900;

      int? offsetMinutes;
      if (zone.startsWith('+') || zone.startsWith('-')) {
        final hours = int.tryParse(zone.substring(1, 3));
        final minutes = int.tryParse(zone.substring(3, 5));
        if (hours != null && minutes != null && hours <= 23 && minutes <= 59) {
          final sign = zone.startsWith('-') ? -1 : 1;
          offsetMinutes = sign * (hours * 60 + minutes);
        }
      } else {
        offsetMinutes = namedOffsets[zone.toUpperCase()];
      }

      if (month != null &&
          day >= 1 &&
          hour <= 23 &&
          minute <= 59 &&
          second <= 59 &&
          offsetMinutes != null) {
        final date = DateTime.utc(year, month, day, hour, minute, second);
        if (date.year == year && date.month == month && date.day == day) {
          return date.subtract(Duration(minutes: offsetMinutes)).toLocal();
        }
      }
    }

    try {
      return HttpDate.parse(input).toLocal();
    } on FormatException {
      return null;
    } on HttpException {
      return null;
    }
  }

  static String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  void _replaceItem(FeedItem item) {
    final index = _items.indexWhere((value) => value.id == item.id);
    if (index == -1) {
      _items.add(item);
    } else {
      _items[index] = item;
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

class _ParsedFeed {
  const _ParsedFeed({required this.source, required this.items});

  final FeedSource source;
  final List<FeedItem> items;
}
