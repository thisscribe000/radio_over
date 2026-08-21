/// A single timed caption (transcript line), like a lyric line.
class PodcastCaption {
  const PodcastCaption({required this.start, required this.text});

  final Duration start;
  final String text;
}

/// A single chapter marker: a title at a point in the episode.
class PodcastChapter {
  const PodcastChapter({required this.title, required this.start, this.description});

  final String title;
  final Duration start;
  final String? description;
}

/// Generates placeholder chapter markers spread evenly across the episode.
/// A real feed would ship its own chapter timestamps; this keeps the feel
/// without shipping a chapter editor.
List<PodcastChapter> buildMockChapters(Duration duration, String episodeTitle) {
  const List<String> titles = [
    'Introduction',
    'The story so far',
    'Turning point',
    'What happens next',
  ];
  final int n = titles.length + 1;
  final Duration step = Duration(milliseconds: duration.inMilliseconds ~/ n);
  return [
    for (int i = 0; i < titles.length; i++)
      PodcastChapter(title: titles[i], start: step * i),
  ];
}

/// Generates placeholder transcript captions spread evenly across the episode.
/// A real feed would ship timed captions; this keeps the sync-highlighting
/// feel without shipping a full transcript editor.
List<PodcastCaption> buildMockCaptions(Duration duration, String episodeTitle) {
  const List<String> lines = [
    "You're listening.",
    'A special report from the team.',
    'And we are starting right now.',
    'Let us take a closer look at what we know so far.',
    'The details are still emerging, but the picture is becoming clearer.',
    'One thing is certain: this changes the conversation.',
    'Earlier, we spoke to people on the ground.',
    'They described a situation more complex than it first appears.',
    'There are questions no one seems willing to answer.',
    'And that is exactly why we decided to follow this story.',
    'The evidence points somewhere we did not expect.',
    'So we asked the obvious question: what happens next?',
    'Nobody had a simple answer.',
    'Behind the headlines there is a quieter story.',
    'It is the one worth listening to carefully.',
    'Let us slow down and walk through it together.',
    'Because sometimes the smallest detail matters most.',
    "Which brings us to the heart of it all.",
    'We will keep following this story.',
    'Thanks for listening.',
  ];
  const String opener = 'This is ';
  final int n = lines.length + 1;
  final Duration step = Duration(milliseconds: duration.inMilliseconds ~/ n);
  return [
    PodcastCaption(start: Duration.zero, text: '$opener$episodeTitle.'),
    for (int i = 0; i < lines.length; i++)
      PodcastCaption(start: step * (i + 1), text: lines[i]),
  ];
}

/// A single podcast episode. Immutable; playback position is expressed by
/// copying the episode with a new [position] via [copyWith].
class PodcastEpisode {
  const PodcastEpisode({
    required this.id,
    required this.podcastId,
    required this.podcastName,
    required this.title,
    required this.duration,
    this.episodeNumber,
    this.published,
    this.about,
    this.position = Duration.zero,
    this.transcriptAvailable = false,
    this.audioUrl,
    this.guid,
    this.imageUrl,
  });

  /// Stable unique identifier, e.g. "the-daily-gaza". Used for favourites
  /// and deep links. Falls back to the feed-provided [guid] when a real feed
  /// is parsed; keeps legacy mock episodes unique by construction.
  final String id;

  /// The [PodcastSeries.id] this episode belongs to.
  final String podcastId;

  final String podcastName;
  final String title;
  final Duration duration;

  /// Direct audio file URL from the feed enclosure. The player hands this to
  /// the playback engine for streaming/downloads once feeds are live.
  final String? audioUrl;

  /// Feed-provided stable identifier (e.g. `<guid>`/`enclosure url`) used to
  /// dedupe and persist episodes across refreshes.
  final String? guid;

  /// Episode artwork URL when the feed overrides the show art. Optional.
  final String? imageUrl;

  /// Position within the show, e.g. "Episode 184".
  final int? episodeNumber;

  /// Human-readable publish date, e.g. "Published Aug 18".
  final String? published;

  /// Short description/excerpt used by the episode list and About section.
  final String? about;

  /// Saved playback position. Immutable on the model; the playback controller
  /// owns the live position while the episode is current.
  final Duration position;

  /// Whether a full transcript exists for this episode. The Episode Detail
  /// screen renders a placeholder when false and the transcript when true.
  final bool transcriptAvailable;

  /// Whether this episode has been played to the end.
  bool get isCompleted => duration > Duration.zero && position >= duration;

  /// Fraction of the episode already played, clamped to 0..1.
  double get playbackFraction => duration <= Duration.zero
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  /// Timed transcript lines, derived lazily until a real feed exists.
  List<PodcastCaption> get captions => buildMockCaptions(duration, title);

  /// Chapter markers, derived lazily until a real feed ships them.
  List<PodcastChapter> get chapters => buildMockChapters(duration, title);

  PodcastEpisode copyWith({
    String? id,
    String? podcastId,
    String? podcastName,
    String? title,
    Duration? duration,
    int? episodeNumber,
    String? published,
    String? about,
    Duration? position,
    bool? transcriptAvailable,
    String? audioUrl,
    String? guid,
    String? imageUrl,
  }) {
    return PodcastEpisode(
      id: id ?? this.id,
      podcastId: podcastId ?? this.podcastId,
      podcastName: podcastName ?? this.podcastName,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      published: published ?? this.published,
      about: about ?? this.about,
      position: position ?? this.position,
      transcriptAvailable: transcriptAvailable ?? this.transcriptAvailable,
      audioUrl: audioUrl ?? this.audioUrl,
      guid: guid ?? this.guid,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

/// Stable content identity for one episode, used to diff episodes across
/// feed refreshes without ever relying on list position.
///
/// The feed GUID is preferred. When a feed omits it, a normalized
/// title + publication date + audio URL combination stands in so the same
/// item keeps its identity between fetches.
String episodeIdentityKey(PodcastEpisode episode) {
  final String? guid = episode.guid;
  if (guid != null && guid.isNotEmpty) return 'guid:$guid';
  final String title =
      episode.title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final String date = episode.published?.trim() ?? '';
  final String audio = episode.audioUrl?.trim() ?? '';
  return 'fallback:$title|$date|$audio';
}

/// A podcast show with its episodes, used by the Podcasts and detail screens.
class PodcastSeries {
  const PodcastSeries({
    required this.id,
    required this.name,
    required this.category,
    required this.publisher,
    required this.description,
    this.frequency,
    required this.episodes,
    this.imageUrl,
    this.feedUrl,
    this.feedAuthor,
  });

  /// Stable unique identifier, e.g. "the-daily". Falls back to a slug of the
  /// feed title when parsed from RSS.
  final String id;

  final String name;
  final String category;

  /// The creator/publisher credited with the show, e.g. "The New York Times".
  final String publisher;

  /// Short editorial description shown in the FEATURED section and header.
  final String description;

  /// Release schedule, e.g. "Every weekday". Optional until feeds are real.
  final String? frequency;

  /// Square show artwork URL from the directory or feed art. Optional.
  final String? imageUrl;

  /// Absolute RSS feed URL this series was parsed from, for refresh.
  final String? feedUrl;

  /// Raw `<itunes:author>`/author text from the feed, if the directory has
  /// nothing better than the show host to credit.
  final String? feedAuthor;

  final List<PodcastEpisode> episodes;

  /// Stable identity used by routes and keys.
  String get showId => id;

  /// A single episode by id when present in this feed (null for foreign ids).
  PodcastEpisode? episodeById(String episodeId) {
    for (final PodcastEpisode e in episodes) {
      if (e.id == episodeId) return e;
    }
    return null;
  }
}

/// Temporary series data until a real podcast feed is available.
const List<PodcastSeries> mockPodcasts = [
  PodcastSeries(
    id: 'the-daily',
    name: 'The Daily',
    category: 'News',
    publisher: 'The New York Times',
    frequency: 'Every weekday',
    description: 'How the news works — the stories behind the headlines, from the team that makes them. New episodes every weekday morning.',
    episodes: [
      PodcastEpisode(
        id: 'the-daily-gaza',
        podcastId: 'the-daily',
        podcastName: 'The Daily',
        title: 'The View From Gaza',
        duration: Duration(minutes: 32),
        episodeNumber: 184,
        published: 'Aug 18',
        about: 'On the ground in Gaza, an ordinary day interrupted. We follow one family through a morning that changes everything, and ask what the world knows — and what it refuses to.',
        transcriptAvailable: true,
      ),
      PodcastEpisode(
        id: 'the-daily-banking',
        podcastId: 'the-daily',
        podcastName: 'The Daily',
        title: 'Inside the Banking Crisis',
        duration: Duration(minutes: 28),
        episodeNumber: 183,
        published: 'Aug 17',
        about: 'How three quiet meetings in a single week brought a global lender to the brink — and the decision that pulled it back.',
        position: Duration(minutes: 11, seconds: 42),
      ),
    ],
  ),
  PodcastSeries(
    id: '99pi',
    name: '99% Invisible',
    category: 'Design',
    publisher: 'Roman Mars',
    frequency: 'Irregular',
    description: 'Design is everywhere in our lives, perhaps most powerfully in the places where we\'ve stopped noticing it. This is the story of those unseen details.',
    episodes: [
      PodcastEpisode(
        id: '99pi-airport-codes',
        podcastId: '99pi',
        podcastName: '99% Invisible',
        title: 'The Secret Lives of Airport Codes',
        duration: Duration(minutes: 38),
        episodeNumber: 546,
        published: 'Aug 16',
        about: 'Three letters that decide where everything goes. The surprisingly contested history of the airport code.',
      ),
      PodcastEpisode(
        id: '99pi-banyan',
        podcastId: '99pi',
        podcastName: '99% Invisible',
        title: 'The Great Banyan Tree',
        duration: Duration(minutes: 26),
        episodeNumber: 545,
        published: 'Aug 14',
        about: 'A single tree that became a courtyard, a shade, and a city landmark — and the people who keep it alive.',
        position: Duration(minutes: 6, seconds: 18),
      ),
    ],
  ),
  PodcastSeries(
    id: 'serial',
    name: 'Serial',
    category: 'True Crime',
    publisher: 'Serial Productions',
    frequency: 'Season by season',
    description: 'One story, told week by week. Investigative journalism with a narrative at its core — a single season following one case to the end.',
    episodes: [
      PodcastEpisode(
        id: 'serial-alibi',
        podcastId: 'serial',
        podcastName: 'Serial',
        title: 'The Alibi',
        duration: Duration(minutes: 45),
        episodeNumber: 12,
        published: 'Aug 12',
        about: 'A phone bill, a gas station, and a question nobody can answer. We re-examine the alibi that changed the case.',
      ),
      PodcastEpisode(
        id: 'serial-breakup',
        podcastId: 'serial',
        podcastName: 'Serial',
        title: 'The Breakup',
        duration: Duration(minutes: 41),
        episodeNumber: 11,
        published: 'Aug 10',
        about: 'When the key witness steps back, the whole story tilts. What happened to make them walk away?',
        position: Duration(minutes: 41),
      ),
    ],
  ),
];

/// Flat list of every mock episode, in order.
List<PodcastEpisode> get mockPodcastEpisodes =>
    [for (final PodcastSeries series in mockPodcasts) ...series.episodes];

/// The show promoted in the FEATURED section at the top of the home screen.
PodcastSeries get featuredPodcast => mockPodcasts.first;

/// The episode highlighted by the FEATURED section (the show's latest).
PodcastEpisode get featuredEpisode => featuredPodcast.episodes.first;