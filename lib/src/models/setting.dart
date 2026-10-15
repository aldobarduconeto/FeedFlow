class Setting {
  final bool autoRefresh;
  final int refreshIntervalMinutes;
  final bool wifiOnly;
  final bool markAsReadOnOpen;
  final bool downloadImages;
  final bool autoplayPodcasts;
  final bool skipSilence;
  final double playbackSpeed;
  final int retentionDays;
  final bool savePlaybackPosition;

  const Setting({
    this.autoRefresh = true,
    this.refreshIntervalMinutes = 30,
    this.wifiOnly = false,
    this.markAsReadOnOpen = true,
    this.downloadImages = true,
    this.autoplayPodcasts = false,
    this.skipSilence = false,
    this.playbackSpeed = 1.0,
    this.retentionDays = 30,
    this.savePlaybackPosition = true,
  });

  Setting copyWith({
    bool? autoRefresh,
    int? refreshIntervalMinutes,
    bool? wifiOnly,
    bool? markAsReadOnOpen,
    bool? downloadImages,
    bool? autoplayPodcasts,
    bool? skipSilence,
    double? playbackSpeed,
    int? retentionDays,
    bool? savePlaybackPosition,
  }) {
    return Setting(
      autoRefresh: autoRefresh ?? this.autoRefresh,
      refreshIntervalMinutes:
          refreshIntervalMinutes ?? this.refreshIntervalMinutes,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      markAsReadOnOpen: markAsReadOnOpen ?? this.markAsReadOnOpen,
      downloadImages: downloadImages ?? this.downloadImages,
      autoplayPodcasts: autoplayPodcasts ?? this.autoplayPodcasts,
      skipSilence: skipSilence ?? this.skipSilence,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      retentionDays: retentionDays ?? this.retentionDays,
      savePlaybackPosition: savePlaybackPosition ?? this.savePlaybackPosition,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoRefresh': autoRefresh,
      'refreshIntervalMinutes': refreshIntervalMinutes,
      'wifiOnly': wifiOnly,
      'markAsReadOnOpen': markAsReadOnOpen,
      'downloadImages': downloadImages,
      'autoplayPodcasts': autoplayPodcasts,
      'skipSilence': skipSilence,
      'playbackSpeed': playbackSpeed,
      'retentionDays': retentionDays,
      'savePlaybackPosition': savePlaybackPosition,
    };
  }

  factory Setting.fromMap(Map<String, dynamic> map) {
    return Setting(
      autoRefresh: map['autoRefresh'] as bool? ?? true,
      refreshIntervalMinutes: map['refreshIntervalMinutes'] as int? ?? 30,
      wifiOnly: map['wifiOnly'] as bool? ?? false,
      markAsReadOnOpen: map['markAsReadOnOpen'] as bool? ?? true,
      downloadImages: map['downloadImages'] as bool? ?? true,
      autoplayPodcasts: map['autoplayPodcasts'] as bool? ?? false,
      skipSilence: map['skipSilence'] as bool? ?? false,
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      retentionDays: map['retentionDays'] as int? ?? 30,
      savePlaybackPosition: map['savePlaybackPosition'] as bool? ?? true,
    );
  }
  static const Setting defaults = Setting();
}
