import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/suggested_feed.dart';

import 'package:flutter/foundation.dart';

class ExternalFeed {
  const ExternalFeed({
    required this.name,
    required this.description,
    required this.url,
    required this.kind,
    this.slug,
  });

  final String name;
  final String description;
  final String url;
  final String kind;
  final String? slug;

  SuggestedFeed toSuggestedFeed() {
    final category = _mapKindToCategory(kind);
    return SuggestedFeed(
      name: name,
      description: description,
      url: url,
      category: category,
      isPodcast: kind == 'podcast',
    );
  }

  String _mapKindToCategory(String kind) {
    switch (kind.toLowerCase()) {
      case 'podcast':
        return 'Podcasts';
      case 'news':
        return 'Notícias';
      case 'music':
      case 'video':
      case 'comic':
        return 'Entretenimento';
      default:
        return 'Tecnologia';
    }
  }
}

class DiscoveryService extends ChangeNotifier {
  static const _rssAmplifierBaseUrl = 'https://rssamplifier.com/api';
  static const _p0dcastersBaseUrl = 'https://p0dcasters.com/api';

  bool isSearching = false;
  List<SuggestedFeed> searchResults = [];
  String? lastSearchQuery;
  String? searchError;

  Future<List<SuggestedFeed>> searchFeeds(String query) async {
    if (query.trim().isEmpty) {
      searchResults = [];
      lastSearchQuery = null;
      searchError = null;
      notifyListeners();
      return [];
    }

    isSearching = true;
    lastSearchQuery = query;
    searchError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _searchRSSAmplifier(query),
        _searchP0dcasters(query),
      ]);

      final allResults = [...results[0], ...results[1]];

      // Remove duplicates based on URL
      final uniqueResults = <SuggestedFeed>[];
      final seenUrls = <String>{};

      for (final feed in allResults) {
        if (!seenUrls.contains(feed.url)) {
          seenUrls.add(feed.url);
          uniqueResults.add(feed);
        }
      }

      searchResults = uniqueResults;
      notifyListeners();
      return uniqueResults;
    } catch (e) {
      searchError = e.toString();
      searchResults = [];
      notifyListeners();
      return [];
    } finally {
      isSearching = false;
      notifyListeners();
    }
  }

  Future<List<SuggestedFeed>> _searchRSSAmplifier(String query) async {
    try {
      final uri = Uri.parse('$_rssAmplifierBaseUrl/search')
          .replace(queryParameters: {'q': query, 'limit': '60'});

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final feeds = data['feeds'] as List<dynamic>? ?? [];

      return feeds
          .map((item) => _parseRSSAmplifierFeed(item as Map<String, dynamic>))
          .where((feed) => feed != null)
          .cast<SuggestedFeed>()
          .toList();
    } catch (e) {
      if (kDebugMode) print('RSS Amplifier search error: $e');
      return [];
    }
  }

  Future<List<SuggestedFeed>> _searchP0dcasters(String query) async {
    try {
      final uri = Uri.parse('$_p0dcastersBaseUrl/search')
          .replace(queryParameters: {'q': query, 'limit': '30'});

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body) as List<dynamic>;

      return data
          .map((item) => _parseP0dcastersFeed(item as Map<String, dynamic>))
          .where((feed) => feed != null)
          .cast<SuggestedFeed>()
          .toList();
    } catch (e) {
      if (kDebugMode) print('p0dcasters search error: $e');
      return [];
    }
  }

  SuggestedFeed? _parseRSSAmplifierFeed(Map<String, dynamic> data) {
    try {
      final url = data['feed_url'] as String? ?? data['url'] as String?;
      final name = data['title'] as String? ?? data['name'] as String?;
      final description = data['description'] as String? ?? '';
      final kind = data['kind'] as String? ?? 'blog';

      if (url == null || url.isEmpty || name == null || name.isEmpty) {
        return null;
      }

      return SuggestedFeed(
        name: name,
        description: description,
        url: url,
        category: _mapKindToCategory(kind),
        isPodcast: kind == 'podcast',
      );
    } catch (e) {
      if (kDebugMode) print('Error parsing RSS Amplifier feed: $e');
      return null;
    }
  }

  SuggestedFeed? _parseP0dcastersFeed(Map<String, dynamic> data) {
    try {
      final url = data['feed_url'] as String? ?? data['rss'] as String?;
      final name = data['title'] as String? ?? data['name'] as String?;
      final description = data['description'] as String? ?? '';

      if (url == null || url.isEmpty || name == null || name.isEmpty) {
        return null;
      }

      return SuggestedFeed(
        name: name,
        description: description,
        url: url,
        category: 'Podcasts',
        isPodcast: true,
      );
    } catch (e) {
      if (kDebugMode) print('Error parsing p0dcasters feed: $e');
      return null;
    }
  }

  String _mapKindToCategory(String kind) {
    switch (kind.toLowerCase()) {
      case 'podcast':
        return 'Podcasts';
      case 'news':
        return 'Notícias';
      case 'music':
      case 'video':
      case 'comic':
        return 'Entretenimento';
      default:
        return 'Tecnologia';
    }
  }

  Future<List<SuggestedFeed>> browseByCategory(String category) async {
    try {
      final kind = _categoryToKind(category);
      if (kind == null) return [];

      final uri = Uri.parse('$_rssAmplifierBaseUrl/feeds')
          .replace(queryParameters: {'kind': kind, 'limit': '90'});

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body) as List<dynamic>;

      return data
          .map((item) => _parseRSSAmplifierFeed(item as Map<String, dynamic>))
          .where((feed) => feed != null)
          .cast<SuggestedFeed>()
          .toList();
    } catch (e) {
      if (kDebugMode) print('Browse by category error: $e');
      return [];
    }
  }

  String? _categoryToKind(String category) {
    switch (category) {
      case 'Podcasts':
        return 'podcast';
      case 'Notícias':
        return 'news';
      case 'Tecnologia':
        return 'blog';
      default:
        return null;
    }
  }
}
