class PodcastChapter {
  const PodcastChapter({required this.start, required this.title});
  final Duration start;
  final String title;
  Map<String, dynamic> toMap() => {
    'startTime': start.inMilliseconds / 1000,
    'title': title,
  };
  static PodcastChapter? fromMap(Map<String, dynamic> map) {
    final seconds = map['startTime'];
    if (seconds is! num || !seconds.isFinite || seconds < 0) return null;
    return PodcastChapter(
      start: Duration(milliseconds: (seconds * 1000).round()),
      title: map['title'] as String? ?? 'Capítulo',
    );
  }
}
