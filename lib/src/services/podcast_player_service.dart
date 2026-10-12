import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/feed.dart';
import 'feed_service.dart';

class PodcastPlayerService extends ChangeNotifier {
  PodcastPlayerService({required this.feedService}) {
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
      unawaited(_savePlaybackPosition());
      notifyListeners();
    });
  }

  final FeedService feedService;
  final AudioPlayer _player = AudioPlayer();

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

    _positionSaveTimer?.cancel();
    _positionSaveTimer = null;
    _isLoading = true;
    _error = null;
    _currentItem = item;
    _position = item.playbackPosition ?? Duration.zero;
    _duration = item.audioDuration;
    notifyListeners();

    try {
      await _player.stop();
      final source = await _sourceFor(item);
      await _player.setSource(source);
      if (_position > Duration.zero) {
        await _player.seek(_position);
      }
      await _player.resume();
    } catch (error) {
      _error = 'Não foi possível reproduzir o episódio: $error';
      _currentItem = null;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    try {
      await feedService.savePlaybackPosition(item, _position);
      _currentItem = item.copyWith(playbackPosition: _position);
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
    unawaited(_stateSubscription?.cancel());
    unawaited(_positionSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(_completionSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }
}
