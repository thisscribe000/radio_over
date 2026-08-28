import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'data/content_scope.dart';
import 'data/downloads/download_manager.dart';
import 'data/downloads/download_store.dart';
import 'data/favourites/favourite_station_store.dart';
import 'data/library/library_store.dart';
import 'data/podcasts/podcast_feed_repository.dart';
import 'data/podcasts/apple_podcast_directory_repository.dart';
import 'data/podcasts/podcast_feed_store.dart';
import 'data/progress/playback_progress_store.dart';
import 'data/radio/radio_browser_repository.dart';
import 'models/station.dart';
import 'navigation/app_shell.dart';
import 'playback/engines/just_audio_engine.dart';
import 'playback/playback_controller.dart';
import 'playback/playback_service.dart';
import 'search/recent_search_store.dart';
import 'search/recent_searches.dart';
import 'theme.dart';

void main() => runApp(const RadioApp());

/// Root of the app.
///
/// Holds the single [PlaybackController] and the live [AppContent] scope
/// (Radio Browser + Podcast Index + RSS feeds), and opens on the navigation
/// shell, which starts at the Radio screen.
class RadioApp extends StatefulWidget {
  const RadioApp({super.key});

  @override
  State<RadioApp> createState() => _RadioAppState();
}

class _RadioAppState extends State<RadioApp> {
  final PlaybackController _controller = PlaybackController(
    engine: JustAudioEngine(),
    favouriteStore: SharedPreferencesFavouriteStationStore(),
    libraryStore: SharedPreferencesLibraryStore(),
    progressStore: SharedPreferencesPlaybackProgressStore(),
    downloads: DownloadManager(store: SharedPreferencesDownloadStore()),
  );

  PlaybackService? _audioService;

  /// Persistent search history (SharedPreferences-backed).
  late final RecentSearches _recentSearches =
      RecentSearches(store: SharedPreferencesRecentSearchStore());

  /// Live content scope (Radio Browser + Podcast Index + RSS feeds). Late so
  /// subscription tracking can read follows straight off the controller and
  /// newly discovered episodes can be flagged unseen for the NEW indicator.
  late final AppContent _content = AppContent(
    radio: RadioBrowserRepository(),
    podcastDirectory: ApplePodcastDirectoryRepository(),
    podcastFeeds: RssPodcastFeedRepository(),
    isLive: true,
    customFeedStore: SharedPreferencesPodcastFeedStore(),
    pinnedStation: loveworldRadioStation,
    savedShowsProvider: () => _controller.savedShows,
    onNewEpisodes: (show, episodes) =>
        _controller.markEpisodesUnseen([for (final e in episodes) e.id]),
  );

  @override
  void initState() {
    super.initState();
    _audioService = PlaybackService(controller: _controller);
    unawaited(AudioService.init(
      builder: () => _audioService!,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.radioover.radio_over.audio',
        androidNotificationChannelName: 'Radio Over',
      ),
    ));
    unawaited(_content.loadRadio());
    unawaited(_content.loadShows());
    unawaited(_content.restoreCustomFeeds());
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Over',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AppShell(
        controller: _controller,
        content: _content,
        recentSearches: _recentSearches,
      ),
    );
  }
}