import 'podcast_episode.dart';
import 'station.dart';

/// The kind of audio currently in control of the shared playback surface.
enum AudioType { none, radio, podcast }

/// Whether the current audio is actively outputting.
enum PlayerStatus { stopped, playing, paused }

/// One listen recorded for the library's RECENTLY PLAYED history: either a
/// broadcast station or a podcast episode, with the local time it started.
/// Exactly one of [station] or [episode] is set.
class ListenRecord {
  const ListenRecord({this.station, this.episode, required this.playedAt});

  final RadioStation? station;
  final PodcastEpisode? episode;
  final DateTime playedAt;

  bool get isStation => station != null;
}

/// The audio medium a listening-history entry refers to.
enum HistoryContentType { radio, podcast }

/// One entry in the listener's recent listening history.
///
/// Unlike [ListenRecord], this deliberately references content by id instead
/// of embedding the whole station or episode object, so history stays bounded
/// and independent of whatever the catalogue looks like later. The screens
/// resolve the id against the existing content models when they render.
class ListeningHistoryItem {
  const ListeningHistoryItem({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.listenedAt,
    this.durationListened = Duration.zero,
    this.playbackPosition = Duration.zero,
  });

  /// Stable unique id for this entry, e.g. "radio:bbc-world-service".
  final String id;

  final HistoryContentType contentType;

  /// The referenced [RadioStation.stationId] or [PodcastEpisode.id].
  final String contentId;

  /// When the listen started, used for the chronological grouping.
  final DateTime listenedAt;

  /// How long this listen ran for, seconds granularity. Zero when unknown
  /// (radio, or before real tracking exists).
  final Duration durationListened;

  /// Where playback reached for recordings. Only meaningful for podcast
  /// episodes; radio is live.
  final Duration playbackPosition;

  factory ListeningHistoryItem.station(RadioStation station, DateTime at) =>
      ListeningHistoryItem(
        id: 'radio:${station.stationId}',
        contentType: HistoryContentType.radio,
        contentId: station.stationId,
        listenedAt: at,
      );

  factory ListeningHistoryItem.episode(PodcastEpisode episode, DateTime at) =>
      ListeningHistoryItem(
        id: 'episode:${episode.id}',
        contentType: HistoryContentType.podcast,
        contentId: episode.id,
        listenedAt: at,
        playbackPosition: episode.position,
      );
}

/// How a sleep timer decides when to stop playback.
enum SleepTimerMode {
  /// Stops after a fixed countdown from when it was started.
  duration,

  /// Stops when the currently playing podcast episode ends.
  endOfEpisode,
}

/// The active sleep timer, owned by the playback controller so it survives
/// screen changes. [remainingDuration] is the originally chosen countdown;
/// the live remaining time is derived from [endAt] against a clock so the UI
/// recalculates it on rebuild without ticking its own counter.
class SleepTimerState {
  const SleepTimerState({
    required this.mode,
    required this.remainingDuration,
    required this.startedAt,
    this.endAt,
  });

  final SleepTimerMode mode;

  /// The duration the listener picked, or zero for end-of-episode.
  final Duration remainingDuration;

  final DateTime startedAt;

  /// Absolute expiry moment for [SleepTimerMode.duration]; null otherwise.
  final DateTime? endAt;
}