import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/models/playback.dart';
import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/models/station.dart';
import 'package:radio_over/playback/audio_engine.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/playback/playback_service.dart';

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

/// Regression coverage for the "media source ownership" invariant: the radio
/// stream is the active source and nothing (UI navigation, service commands)
/// may claim a podcast is playing or pause a podcast while radio audio flows.
///
/// The controller guarantees mutual exclusion: [PlaybackController.playRadioStation]
/// nulls [PlaybackController.currentEpisode] and sets audioType to radio, so the
/// podcast surface is never reported active and the system media session reports
/// the station. These tests pin that behaviour so a future change cannot regress it.
void main() {
  PlaybackService buildService(PlaybackController controller) =>
      PlaybackService(
        controller: controller,
        configureSession: () async {},
      );

  group('radio owns the playback source while playing', () {
    test('radio playback leaves no episode active (both surfaces mutually exclusive)',
        () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);

      controller.playRadioStation(station());

      expect(controller.audioType, AudioType.radio);
      expect(controller.radioActive, isTrue);
      expect(controller.currentStation, isNotNull);

      expect(controller.currentEpisode, isNull);
      expect(controller.podcastActive, isFalse);
    });

    test('navigating to the podcast surface does not re-own the source', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);

      controller.playRadioStation(station());
      await settle();

      // "Navigation" does not call any controller method; assert that merely
      // querying the podcast surface (what the Podcasts tab does) cannot flip
      // the active source or fabricate an active episode.
      expect(controller.podcastActive, isFalse);
      expect(controller.currentEpisode, isNull);
      expect(controller.audioType, AudioType.radio);
      expect(controller.isPlaying, isTrue);
    });

    test('system media item reports the radio station while radio plays', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);

      controller.playPodcastEpisode(episode());
      await settle();

      // User then starts radio.
      controller.playRadioStation(station());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);

      final MediaItem item = service.mediaItem.value!;
      expect(item.id, 'station:bbc-world-service');
      expect(item.title, 'BBC World Service');
      expect(item.isLive, isTrue);
    });

    test('system controls/state reflect radio (no podcast skip controls)', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);

      controller.playRadioStation(station());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);

      final PlaybackState state = service.playbackState.value;
      expect(state.playing, isTrue);
      final List<MediaAction> actions =
          state.controls.map((c) => c.action).toList();
      expect(actions, isNot(contains(MediaAction.skipToNext)));
      expect(actions, isNot(contains(MediaAction.skipToPrevious)));
    });

    test('pause from the system pauses the radio stream, not a podcast', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);

      controller.playRadioStation(station());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);

      await service.pause();

      expect(controller.audioType, AudioType.radio);
      expect(controller.isPlaying, isFalse);
      expect(controller.currentEpisode, isNull);
      expect(controller.podcastActive, isFalse);
      expect(service.playbackState.value.playing, isFalse);
    });

    test('pause then play resumes the same radio source', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);

      controller.playRadioStation(station());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);

      await service.pause();
      await service.play();

      expect(controller.audioType, AudioType.radio);
      expect(controller.isPlaying, isTrue);
      expect(controller.podcastActive, isFalse);
    });

    test('switching to a podcast changes the engine source and pause target',
        () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);

      controller.playRadioStation(station());
      await settle();
      controller.playPodcastEpisode(episode());
      await settle();

      expect(controller.audioType, AudioType.podcast);
      expect(controller.currentStation, isNull);
      expect(controller.currentEpisode?.id, 'ep-1');
      expect(engine.currentUrl, episode().audioUrl);

      controller.toggle();
      expect(controller.isPlaying, isFalse);
      expect(engine.isPaused, isTrue);
      expect(engine.currentUrl, episode().audioUrl);
    });

    test('switching back to radio changes the engine source and pause target',
        () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);

      controller.playPodcastEpisode(episode());
      await settle();
      controller.playRadioStation(station());
      await settle();

      expect(controller.audioType, AudioType.radio);
      expect(controller.currentEpisode, isNull);
      expect(engine.currentUrl, station().streamUrl);

      controller.toggle();
      expect(controller.isPlaying, isFalse);
      expect(engine.isPaused, isTrue);
      expect(engine.currentUrl, station().streamUrl);
    });
  });
}
