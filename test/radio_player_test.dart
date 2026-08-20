import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/models/playback.dart';
import 'package:radio_over/models/station.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/radio_player_screen.dart';
import 'package:radio_over/screens/radio_screen.dart';
import 'package:radio_over/theme.dart';
import 'package:radio_over/widgets/live_badge.dart';
import 'package:radio_over/widgets/radio_waveform.dart';

/// The player screen runs subtle looping animations while playing, so
/// [pumpAndSettle] can never settle. Drive frames with bounded pumps instead.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> pumpRadioScreen(WidgetTester tester, PlaybackController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: RadioScreen(controller: controller),
    ),
  );
}

Future<void> openPlayer(WidgetTester tester, PlaybackController controller) async {
  final Finder row =
      find.byKey(const ValueKey('station-BBC World Service'));
  await tester.scrollUntilVisible(
    row,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(row);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('BBC WORLD SERVICE'));
  await settle(tester);
}

void main() {
  group('RadioPlayerScreen', () {
    testWidgets('opens from the radio mini-player with live player structure', (tester) async {
      final PlaybackController controller = PlaybackController();
      await pumpRadioScreen(tester, controller);

      await openPlayer(tester, controller);

      expect(find.byType(RadioPlayerScreen), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('RADIO'), findsOneWidget);
      expect(find.byType(LiveBadge), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.byType(RadioWaveform), findsOneWidget);
      expect(find.text('BBC WORLD SERVICE'), findsOneWidget);
      expect(find.text('World News Today'), findsAtLeastNWidgets(1));
      expect(find.text('NOW PLAYING'), findsOneWidget);
      expect(find.text('BBC World Service'), findsOneWidget);
    });

    testWidgets('back returns to the radio home screen', (tester) async {
      final PlaybackController controller = PlaybackController();
      await pumpRadioScreen(tester, controller);

      await openPlayer(tester, controller);
      await tester.tap(find.byKey(const ValueKey('player-back')));
      await settle(tester);

      expect(find.byType(RadioPlayerScreen), findsNothing);
      expect(find.text('LIVE STATIONS'), findsOneWidget);
    });

    testWidgets('big play/pause control toggles playback state and icon', (tester) async {
      final PlaybackController controller = PlaybackController();
      await pumpRadioScreen(tester, controller);

      await openPlayer(tester, controller);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(controller.isPlaying, isTrue);

      await tester.tap(find.byKey(const ValueKey('player-play-pause')));
      await settle(tester);

      expect(controller.status, PlayerStatus.paused);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('player-play-pause')));
      await settle(tester);

      expect(controller.isPlaying, isTrue);
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('next and previous switch stations through the mock list', (tester) async {
      final PlaybackController controller = PlaybackController();
      await pumpRadioScreen(tester, controller);

      await openPlayer(tester, controller);
      expect(controller.currentStation, mockStations.first);

      await tester.tap(find.byKey(const ValueKey('player-next')));
      await settle(tester);
      expect(controller.currentStation, mockStations[1]);
      expect(find.text('TALK RADIO'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('player-previous')));
      await settle(tester);
      expect(controller.currentStation, mockStations.first);

      await tester.tap(find.byKey(const ValueKey('player-previous')));
      await settle(tester);
      expect(controller.currentStation, mockStations.last, reason: 'previous wraps to the last station');
    });

    testWidgets('favourite toggles between selected and unselected', (tester) async {
      final PlaybackController controller = PlaybackController();
      await pumpRadioScreen(tester, controller);

      await openPlayer(tester, controller);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('player-favourite')));
      await settle(tester);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);

      await tester.tap(find.byKey(const ValueKey('player-favourite')));
      await settle(tester);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('player ignores radio screen below while keep keyboard-free layout', (tester) async {
      final PlaybackController controller = PlaybackController();
      await pumpRadioScreen(tester, controller);

      await openPlayer(tester, controller);

      expect(find.byType(RadioScreen), findsNothing, reason: 'underlying route is offstage');
    });
  });
}