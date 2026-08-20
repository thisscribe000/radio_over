import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/models/station.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/radio_player_screen.dart';
import 'package:radio_over/screens/radio_screen.dart';
import 'package:radio_over/screens/station_detail_screen.dart';
import 'package:radio_over/theme.dart';
import 'package:radio_over/widgets/podcast_mini_player.dart';
import 'package:radio_over/widgets/radio_mini_player.dart';

PlaybackController newController() {
  final PlaybackController controller = PlaybackController();
  addTearDown(controller.dispose);
  return controller;
}

Widget detailApp(
  PlaybackController controller, {
  RadioStation? station,
}) {
  station ??= mockStations.first;
  return MaterialApp(
    theme: buildAppTheme(),
    home: StationDetailScreen(
      station: station,
      controller: controller,
    ),
  );
}

Widget homeApp(PlaybackController controller) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: RadioScreen(controller: controller),
  );
}

/// The radio player runs looping live animations, so once it is pushed the
/// tree never settles. Drive frames with bounded pumps instead.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Reveals a section inside the detail screen's vertical list.
Future<void> revealInDetail(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    220,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('station-detail-list')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
}

/// Reveals a row in the radio home list and opens its Station Detail page via
/// the quiet info affordance.
Future<void> openDetailFromHome(WidgetTester tester, String name) async {
  final Finder affordance = find.byKey(ValueKey('row-detail-$name'));
  await tester.scrollUntilVisible(
    affordance,
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(affordance);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('Radio Station Detail', () {
    testWidgets('opens from the radio home row detail affordance', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(homeApp(controller));

      await openDetailFromHome(tester, 'BBC World Service');

      expect(find.byType(StationDetailScreen), findsOneWidget);
      expect(find.text('BBC WORLD SERVICE'), findsOneWidget);
      expect(find.text('London, United Kingdom'), findsOneWidget);
    });

    testWidgets('back returns to the radio home screen', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(homeApp(controller));
      await openDetailFromHome(tester, 'BBC World Service');

      await tester.tap(find.byKey(const ValueKey('station-detail-back')));
      await tester.pumpAndSettle();

      expect(find.byType(StationDetailScreen), findsNothing);
      expect(find.byType(RadioScreen), findsOneWidget);
    });

    testWidgets('lists the station identity, live now and up next', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(
        detailApp(controller, station: mockStations[1]), // Talk Radio
      );

      expect(find.text('TALK RADIO'), findsOneWidget);
      expect(find.text('LIVE'), findsWidgets);
      expect(find.text('NOW PLAYING'), findsOneWidget);
      expect(find.text('THE MORNING CALL'), findsOneWidget);
      await revealInDetail(tester, find.byKey(const ValueKey('detail-up-next')));
      expect(find.text('The Afternoon Debate'), findsWidgets);
      expect(find.text('SCHEDULE'), findsOneWidget);
    });

    testWidgets('LISTEN LIVE starts the station and opens the radio player', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(
        detailApp(controller, station: mockStations[0]),
      );

      await tester.tap(find.byKey(const ValueKey('detail-listen')));
      await settle(tester);

      expect(controller.radioActive, isTrue);
      expect(controller.isPlaying, isTrue);
      expect(controller.currentStation?.name, 'BBC World Service');
      expect(find.byType(RadioPlayerScreen), findsOneWidget);
    });

    testWidgets('shows PLAYING NOW and reopens the player when already on air', (tester) async {
      final PlaybackController controller = newController();
      controller.playRadioStation(mockStations[0]);
      await tester.pumpWidget(
        detailApp(controller, station: mockStations[0]),
      );

      expect(find.text('PLAYING NOW'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('detail-listen')));
      await settle(tester);
      expect(find.byType(RadioPlayerScreen), findsOneWidget);
    });

    testWidgets('saving on the home reaches the detail screen', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(homeApp(controller));

      // The heart on the POPULAR STATIONS card saves straight into the
      // controller-level store.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('card-BBC World Service')),
          matching: find.byKey(const ValueKey('fav-off')),
        ),
      );
      await tester.pump();
      expect(controller.isFavouriteStation('BBC World Service'), isTrue);

      await openDetailFromHome(tester, 'BBC World Service');
      expect(find.text('♥ SAVED'), findsOneWidget);
    });

    testWidgets('saving on the detail screen reaches the home favourites', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(homeApp(controller));
      await openDetailFromHome(tester, 'BBC World Service');

      await tester.tap(find.byKey(const ValueKey('detail-favourite')));
      await tester.pump();
      expect(find.text('♥ SAVED'), findsOneWidget);
      expect(controller.isFavouriteStation('BBC World Service'), isTrue);

      await tester.tap(find.byKey(const ValueKey('station-detail-back')));
      await tester.pumpAndSettle();

      // The home keeps its scroll position, so after returning from the
      // detail it is already at the bottom; scroll back to the top region
      // before asking for the favourites section.
      final Finder homeScroll = find
          .descendant(
            of: find.byType(RadioScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(homeScroll, const Offset(0, 1200));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('section-favourites')),
        220,
        scrollable: homeScroll,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('section-favourites')),
          matching: find.text('BBC World Service'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('favourite toggles between save and saved', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(
        detailApp(controller, station: mockStations[2]), // Jazz FM
      );

      expect(find.text('♡ SAVE STATION'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('detail-favourite')));
      await tester.pump();
      expect(find.text('♥ SAVED'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('detail-favourite')));
      await tester.pump();
      expect(find.text('♡ SAVE STATION'), findsOneWidget);
    });

    testWidgets('schedule day selector filters the programme rows', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(
        detailApp(controller, station: mockStations[0]),
      );

      await revealInDetail(tester, find.byKey(const ValueKey('schedule-day-FRI')));
      expect(find.text('World News Today'), findsOneWidget); // TODAY row

      await tester.tap(find.byKey(const ValueKey('schedule-day-FRI')));
      await tester.pump();

      expect(find.text('World News Today'), findsNothing);
      expect(find.text('Business Today'), findsOneWidget);
    });

    testWidgets('about expands and collapses for longer descriptions', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(
        detailApp(controller, station: mockStations[0]),
      );

      await revealInDetail(tester, find.byKey(const ValueKey('station-about-toggle')));
      expect(find.text('MORE'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('station-about-toggle')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('LESS'), findsOneWidget);
    });

    testWidgets('related card opens another station detail page', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(
        detailApp(controller, station: mockStations[0]),
      );

      await revealInDetail(tester, find.byKey(const ValueKey('related-npr')));
      await tester.tap(find.byKey(const ValueKey('related-npr')));
      await tester.pumpAndSettle();

      expect(find.byType(StationDetailScreen), findsOneWidget);
      expect(find.text('NPR'), findsOneWidget);
    });

    testWidgets('keeps the radio mini player when a station is on air', (tester) async {
      final PlaybackController controller = newController();
      controller.playRadioStation(mockStations[3]); // NPR
      await tester.pumpWidget(
        detailApp(controller, station: mockStations[0]),
      );

      expect(find.byType(RadioMiniPlayer), findsOneWidget);
      expect(controller.radioActive, isTrue);
    });

    testWidgets('keeps the podcast mini player when an episode is playing', (tester) async {
      final PlaybackController controller = newController();
      controller.playPodcastEpisode(mockPodcastEpisodes.first);
      await tester.pumpWidget(
        detailApp(controller, station: mockStations[0]),
      );

      expect(find.byType(PodcastMiniPlayer), findsOneWidget);
      expect(controller.podcastActive, isTrue);

      // The podcast playback clock keeps a periodic timer alive; stop playback
      // so the timer is cancelled before the framework checks for pending
      // timers (the shared teardown then disposes the controller once).
      controller.stop();
      await tester.pump();
    });
  });
}