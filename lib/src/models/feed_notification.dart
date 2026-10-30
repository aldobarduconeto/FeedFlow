class FeedNotification {
  final String id;
  final String title;
  final String publisher;
  final String feedId;
  final String itemId;
  final bool isPodcast;
  final DateTime publishedAt;
  final DateTime receivedAt;
  final bool isRead;
  final String? imageUrl;
  final String? audioUrl;

  const FeedNotification({
    required this.id,
    required this.title,
    required this.publisher,
    required this.feedId,
    required this.itemId,
    this.isPodcast = false,
    required this.publishedAt,
    required this.receivedAt,
    this.isRead = false,
    this.imageUrl,
    this.audioUrl,
  });

  FeedNotification copyWith({
    String? id,
    String? title,
    String? publisher,
    String? feedId,
    String? itemId,
    bool? isPodcast,
    DateTime? publishedAt,
    DateTime? receivedAt,
    bool? isRead,
    String? imageUrl,
    String? audioUrl,
  }) {
    return FeedNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      publisher: publisher ?? this.publisher,
      feedId: feedId ?? this.feedId,
      itemId: itemId ?? this.itemId,
      isPodcast: isPodcast ?? this.isPodcast,
      publishedAt: publishedAt ?? this.publishedAt,
      receivedAt: receivedAt ?? this.receivedAt,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'publisher': publisher,
      'feedId': feedId,
      'itemId': itemId,
      'isPodcast': isPodcast,
      'publishedAt': publishedAt.toIso8601String(),
      'receivedAt': receivedAt.toIso8601String(),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
    };
  }

  factory FeedNotification.fromMap(Map<String, dynamic> map) {
    return FeedNotification(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Sem título',
      publisher: map['publisher'] as String? ?? 'Desconhecido',
      feedId: map['feedId'] as String? ?? '',
      itemId: map['itemId'] as String? ?? '',
      isPodcast: map['isPodcast'] as bool? ?? false,
      publishedAt: map['publishedAt'] != null
          ? DateTime.tryParse(map['publishedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      receivedAt: map['receivedAt'] != null
          ? DateTime.tryParse(map['receivedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
      imageUrl: map['imageUrl'] as String?,
      audioUrl: map['audioUrl'] as String?,
    );
  }
}
