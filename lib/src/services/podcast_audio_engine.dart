import 'package:audioplayers/audioplayers.dart';

import 'audio_backend.dart';
import 'effects_backend_native.dart'
    if (dart.library.js_interop) 'effects_backend_web.dart';

/// Both native and browser backends apply the same speech equalization profile.
/// The optional standard player keeps transport tests independent of hardware.
class PodcastAudioEngine {
  PodcastAudioEngine({AudioPlayer? player}) : _standard = player {
    if (player == null) _effects = createEffectsBackend();
  }
  final AudioPlayer? _standard;
  AudioBackend? _effects;
  bool get supportsDialogue => _effects?.supportsDialogue ?? false;
  Stream<PlayerState> get onPlayerStateChanged =>
      _standard?.onPlayerStateChanged ?? _effects!.states;
  Stream<Duration> get onPositionChanged =>
      _standard?.onPositionChanged ?? _effects!.positions;
  Stream<Duration> get onDurationChanged =>
      _standard?.onDurationChanged ?? _effects!.durations;
  Stream<void> get onPlayerComplete =>
      _standard?.onPlayerComplete ?? _effects!.completions;
  Stream<Object> get errors => _effects?.errors ?? const Stream.empty();
  Future<void> setSource(Source source) =>
      _standard?.setSource(source) ?? _effects!.setSource(source);
  Future<void> pause() => _standard?.pause() ?? _effects!.pause();
  Future<void> resume() => _standard?.resume() ?? _effects!.resume();
  Future<void> stop() => _standard?.stop() ?? _effects!.stop();
  Future<void> seek(Duration position) =>
      _standard?.seek(position) ?? _effects!.seek(position);
  Future<void> setPlaybackRate(double speed) =>
      _standard?.setPlaybackRate(speed) ?? _effects!.setRate(speed);
  Future<void> enhanceDialogue(bool enabled) async {
    if (_effects == null)
      throw UnsupportedError('Efeito indisponível neste reprodutor.');
    await _effects!.enhanceDialogue(enabled);
  }

  Future<void> dispose() async {
    await _standard?.dispose();
    await _effects?.dispose();
  }
}
