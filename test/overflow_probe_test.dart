import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/data/content_scope.dart';
import 'package:radio_over/data/radio/mock_radio_repository.dart';
import 'package:radio_over/data/podcasts/mock_podcast_directory_repository.dart';
import 'package:radio_over/data/podcasts/mock_podcast_feed_repository.dart';
import 'package:radio_over/models/station.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/radio_screen.dart';
import 'package:radio_over/theme.dart';

List<RadioStation> _adversarialStations() => [
  RadioStation(
    id: 'long-featured',
    name: 'Very Long Name Community Radio Station International Broadcasting',
    category: 'Long Category Name Entertainment News Talk',
    country: 'United Kingdom of Great Britain and Northern Ireland',
    program: 'Some quite long programme title that keeps going',
    streamUrl: 'https://example.com/stream',
  ),
  RadioStation(
    id: 'talk-radio',
    name: 'Talk Radio',
    category: 'Talk',
    country: 'United Kingdom',
    program: 'The Afternoon Debate',
    streamUrl: 'https://example.com/stream',
  ),
  RadioStation(
    id: 'news',
    name: 'News 24/7 World Radio Network Service',
    category: 'News',
    country: 'United States',
    program: 'Top stories',
    streamUrl: 'https://example.com/stream',
  ),
];

AppContent _content() => AppContent(
  radio: MockRadioRepository(_adversarialStations()),
  podcastDirectory: const MockPodcastDirectoryRepository(),
  podcastFeeds: const MockPodcastFeedRepository(),
  isLive: true,
);

Future<void> _pumpRadio(
  WidgetTester tester,
  PlaybackController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: RadioScreen(controller: controller, content: _content()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

final List<String> _errors = <String>[];

void _capture(WidgetTester tester, String label) {
  final dynamic e = tester.takeException();
  if (e != null) _errors.add('$label: $e');
}

void main() {
  setUp(() => _errors.clear());

  testWidgets('no overflow with long station data at 390px', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final PlaybackController controller = PlaybackController();
    addTearDown(controller.dispose);

    controller.playRadioStation(_adversarialStations().first);
    await _pumpRadio(tester, controller);

    final Finder scrollable = find.byType(Scrollable).first;
    for (int i = 0; i < 30; i++) {
      _capture(tester, 'step $i');
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 100));
    }
    _capture(tester, 'final');

    expect(_errors, isEmpty, reason: 'Overflow:\n${_errors.join('\n')}');
  });

  testWidgets('no overflow with long station data at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final PlaybackController controller = PlaybackController();
    addTearDown(controller.dispose);

    controller.playRadioStation(_adversarialStations().first);
    await _pumpRadio(tester, controller);

    final Finder scrollable = find.byType(Scrollable).first;
    for (int i = 0; i < 30; i++) {
      _capture(tester, 'narrow step $i');
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 100));
    }
    _capture(tester, 'narrow final');

    expect(_errors, isEmpty, reason: 'Overflow:\n${_errors.join('\n')}');
  });
}
