class Setting {
  // Sincronização & Rede
  final bool autoRefresh;
  final int refreshIntervalMinutes;
  final bool wifiOnly;
  final bool refreshOnStartup;

  // Leitor & Artigos
  final bool markAsReadOnOpen;
  final bool markAsReadOnScroll;
  final bool downloadImages;
  final bool openInExternalBrowser;
  final bool confirmMarkAllRead;
  final bool compactFeedView;

  // Podcasts & Player de Áudio
  final bool autoplayPodcasts;
  final bool skipSilence;
  final double playbackSpeed;
  final bool savePlaybackPosition;
  final int seekForwardSeconds;
  final int seekBackwardSeconds;
  final bool pauseOnHeadphonesDisconnect;
  final int defaultSleepTimerMinutes;

  // Armazenamento
  final int retentionDays;

  // Notificações
  final bool notifyNews;
  final bool notifyPodcasts;

  const Setting({
    this.autoRefresh = true,
    this.refreshIntervalMinutes = 30,
    this.wifiOnly = false,
    this.refreshOnStartup = true,
    this.markAsReadOnOpen = true,
    this.markAsReadOnScroll = false,
    this.downloadImages = true,
    this.openInExternalBrowser = false,
    this.confirmMarkAllRead = true,
    this.compactFeedView = false,
    this.autoplayPodcasts = false,
    this.skipSilence = false,
    this.playbackSpeed = 1.0,
    this.savePlaybackPosition = true,
    this.seekForwardSeconds = 30,
    this.seekBackwardSeconds = 15,
    this.pauseOnHeadphonesDisconnect = true,
    this.defaultSleepTimerMinutes = 30,
    this.retentionDays = 30,
    this.notifyNews = true,
    this.notifyPodcasts = true,
  });

  Setting copyWith({
    bool? autoRefresh,
    int? refreshIntervalMinutes,
    bool? wifiOnly,
    bool? refreshOnStartup,
    bool? markAsReadOnOpen,
    bool? markAsReadOnScroll,
    bool? downloadImages,
    bool? openInExternalBrowser,
    bool? confirmMarkAllRead,
    bool? compactFeedView,
    bool? autoplayPodcasts,
    bool? skipSilence,
    double? playbackSpeed,
    bool? savePlaybackPosition,
    int? seekForwardSeconds,
    int? seekBackwardSeconds,
    bool? pauseOnHeadphonesDisconnect,
    int? defaultSleepTimerMinutes,
    int? retentionDays,
    bool? notifyNews,
    bool? notifyPodcasts,
  }) {
    return Setting(
      autoRefresh: autoRefresh ?? this.autoRefresh,
      refreshIntervalMinutes:
          refreshIntervalMinutes ?? this.refreshIntervalMinutes,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      refreshOnStartup: refreshOnStartup ?? this.refreshOnStartup,
      markAsReadOnOpen: markAsReadOnOpen ?? this.markAsReadOnOpen,
      markAsReadOnScroll: markAsReadOnScroll ?? this.markAsReadOnScroll,
      downloadImages: downloadImages ?? this.downloadImages,
      openInExternalBrowser:
          openInExternalBrowser ?? this.openInExternalBrowser,
      confirmMarkAllRead: confirmMarkAllRead ?? this.confirmMarkAllRead,
      compactFeedView: compactFeedView ?? this.compactFeedView,
      autoplayPodcasts: autoplayPodcasts ?? this.autoplayPodcasts,
      skipSilence: skipSilence ?? this.skipSilence,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      savePlaybackPosition: savePlaybackPosition ?? this.savePlaybackPosition,
      seekForwardSeconds: seekForwardSeconds ?? this.seekForwardSeconds,
      seekBackwardSeconds: seekBackwardSeconds ?? this.seekBackwardSeconds,
      pauseOnHeadphonesDisconnect:
          pauseOnHeadphonesDisconnect ?? this.pauseOnHeadphonesDisconnect,
      defaultSleepTimerMinutes:
          defaultSleepTimerMinutes ?? this.defaultSleepTimerMinutes,
      retentionDays: retentionDays ?? this.retentionDays,
      notifyNews: notifyNews ?? this.notifyNews,
      notifyPodcasts: notifyPodcasts ?? this.notifyPodcasts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoRefresh': autoRefresh,
      'refreshIntervalMinutes': refreshIntervalMinutes,
      'wifiOnly': wifiOnly,
      'refreshOnStartup': refreshOnStartup,
      'markAsReadOnOpen': markAsReadOnOpen,
      'markAsReadOnScroll': markAsReadOnScroll,
      'downloadImages': downloadImages,
      'openInExternalBrowser': openInExternalBrowser,
      'confirmMarkAllRead': confirmMarkAllRead,
      'compactFeedView': compactFeedView,
      'autoplayPodcasts': autoplayPodcasts,
      'skipSilence': skipSilence,
      'playbackSpeed': playbackSpeed,
      'savePlaybackPosition': savePlaybackPosition,
      'seekForwardSeconds': seekForwardSeconds,
      'seekBackwardSeconds': seekBackwardSeconds,
      'pauseOnHeadphonesDisconnect': pauseOnHeadphonesDisconnect,
      'defaultSleepTimerMinutes': defaultSleepTimerMinutes,
      'retentionDays': retentionDays,
      'notifyNews': notifyNews,
      'notifyPodcasts': notifyPodcasts,
    };
  }

  factory Setting.fromMap(Map<String, dynamic> map) {
    return Setting(
      autoRefresh: map['autoRefresh'] as bool? ?? true,
      refreshIntervalMinutes: map['refreshIntervalMinutes'] as int? ?? 30,
      wifiOnly: map['wifiOnly'] as bool? ?? false,
      refreshOnStartup: map['refreshOnStartup'] as bool? ?? true,
      markAsReadOnOpen: map['markAsReadOnOpen'] as bool? ?? true,
      markAsReadOnScroll: map['markAsReadOnScroll'] as bool? ?? false,
      downloadImages: map['downloadImages'] as bool? ?? true,
      openInExternalBrowser: map['openInExternalBrowser'] as bool? ?? false,
      confirmMarkAllRead: map['confirmMarkAllRead'] as bool? ?? true,
      compactFeedView: map['compactFeedView'] as bool? ?? false,
      autoplayPodcasts: map['autoplayPodcasts'] as bool? ?? false,
      skipSilence: map['skipSilence'] as bool? ?? false,
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      savePlaybackPosition: map['savePlaybackPosition'] as bool? ?? true,
      seekForwardSeconds: map['seekForwardSeconds'] as int? ?? 30,
      seekBackwardSeconds: map['seekBackwardSeconds'] as int? ?? 15,
      pauseOnHeadphonesDisconnect:
          map['pauseOnHeadphonesDisconnect'] as bool? ?? true,
      defaultSleepTimerMinutes: map['defaultSleepTimerMinutes'] as int? ?? 30,
      retentionDays: map['retentionDays'] as int? ?? 30,
      notifyNews: map['notifyNews'] as bool? ?? true,
      notifyPodcasts: map['notifyPodcasts'] as bool? ?? true,
    );
  }

  static const Setting defaults = Setting();
}
