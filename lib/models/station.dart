/// A single scheduled programme on a radio station.
class RadioProgramme {
  const RadioProgramme({
    required this.id,
    required this.stationId,
    required this.title,
    required this.start,
    required this.end,
    this.description,
    this.host,
    this.day = 'TODAY',
  });

  /// Stable unique identifier, e.g. "bbc-world-news".
  final String id;

  /// The owning [RadioStation.stationId].
  final String stationId;

  final String title;

  /// Optional short description, shown in UP NEXT / NOW PLAYING.
  final String? description;

  /// Presenter/host name where known, e.g. "Smitha Mundasad".
  final String? host;

  /// Start time, e.g. "09:00".
  final String start;

  /// End time, e.g. "12:00".
  final String end;

  /// Schedule-day label, e.g. "TODAY", "FRI". Kept as a display string so the
  /// schedule reads naturally and stays easy to scan.
  final String day;
}

/// A single live radio station.
class RadioStation {
  const RadioStation({
    required this.name,
    required this.category,
    required this.program,
    this.id,
    this.country,
    this.city,
    this.description,
    this.language,
    this.website,
    this.schedule = const [],
    this.logoUrl,
    this.streamUrl,
    this.streamType,
    this.tags = const [],
    this.bitrate,
    this.codec,
    this.favicon,
    this.isOnline = true,
    this.nowPlaying,
  });

  /// Stable unique identifier, e.g. "bbc-world-service". Falls back to the
  /// display name so existing stations never need an id to be routable.
  final String? id;

  final String name;

  /// Primary genre/category, e.g. "News".
  final String category;

  /// The current programme/show being broadcast. Legacy display string used
  /// by the player and mini players; structured schedule data lives alongside.
  final String program;

  /// Optional country/region, shown when useful (e.g. a featured station).
  final String? country;

  /// Optional city, shown alongside the country when known.
  final String? city;

  /// Short editorial description for ABOUT THIS STATION.
  final String? description;

  /// Primary broadcast language, e.g. "English". Optional.
  final String? language;

  /// Official source, shown as a quiet secondary detail. Optional.
  final String? website;

  /// Today's and upcoming programmes, ordered by time.
  final List<RadioProgramme> schedule;

  /// Direct URL to the audio stream, e.g. an Icecast/Shoutcast endpoint.
  /// The player hands this to the playback engine when LISTEN LIVE is used.
  final String? streamUrl;

  /// Stream container media type, e.g. "audio/mpeg". Optional.
  final String? streamType;

  /// Free-form tags/categories reported by the directory, e.g. news, talk.
  final List<String> tags;

  /// Reported stream bitrate in kbps when the directory provides it.
  final int? bitrate;

  /// Reported stream codec, e.g. "MP3", "AAC". Optional.
  final String? codec;

  /// Square station artwork/logo URL from the directory. Optional.
  final String? logoUrl;

  /// Small favicon URL. Optional.
  final String? favicon;

  /// Whether the directory reports the stream as currently online.
  final bool isOnline;

  /// Free-form currently-airing programme if the source provides it.
  final String? nowPlaying;

  /// Stable identity used by routes and keys.
  String get stationId => id ?? name;

  /// Human-readable location line, e.g. "London, United Kingdom".
  String? get location {
    if (city != null && country != null) return '$city, $country';
    return country;
  }

  /// The earliest TODAY programme on air, if the schedule knows one.
  RadioProgramme? get currentProgramme {
    for (final RadioProgramme p in schedule) {
      if (p.day == 'TODAY') return p;
    }
    return null;
  }

  /// The next TODAY programme after [currentProgramme].
  RadioProgramme? get nextProgramme {
    final RadioProgramme? current = currentProgramme;
    if (current == null) return null;
    for (final RadioProgramme p in schedule) {
      if (p.day == 'TODAY' && p.id != current.id) return p;
    }
    return null;
  }
}

/// Curated discovery categories used by the home screen's filter chips.
const List<String> radioCategories = [
  'News',
  'Music',
  'Talk',
  'Sports',
  'Gospel',
  'Business',
  'Culture',
  'Entertainment',
];

/// Loveworld Radio — pinned at the top of the radio catalogue and featured in
/// LIVE NOW. Kept as its own named constant so both the mock catalogue and the
/// live scope can reference the same persistent station (it is re-inserted to
/// the front of the catalogue whenever a live load replaces it).
const RadioStation loveworldRadioStation = RadioStation(
  id: 'loveworld-radio',
  name: 'Loveworld Radio',
  category: 'Gospel',
  program: 'Praise and Worship',
  country: 'Nigeria',
  city: 'Lagos',
  language: 'English',
  website: 'loveworldradio.org',
  description:
      'Loveworld Radio — uplifting praise, worship and the word, broadcast from the Loveworld Christian network.',
  streamUrl: 'https://radio.superfm963.com/proxy/lwradio/stream',
  streamType: 'audio/mpeg',
  codec: 'MP3',
  tags: ['gospel', 'worship', 'christian'],
  schedule: [
    RadioProgramme(
      id: 'loveworld-praise-worship',
      stationId: 'loveworld-radio',
      title: 'Praise and Worship',
      description: 'A session of praise, worship and the word.',
      start: '06:00',
      end: '09:00',
      day: 'TODAY',
    ),
    RadioProgramme(
      id: 'loveworld-word-session',
      stationId: 'loveworld-radio',
      title: 'The Word Session',
      description: 'Biblical teaching and devotion.',
      start: '09:00',
      end: '12:00',
      day: 'TODAY',
    ),
    RadioProgramme(
      id: 'loveworld-evening-worship',
      stationId: 'loveworld-radio',
      title: 'Evening Worship',
      description: 'Winding down the day with worship.',
      start: '18:00',
      end: '21:00',
      day: 'TODAY',
    ),
  ],
);

/// Temporary station data until a real radio API is available.
///
/// The first entries are the demo stations the players were built around;
/// the rest round out the discovery categories. Kept separate from the UI so
/// real stations can replace this list later.
const List<RadioStation> mockStations = [
  loveworldRadioStation,
  RadioStation(
    id: 'bbc-world-service',
    name: 'BBC World Service',
    category: 'News',
    program: 'World News Today',
    country: 'United Kingdom',
    city: 'London',
    language: 'English',
    website: 'bbc.co.uk/worldservice',
    description:
        'BBC World Service provides international news, analysis and programming from around the world, around the clock.',
    schedule: [
      RadioProgramme(
        id: 'bbc-world-news-today',
        stationId: 'bbc-world-service',
        title: 'World News Today',
        description: 'A global round-up of the day\'s biggest stories.',
        host: 'Smitha Mundasad',
        start: '09:00',
        end: '11:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'bbc-global-business',
        stationId: 'bbc-world-service',
        title: 'Global Business Report',
        description: 'Business and markets from around the world.',
        host: 'Aaron Heslehurst',
        start: '11:00',
        end: '13:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'bbc-world-news',
        stationId: 'bbc-world-service',
        title: 'World News',
        description: 'Headlines and analysis on the hour.',
        start: '13:00',
        end: '15:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'bbc-the-documentary',
        stationId: 'bbc-world-service',
        title: 'The Documentary',
        description: 'Stories that change the way we see the world.',
        host: 'Leila Nathoo',
        start: '15:00',
        end: '16:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'bbc-business-today-fri',
        stationId: 'bbc-world-service',
        title: 'Business Today',
        description: 'The business stories behind the headlines.',
        start: '10:00',
        end: '12:00',
        day: 'FRI',
      ),
    ],
  ),
  RadioStation(
    id: 'talk-radio',
    name: 'Talk Radio',
    category: 'Talk',
    program: 'The Afternoon Debate',
    country: 'United Kingdom',
    city: 'London',
    language: 'English',
    website: 'talkradio.co.uk',
    description:
        'The home of live, unscripted conversation — national debate and the big topics of the day.',
    schedule: [
      RadioProgramme(
        id: 'talk-morning-call',
        stationId: 'talk-radio',
        title: 'The Morning Call',
        description: 'Opening lines on the day\'s headlines.',
        start: '09:00',
        end: '11:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'talk-afternoon-debate',
        stationId: 'talk-radio',
        title: 'The Afternoon Debate',
        description: 'One issue, two sides, your calls.',
        start: '11:00',
        end: '14:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'talk-drive',
        stationId: 'talk-radio',
        title: 'Talk Drive',
        description: 'News, sport and the stories driving the afternoon.',
        start: '14:00',
        end: '18:00',
        day: 'TODAY',
      ),
    ],
  ),
  RadioStation(
    id: 'jazz-fm',
    name: 'Jazz FM',
    category: 'Jazz',
    program: 'Late Night Jazz',
    country: 'United Kingdom',
    city: 'London',
    language: 'English',
    website: 'jazzfm.co.uk',
    description:
        'Jazz, soul and the smooth sounds of late-night radio, with presenters who know every note.',
    schedule: [
      RadioProgramme(
        id: 'jazz-morning-smooth',
        stationId: 'jazz-fm',
        title: 'Morning Smooth Jazz',
        description: 'An easy start to the day.',
        start: '07:00',
        end: '10:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'jazz-lunchtime',
        stationId: 'jazz-fm',
        title: 'Lunchtime Jazz',
        description: 'Standards and classics for the middle of the day.',
        start: '10:00',
        end: '13:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'jazz-late-night',
        stationId: 'jazz-fm',
        title: 'Late Night Jazz',
        description: 'Slow, warm and after dark.',
        host: 'Sienna Blake',
        start: '13:00',
        end: '16:00',
        day: 'TODAY',
      ),
    ],
  ),
  RadioStation(
    id: 'npr',
    name: 'NPR',
    category: 'News',
    program: 'Morning Edition',
    country: 'United States',
    city: 'Washington DC',
    language: 'English',
    website: 'npr.org',
    description:
        'American public radio — journalism, storytelling and music from stations across the United States.',
    schedule: [
      RadioProgramme(
        id: 'npr-morning-edition',
        stationId: 'npr',
        title: 'Morning Edition',
        description: 'The news of the morning, told from where it matters.',
        host: 'Steve Inskeep',
        start: '05:00',
        end: '09:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'npr-here-now',
        stationId: 'npr',
        title: 'Here & Now',
        description: 'The midday news magazine.',
        start: '09:00',
        end: '12:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'npr-all-things',
        stationId: 'npr',
        title: 'All Things Considered',
        description: 'The day\'s news in context.',
        start: '16:00',
        end: '18:00',
        day: 'TODAY',
      ),
    ],
  ),
  RadioStation(
    id: 'classic-fm',
    name: 'Classic FM',
    category: 'Music',
    program: 'The Breakfast Show',
    country: 'United Kingdom',
    city: 'London',
    language: 'English',
    website: 'classicfm.com',
    description:
        'Classical music for everyone — the world\'s great orchestras and the presenters who bring them home.',
    schedule: [
      RadioProgramme(
        id: 'classic-breakfast',
        stationId: 'classic-fm',
        title: 'The Breakfast Show',
        description: 'Bright and famous classics to start the day.',
        host: 'Alexander Armstrong',
        start: '06:00',
        end: '09:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'classic-mid-morning',
        stationId: 'classic-fm',
        title: 'Mid-morning Classics',
        description: 'The relaxed upper reaches of the morning.',
        start: '09:00',
        end: '12:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'classic-dinner',
        stationId: 'classic-fm',
        title: 'Dinner Classics',
        description: 'Smooth music for the evening.',
        start: '17:00',
        end: '20:00',
        day: 'TODAY',
      ),
    ],
  ),
  RadioStation(
    id: 'espn-radio',
    name: 'ESPN Radio',
    category: 'Sports',
    program: 'SportsCenter Live',
    country: 'United States',
    city: 'Bristol',
    language: 'English',
    website: 'espn.com/radio',
    description:
        'Around-the-clock sports talk — scores, analysis and the voices of the games you follow.',
    schedule: [
      RadioProgramme(
        id: 'espn-sportcenter',
        stationId: 'espn-radio',
        title: 'SportsCenter Live',
        description: 'Live updates and morning debate.',
        start: '09:00',
        end: '12:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'espn-game-day',
        stationId: 'espn-radio',
        title: 'Game Day',
        description: 'Pregame build-up and the day\'s marquee matchups.',
        start: '12:00',
        end: '15:00',
        day: 'TODAY',
      ),
    ],
  ),
  RadioStation(
    id: 'the-spirit',
    name: 'The Spirit',
    category: 'Gospel',
    program: 'Morning Devotion',
    country: 'United States',
    city: 'Atlanta',
    language: 'English',
    website: 'thespirit.com',
    description:
        'Inspirational music, teaching and devotion — uplifting programming for the whole day.',
    schedule: [
      RadioProgramme(
        id: 'spirit-morning-devotion',
        stationId: 'the-spirit',
        title: 'Morning Devotion',
        description: 'Beginning the day with scripture and song.',
        start: '06:00',
        end: '08:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'spirit-gospel-hour',
        stationId: 'the-spirit',
        title: 'The Gospel Hour',
        description: 'The best of church choirs and gospel greats.',
        start: '08:00',
        end: '11:00',
        day: 'TODAY',
      ),
    ],
  ),
  RadioStation(
    id: 'markets-live',
    name: 'Markets Live',
    category: 'Business',
    program: 'Market Briefing',
    country: 'United Kingdom',
    city: 'London',
    language: 'English',
    website: 'marketslive.uk',
    description:
        'Live market coverage — opening calls, closing bells and everything in between.',
    schedule: [
      RadioProgramme(
        id: 'markets-briefing',
        stationId: 'markets-live',
        title: 'Market Briefing',
        description: 'The morning\'s market outlook in thirty minutes.',
        start: '08:00',
        end: '08:30',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'markets-live-desk',
        stationId: 'markets-live',
        title: 'The Live Desk',
        description: 'Reaction as the exchanges open across Europe.',
        start: '08:30',
        end: '11:00',
        day: 'TODAY',
      ),
    ],
  ),
  RadioStation(
    id: 'culture-stream',
    name: 'Culture Stream',
    category: 'Culture',
    program: 'The Arts Hour',
    country: 'France',
    city: 'Paris',
    language: 'French',
    website: 'culturestream.fr',
    description:
        'Arts, ideas and the cultural conversations of the moment, broadcast from Paris to the world.',
    schedule: [
      RadioProgramme(
        id: 'culture-arts-hour',
        stationId: 'culture-stream',
        title: 'The Arts Hour',
        description: 'Interviews and ideas from the creative world.',
        host: 'Margaux Fontaine',
        start: '10:00',
        end: '12:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'culture-cinema',
        stationId: 'culture-stream',
        title: 'Cinema Front Row',
        description: 'Reviews and previews from the film festival circuit.',
        start: '12:00',
        end: '14:00',
        day: 'TODAY',
      ),
    ],
  ),
  RadioStation(
    id: 'pop-world',
    name: 'Pop World',
    category: 'Entertainment',
    program: 'Tonight\'s Headlines',
    country: 'United Kingdom',
    city: 'London',
    language: 'English',
    website: 'popworld.co.uk',
    description:
        'Pop music and entertainment — the hits, the tour news and the headlines everyone is talking about.',
    schedule: [
      RadioProgramme(
        id: 'pop-hits-now',
        stationId: 'pop-world',
        title: 'Hits Now',
        description: 'The biggest pop records on repeat.',
        start: '09:00',
        end: '12:00',
        day: 'TODAY',
      ),
      RadioProgramme(
        id: 'pop-todays-headlines',
        stationId: 'pop-world',
        title: 'Tonight\'s Headlines',
        description: 'Entertainment news you can talk about.',
        host: 'Dana Cole',
        start: '12:00',
        end: '14:00',
        day: 'TODAY',
      ),
    ],
  ),
];

/// The station promoted in the LIVE NOW feature at the top of the home screen.
RadioStation get featuredStation => mockStations.first;