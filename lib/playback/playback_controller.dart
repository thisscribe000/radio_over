import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/downloads/download_manager.dart';
import '../data/downloads/download_store.dart';
import '../data/favourites/favourite_station_store.dart';
import '../data/library/library_store.dart';
import '../data/progress/playback_progress_store.dart';
import '../data/theme/theme_store.dart';
import '../data/profile/user_profile_store.dart';
import '../data/timeline/comment_store.dart';
import '../data/timeline/snippet_store.dart';
import '../models/audio_snippet.dart';
import '../models/download.dart';
import '../models/playback.dart';
import '../models/playback_progress.dart';
import '../models/podcast_episode.dart';
import '../models/snippet_comment.dart';
import '../models/station.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
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

  /// Cap on rows the Continue Listening section shows at once.
  static const int maxContinueListeningItems = 10;

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

  /// Persists saved episodes + followed shows across restarts. Defaults to
  /// memory-only so tests never touch platform channels.
  final LibraryStore _libraryStore;

  /// Persists podcast playback progress (position/duration/timestamps) across
  /// restarts. Defaults to memory-only.
  final PlaybackProgressStore _progressStore;

  /// Persists the active theme mode.
  final ThemeStore _themeStore;

  /// Persists user profile settings.
  final UserProfileStore _profileStore;

  /// Persists community audio snippets.
  final SnippetStore _snippetStore;

  /// Persists snippet comments.
  final SnippetCommentStore _commentStore;

  /// Cap on how often playback progress is written to storage. Position is
  /// held in memory every tick (so Continue Listening stays live); the store
  /// is only written this frequently to avoid hammering disk each second.
  final Duration progressPersistInterval;

  /// Owns podcast episode downloads. Defaults to an internal manager with an
  /// in-memory store so tests that never touch downloads are unaffected.
  final DownloadManager downloads;

  StreamSubscription<AudioEngineEvent>? _engineSub;

  PlaybackController({
    DateTime Function()? clock,
    AudioEngine? engine,
    FavouriteStationStore? favouriteStore,
    LibraryStore? libraryStore,
    PlaybackProgressStore? progressStore,
    ThemeStore? themeStore,
    UserProfileStore? profileStore,
    SnippetStore? snippetStore,
    SnippetCommentStore? commentStore,
    DownloadManager? downloads,
    Duration? progressPersistInterval,
    this.radioRetryDelay = const Duration(seconds: 2),
  })  : _now = clock ?? DateTime.now,
        _engine = engine ?? SimulatedAudioEngine(),
        _favouriteStore = favouriteStore ?? InMemoryFavouriteStationStore(),
        _libraryStore = libraryStore ?? InMemoryLibraryStore(),
        _progressStore = progressStore ?? InMemoryPlaybackProgressStore(),
        _themeStore = themeStore ?? InMemoryThemeStore(),
        _profileStore = profileStore ?? InMemoryUserProfileStore(),
        _snippetStore = snippetStore ?? InMemorySnippetStore(),
        _commentStore = commentStore ?? InMemorySnippetCommentStore(),
        downloads = downloads ??
            DownloadManager(
              store: InMemoryDownloadStore(),
              resolveBaseDir: () async => Directory.systemTemp,
            ),
        progressPersistInterval = progressPersistInterval ?? const Duration(seconds: 10) {
    final AudioEngine engine = _engine;
    if (engine is StatefulAudioEngine) {
      _engineSub = engine.events
          .listen(_onEngineEvent, onError: (_) => _handleRadioError());
    }
    this.downloads.addListener(notifyListeners);
    unawaited(_loadFavourites());
    unawaited(_loadPersisted());
    unawaited(_loadSnippets());
    unawaited(_loadComments());
  }

  /// The engine currently driving sound (exposed for future wiring).
  AudioEngine get engine => _engine;

  AudioType _audioType = AudioType.none;
  PlayerStatus _status = PlayerStatus.stopped;
  RadioStation? _currentStation;
  PodcastEpisode? _currentEpisode;

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    unawaited(_themeStore.saveThemeMode(mode));
    notifyListeners();
  }

  UserProfile _userProfile = const UserProfile();

  String get username => _userProfile.username;
  String get bio => _userProfile.bio;
  List<String> get interests => _userProfile.interests;
  bool get isPremium => _userProfile.isPremium;
  bool get hasCompletedOnboarding => _userProfile.hasCompletedOnboarding;
  bool get highQualityAudio => _userProfile.highQualityAudio;
  bool get enableNotifications => _userProfile.enableNotifications;
  bool get newEpisodeAlerts => _userProfile.newEpisodeAlerts;

  Future<void> setHighQualityAudio(bool value) async {
    if (_userProfile.highQualityAudio == value) return;
    _userProfile = _userProfile.copyWith(highQualityAudio: value);
    await _profileStore.saveProfile(_userProfile);
    notifyListeners();
  }

  Future<void> setEnableNotifications(bool value) async {
    if (_userProfile.enableNotifications == value) return;
    _userProfile = _userProfile.copyWith(enableNotifications: value);
    await _profileStore.saveProfile(_userProfile);
    notifyListeners();
  }

  Future<void> setNewEpisodeAlerts(bool value) async {
    if (_userProfile.newEpisodeAlerts == value) return;
    _userProfile = _userProfile.copyWith(newEpisodeAlerts: value);
    await _profileStore.saveProfile(_userProfile);
    notifyListeners();
  }

  Future<void> updateUserProfile(String username, String bio, List<String> interests) async {
    _userProfile = _userProfile.copyWith(
      username: username,
      bio: bio,
      interests: interests,
    );
    await _profileStore.saveProfile(_userProfile);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _userProfile = _userProfile.copyWith(hasCompletedOnboarding: true);
    await _profileStore.saveProfile(_userProfile);
    notifyListeners();
  }

  Future<void> togglePremium() async {
    _userProfile = _userProfile.copyWith(isPremium: !_userProfile.isPremium);
    await _profileStore.saveProfile(_userProfile);
    notifyListeners();
  }

  Future<void> setPremium(bool value) async {
    if (_userProfile.isPremium == value) return;
    _userProfile = _userProfile.copyWith(isPremium: value);
    await _profileStore.saveProfile(_userProfile);
    notifyListeners();
  }

  /// True when the current podcast episode failed to start and is not yet
  /// downloaded — drives the offline hint on the player.
  bool _podcastStartFailed = false;
  final List<ListenRecord> _recent = [];
  final List<ListeningHistoryItem> _history = [];
  final Map<String, RadioStation> _favouriteStations = {};
  final Set<String> _savedShows = {};
  final Set<String> _savedEpisodes = {};
  final Set<String> _followedCreators = {};
  final Set<String> _unseenEpisodes = {};
  UserRole _userRole = UserRole.listener;
  UserRole get userRole => _userRole;

  void setUserRole(UserRole role) {
    if (_userRole == role) return;
    _userRole = role;
    notifyListeners();
  }

  final List<AudioSnippet> _snippets = [];
  AudioSnippet? _playingSnippet;
  final List<SnippetComment> _comments = [];
  List<SnippetComment> get comments => List.unmodifiable(_comments);
  Timer? _ticker;
  SleepTimerState? _sleepTimer;
  Timer? _sleepTicker;

  /// Persisted podcast progress keyed by episode id. Mirrors the real
  /// catalogue-independent [PlaybackProgress] records restored at startup.
  final Map<String, PlaybackProgress> _progress = {};

  /// Periodic writer that flushes in-memory progress to the store. Runs only
  /// while a podcast is actively playing, at [progressPersistInterval].
  Timer? _progressPersistTimer;

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

  /// Restores the listener's saved shows, saved episodes and playback progress
  /// from their persistent stores. Each is loaded only when still empty so a
  /// pre-populated in-session state (e.g. a freshly saved item) wins.
  Future<void> _loadPersisted() async {
    try {
      final List<String> shows = await _libraryStore.loadSavedShows();
      if (shows.isNotEmpty && _savedShows.isEmpty) {
        _savedShows.addAll(shows);
        notifyListeners();
      }
    } on Exception {
      // Best-effort; in-session state stays authoritative.
    }
    try {
      final List<String> episodes = await _libraryStore.loadSavedEpisodes();
      if (episodes.isNotEmpty && _savedEpisodes.isEmpty) {
        _savedEpisodes.addAll(episodes);
        notifyListeners();
      }
    } on Exception {
      // Best-effort.
    }
    try {
      final List<String> creators = await _libraryStore.loadSavedCreators();
      if (creators.isNotEmpty && _followedCreators.isEmpty) {
        _followedCreators.addAll(creators);
        notifyListeners();
      }
    } on Exception {
      // Best-effort.
    }
    try {
      final Map<String, PlaybackProgress> restored = await _progressStore.load();
      if (restored.isNotEmpty && _progress.isEmpty) {
        _progress
          ..clear()
          ..addAll(restored);
        notifyListeners();
      }
    } on Exception {
      // Best-effort; progress stays session-only.
    }
    try {
      final ThemeMode mode = await _themeStore.loadThemeMode();
      if (_themeMode != mode) {
        _themeMode = mode;
        notifyListeners();
      }
    } on Exception {
      // Best-effort.
    }
    try {
      final UserProfile profile = await _profileStore.loadProfile();
      _userProfile = profile;
      notifyListeners();
    } on Exception {
      // Best-effort.
    }
  }

  /// Shows the listener saved, shared across the Podcasts home and the show
  /// detail screen so FOLLOW/SAVED is one consistent state.
  Set<String> get savedShows => Set.unmodifiable(_savedShows);

  /// Exposes the set of creator/publisher names followed by the user.
  Set<String> get followedCreators => Set.unmodifiable(_followedCreators);

  bool isFollowingCreator(String creatorId) => _followedCreators.contains(creatorId);

  void toggleFollowCreator(String creatorId) {
    if (!_followedCreators.remove(creatorId)) {
      _followedCreators.add(creatorId);
    }
    unawaited(_persistSavedCreators());
    notifyListeners();
  }

  Future<void> _persistSavedCreators() async {
    try {
      await _libraryStore.saveSavedCreators(_followedCreators.toList());
    } on Exception {
      // Best-effort.
    }
  }

  /// Community audio snippets on the timeline.
  List<AudioSnippet> get snippets => List.unmodifiable(_snippets);

  /// Currently playing snippet if audio playback was initiated from a snippet card.
  AudioSnippet? get playingSnippet => _playingSnippet;

  Future<void> _loadSnippets() async {
    try {
      final loaded = await _snippetStore.loadSnippets();
      if (loaded.isNotEmpty && _snippets.isEmpty) {
        _snippets.addAll(loaded);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    try {
      final loaded = await _commentStore.loadComments();
      if (loaded.isNotEmpty && _comments.isEmpty) {
        _comments.addAll(loaded);
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Returns all comments for a specific snippet.
  List<SnippetComment> commentsFor(String snippetId) {
    return _comments
        .where((c) => c.snippetId == snippetId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Returns the total comment count for a snippet.
  int commentsCountFor(String snippetId) {
    return _comments.where((c) => c.snippetId == snippetId).length;
  }

  /// Adds a new comment, updates snippet commentsCount, and persists both.
  Future<void> addComment(SnippetComment comment) async {
    _comments.add(comment);
    final int sIdx = _snippets.indexWhere((s) => s.id == comment.snippetId);
    if (sIdx != -1) {
      _snippets[sIdx] = _snippets[sIdx].copyWith(
        commentsCount: _snippets[sIdx].commentsCount + 1,
      );
      await _snippetStore.saveSnippets(_snippets);
    }
    await _commentStore.saveComments(_comments);
    notifyListeners();
  }

  /// Toggles like status on a comment.
  Future<void> toggleLikeComment(String commentId) async {
    final int idx = _comments.indexWhere((c) => c.id == commentId);
    if (idx != -1) {
      final SnippetComment c = _comments[idx];
      final bool newLiked = !c.isLiked;
      final int newCount = newLiked
          ? c.likesCount + 1
          : (c.likesCount > 0 ? c.likesCount - 1 : 0);
      _comments[idx] = c.copyWith(isLiked: newLiked, likesCount: newCount);
      await _commentStore.saveComments(_comments);
      notifyListeners();
    }
  }

  /// Adds a newly trimmed audio snippet and persists it to the timeline.
  Future<void> createSnippet(AudioSnippet snippet) async {
    _snippets.insert(0, snippet);
    await _snippetStore.saveSnippets(_snippets);
    notifyListeners();
  }

  /// Adds an ordered multi-part audio thread to the timeline and persists it.
  Future<void> createSnippetThread(List<AudioSnippet> threadItems) async {
    if (threadItems.isEmpty) return;
    for (final item in threadItems.reversed) {
      _snippets.insert(0, item);
    }
    await _snippetStore.saveSnippets(_snippets);
    notifyListeners();
  }

  /// Returns all snippets belonging to [threadId] sorted by threadIndex.
  List<AudioSnippet> threadSnippets(String threadId) {
    return _snippets
        .where((s) => s.threadId == threadId)
        .toList()
      ..sort((a, b) => a.threadIndex.compareTo(b.threadIndex));
  }

  /// Toggles the like state for a snippet and increments/decrements its counter.
  Future<void> toggleLikeSnippet(String snippetId) async {
    final int index = _snippets.indexWhere((s) => s.id == snippetId);
    if (index != -1) {
      final AudioSnippet item = _snippets[index];
      final bool newLiked = !item.isLiked;
      final int newCount = newLiked
          ? item.likesCount + 1
          : (item.likesCount > 0 ? item.likesCount - 1 : 0);
      _snippets[index] = item.copyWith(isLiked: newLiked, likesCount: newCount);
      await _snippetStore.saveSnippets(_snippets);
      notifyListeners();
    }
  }

  /// Plays the audio of a snippet from its start timestamp.
  void playSnippet(AudioSnippet snippet) {
    _playingSnippet = snippet;
    final PodcastEpisode ep = PodcastEpisode(
      id: snippet.episodeId,
      podcastId: snippet.podcastId,
      podcastName: snippet.podcastName,
      title: snippet.episodeTitle,
      duration: snippet.end > Duration.zero ? snippet.end : const Duration(minutes: 30),
      audioUrl: snippet.audioUrl,
      imageUrl: snippet.episodeImageUrl,
    );
    playPodcastEpisode(ep);
    seek(snippet.start);
  }

  /// Calculates the total podcast listening duration across all episodes the user spent time on.
  Duration get totalPodcastListeningTime {
    Duration sum = Duration.zero;
    for (final PlaybackProgress p in _progress.values) {
      sum += p.position;
    }
    return sum;
  }

  bool isSavedShow(String showId) => _savedShows.contains(showId);

  void toggleSavedShow(String showId) {
    if (!_savedShows.remove(showId)) {
      _savedShows.add(showId);
    }
    unawaited(_persistSavedShows());
    notifyListeners();
  }

  Future<void> _persistSavedShows() async {
    try {
      await _libraryStore.saveSavedShows(_savedShows.toList());
    } on Exception {
      // Best-effort.
    }
  }

  /// Individually saved podcast episodes, shared between the podcast player's
  /// heart and the library's SAVED EPISODES section.
  Set<String> get savedEpisodes => Set.unmodifiable(_savedEpisodes);

  bool isSavedEpisode(String episodeId) => _savedEpisodes.contains(episodeId);

  void toggleSavedEpisode(String episodeId) {
    if (!_savedEpisodes.remove(episodeId)) {
      _savedEpisodes.add(episodeId);
    }
    unawaited(_persistSavedEpisodes());
    notifyListeners();
  }

  Future<void> _persistSavedEpisodes() async {
    try {
      await _libraryStore.saveSavedEpisodes(_savedEpisodes.toList());
    } on Exception {
      // Best-effort.
    }
  }

  /// Episode ids available offline. Derived from the download manager's
  /// completed set; the library's DOWNLOADS entry reads the count from here.
  Set<String> get downloadedEpisodes =>
      Set.unmodifiable(downloads.completedIds);

  bool isDownloaded(String episodeId) => downloads.isDownloaded(episodeId);

  /// Toggles offline availability for [episode]: starts a download when absent,
  /// removes the downloaded file when present.
  void toggleDownload(PodcastEpisode episode) {
    if (downloads.isDownloaded(episode.id)) {
      unawaited(downloads.remove(episode.id));
    } else {
      unawaited(downloads.enqueue(episode));
    }
  }

  // --- Download passthroughs -----------------------------------------------

  void requestDownload(PodcastEpisode episode) =>
      unawaited(downloads.enqueue(episode));

  void removeDownload(String episodeId) =>
      unawaited(downloads.remove(episodeId));

  void pauseDownload(String episodeId) => downloads.pause(episodeId);

  void resumeDownload(String episodeId) => downloads.resume(episodeId);

  void cancelDownload(String episodeId) =>
      unawaited(downloads.cancel(episodeId));

  void retryDownload(String episodeId) =>
      unawaited(downloads.retry(episodeId));

  DownloadItem? downloadFor(String episodeId) => downloads.itemFor(episodeId);

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

  /// Clears all unseen episode flags at once.
  void clearAllUnseenEpisodes() {
    if (_unseenEpisodes.isEmpty) return;
    _unseenEpisodes.clear();
    notifyListeners();
  }

  Duration get podcastPosition => _currentEpisode?.position ?? Duration.zero;
  Duration get podcastDuration => _currentEpisode?.duration ?? Duration.zero;

  // --- Playback progress (Continue Listening) ------------------------------

  /// The most recently restored/observed [PlaybackProgress] record for
  /// [episodeId], or null when none exists yet.
  PlaybackProgress? progressFor(String episodeId) {
    final PlaybackProgress? p = _progress[episodeId];
    if (p == null || !p.inProgress) return null;
    return p;
  }

  /// Resolves the [PlaybackProgress] the library should present for
  /// [episode]: a persisted/observed record when one exists, otherwise a
  /// catalogue-synthesised record when the episode itself carries a baked
  /// position (mock fixtures keep working without ever having been played).
  PlaybackProgress? progressForEpisode(PodcastEpisode episode) {
    final PlaybackProgress? persisted = _progress[episode.id];
    if (persisted != null) {
      return persisted.inProgress ? persisted : null;
    }
    return episode.position > Duration.zero &&
            episode.position < episode.duration
        ? PlaybackProgress(
            episodeId: episode.id,
            position: episode.position,
            duration: episode.duration,
            // Catalogue-synthesised: an old sentinel so genuinely played
            // episodes always rank ahead in Continue Listening.
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
          )
        : null;
  }

  /// Unfinished persisted progress sorted most-recently-updated first, capped
  /// to [maxContinueListeningItems]. Drives the library's Continue Listening.
  List<PlaybackProgress> get continueListening {
    final List<PlaybackProgress> list = _progress.values
        .where((p) => p.inProgress)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.take(maxContinueListeningItems).toList();
  }

  /// Keeps the in-memory record for the current episode current. Cheap and
  /// runs on every tick so Continue Listening reflects the live position; the
  /// store write itself is throttled separately.
  void _updateProgressRecord({bool? completed}) {
    final PodcastEpisode? episode = _currentEpisode;
    if (episode == null) return;
    final PlaybackProgress? prior = _progress[episode.id];
    _progress[episode.id] = PlaybackProgress(
      episodeId: episode.id,
      position: episode.position,
      duration: episode.duration,
      updatedAt: _now(),
      completed: completed ?? prior?.completed ?? false,
    );
  }

  /// Writes the in-memory progress map to the backing store (best-effort).
  void _persistProgressNow() {
    final Map<String, PlaybackProgress> snapshot = Map<String, PlaybackProgress>.of(_progress);
    unawaited(_progressStore.save(snapshot));
  }

  void _startProgressPersistTimer() {
    if (_progressPersistTimer != null) return;
    final Duration interval = progressPersistInterval;
    if (interval <= Duration.zero) return;
    _progressPersistTimer = Timer.periodic(interval, (_) {
      if (_audioType == AudioType.podcast && _status == PlayerStatus.playing) {
        _updateProgressRecord();
        _persistProgressNow();
      }
    });
  }

  void _stopProgressPersistTimer() {
    _progressPersistTimer?.cancel();
    _progressPersistTimer = null;
  }


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
  /// text. Radio drives its full state machine here; podcast only tracks
  /// start failures (for the offline hint) since position is controller-driven.
  void _onEngineEvent(AudioEngineEvent event) {
    if (event.metadata != null && event.metadata!.isNotEmpty) {
      _radioMetadata = event.metadata;
      if (_audioType == AudioType.radio) notifyListeners();
    }
    switch (event.state) {
      case EngineStreamState.idle:
        break; // stop() already handled at the controller level
      case EngineStreamState.connecting:
        if (_audioType == AudioType.radio) {
          _applyRadioState(RadioConnectionState.connecting);
        }
        break;
      case EngineStreamState.buffering:
        if (_audioType == AudioType.radio) {
          _applyRadioState(RadioConnectionState.buffering);
        }
        break;
      case EngineStreamState.playing:
        if (_audioType == AudioType.radio) {
          _applyRadioState(RadioConnectionState.playing);
        }
        if (_audioType == AudioType.podcast && _podcastStartFailed) {
          _podcastStartFailed = false;
          notifyListeners();
        }
        break;
      case EngineStreamState.error:
        if (_audioType == AudioType.radio) {
          _handleRadioError();
        } else if (_audioType == AudioType.podcast) {
          _podcastStartFailed = true;
          notifyListeners();
        }
        break;
    }
  }

  /// Whether the current podcast failed to start and is not downloaded — the
  /// player surfaces the offline hint in that case.
  bool get podcastStartFailed =>
      _audioType == AudioType.podcast &&
      _podcastStartFailed &&
      _currentEpisode != null &&
      !isDownloaded(_currentEpisode!.id);

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
    final PodcastEpisode restored = _restoredEpisode(episode);
    _currentEpisode = restored;
    _currentStation = null;
    _status = PlayerStatus.playing;
    _unseenEpisodes.remove(episode.id);
    _podcastStartFailed = false;
    _resetRadioSurface();
    _recordRecentEpisode(episode);
    _syncTicker();
    _startProgressPersistTimer();
    final String source = downloads.localPathFor(episode.id) ??
        episode.audioUrl ??
        '';
    final Duration startPos = restored.position;
    unawaited(_engine.start(
      source,
      initialPosition: startPos > Duration.zero ? startPos : null,
    ));
    notifyListeners();
  }

  /// Returns [episode] seeded with its restored playback position.
  ///
  /// Unfinished episodes resume from where the listener left off. A completed
  /// episode replays from the start (a fresh listen) — it no longer behaves
  /// like an unfinished Continue Listening item.
  PodcastEpisode _restoredEpisode(PodcastEpisode episode) {
    final PlaybackProgress? saved = _progress[episode.id];
    if (saved == null || saved.completed) {
      return episode;
    }
    final Duration duration = episode.duration > Duration.zero
        ? episode.duration
        : saved.duration;
    final Duration clamped = saved.position < Duration.zero
        ? Duration.zero
        : (saved.position > duration ? duration : saved.position);
    return episode.copyWith(position: clamped);
  }

  void toggle() {
    if (_audioType == AudioType.none) return;
    final bool wasPlaying = _status == PlayerStatus.playing;
    _status = wasPlaying ? PlayerStatus.paused : PlayerStatus.playing;
    unawaited(wasPlaying ? _engine.pause() : _engine.resume());
    _syncTicker();
    if (wasPlaying && _audioType == AudioType.podcast) {
      _updateProgressRecord();
      _persistProgressNow();
    } else if (!wasPlaying && _audioType == AudioType.podcast) {
      _startProgressPersistTimer();
    }
    notifyListeners();
  }

  void seek(Duration position) {
    final PodcastEpisode? episode = _currentEpisode;
    if (_audioType != AudioType.podcast || episode == null) return;
    final Duration clamped = position < Duration.zero
        ? Duration.zero
        : (position > episode.duration ? episode.duration : position);
    _currentEpisode = episode.copyWith(position: clamped);
    _updateProgressRecord();
    _persistProgressNow();
    unawaited(_engine.seek(clamped));
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
    _stopProgressPersistTimer();
    _persistProgressNow();
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
    _stopProgressPersistTimer();
  }

  void _advance() {
    final PodcastEpisode? episode = _currentEpisode;
    if (episode == null || _status != PlayerStatus.playing || _audioType != AudioType.podcast) {
      return;
    }
    final Duration next = episode.position + const Duration(seconds: 1);

    // If currently playing a snippet/thread part and it reached the end of this part
    final AudioSnippet? snippet = _playingSnippet;
    if (snippet != null && next >= snippet.end) {
      if (snippet.isThread &&
          snippet.threadIndex < snippet.threadTotal &&
          snippet.threadId != null) {
        final String tId = snippet.threadId!;
        final int nextIdx = snippet.threadIndex + 1;
        final nextPart = _snippets.cast<AudioSnippet?>().firstWhere(
              (s) => s?.threadId == tId && s?.threadIndex == nextIdx,
              orElse: () => null,
            );
        if (nextPart != null) {
          playSnippet(nextPart);
          return;
        }
      }
    }

    if (next >= episode.duration) {
      if (_sleepTimer?.mode == SleepTimerMode.endOfEpisode) {
        _expireSleepTimer();
        return;
      }
      _currentEpisode = episode.copyWith(position: episode.duration);
      _status = PlayerStatus.paused;
      _syncTicker();
      _updateProgressRecord(completed: true);
      _persistProgressNow();
    } else {
      _currentEpisode = episode.copyWith(position: next);
      _updateProgressRecord();
    }
    notifyListeners();
  }

  /// Restarts playback of the current episode from the beginning, clearing its
  /// saved progress so it no longer appears in Continue Listening.
  void restartEpisode() {
    final PodcastEpisode? episode = _currentEpisode;
    if (episode == null || _audioType != AudioType.podcast) return;
    _currentEpisode = episode.copyWith(position: Duration.zero);
    _updateProgressRecord();
    _persistProgressNow();
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _sleepTicker?.cancel();
    _radioRetryTimer?.cancel();
    _stopProgressPersistTimer();
    _persistProgressNow();
    _engineSub?.cancel();
    downloads.removeListener(notifyListeners);
    unawaited(_engine.disposeEngine());
    super.dispose();
  }
}