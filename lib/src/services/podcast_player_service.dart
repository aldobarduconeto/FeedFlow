import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'podcast_audio_engine.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/feed.dart';
import 'feed_service.dart';

class PodcastPlayerService extends ChangeNotifier {
  PodcastPlayerService({required this.feedService, AudioPlayer? audioPlayer})
    : _player = PodcastAudioEngine(player: audioPlayer) {
    _errorSubscription = _player.errors.listen((error) {
      _error = 'Falha na reprodução: $error';
      notifyListeners();
    });
    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      _playerState = state;
      if (state == PlayerState.playing) {
        _positionSaveTimer ??= Timer.periodic(
          const Duration(seconds: 30),
          (_) => unawaited(_savePlaybackPosition()),
        );
      } else {
        _positionSaveTimer?.cancel();
        _positionSaveTimer = null;
      }
      notifyListeners();
    });
    _positionSubscription = _player.onPositionChanged.listen((position) {
      _position = position;
      notifyListeners();
    });
    _durationSubscription = _player.onDurationChanged.listen((duration) {
      _duration = duration;
      notifyListeners();
    });
    _completionSubscription = _player.onPlayerComplete.listen((_) {
      _position = _duration ?? _position;
      unawaited(_finishEpisode());
      notifyListeners();
    });
  }

  final FeedService feedService;
  final PodcastAudioEngine _player;
  StreamSubscription<Object>? _errorSubscription;
  final Map<String, double> _speeds = {};
  bool _dialogue = false;
  bool get enhanceDialogue => _dialogue;
  bool get supportsDialogue => _player.supportsDialogue;
  SharedPreferences? _preferences;

  Future<void> initializePreferences() async {
    _preferences = await SharedPreferences.getInstance();
    final saved = _preferences!.getString('podcast.speeds');
    if (saved != null) {
      try {
        final map = jsonDecode(saved) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final value = entry.value;
          if (value is num && value.isFinite) {
            _speeds[entry.key] = value.toDouble().clamp(0.8, 2.0);
          }
        }
      } on FormatException {
        _speeds.clear();
      } on TypeError {
        _speeds.clear();
      }
    }
    _dialogue =
        supportsDialogue &&
        (_preferences!.getBool('podcast.dialogue') ?? false);
  }

  Future<void> setEnhanceDialogue(bool enabled) async {
    await _player.enhanceDialogue(enabled);
    _dialogue = enabled;
    await _preferences?.setBool('podcast.dialogue', enabled);
    notifyListeners();
  }

  final List<FeedItem> _queue = [];
  List<FeedItem> get queue => List.unmodifiable(_queue);

  void enqueue(FeedItem item, {bool next = false}) {
    if (!item.isPodcast || !item.hasAudio || isCurrent(item)) return;
    _queue.removeWhere((entry) => entry.id == item.id);
    if (next) {
      _queue.insert(0, item);
    } else {
      _queue.add(item);
    }
    notifyListeners();
  }

  void removeFromQueue(String id) {
    _queue.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void clearQueue() {
    _queue.clear();
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    notifyListeners();
  }

  Future<void> _finishEpisode() async {
    await _savePlaybackPosition();
    if (_queue.isEmpty || _isLoading) return;
    try {
      await playNext();
    } catch (_) {
      // toggle exposes the playback error to the UI; keep the queue for retry.
    }
  }

  Future<void> playNext() async {
    if (_queue.isEmpty || _isLoading) return;
    final queued = _queue.first;
    final item = feedService.items.firstWhere(
      (entry) => entry.id == queued.id,
      orElse: () => queued,
    );
    await toggle(item);
  }

  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<void>? _completionSubscription;
  Timer? _positionSaveTimer;
  FeedItem? _currentItem;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration? _duration;
  String? _error;
  bool _isLoading = false;

  FeedItem? get currentItem => _currentItem;
  PlayerState get playerState => _playerState;
  Duration get position => _position;
  Duration? get duration => _duration;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isPlaying => _playerState == PlayerState.playing;

  bool isCurrent(FeedItem item) => _currentItem?.id == item.id;

  Future<void> toggle(FeedItem item) async {
    if (!item.isPodcast || !item.hasAudio) {
      throw const FormatException('Este episódio não possui áudio.');
    }
    if (isCurrent(item)) {
      if (_isLoading) return;
      if (isPlaying) {
        await _player.pause();
        await _savePlaybackPosition();
      } else {
        _error = null;
        if (_playerState == PlayerState.completed) {
          _position = Duration.zero;
          await _player.seek(Duration.zero);
        }
        await _player.resume();
      }
      return;
    }

    if (_isLoading) return;
    _isLoading = true;
    await _savePlaybackPosition();
    _positionSaveTimer?.cancel();
    _positionSaveTimer = null;
    _isLoading = true;
    _error = null;
    _currentItem = item;
    _playbackSpeed = _speeds[item.feedId] ?? 1.0;
    final resumePosition = item.playbackPosition ?? Duration.zero;
    _position = resumePosition;
    _duration = item.audioDuration;
    notifyListeners();

    try {
      await _player.stop();
      final source = await _sourceFor(item);
      await _player.setSource(source);
      await _player.setPlaybackRate(_playbackSpeed);
      if (_dialogue) {
        try {
          await _player.enhanceDialogue(true);
        } catch (error) {
          _dialogue = false;
          _error = 'Aprimorar diálogo indisponível: $error';
        }
      }
      if (resumePosition > Duration.zero) {
        await _player.seek(resumePosition);
      }
      await _player.resume();
      _queue.removeWhere((entry) => entry.id == item.id);
    } catch (error) {
      _error = 'Não foi possível reproduzir o episódio: $error';
      _currentItem = null;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  Future<void> setPlaybackSpeed(double speed) async {
    if (!speed.isFinite || speed < 0.8 || speed > 2.0) {
      throw ArgumentError('A velocidade deve estar entre 0,8x e 2x.');
    }
    await _player.setPlaybackRate(speed);
    _playbackSpeed = speed;
    final item = _currentItem;
    if (item != null) {
      _speeds[item.feedId] = speed;
      await _preferences?.setString('podcast.speeds', jsonEncode(_speeds));
    }
    notifyListeners();
  }

  Future<void> skipForward([
    Duration offset = const Duration(seconds: 30),
  ]) async {
    await seek(_position + offset);
  }

  Future<void> skipBackward([
    Duration offset = const Duration(seconds: 15),
  ]) async {
    final newPosition = _position - offset;
    await seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  Future<Source> _sourceFor(FeedItem item) async {
    final savedPath = item.downloadedAudioPath;
    if (!kIsWeb && savedPath != null && await File(savedPath).exists()) {
      return DeviceFileSource(savedPath);
    }
    return UrlSource(item.audioUrl!);
  }

  Future<void> _savePlaybackPosition() async {
    final item = _currentItem;
    if (item == null || _position == item.playbackPosition) return;
    final position = _position;
    try {
      await feedService.savePlaybackPosition(item, position);
      if (_currentItem?.id == item.id) {
        _currentItem = item.copyWith(playbackPosition: position);
      }
    } catch (error) {
      _error = 'Não foi possível salvar a posição do episódio: $error';
      notifyListeners();
    }
  }

  Future<void> seek(Duration position) async {
    final maximum = _duration;
    final boundedPosition = maximum == null
        ? position
        : Duration(
            milliseconds: position.inMilliseconds.clamp(
              0,
              maximum.inMilliseconds,
            ),
          );
    await _player.seek(boundedPosition);
    _position = boundedPosition;
    await _savePlaybackPosition();
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSaveTimer?.cancel();
    unawaited(_savePlaybackPosition());
    unawaited(_errorSubscription?.cancel());
    unawaited(_stateSubscription?.cancel());
    unawaited(_positionSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(_completionSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }
}
