/// One record of podcast playback progress persisted for a single episode.
///
/// Deliberately minimal and independent from the catalogue: it references an
/// episode by stable [episodeId] and stores exactly what is needed to restore
/// playback (position, duration) and to drive Continue Listening (updatedAt,
/// completed). Progress is orthogonal to saved/downloaded/history state and
/// lives only here, owned by the playback controller.
class PlaybackProgress {
  const PlaybackProgress({
    required this.episodeId,
    required this.position,
    required this.duration,
    required this.updatedAt,
    this.completed = false,
  });

  /// The [PodcastEpisode.id] this progress belongs to.
  final String episodeId;

  /// Where the listener last was, within [duration].
  final Duration position;

  /// The episode's total duration at the time it was last updated.
  final Duration duration;

  /// When [position] was last recorded — the primary Continue Listening sort.
  final DateTime updatedAt;

  /// Whether the episode has been played to the end. Completed episodes stop
  /// behaving like unfinished Continue Listening items.
  final bool completed;

  /// The listener has made meaningful progress but not finished.
  bool get inProgress =>
      !completed && position > Duration.zero && position < duration;

  /// Fraction of the episode played, clamped to 0..1 (0 when unknown).
  double get fraction => duration <= Duration.zero
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  PlaybackProgress copyWith({
    Duration? position,
    Duration? duration,
    DateTime? updatedAt,
    bool? completed,
  }) {
    return PlaybackProgress(
      episodeId: episodeId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      updatedAt: updatedAt ?? this.updatedAt,
      completed: completed ?? this.completed,
    );
  }
}
