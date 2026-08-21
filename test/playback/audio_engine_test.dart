import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/models/station.dart';
import 'package:radio_over/playback/audio_engine.dart';
import 'package:radio_over/playback/playback_controller.dart';

void main() {
  group('SimulatedAudioEngine', () {
    test('records the URL it was asked to play', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      await engine.start('https://stream/radio.mp3');
      expect(engine.currentUrl, 'https://stream/radio.mp3');
      expect(engine.isPaused, isFalse);
      expect(engine.isStopped, isFalse);
    });

    test('pause/resume/stop flip its flags', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      await engine.start('u');
      await engine.pause();
      expect(engine.isPaused, isTrue);
      await engine.resume();
      expect(engine.isPaused, isFalse);
      await engine.stop();
      expect(engine.isStopped, isTrue);
      expect(engine.currentUrl, isNull);
    });
  });

  group('PlaybackController engine delegation', () {
    const RadioStation station = RadioStation(
      name: 'Waves',
      category: 'Music',
      program: 'Airing Now',
      streamUrl: 'https://waves/listen.mp3',
    );

    test('playRadioStation hands the stream URL to the engine', () {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);

      controller.playRadioStation(station);
      expect(engine.currentUrl, 'https://waves/listen.mp3');

      controller.dispose();
    });

    test('toggle pause/resume reaches the engine; stop releases it', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final PlaybackController controller = PlaybackController(engine: engine);
      controller.playRadioStation(station);

      controller.toggle();
      expect(engine.isPaused, isTrue);
      controller.toggle();
      expect(engine.isPaused, isFalse);

      controller.stop();
      expect(engine.isStopped, isTrue);
      controller.dispose();
    });
  });
}