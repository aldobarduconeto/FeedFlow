import '../models/feed.dart';
import '../models/suggested_feed.dart';
import 'feed_service.dart';

import 'package:flutter/foundation.dart';

class SuggestionPreview {
  const SuggestionPreview({required this.items, this.error});

  final List<FeedItem> items;
  final String? error;

  bool get hasError => error != null;
}

/// Loads live entries for the catalog without adding the sources to the user.
class SuggestionService extends ChangeNotifier {
  static const _maxConcurrentRequests = 3;

  SuggestionService(this._feedService);

  final FeedService _feedService;
  Map<String, SuggestionPreview> _previews = const {};
  bool isRefreshing = false;
  DateTime? lastUpdatedAt;
  Future<void>? _refreshOperation;
  bool _isDisposed = false;

  Map<String, SuggestionPreview> get previews => Map.unmodifiable(_previews);

  Future<void> refresh(Iterable<SuggestedFeed> suggestions) async {
    if (_isDisposed) return;
    final currentOperation = _refreshOperation;
    if (currentOperation != null) {
      await currentOperation;
      return;
    }
    final operation = _refresh(suggestions);
    _refreshOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_refreshOperation, operation)) _refreshOperation = null;
    }
  }

  Future<void> _refresh(Iterable<SuggestedFeed> suggestions) async {
    isRefreshing = true;
    _notifyListeners();
    try {
      final feeds = suggestions.toList(growable: false);
      final results = <MapEntry<String, SuggestionPreview>>[];
      for (
        var start = 0;
        start < feeds.length;
        start += _maxConcurrentRequests
      ) {
        final end = (start + _maxConcurrentRequests).clamp(0, feeds.length);
        results.addAll(
          await Future.wait(
            feeds.sublist(start, end).map((suggestion) async {
              try {
                final items = await _feedService.previewFeed(suggestion.url);
                return MapEntry(
                  suggestion.url,
                  SuggestionPreview(items: items),
                );
              } catch (error) {
                return MapEntry(
                  suggestion.url,
                  SuggestionPreview(items: const [], error: error.toString()),
                );
              }
            }),
          ),
        );
      }
      _previews = {
        ..._previews,
        for (final result in results) result.key: result.value,
      };
      lastUpdatedAt = DateTime.now();
    } finally {
      isRefreshing = false;
      _notifyListeners();
    }
  }

  void _notifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
