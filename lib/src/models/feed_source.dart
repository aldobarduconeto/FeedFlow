import 'feed.dart';

class FeedSource {
  final String id;
  final String url;
  final String title;
  final String description;
  final String category;
  final FeedType type;

  const FeedSource({
    required this.id,
    required this.url,
    required this.title,
    this.description = '',
    this.category = 'Personalizados',
    this.type = FeedType.article,
  });

  bool get isPodcast => type == FeedType.podcast;

  FeedSource copyWith({
    String? title,
    String? description,
    String? category,
    FeedType? type,
  }) {
    return FeedSource(
      id: id,
      url: url,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'url': url,
    'title': title,
    'description': description,
    'category': category,
    'type': type.name,
  };

  factory FeedSource.fromMap(Map<String, dynamic> map) {
    return FeedSource(
      id: map['id'] as String,
      url: map['url'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'Personalizados',
      type: FeedType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => FeedType.article,
      ),
    );
  }
}
