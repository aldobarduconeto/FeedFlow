class CatalogFeedLink {
  final String url;
  final String categoryName;
  final bool isPodcast;

  const CatalogFeedLink({
    required this.url,
    required this.categoryName,
    required this.isPodcast,
  });
}

class CatalogDomainEntry {
  final String host;
  final int countryIndex;
  final String countryName;
  final int? rank;
  final int? avgLen;
  final List<String> languages;
  final List<CatalogFeedLink> feeds;
  final String? summary;
  final List<String> categories;

  const CatalogDomainEntry({
    required this.host,
    required this.countryIndex,
    required this.countryName,
    this.rank,
    this.avgLen,
    required this.languages,
    required this.feeds,
    this.summary,
    required this.categories,
  });

  int get channelCount => feeds.where((f) => !f.isPodcast).length;
  int get podcastCount => feeds.where((f) => f.isPodcast).length;

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (host.toLowerCase().contains(q)) return true;
    if (summary != null && summary!.toLowerCase().contains(q)) return true;
    if (categories.any((c) => c.toLowerCase().contains(q))) return true;
    return false;
  }
}
