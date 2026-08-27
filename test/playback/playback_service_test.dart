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
      logoUrl: 'https://example.com/logo.png',
    );

PodcastEpisode episode() => const PodcastEpisode(
      id: 'ep-1',
      podcastId: 'the-daily',
      podcastName: 'The Daily',
      title: 'An episode',
      duration: Duration(minutes: 20),
      audioUrl: 'https://example.com/ep-1.mp3',
      imageUrl: 'https://example.com/art.jpg',
    );

void main() {
  PlaybackService buildService(PlaybackController controller) =>
      PlaybackService(
        controller: controller,
        configureSession: () async {},
      );

  group('PlaybackService media-session bridge', () {
    test('play resumes a paused controller', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playPodcastEpisode(episode());
      controller.toggle(); // pause
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      await service.play();
      expect(controller.isPlaying, isTrue);
    });

    test('pause pauses a playing controller', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playPodcastEpisode(episode());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      await service.pause();
      expect(controller.isPlaying, isFalse);
    });

    test('play is a no-op when already playing', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playPodcastEpisode(episode());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      await service.play();
      expect(controller.isPlaying, isTrue);
      expect(engine.isPaused, isFalse);
    });

    test('stop stops playback', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playRadioStation(station());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      await service.stop();
      expect(controller.audioType, AudioType.none);
      expect(engine.isStopped, isTrue);
    });

    test('seek forwards to the controller', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playPodcastEpisode(episode());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      await service.seek(const Duration(seconds: 30));
      expect(controller.podcastPosition, const Duration(seconds: 30));
    });

    test('fastForward nudges a podcast forward 10 seconds', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playPodcastEpisode(episode());
      controller.seek(const Duration(minutes: 2));
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      await service.fastForward();
      expect(controller.podcastPosition, const Duration(minutes: 2, seconds: 10));
    });

    test('fastForward clamps to the episode duration', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playPodcastEpisode(episode());
      controller.seek(const Duration(minutes: 19, seconds: 55));
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      await service.fastForward();
      expect(controller.podcastPosition, controller.podcastDuration);
    });

    test('rewind nudges a podcast backward 10 seconds', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playPodcastEpisode(episode());
      controller.seek(const Duration(minutes: 2));
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      await service.rewind();
      expect(controller.podcastPosition, const Duration(minutes: 1, seconds: 50));
    });

    test('rewind clamps at zero', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playPodcastEpisode(episode());
      controller.seek(const Duration(seconds: 5));
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      await service.rewind();
      expect(controller.podcastPosition, Duration.zero);
    });

    test('fastForward and rewind are no-ops for radio', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playRadioStation(station());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      await service.fastForward();
      await service.rewind();
      expect(controller.radioState, RadioConnectionState.playing);
    });

    test('state sync reports playing/position for a podcast', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playPodcastEpisode(episode());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      final PlaybackState state = service.playbackState.value;
      expect(state.playing, isTrue);
      expect(state.processingState, AudioProcessingState.ready);
      expect(state.updatePosition, Duration.zero);
      expect(state.systemActions, contains(MediaAction.seek));
      expect(state.controls.map((c) => c.action), contains(MediaAction.skipToNext));
    });

    test('media item carries podcast metadata and duration', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playPodcastEpisode(episode());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      final MediaItem item = service.mediaItem.value!;
      expect(item.title, 'An episode');
      expect(item.artist, 'The Daily');
      expect(item.duration, const Duration(minutes: 20));
      expect(item.artUri, Uri.parse('https://example.com/art.jpg'));
    });

    test('radio media item carries station name and live artwork', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playRadioStation(station());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      final MediaItem item = service.mediaItem.value!;
      expect(item.title, 'BBC World Service');
      expect(item.artist, 'World News Today');
      expect(item.isLive, isTrue);
      expect(item.artUri, Uri.parse('https://example.com/logo.png'));
    });

    test('radio falls back to favicon when no logo', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playRadioStation(RadioStation(
        id: 'talk-radio',
        name: 'Talk Radio',
        category: 'Talk',
        program: 'The Afternoon Debate',
        streamUrl: 'https://example.com/stream',
        favicon: 'https://example.com/fav.ico',
      ));
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      final MediaItem item = service.mediaItem.value!;
      expect(item.artUri, Uri.parse('https://example.com/fav.ico'));
    });

    test('radio with no artwork yields no art URI', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playRadioStation(RadioStation(
        id: 'no-art',
        name: 'No Art Station',
        category: 'News',
        program: 'Programme',
        streamUrl: 'https://example.com/stream',
      ));
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      final MediaItem item = service.mediaItem.value!;
      expect(item.artUri, isNull);
    });

    test('stopping sets processing state to idle', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playPodcastEpisode(episode());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      await service.stop();
      expect(service.playbackState.value.processingState,
          AudioProcessingState.idle);
    });

    test('onTaskRemoved stops playback', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);
      controller.playRadioStation(station());
      await settle();

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);
      await service.onTaskRemoved();
      expect(controller.audioType, AudioType.none);
      expect(engine.isStopped, isTrue);
    });

    test('state stays synced when controller toggles after service creation',
        () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      addTearDown(controller.dispose);

      final PlaybackService service = buildService(controller);
      addTearDown(service.dispose);

      controller.playPodcastEpisode(episode());
      await settle();
      expect(service.playbackState.value.playing, isTrue);

      controller.toggle(); // pause
      await settle();
      expect(service.playbackState.value.playing, isFalse);
    });
  });
}
