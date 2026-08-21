import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/favourites/favourite_station_store.dart';
import '../models/playback.dart';
import '../models/podcast_episode.dart';
import '../models/station.dart';
import 'audio_engine.dart';

/// Single source of truth for what is currently playing.
///
/// Intentionally minimal: a plain [ChangeNotifier] the eventual audio service
/// can grow into without touching the widget layer. The built-in clock ticker
/// is placeholder logic that fakes playback progression for podcasts until a
/// real stream/player exists.
class PlaybackController extends ChangeNotifier {
  /// Upper bound for the full listening history. Most-recent entries are kept;
  /// the exact cap can be tuned without touching callers.
  static const int maxListeningHistoryEntries = 150;

  /// Automatic reconnection attempts after a stream error before the UI is
  /// allowed to declare UNABLE TO CONNECT. A manual retry always resets this.
  static const int maxRadioRetries = 2;

  /// Injectable clock so the sleep timer's expiry can be driven
  /// deterministically in tests. Defaults to the real wall clock.
  final DateTime Function() _now;

  /// Injectable audio engine. Defaults to [SimulatedAudioEngine] so the app
  /// (and the existing test suite) behaves identically without a device stack.
  final AudioEngine _engine;

  /// Delay between automatic radio reconnection attempts. Configurable so
  /// tests can collapse it to zero.
  final Duration radioRetryDelay;

  /// Persists favourite stations across restarts. Defaults to memory-only.
  final FavouriteStationStore _favouriteStore;

  StreamSubscription<AudioEngineEvent>? _engineSub;

  PlaybackController({
    DateTime Function()? clock,
    AudioEngine? engine,
    FavouriteStationStore? favouriteStore,
    this.radioRetryDelay = const Duration(seconds: 2),
  })  : _now = clock ?? DateTime.now,
        _engine = engine ?? SimulatedAudioEngine(),
        _favouriteStore = favouriteStore ?? InMemoryFavouriteStationStore() {
    final AudioEngine engine = _engine;
    if (engine is StatefulAudioEngine) {
      _engineSub = engine.events
          .listen(_onEngineEvent, onError: (_) => _handleRadioError());
    }
    unawaited(_loadFavourites());
  }

  /// The engine currently driving sound (exposed for future wiring).
  AudioEngine get engine => _engine;

  AudioType _audioType = AudioType.none;
  PlayerStatus _status = PlayerStatus.stopped;
  RadioStation? _currentStation;
  PodcastEpisode? _currentEpisode;
  final List<ListenRecord> _recent = [];
  final List<ListeningHistoryItem> _history = [];
  final Map<String, RadioStation> _favouriteStations = {};
  final Set<String> _savedShows = {};
  final Set<String> _savedEpisodes = {};
  final Set<String> _downloadedEpisodes = {};
  final Set<String> _unseenEpisodes = {};
  Timer? _ticker;
  SleepTimerState? _sleepTimer;
  Timer? _sleepTicker;

  RadioConnectionState _radioState = RadioConnectionState.idle;
  String? _radioMetadata;
  int _radioAttempts = 0;
  Timer? _radioRetryTimer;

  AudioType get audioType => _audioType;
  PlayerStatus get status => _status;
  RadioStation? get currentStation => _currentStation;
  PodcastEpisode? get currentEpisode => _currentEpisode;

  /// Real connection state of the live radio stream (connecting/buffering/
  /// playing/error). Never claims a station is live before audio flows.
  RadioConnectionState get radioState => _radioState;

  /// Now-playing text exactly as the stream reported it, or null when the
  /// station exposes none. The UI falls back to LIVE/station name — nothing
  /// is ever invented here.
  String? get radioNowPlaying => _radioMetadata;

  /// Radio stations played this session, most recent first. Empty until
  /// something has been played. Used by the RECENTLY PLAYED section.
  List<RadioStation> get recentStations {
    final List<RadioStation> stations = [
      for (final ListenRecord record in _recent)
        if (record.station != null) record.station!,
    ];
    return List.unmodifiable(stations.take(4));
  }

  /// Every listen recorded this session (stations and episodes interleaved),
  /// most recent first. The library's RECENTLY PLAYED section reads this.
  List<ListenRecord> get recentHistory => List.unmodifiable(_recent);

  /// The full listening history, most recent first, bounded to
  /// [maxListeningHistoryEntries]. Entries reference content by id so they
  /// stay independent of the catalogue content they point at.
  List<ListeningHistoryItem> get listeningHistory => List.unmodifiable(_history);

  /// Removes a single entry (by its [ListeningHistoryItem.id]) from the
  /// history and from the library's recently-played list.
  void removeFromListeningHistory(String id) {
    final int index = _history.indexWhere((h) => h.id == id);
    if (index == -1) return;
    final ListeningHistoryItem item = _history.removeAt(index);
    if (item.contentType == HistoryContentType.radio) {
      _recent.removeWhere((r) => r.station?.stationId == item.contentId);
    } else {
      _recent.removeWhere((r) => r.episode?.id == item.contentId);
    }
    notifyListeners();
  }

  /// Clears all listening activity, including the library's RECENTLY PLAYED.
  void clearListeningHistory() {
    if (_history.isEmpty && _recent.isEmpty) return;
    _history.clear();
    _recent.clear();
    notifyListeners();
  }

  /// Stations the listener saved, shared across every surface (home, search,
  /// station detail) so SAVE is one consistent state rather than per-screen.
  /// Keyed by stable [RadioStation.stationId]; each entry keeps a cached
  /// metadata snapshot so favourites survive restarts, catalogue churn and
  /// offline use without duplicating live catalogue objects.
  Set<String> get favouriteStations => Set.unmodifiable(_favouriteStations.keys);

  /// Cached snapshots of the favourite stations, in the order they were
  /// saved. The Library renders from this — real stations only.
  List<RadioStation> get favouriteStationDetails =>
      List.unmodifiable(_favouriteStations.values);

  RadioStation? favouriteStationById(String stationId) => _favouriteStations[stationId];

  bool isFavouriteStation(String stationId) => _favouriteStations.containsKey(stationId);

  void toggleFavouriteStation(String stationId, {RadioStation? details}) {
    if (_favouriteStations.remove(stationId) == null) {
      final RadioStation? snapshot = details ?? _currentStation;
      if (snapshot != null && snapshot.stationId == stationId) {
        _favouriteStations[stationId] = snapshot;
      } else {
        // Id-only save (no snapshot available): keep a bare-bones record so
        // the favourite still exists until richer details arrive.
        _favouriteStations[stationId] = RadioStation(
          id: stationId,
          name: stationId,
          category: 'Radio',
          program: 'LIVE RADIO',
        );
      }
    }
    unawaited(_persistFavourites());
    notifyListeners();
  }

  Future<void> _loadFavourites() async {
    try {
      final Map<String, RadioStation> restored =
          await _favouriteStore.load();
      if (restored.isEmpty || _favouriteStations.isNotEmpty) return;
      _favouriteStations
        ..clear()
        ..addAll(restored);
      notifyListeners();
    } on Exception {
      // Storage unavailable (e.g. tests): favourites stay session-only.
    }
  }

  Future<void> _persistFavourites() async {
    try {
      await _favouriteStore.save(_favouriteStations);
    } on Exception {
      // Persistence is best-effort; the in-session set stays authoritative.
    }
  }

  /// Shows the listener saved, shared across the Podcasts home and the show
  /// detail screen so FOLLOW/SAVED is one consistent state.
  Set<String> get savedShows => Set.unmodifiable(_savedShows);

  bool isSavedShow(String showId) => _savedShows.contains(showId);

  void toggleSavedShow(String showId) {
    if (!_savedShows.remove(showId)) {
      _savedShows.add(showId);
    }
    notifyListeners();
  }

  /// Individually saved podcast episodes, shared between the podcast player's
  /// heart and the library's SAVED EPISODES section.
  Set<String> get savedEpisodes => Set.unmodifiable(_savedEpisodes);

  bool isSavedEpisode(String episodeId) => _savedEpisodes.contains(episodeId);

  void toggleSavedEpisode(String episodeId) {
    if (!_savedEpisodes.remove(episodeId)) {
      _savedEpisodes.add(episodeId);
    }
    notifyListeners();
  }

  /// Episode ids available offline. Filled from the podcast player's download
  /// action; the library's DOWNLOADS entry reads the count from here.
  Set<String> get downloadedEpisodes => Set.unmodifiable(_downloadedEpisodes);

  bool isDownloaded(String episodeId) => _downloadedEpisodes.contains(episodeId);

  void toggleDownloaded(String episodeId) {
    if (!_downloadedEpisodes.remove(episodeId)) {
      _downloadedEpisodes.add(episodeId);
    }
    notifyListeners();
  }

  /// Episodes discovered by feed refresh that the listener has not opened
  /// yet. Deliberately independent of saved/downloaded state and of playback
  /// progress: an episode can be new + saved, new + downloaded, and so on.
  Set<String> get unseenEpisodes => Set.unmodifiable(_unseenEpisodes);

  /// Whether an episode should still show its NEW indicator.
  bool isNewEpisode(String episodeId) => _unseenEpisodes.contains(episodeId);

  /// Flags episodes as newly discovered (drives the NEW indicator).
  void markEpisodesUnseen(Iterable<String> episodeIds) {
    bool changed = false;
    for (final String id in episodeIds) {
      if (id.isNotEmpty && _unseenEpisodes.add(id)) changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Clears the NEW indicator once the listener has meaningfully opened the
  /// episode (playing it does this automatically).
  void markEpisodeSeen(String episodeId) {
    if (!_unseenEpisodes.remove(episodeId)) return;
    notifyListeners();
  }

  Duration get podcastPosition => _currentEpisode?.position ?? Duration.zero;
  Duration get podcastDuration => _currentEpisode?.duration ?? Duration.zero;

  /// A radio broadcast owns the playback surface (even while paused).
  bool get radioActive => _audioType == AudioType.radio && _currentStation != null;

  /// A podcast owns the playback surface (even while paused).
  bool get podcastActive => _audioType == AudioType.podcast && _currentEpisode != null;

  /// Whether audio is actually outputting right now.
  bool get isPlaying => _status == PlayerStatus.playing;

  void playRadioStation(RadioStation station) {
    _audioType = AudioType.radio;
    _currentStation = station;
    _currentEpisode = null;
    _status = PlayerStatus.playing;
    _radioMetadata = null;
    _radioAttempts = 0;
    _radioRetryTimer?.cancel();
    _radioState = RadioConnectionState.connecting;
    _recordRecent(station);
    _syncTicker();
    unawaited(_engine.start(station.streamUrl ?? ''));
    notifyListeners();
  }

  /// Manual reconnection after a stream failure. Resets the auto-retry
  /// budget and re-opens the current station's stream.
  void retryRadio() {
    final RadioStation? station = _currentStation;
    if (_audioType != AudioType.radio || station == null) return;
    _radioAttempts = 0;
    _radioRetryTimer?.cancel();
    _radioMetadata = null;
    _status = PlayerStatus.playing;
    _radioState = RadioConnectionState.connecting;
    _syncTicker();
    unawaited(_engine.start(station.streamUrl ?? ''));
    notifyListeners();
  }

  /// Engine reports: connection progress, starvation, death, or now-playing
  /// text. Only radio listens to these — podcast position is controller-driven.
  void _onEngineEvent(AudioEngineEvent event) {
    if (event.metadata != null && event.metadata!.isNotEmpty) {
      _radioMetadata = event.metadata;
      if (_audioType == AudioType.radio) notifyListeners();
    }
    switch (event.state) {
      case EngineStreamState.idle:
        break; // stop() already handled at the controller level
      case EngineStreamState.connecting:
        _applyRadioState(RadioConnectionState.connecting);
        break;
      case EngineStreamState.buffering:
        _applyRadioState(RadioConnectionState.buffering);
        break;
      case EngineStreamState.playing:
        _applyRadioState(RadioConnectionState.playing);
        break;
      case EngineStreamState.error:
        _handleRadioError();
        break;
    }
  }

  void _applyRadioState(RadioConnectionState state) {
    if (_audioType != AudioType.radio || _radioState == state) return;
    _radioState = state;
    notifyListeners();
  }

  /// Limited automatic reconnection before surfacing UNABLE TO CONNECT.
  void _handleRadioError() {
    if (_audioType != AudioType.radio) return;
    final RadioStation? station = _currentStation;
    if (station == null) return;
    if (_radioAttempts < maxRadioRetries) {
      _radioAttempts++;
      _radioRetryTimer?.cancel();
      _radioState = RadioConnectionState.connecting; // still trying quietly
      notifyListeners();
      _radioRetryTimer = Timer(radioRetryDelay, () {
        if (_audioType != AudioType.radio ||
            _currentStation?.stationId != station.stationId) {
          return;
        }
        unawaited(_engine.start(station.streamUrl ?? ''));
      });
      return;
    }
    _radioState = RadioConnectionState.error;
    notifyListeners();
  }

  void _resetRadioSurface() {
    _radioRetryTimer?.cancel();
    _radioMetadata = null;
    _radioAttempts = 0;
    _radioState = RadioConnectionState.idle;
  }

  void _recordRecent(RadioStation station) {
    _recent.removeWhere((r) => r.station?.name == station.name);
    _recent.insert(0, ListenRecord(station: station, playedAt: _now()));
    _upsertHistory(ListeningHistoryItem.station(station, _now()));
    _trimRecent();
  }

  void _recordRecentEpisode(PodcastEpisode episode) {
    _recent.removeWhere((r) => r.episode?.id == episode.id);
    _recent.insert(0, ListenRecord(episode: episode, playedAt: _now()));
    _upsertHistory(ListeningHistoryItem.episode(episode, _now()));
    _trimRecent();
  }

  /// Records a listen in the full history, keeping it bounded and unique per
  /// piece of content (a repeat listen moves to the front rather than adding a
  /// duplicate).
  void _upsertHistory(ListeningHistoryItem item) {
    _history.removeWhere((h) => h.id == item.id);
    _history.insert(0, item);
    if (_history.length > maxListeningHistoryEntries) {
      _history.removeRange(maxListeningHistoryEntries, _history.length);
    }
  }

  /// Keeps the history bounded: at most four entries per type, eleven total.
  void _trimRecent() {
    int stationCount = 0;
    int episodeCount = 0;
    final List<ListenRecord> kept = [];
    for (final ListenRecord record in _recent) {
      if (record.isStation) {
        if (stationCount >= 4) continue;
        stationCount++;
      } else {
        if (episodeCount >= 4) continue;
        episodeCount++;
      }
      kept.add(record);
    }
    if (kept.length > 11) {
      kept.removeRange(11, kept.length);
    }
    _recent
      ..clear()
      ..addAll(kept);
  }

  void playPodcastEpisode(PodcastEpisode episode) {
    _audioType = AudioType.podcast;
    _currentEpisode = episode;
    _currentStation = null;
    _status = PlayerStatus.playing;
    _unseenEpisodes.remove(episode.id);
    _resetRadioSurface();
    _recordRecentEpisode(episode);
    _syncTicker();
    unawaited(_engine.start(episode.audioUrl ?? ''));
    notifyListeners();
  }

  void toggle() {
    if (_audioType == AudioType.none) return;
    final bool wasPlaying = _status == PlayerStatus.playing;
    _status = wasPlaying ? PlayerStatus.paused : PlayerStatus.playing;
    unawaited(wasPlaying ? _engine.pause() : _engine.resume());
    _syncTicker();
    notifyListeners();
  }

  void seek(Duration position) {
    final PodcastEpisode? episode = _currentEpisode;
    if (_audioType != AudioType.podcast || episode == null) return;
    final Duration clamped = position < Duration.zero
        ? Duration.zero
        : (position > episode.duration ? episode.duration : position);
    _currentEpisode = episode.copyWith(position: clamped);
    notifyListeners();
  }

  void stop() {
    _audioType = AudioType.none;
    _status = PlayerStatus.stopped;
    _currentStation = null;
    _currentEpisode = null;
    _resetRadioSurface();
    unawaited(_engine.stop());
    _syncTicker();
    notifyListeners();
  }

  // --- Sleep timer -------------------------------------------------------

  /// Whether a sleep timer is currently armed.
  bool get sleepActive => _sleepTimer != null;

  SleepTimerMode? get sleepMode => _sleepTimer?.mode;

  /// How long until the armed sleep timer stops playback, or null when the
  /// remaining time cannot be derived (no timer, or end-of-episode with no
  /// episode active). Recalculated against the injected clock on every read.
  Duration? get sleepRemaining {
    final SleepTimerState? timer = _sleepTimer;
    if (timer == null) return null;
    if (timer.mode == SleepTimerMode.duration) {
      final Duration left = timer.endAt!.difference(_now());
      return left.isNegative ? Duration.zero : left;
    }
    final PodcastEpisode? episode = _currentEpisode;
    if (episode == null) return null;
    final Duration left = episode.duration - episode.position;
    return left.isNegative ? Duration.zero : left;
  }

  /// Arms a countdown sleep timer. A previously active timer is replaced.
  void startSleepTimer(Duration duration) {
    final DateTime now = _now();
    _sleepTimer = SleepTimerState(
      mode: SleepTimerMode.duration,
      remainingDuration: duration,
      startedAt: now,
      endAt: now.add(duration),
    );
    _ensureSleepTicker();
    notifyListeners();
  }

  /// Arms a sleep timer that stops at the end of the current podcast episode.
  void startSleepTimerEndOfEpisode() {
    if (_audioType != AudioType.podcast) return;
    _sleepTimer = SleepTimerState(
      mode: SleepTimerMode.endOfEpisode,
      remainingDuration: Duration.zero,
      startedAt: _now(),
    );
    _ensureSleepTicker();
    notifyListeners();
  }

  /// Cancels the active sleep timer without touching playback.
  void cancelSleepTimer() {
    if (_sleepTimer == null) return;
    _sleepTimer = null;
    _sleepTicker?.cancel();
    _sleepTicker = null;
    notifyListeners();
  }

  void _ensureSleepTicker() {
    _sleepTicker ??= Timer.periodic(const Duration(seconds: 1), (_) => _advanceSleep());
  }

  /// Checks expiry and, while a timer is running, nudges listeners each second
  /// so the on-screen countdown recomputes itself.
  void _advanceSleep() {
    final SleepTimerState? timer = _sleepTimer;
    if (timer == null) {
      _sleepTicker?.cancel();
      _sleepTicker = null;
      return;
    }
    if (timer.mode == SleepTimerMode.duration && !_now().isBefore(timer.endAt!)) {
      _expireSleepTimer();
      return;
    }
    notifyListeners();
  }

  void _expireSleepTimer() {
    _sleepTimer = null;
    _sleepTicker?.cancel();
    _sleepTicker = null;
    stop();
  }

  void _syncTicker() {
    final bool shouldRun = _audioType == AudioType.podcast && _status == PlayerStatus.playing;
    if (shouldRun) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _advance());
      return;
    }
    _ticker?.cancel();
    _ticker = null;
  }

  void _advance() {
    final PodcastEpisode? episode = _currentEpisode;
    if (episode == null || _status != PlayerStatus.playing || _audioType != AudioType.podcast) {
      return;
    }
    final Duration next = episode.position + const Duration(seconds: 1);
    if (next >= episode.duration) {
      if (_sleepTimer?.mode == SleepTimerMode.endOfEpisode) {
        _expireSleepTimer();
        return;
      }
      _currentEpisode = episode.copyWith(position: episode.duration);
      _status = PlayerStatus.paused;
      _syncTicker();
    } else {
      _currentEpisode = episode.copyWith(position: next);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sleepTicker?.cancel();
    _radioRetryTimer?.cancel();
    _engineSub?.cancel();
    unawaited(_engine.disposeEngine());
    super.dispose();
  }
}