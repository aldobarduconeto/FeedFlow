import 'dart:async';
import 'dart:js_interop';

import 'package:audioplayers/audioplayers.dart';
import 'package:web/web.dart' as web;

import 'audio_backend.dart';

AudioBackend createEffectsBackend() => BrowserEffectsBackend();

class BrowserEffectsBackend extends AudioBackend {
  BrowserEffectsBackend() {
    _attach();
  }
  void _attach() {
    final element = _audio;
    _audio.preload = 'metadata';
    _audio.addEventListener(
      'timeupdate',
      ((web.Event _) {
        if (_disposed || element != _audio) return;
        if (!_positions.isClosed)
          _positions.add(
            Duration(milliseconds: (_audio.currentTime * 1000).round()),
          );
      }).toJS,
    );
    _audio.addEventListener(
      'durationchange',
      ((web.Event _) {
        if (_disposed || element != _audio) return;
        final seconds = _audio.duration;
        if (seconds.isFinite && !_durations.isClosed)
          _durations.add(Duration(milliseconds: (seconds * 1000).round()));
      }).toJS,
    );
    _audio.addEventListener(
      'play',
      ((web.Event _) {
        if (_disposed || element != _audio) return;
        _states.add(PlayerState.playing);
      }).toJS,
    );
    _audio.addEventListener(
      'pause',
      ((web.Event _) {
        if (_disposed || element != _audio) return;
        if (!_audio.ended) _states.add(PlayerState.paused);
      }).toJS,
    );
    _audio.addEventListener(
      'ended',
      ((web.Event _) {
        if (_disposed || element != _audio) return;
        _states.add(PlayerState.completed);
        _completions.add(null);
      }).toJS,
    );
    _audio.addEventListener(
      'loadedmetadata',
      ((web.Event _) {
        if (_disposed || element != _audio) return;
        if (!(_loading?.isCompleted ?? true)) _loading!.complete();
      }).toJS,
    );
    _audio.addEventListener(
      'error',
      ((web.Event _) {
        if (_disposed || element != _audio) return;
        if (_cors && _context == null) {
          // CORS is required by Web Audio but not by ordinary media playback.
          _cors = false;
          _audio.removeAttribute('crossorigin');
          _audio.load();
          return;
        }
        final error = StateError('O navegador não conseguiu abrir este áudio.');
        if (!(_loading?.isCompleted ?? true)) {
          _loading!.completeError(error);
        } else if (!_errors.isClosed) {
          _errors.add(error);
        }
      }).toJS,
    );
  }

  web.HTMLAudioElement _audio = web.HTMLAudioElement();
  web.AudioContext? _context;
  web.MediaElementAudioSourceNode? _source;
  web.BiquadFilterNode? _bass;
  web.BiquadFilterNode? _voice;
  web.GainNode? _gain;
  bool _cors = true;
  bool _disposed = false;
  Completer<void>? _loading;
  final _states = StreamController<PlayerState>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration>.broadcast();
  final _completions = StreamController<void>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  @override
  bool get supportsDialogue => _cors;
  @override
  Stream<PlayerState> get states => _states.stream;
  @override
  Stream<Duration> get positions => _positions.stream;
  @override
  Stream<Duration> get durations => _durations.stream;
  @override
  Stream<void> get completions => _completions.stream;
  @override
  Stream<Object> get errors => _errors.stream;
  @override
  Future<void> setSource(Source source) async {
    if (source is! UrlSource)
      throw UnsupportedError('Arquivo local indisponível no navegador.');
    final previous = _audio;
    _audio = web.HTMLAudioElement();
    previous.pause();
    previous.removeAttribute('src');
    previous.load();
    if (_context != null) await _context!.close().toDart;
    _context = null;
    _source = null;
    _bass = null;
    _voice = null;
    _gain = null;
    _attach();
    _loading = Completer<void>();
    _cors = true;
    _audio.crossOrigin = 'anonymous';
    _audio.src = source.url;
    _audio.load();
    await _loading!.future.timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> pause() async {
    _audio.pause();
  }

  @override
  Future<void> resume() async {
    if (_context != null) await _context!.resume().toDart;
    await _audio.play().toDart;
  }

  @override
  Future<void> stop() async {
    _audio.pause();
    if (_audio.readyState > 0) _audio.currentTime = 0;
  }

  @override
  Future<void> seek(Duration position) async {
    _audio.currentTime = position.inMilliseconds / 1000;
  }

  @override
  Future<void> setRate(double speed) async {
    _audio.playbackRate = speed;
  }

  @override
  Future<void> enhanceDialogue(bool enabled) async {
    if (!_cors)
      throw UnsupportedError(
        'Este servidor não permite processamento de áudio no navegador (CORS).',
      );
    if (_context == null) {
      final context = _context = web.AudioContext();
      _source = context.createMediaElementSource(_audio);
      _bass = context.createBiquadFilter()..type = 'lowshelf';
      _bass!.frequency.value = DialogueProfile.bassFrequency;
      _voice = context.createBiquadFilter()..type = 'peaking';
      _voice!.frequency.value = DialogueProfile.voiceFrequency;
      _voice!.Q.value = DialogueProfile.q;
      _gain = context.createGain();
      _source!.connect(_bass!);
      _bass!.connect(_voice!);
      _voice!.connect(_gain!);
      _gain!.connect(context.destination);
    }
    _bass!.gain.value = enabled ? DialogueProfile.bassGain : 0;
    _voice!.gain.value = enabled ? DialogueProfile.voiceGain : 0;
    _gain!.gain.value = enabled ? DialogueProfile.headroom : 1;
    await _context!.resume().toDart;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _audio.pause();
    _audio.removeAttribute('src');
    _audio.load();
    await _context?.close().toDart;
    await _states.close();
    await _positions.close();
    await _durations.close();
    await _completions.close();
    await _errors.close();
  }
}
