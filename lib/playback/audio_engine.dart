import 'dart:async';

/// Abstraction over whatever actually plays audio on the device.
///
/// The controller knows *what* to play and *which* programme is current; the
/// engine knows *how* to make sound come out. Keeping them separate means the
/// simulated engine (widget tests, Linux/dev) and a real plugin engine (mobile)
/// can both exist without touching the controller or the widget layer.
abstract class AudioEngine {
  /// Begins streaming/playing [url]. Replaces whatever was playing before.
  Future<void> start(String url);

  /// Pauses current playback, retaining position where the format allows.
  Future<void> pause();

  /// Resumes from [pause].
  Future<void> resume();

  /// Stops playback entirely and releases the source.
  Future<void> stop();

  /// Frees resources. Future-proofing; called on controller teardown.
  Future<void> disposeEngine();
}

/// What the engine is doing with the stream right now. Mirrors
/// [RadioConnectionState] (models/playback.dart) without dragging models into
/// the engine layer.
enum EngineStreamState { idle, connecting, buffering, playing, error }

/// One report from the engine: a stream-state change and/or freshly decoded
/// stream metadata (e.g. an ICY "Artist - Song" title from a live broadcast).
class AudioEngineEvent {
  const AudioEngineEvent({required this.state, this.metadata});

  final EngineStreamState state;

  /// Now-playing text exactly as the stream reported it, or null when the
  /// stream exposes none. Never invented by the engine.
  final String? metadata;
}

/// An [AudioEngine] that reports connection progress and stream metadata.
///
/// The controller probes for this capability (`is`) so simple engines stay
/// simple while real ones drive buffering/error states and NOW PLAYING text.
abstract class StatefulAudioEngine implements AudioEngine {
  /// Broadcast for every state change/metadata update of the current source.
  Stream<AudioEngineEvent> get events;
}

/// Placeholder engine that pretends to play but makes no sound.
///
/// This is the default so the app runs everywhere (CI, widget tests, desktop)
/// with zero audio plumbing. Scriptable: tests decide whether starts succeed,
/// when buffering begins, what metadata arrives, and when streams fail —
/// making the controller's whole radio state machine deterministic.
class SimulatedAudioEngine implements StatefulAudioEngine {
  String? currentUrl;
  bool isPaused = false;
  bool isStopped = true;

  /// When non-null, the next [start] fails with this outcome instead of
  /// connecting (consumed once).
  bool failNextStart = false;

  final StreamController<AudioEngineEvent> _events =
      StreamController<AudioEngineEvent>.broadcast();
  EngineStreamState _state = EngineStreamState.idle;

  @override
  Stream<AudioEngineEvent> get events => _events.stream;

  /// The last state emitted; lets tests assert without awaiting streams.
  EngineStreamState get state => _state;

  void _emit(EngineStreamState state, {String? metadata}) {
    _state = state;
    if (!_events.isClosed) {
      _events.add(AudioEngineEvent(state: state, metadata: metadata));
    }
  }

  /// Simulates the stream starving mid-broadcast (network hiccup).
  void simulateBuffering() => _emit(EngineStreamState.buffering);

  /// Simulates recovery after [simulateBuffering].
  void simulateRecovery() => _emit(EngineStreamState.playing);

  /// Simulates the stream dying (connection lost, dead URL).
  void simulateError() => _emit(EngineStreamState.error);

  /// Simulates the station broadcasting now-playing text.
  void simulateMetadata(String title) =>
      _events.add(AudioEngineEvent(state: _state, metadata: title));

  @override
  Future<void> start(String url) async {
    if (url.isEmpty) return;
    _emit(EngineStreamState.connecting);
    if (failNextStart) {
      failNextStart = false;
      _emit(EngineStreamState.error);
      return;
    }
    currentUrl = url;
    isPaused = false;
    isStopped = false;
    _emit(EngineStreamState.playing);
  }

  @override
  Future<void> pause() async {
    isPaused = true;
  }

  @override
  Future<void> resume() async {
    isPaused = false;
  }

  @override
  Future<void> stop() async {
    isStopped = true;
    isPaused = false;
    currentUrl = null;
    _emit(EngineStreamState.idle);
  }

  @override
  Future<void> disposeEngine() async {
    await _events.close();
  }
}
