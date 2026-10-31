import 'package:audioplayers/audioplayers.dart';

abstract class AudioBackend {
  Stream<PlayerState> get states;
  Stream<Duration> get positions;
  Stream<Duration> get durations;
  Stream<void> get completions;
  Stream<Object> get errors;
  bool get supportsDialogue;
  Future<void> setSource(Source source);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setRate(double speed);
  Future<void> enhanceDialogue(bool enabled);
  Future<void> dispose();
}

abstract final class DialogueProfile {
  static const bassFrequency = 200.0;
  static const bassGain = -4.0;
  static const voiceFrequency = 2000.0;
  static const voiceGain = 3.0;
  static const q = 0.7;
  static const headroom = 0.75;
  static const nativeFilter =
      'lavfi=[bass=g=-4:f=200:t=q:w=0.7,'
      'equalizer=f=2000:t=q:w=0.7:g=3,volume=0.75]';
}
