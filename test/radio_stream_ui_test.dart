import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/models/playback.dart';
import 'package:radio_over/models/station.dart';
import 'package:radio_over/playback/audio_engine.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/library_screen.dart';
import 'package:radio_over/screens/radio_player_screen.dart';
import 'package:radio_over/screens/radio_screen.dart';
import 'package:radio_over/theme.dart';

RadioStation station() => const RadioStation(
      id: 'bbc-world-service',
      name: 'BBC World Service',
      category: 'News',
      program: 'World News Today',
      country: 'United Kingdom',
      streamUrl: 'https://example.com/stream',
    );

/// An engine that never finishes connecting — the honest CONNECTING… state.
class StalledEngine extends SimulatedAudioEngine {
  @override
  Future<void> start(String url) async {}
}

void main() {
  testWidgets('player shows CONNECTING while the stream opens and drops it once live',
      (tester) async {
    final SimulatedAudioEngine engine = StalledEngine();
    final PlaybackController controller = PlaybackController(engine: engine);
    addTearDown(controller.dispose);

    controller.playRadioStation(station());
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: RadioPlayerScreen(controller: controller),
    ));
    await tester.pump();
    expect(find.text('CONNECTING…'), findsOneWidget);
    expect(find.byKey(const ValueKey('stream-status')), findsOneWidget);

    // The stream opens: the status line disappears.
    engine.simulateRecovery();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('stream-status')), findsNothing);
  });

  testWidgets('a dead stream ends in UNABLE TO CONNECT and TRY AGAIN reconnects',
      (tester) async {
    final SimulatedAudioEngine engine = SimulatedAudioEngine();
    final PlaybackController controller = PlaybackController(
      engine: engine,
      radioRetryDelay: Duration.zero,
    );
    addTearDown(controller.dispose);

    engine.failNextStart = true;
    controller.playRadioStation(station());
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: RadioPlayerScreen(controller: controller),
    ));
    // Drive the failure budget deterministically: each reported error
    // consumes one automatic attempt; the third lands in the manual state.
    await tester.pump(); // initial connecting+error -> attempt 1
    engine.simulateError();
    await tester.pump(); // attempt 2
    engine.simulateError();
    await tester.pump(); // budget exhausted
    expect(controller.radioState, RadioConnectionState.error);
    expect(find.text('UNABLE TO CONNECT · TRY AGAIN'), findsOneWidget);

    // The manual retry is allowed to succeed.
    engine.failNextStart = false;
    await tester.tap(find.byKey(const ValueKey('stream-retry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.radioState, RadioConnectionState.playing);
    expect(find.byKey(const ValueKey('stream-status')), findsNothing);
  });

  testWidgets('the radio mini player shows real now-playing metadata when reported',
      (tester) async {
    final SimulatedAudioEngine engine = SimulatedAudioEngine();
    final PlaybackController controller = PlaybackController(engine: engine);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: RadioScreen(controller: controller),
    ));
    controller.playRadioStation(station());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    engine.simulateMetadata('Nina Simone - Feeling Good');
    await tester.pump();
    expect(find.text('Nina Simone - Feeling Good'), findsOneWidget);
  });

  testWidgets('library renders a saved offline station with an OFFLINE badge',
      (tester) async {
    final PlaybackController controller = PlaybackController();
    addTearDown(controller.dispose);

    controller.toggleFavouriteStation(
      'ghost-fm',
      details: const RadioStation(
        id: 'ghost-fm',
        name: 'Ghost FM',
        category: 'Ambient',
        program: 'LIVE RADIO',
        streamUrl: 'https://ghost.example/stream',
        isOnline: false,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: LibraryScreen(
        controller: controller,
        active: true,
        onExploreAudio: () {},
      ),
    ));
    await tester.pump();

    // FAVOURITE STATIONS sits below the fold in the library list.
    final Finder list = find
        .descendant(
          of: find.byKey(const ValueKey('library-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('library-station-Ghost FM')),
      250,
      scrollable: list,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('library-station-Ghost FM')), findsOneWidget);
    expect(find.byKey(const ValueKey('library-station-offline')), findsOneWidget);
  });
}
