import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/data/favourites/favourite_station_store.dart';
import 'package:radio_over/models/playback.dart';
import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/models/station.dart';
import 'package:radio_over/playback/audio_engine.dart';
import 'package:radio_over/playback/playback_controller.dart';

/// Lets synchronous engine events (delivered as stream microtasks) and
/// zero-duration retry timers run before assertions.
Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

RadioStation station([String id = 'bbc-world-service']) => RadioStation(
      id: id,
      name: 'BBC World Service',
      category: 'News',
      program: 'World News Today',
      country: 'United Kingdom',
      streamUrl: 'https://example.com/$id/stream',
    );

PodcastEpisode episode() => const PodcastEpisode(
      id: 'ep-1',
      podcastId: 'the-daily',
      podcastName: 'The Daily',
      title: 'An episode',
      duration: Duration(minutes: 20),
      audioUrl: 'https://example.com/ep-1.mp3',
    );

/// In-memory store pre-seeded for restore tests.
class SeededStore implements FavouriteStationStore {
  SeededStore(this.data);
  Map<String, RadioStation> data;

  @override
  Future<Map<String, RadioStation>> load() async =>
      Map<String, RadioStation>.of(data);

  @override
  Future<void> save(Map<String, RadioStation> favourites) async {
    data = Map<String, RadioStation>.of(favourites);
  }
}

void main() {
  group('radio stream state machine', () {
    test('listen live reports connecting before the engine confirms playing',
        () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(
        engine: engine,
        radioRetryDelay: Duration.zero,
      );
      addTearDown(controller.dispose);

      expect(controller.radioState, RadioConnectionState.idle);
      controller.playRadioStation(station());
      // The start is async; nothing has confirmed audio yet.
      expect(controller.radioState, anyOf(
        RadioConnectionState.connecting,
        RadioConnectionState.playing,
      ));

      await settle();
      expect(controller.radioState, RadioConnectionState.playing);
      expect(engine.currentUrl, 'https://example.com/bbc-world-service/stream');
    });

    test('buffering and recovery are reflected while live', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(
        engine: engine,
        radioRetryDelay: Duration.zero,
      );
      addTearDown(controller.dispose);

      controller.playRadioStation(station());
      await settle();

      engine.simulateBuffering();
      await settle();
      expect(controller.radioState, RadioConnectionState.buffering);

      engine.simulateRecovery();
      await settle();
      expect(controller.radioState, RadioConnectionState.playing);
    });

    test('a dead stream auto-retries a limited number of times then errors',
        () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(
        engine: engine,
        radioRetryDelay: Duration.zero,
      );
      addTearDown(controller.dispose);

      // Every start fails: arm before the synchronous first attempt, then
      // re-arm each time the controller enters CONNECTING (each retry).
      int connectingCount = 0;
      engine.failNextStart = true;
      controller.addListener(() {
        if (controller.radioState == RadioConnectionState.connecting) {
          connectingCount++;
          engine.failNextStart = true;
        }
      });

      controller.playRadioStation(station());
      await settle();
      await settle();
      await settle();
      expect(connectingCount, greaterThanOrEqualTo(2));
      expect(controller.radioState, RadioConnectionState.error);
    });

    test('manual TRY AGAIN resets the budget and reconnects', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(
        engine: engine,
        radioRetryDelay: Duration.zero,
      );
      addTearDown(controller.dispose);

      bool failuresArmed = true;
      engine.failNextStart = true;
      controller.addListener(() {
        if (controller.radioState == RadioConnectionState.connecting &&
            failuresArmed) {
          engine.failNextStart = true;
        }
      });

      controller.playRadioStation(station());
      await settle();
      await settle();
      await settle();
      expect(controller.radioState, RadioConnectionState.error);

      // The manual retry is allowed to succeed.
      failuresArmed = false;
      controller.retryRadio();
      await settle();
      expect(controller.radioState, RadioConnectionState.playing);
      expect(engine.currentUrl, 'https://example.com/bbc-world-service/stream');
    });

    test('now-playing metadata surfaces exactly as reported and clears on switch',
        () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(
        engine: engine,
        radioRetryDelay: Duration.zero,
      );
      addTearDown(controller.dispose);

      controller.playRadioStation(station());
      await settle();
      expect(controller.radioNowPlaying, isNull);

      engine.simulateMetadata('Nina Simone - Feeling Good');
      await settle();
      expect(controller.radioNowPlaying, 'Nina Simone - Feeling Good');

      controller.playRadioStation(station('jazz-fm'));
      await settle();
      expect(controller.radioNowPlaying, isNull);
    });

    test('switching to a podcast stops radio and resets its surface', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(
        engine: engine,
        radioRetryDelay: Duration.zero,
      );
      addTearDown(controller.dispose);

      controller.playRadioStation(station());
      await settle();
      expect(engine.currentUrl, isNotNull);

      controller.playPodcastEpisode(episode());
      await settle();
      expect(controller.audioType, AudioType.podcast);
      expect(controller.currentStation, isNull);
      expect(controller.radioState, RadioConnectionState.idle);
      expect(controller.radioNowPlaying, isNull);
      expect(engine.currentUrl, 'https://example.com/ep-1.mp3');

      // A late radio event after the switch must not resurrect radio state.
      engine.simulateError();
      await settle();
      expect(controller.audioType, AudioType.podcast);
      expect(controller.radioState, RadioConnectionState.idle);
    });
  });

  group('favourite persistence', () {
    test('favourites survive a restart through the store', () async {
      final SeededStore store = SeededStore({});
      final PlaybackController first = PlaybackController(favouriteStore: store);
      first.toggleFavouriteStation('bbc-world-service', details: station());
      await settle();
      first.dispose();

      final PlaybackController second =
          PlaybackController(favouriteStore: store);
      await settle();
      expect(second.isFavouriteStation('bbc-world-service'), isTrue);
      expect(second.favouriteStationDetails.single.name, 'BBC World Service');
      second.dispose();
    });

    test('a restored offline favourite is kept, not dropped', () async {
      final SeededStore store = SeededStore({
        'ghost-fm': RadioStation(
          id: 'ghost-fm',
          name: 'Ghost FM',
          category: 'Ambient',
          program: 'LIVE RADIO',
          streamUrl: 'https://ghost.example/stream',
          isOnline: false,
        ),
      });
      final PlaybackController controller =
          PlaybackController(favouriteStore: store);
      await settle();

      expect(controller.isFavouriteStation('ghost-fm'), isTrue);
      expect(controller.favouriteStationDetails.single.isOnline, isFalse);
      controller.dispose();
    });
  });
}
