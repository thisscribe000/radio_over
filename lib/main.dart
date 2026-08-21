import 'dart:async';

import 'package:flutter/material.dart';

import 'data/content_scope.dart';
import 'data/favourites/favourite_station_store.dart';
import 'data/podcasts/podcast_feed_repository.dart';
import 'data/podcasts/podcast_index_directory_repository.dart';
import 'data/radio/radio_browser_repository.dart';
import 'navigation/app_shell.dart';
import 'playback/engines/just_audio_engine.dart';
import 'playback/playback_controller.dart';
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
  );

  /// Live content scope (Radio Browser + Podcast Index + RSS feeds). Late so
  /// subscription tracking can read follows straight off the controller and
  /// newly discovered episodes can be flagged unseen for the NEW indicator.
  late final AppContent _content = AppContent(
    radio: RadioBrowserRepository(),
    podcastDirectory: PodcastIndexDirectoryRepository(),
    podcastFeeds: RssPodcastFeedRepository(),
    isLive: true,
    savedShowsProvider: () => _controller.savedShows,
    onNewEpisodes: (show, episodes) =>
        _controller.markEpisodesUnseen([for (final e in episodes) e.id]),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_content.loadRadio());
    unawaited(_content.loadShows());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Over',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AppShell(controller: _controller, content: _content),
    );
  }
}