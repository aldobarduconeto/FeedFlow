import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:media_kit/media_kit.dart' as mk;

import 'audio_backend.dart';

AudioBackend createEffectsBackend() => NativeEffectsBackend();

class NativeEffectsBackend extends AudioBackend {
  NativeEffectsBackend() {
    mk.MediaKit.ensureInitialized();
    _player = mk.Player();
    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        _states.add(
          _player.state.completed
              ? PlayerState.completed
              : playing
              ? PlayerState.playing
              : PlayerState.paused,
        );
      }),
    );
    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        if (completed) _states.add(PlayerState.completed);
      }),
    );
    _subscriptions.add(_player.stream.error.listen(_errors.add));
  }
  late final mk.Player _player;
  final _states = StreamController<PlayerState>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  @override
  bool get supportsDialogue => _player.platform is mk.NativePlayer;
  @override
  Stream<PlayerState> get states => _states.stream;
  @override
  Stream<Duration> get positions => _player.stream.position;
  @override
  Stream<Duration> get durations => _player.stream.duration;
  @override
  Stream<void> get completions =>
      _player.stream.completed.distinct().where((value) => value).map((_) {});
  @override
  Stream<Object> get errors => _errors.stream;
  @override
  Future<void> setSource(Source source) async {
    final url = source is DeviceFileSource
        ? Uri.file(source.path).toString()
        : source is UrlSource
        ? source.url
        : throw UnsupportedError('Fonte de áudio inválida.');
    await _player.open(mk.Media(url), play: false);
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> resume() => _player.play();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setRate(double speed) => _player.setRate(speed);
  @override
  Future<void> enhanceDialogue(bool enabled) async {
    final native = _player.platform;
    if (native is! mk.NativePlayer)
      throw UnsupportedError('Filtros de áudio indisponíveis.');
    try {
      await native.setProperty(
        'af',
        enabled ? DialogueProfile.nativeFilter : '',
      );
      final applied = await native.getProperty('af');
      if (enabled && (!applied.contains('equalizer') || !applied.contains('bass'))) {
        throw UnsupportedError('Este motor não conseguiu aplicar o filtro de voz.');
      }
      if (!enabled && applied.isNotEmpty) {
        throw StateError('Não foi possível desativar o filtro de voz.');
      }
    } catch (_) {
      await native.setProperty('af', '');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _states.close();
    await _errors.close();
  }
}
