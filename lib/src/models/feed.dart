import 'podcast_chapter.dart';

enum FeedType { article, podcast }

class FeedItem {
  final List<PodcastChapter> chapters;
  final String? chaptersUrl;
  final String id;
  final String feedId;
  final String title;
  final String? description;
  final String? content;
  final String? url;
  final String? imageUrl;
  final String? author;
  final DateTime? publishedAt;
  final FeedType type;
  final bool isRead;
  final bool isFavorite;
  final String? audioUrl;
  final Duration? audioDuration;
  final Duration? playbackPosition;
  final double? readingProgress;
  final DateTime? updatedAt;
  final String? downloadedAudioPath;

  const FeedItem({
    this.chapters = const [],
    this.chaptersUrl,
    required this.id,
    required this.feedId,
    required this.title,
    this.description,
    this.content,
    this.url,
    this.imageUrl,
    this.author,
    this.publishedAt,
    this.type = FeedType.article,
    this.isRead = false,
    this.isFavorite = false,
    this.audioUrl,
    this.audioDuration,
    this.playbackPosition,
    this.readingProgress,
    this.updatedAt,
    this.downloadedAudioPath,
  });

  bool get isPodcast => type == FeedType.podcast;
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasPlaybackPosition =>
      playbackPosition != null && playbackPosition! > Duration.zero;

  FeedItem copyWith({
    List<PodcastChapter>? chapters,
    String? chaptersUrl,
    String? id,
    String? feedId,
    String? title,
    String? description,
    String? content,
    String? url,
    String? imageUrl,
    String? author,
    DateTime? publishedAt,
    FeedType? type,
    bool? isRead,
    bool? isFavorite,
    String? audioUrl,
    Duration? audioDuration,
    Duration? playbackPosition,
    double? readingProgress,
    DateTime? updatedAt,
    String? downloadedAudioPath,
  }) {
    return FeedItem(
      chapters: chapters ?? this.chapters,
      chaptersUrl: chaptersUrl ?? this.chaptersUrl,
      id: id ?? this.id,
      feedId: feedId ?? this.feedId,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      url: url ?? this.url,
      imageUrl: imageUrl ?? this.imageUrl,
      author: author ?? this.author,
      publishedAt: publishedAt ?? this.publishedAt,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      isFavorite: isFavorite ?? this.isFavorite,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      readingProgress: readingProgress ?? this.readingProgress,
      updatedAt: updatedAt ?? this.updatedAt,
      downloadedAudioPath: downloadedAudioPath ?? this.downloadedAudioPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chapters': chapters.map((c) => c.toMap()).toList(),
      'chaptersUrl': chaptersUrl,
      'id': id,
      'feedId': feedId,
      'title': title,
      'description': description,
      'content': content,
      'url': url,
      'imageUrl': imageUrl,
      'author': author,
      'publishedAt': publishedAt?.toIso8601String(),
      'type': type.name,
      'isRead': isRead,
      'isFavorite': isFavorite,
      'audioUrl': audioUrl,
      'audioDurationMs': audioDuration?.inMilliseconds,
      'playbackPositionMs': playbackPosition?.inMilliseconds,
      'readingProgress': readingProgress,
      'updatedAt': updatedAt?.toIso8601String(),
      'downloadedAudioPath': downloadedAudioPath,
    };
  }

  factory FeedItem.fromMap(Map<String, dynamic> map) {
    return FeedItem(
      chapters: (map['chapters'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PodcastChapter.fromMap)
          .whereType<PodcastChapter>()
          .toList(),
      chaptersUrl: map['chaptersUrl'] as String?,
      id: map['id'] as String,
      feedId: map['feedId'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      content: map['content'] as String?,
      url: map['url'] as String?,
      imageUrl: map['imageUrl'] as String?,
      author: map['author'] as String?,
      publishedAt: map['publishedAt'] != null
          ? DateTime.tryParse(map['publishedAt'] as String)
          : null,
      type: FeedType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => FeedType.article,
      ),
      isRead: map['isRead'] as bool? ?? false,
      isFavorite: map['isFavorite'] as bool? ?? false,
      audioUrl: map['audioUrl'] as String?,
      audioDuration: map['audioDurationMs'] != null
          ? Duration(milliseconds: (map['audioDurationMs'] as num).toInt())
          : null,
      playbackPosition: map['playbackPositionMs'] != null
          ? Duration(milliseconds: (map['playbackPositionMs'] as num).toInt())
          : null,
      readingProgress: (map['readingProgress'] as num?)?.toDouble(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
      downloadedAudioPath: map['downloadedAudioPath'] as String?,
    );
  }
  static const FeedItem empty = FeedItem(id: '', feedId: '', title: '');
}
