import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../audio_engine.dart';

/// Production engine backed by the just_audio plugin.
///
/// Used by the app entrypoint; the simulated engine stays the default so the
/// widget-test suite never touches platform channels.
///
/// Reports real stream progress as [AudioEngineEvent]s: connecting while the
/// source loads, buffering when the platform reports a starved buffer,
/// playing once audio actually flows, and error when the source cannot be
/// opened or dies. When a station broadcasts ICY metadata ("Artist - Song")
/// it is surfaced verbatim — never invented.
class JustAudioEngine implements StatefulAudioEngine {
  final AudioPlayer _player = AudioPlayer();
  final StreamController<AudioEngineEvent> _events =
      StreamController<AudioEngineEvent>.broadcast();
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<IcyMetadata?>? _icySub;
  StreamSubscription<PlayerException>? _errorSub;

  /// Whether a source is loaded so resume can `play()` against it instead of
  /// rebuilding it when toggling pause/resume.
  bool _hasSource = false;

  String? _lastMetadata;
  EngineStreamState _lastState = EngineStreamState.idle;
  int _sourceGeneration = 0;
  Future<void> _sourceOperation = Future<void>.value();

  JustAudioEngine() {
    _stateSub = _player.playerStateStream.listen(_onPlayerState);
    // ICY now-playing text, when the station provides it (no-op otherwise).
    _icySub = _player.icyMetadataStream.listen((IcyMetadata? icy) {
      final String? title = icy?.info?.title?.trim();
      if (title == null || title.isEmpty || title == _lastMetadata) return;
      _lastMetadata = title;
      _add(AudioEngineEvent(state: _lastState, metadata: title));
    });
    // Mid-playback failures (network loss, dead stream) that do not throw
    // through start().
    _errorSub = _player.errorStream.listen(
      (_) => _add(const AudioEngineEvent(state: EngineStreamState.error)),
    );
  }

  @override
  Stream<AudioEngineEvent> get events => _events.stream;

  void _add(AudioEngineEvent event) {
    _lastState = event.state;
    if (!_events.isClosed) _events.add(event);
  }

  void _onPlayerState(PlayerState state) {
    switch (state.processingState) {
      case ProcessingState.loading:
        _add(const AudioEngineEvent(state: EngineStreamState.connecting));
        break;
      case ProcessingState.buffering:
        _add(const AudioEngineEvent(state: EngineStreamState.buffering));
        break;
      case ProcessingState.ready:
        // Pausing is deliberate app state, not a stream condition — the
        // controller already tracks it, so only report actual playback.
        if (state.playing) {
          _add(const AudioEngineEvent(state: EngineStreamState.playing));
        }
        break;
      case ProcessingState.completed:
        // A live stream reaching its end means the connection dropped;
        // report starvation rather than pretending all is well.
        _add(const AudioEngineEvent(state: EngineStreamState.buffering));
        break;
      case ProcessingState.idle:
        break; // stopped/released — the controller already knows
    }
  }

  @override
  Future<void> start(String url) {
    final int generation = ++_sourceGeneration;
    // Stop immediately so a failed or empty replacement can never leave the
    // previous source audible while the new source is being resolved.
    _hasSource = false;
    unawaited(_player.stop().catchError((_) {}));
    _sourceOperation = _sourceOperation.then(
      (_) => _startSource(url, generation),
    );
    return _sourceOperation;
  }

  Future<void> _startSource(String url, int generation) async {
    if (generation != _sourceGeneration) return;
    if (url.isEmpty) {
      _add(const AudioEngineEvent(state: EngineStreamState.error));
      return;
    }
    _lastMetadata = null;
    _add(const AudioEngineEvent(state: EngineStreamState.connecting));
    try {
      if (!url.contains('://')) {
        // Local file (downloaded episode): play from disk, no ICY headers.
        await _player.setFilePath(url);
      } else {
        await _player.setUrl(
          url,
          headers: const <String, String>{'Icy-MetaData': '1'},
        );
      }
      if (generation != _sourceGeneration) return;
      _hasSource = true;
      await _player.play();
    } catch (_) {
      // Source unreachable/unsupported/failed — surface the failure instead
      // of throwing into the controller's fire-and-forget calls.
      _hasSource = false;
      _add(const AudioEngineEvent(state: EngineStreamState.error));
    }
  }

  @override
  Future<void> pause() {
    try {
      return _player.pause();
    } catch (_) {
      return Future<void>.value();
    }
  }

  @override
  Future<void> resume() {
    if (!_hasSource) return Future<void>.value();
    try {
      return _player.play();
    } catch (_) {
      return Future<void>.value();
    }
  }

  @override
  Future<void> stop() {
    _sourceGeneration++;
    _hasSource = false;
    _lastMetadata = null;
    try {
      return _player.stop();
    } catch (_) {
      return Future<void>.value();
    }
  }

  @override
  Future<void> disposeEngine() async {
    await _sourceOperation;
    await _stateSub?.cancel();
    await _icySub?.cancel();
    await _errorSub?.cancel();
    await _player.dispose();
    await _events.close();
  }
}
