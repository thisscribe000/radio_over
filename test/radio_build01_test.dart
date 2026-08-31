import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/models/playback.dart';
import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/models/station.dart';
import 'package:radio_over/navigation/app_shell.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/radio_player_screen.dart';
import 'package:radio_over/screens/radio_screen.dart';
import 'package:radio_over/theme.dart';
import 'package:radio_over/widgets/podcast_mini_player.dart';
import 'package:radio_over/widgets/radio_mini_player.dart';

/// Creates a controller that is disposed at the end of the test so the
/// podcast ticker never outlives the widget tree.
PlaybackController newController() {
  final PlaybackController controller = PlaybackController();
  addTearDown(controller.dispose);
  return controller;
}

Widget _app(PlaybackController controller) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: RadioScreen(controller: controller),
  );
}

Widget _shell(PlaybackController controller) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: AppShell(controller: controller),
  );
}

/// The screen's single vertical scrollable (the outer ListView). The first
/// Scrollable in the tree is always the outer list, not the horizontal
/// carousels nested inside it.
final Finder radioScroll = find.byType(Scrollable).first;

Finder stationRow(String name) => find.byKey(ValueKey('station-$name'));

Future<void> pumpSettle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Scrolls the outer list until [finder] is on screen.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: radioScroll);
  await tester.pumpAndSettle();
}

/// Jumps the outer list back to the top.
Future<void> scrollToTop(WidgetTester tester) async {
  await tester.drag(radioScroll, const Offset(0, 2000));
  await tester.pumpAndSettle();
}

/// Scrolls to a station row and taps it.
Future<void> tapStation(WidgetTester tester, String name) async {
  await reveal(tester, stationRow(name));
  await tester.tap(stationRow(name));
  await tester.pumpAndSettle();
}

void main() {
  group('Radio home screen', () {
    testWidgets('opens with RADIO title, greeting and discovery sections', (tester) async {
      await tester.pumpWidget(_app(newController()));

      expect(find.byKey(const ValueKey('radio-greeting')), findsOneWidget);
      expect(find.text('LIVE NOW'), findsOneWidget);
      expect(find.text('LOVEWORLD RADIO'), findsOneWidget);

      await reveal(tester, find.text('POPULAR STATIONS'));
      expect(find.text('POPULAR STATIONS'), findsOneWidget);

      await reveal(tester, find.text('CATEGORIES'));
      expect(find.text('CATEGORIES'), findsOneWidget);

      await reveal(tester, find.text('LIVE STATIONS'));
      expect(find.text('LIVE STATIONS'), findsOneWidget);
      expect(stationRow('BBC World Service'), findsOneWidget);
    });

    testWidgets('greeting reflects the time of day', (tester) async {
      await tester.pumpWidget(_app(newController()));

      final String? greeting =
          tester.widget<Text>(find.byKey(const ValueKey('radio-greeting'))).data;
      expect(
        greeting,
        isIn(['Good morning', 'Good afternoon', 'Good evening']),
        reason: 'greeting must be one of the three time-based variants',
      );
    });

    testWidgets('the full station list is present with hairline dividers', (tester) async {
      await tester.pumpWidget(_app(newController()));

      for (final RadioStation station in mockStations) {
        await reveal(tester, stationRow(station.name));
        expect(stationRow(station.name), findsOneWidget);
      }

      final List<Divider> dividers = tester.widgetList<Divider>(find.byType(Divider)).toList();
      expect(dividers, isNotEmpty);
      for (final Divider divider in dividers) {
        expect(divider.thickness, 1);
        expect(divider.height, 1);
      }
    });

    testWidgets('shows no players and no active dots on launch', (tester) async {
      await tester.pumpWidget(_app(newController()));

      expect(find.byType(RadioMiniPlayer), findsNothing);
      expect(find.byType(PodcastMiniPlayer), findsNothing);
      for (final RadioStation station in mockStations) {
        expect(find.byKey(ValueKey('active-${station.name}')), findsNothing);
      }
      expect(find.byKey(const ValueKey('card-live')), findsNothing);
    });

    testWidgets('tapping a station activates it and reveals the top radio player', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(_app(controller));

      await tapStation(tester, 'Loveworld Radio');

      expect(controller.radioActive, isTrue);
      expect(controller.currentStation, mockStations.first);
      expect(controller.isPlaying, isTrue);
      expect(find.byKey(const ValueKey('active-Loveworld Radio')), findsOneWidget);
      expect(find.byType(RadioMiniPlayer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(RadioMiniPlayer),
          matching: find.text('LOVEWORLD RADIO'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a different station switches the active station', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(_app(controller));

      await tapStation(tester, 'Jazz FM');

      expect(controller.currentStation, mockStations[3]);
      expect(find.byKey(const ValueKey('active-Jazz FM')), findsOneWidget);
      expect(find.byKey(const ValueKey('active-BBC World Service')), findsNothing);
    });

    testWidgets('dismissing the top radio player hides it until a new station is chosen', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(_app(controller));

      await tapStation(tester, 'Talk Radio');
      expect(find.byType(RadioMiniPlayer), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('radio-mini-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byType(RadioMiniPlayer), findsNothing);

      await tapStation(tester, 'Jazz FM');
      expect(find.byType(RadioMiniPlayer), findsOneWidget);
    });

    testWidgets('radio mini-player toggles play/pause and stays visible while paused', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(_app(controller));

      await tapStation(tester, 'Talk Radio');
      expect(find.byIcon(Icons.pause), findsOneWidget);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();
      expect(controller.status, PlayerStatus.paused);
      expect(find.byIcon(Icons.play_arrow_outlined), findsOneWidget);
      expect(find.byType(RadioMiniPlayer), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow_outlined));
      await tester.pumpAndSettle();
      expect(controller.isPlaying, isTrue);
    });

    testWidgets('tapping the active station pauses and resumes it', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(_app(controller));

      await tapStation(tester, 'NPR');
      await tapStation(tester, 'NPR');

      expect(controller.status, PlayerStatus.paused);
      expect(find.byType(RadioMiniPlayer), findsOneWidget);

      await tapStation(tester, 'NPR');
      expect(controller.isPlaying, isTrue);
    });

    testWidgets('featured LIVE NOW play starts the station and opens the radio player', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(_app(controller));

      await tester.tap(find.byKey(const ValueKey('featured-play')));
      await pumpSettle(tester);

      expect(controller.radioActive, isTrue);
      expect(controller.currentStation, mockStations.first);
      expect(find.byType(RadioPlayerScreen), findsOneWidget);
    });

    testWidgets('categories filter the live stations list and clear on re-tap', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(_app(controller));

      await reveal(tester, find.byKey(const ValueKey('category-Music')));
      await tester.tap(find.byKey(const ValueKey('category-Music')));
      await tester.pumpAndSettle();

      await reveal(tester, stationRow('Classic FM'));
      expect(stationRow('Classic FM'), findsOneWidget);
      expect(stationRow('BBC World Service'), findsNothing);

      await scrollToTop(tester);
      await reveal(tester, find.byKey(const ValueKey('category-Music')));
      await tester.tap(find.byKey(const ValueKey('category-Music')));
      await tester.pumpAndSettle();

      await reveal(tester, stationRow('BBC World Service'));
      expect(stationRow('BBC World Service'), findsOneWidget);
    });
  });

  group('favourites and recently played', () {
    testWidgets('favourites show an empty state until a station is saved', (tester) async {
      await tester.pumpWidget(_app(newController()));

      await reveal(tester, find.text('No favourite stations yet'));
      expect(find.text('No favourite stations yet'), findsOneWidget);

      await reveal(tester, stationRow('NPR'));
      await tester.tap(
        find.descendant(of: stationRow('NPR'), matching: find.byKey(const ValueKey('fav-off'))),
      );
      await tester.pumpAndSettle();

      await scrollToTop(tester);
      await reveal(tester, find.byKey(const ValueKey('section-favourites')));
      expect(find.text('No favourite stations yet'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('section-favourites')),
          matching: find.text('NPR'),
        ),
        findsOneWidget,
      );

      await reveal(tester, stationRow('NPR'));
      await tester.tap(
        find.descendant(of: stationRow('NPR'), matching: find.byKey(const ValueKey('fav-on'))),
      );
      await tester.pumpAndSettle();

      await scrollToTop(tester);
      await reveal(tester, find.byKey(const ValueKey('section-favourites')));
      expect(find.text('No favourite stations yet'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('section-favourites')),
          matching: find.text('NPR'),
        ),
        findsNothing,
      );
    });

    testWidgets('recently played lists stations listened to this session', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(_app(controller));

      expect(find.byKey(const ValueKey('section-recent')), findsNothing);

      await tapStation(tester, 'BBC World Service');
      await tapStation(tester, 'Jazz FM');

      await scrollToTop(tester);
      await reveal(tester, find.byKey(const ValueKey('section-recent')));
      expect(find.byKey(const ValueKey('section-recent')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('section-recent')),
          matching: find.text('Jazz FM'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('section-recent')),
          matching: find.text('BBC World Service'),
        ),
        findsOneWidget,
      );
      expect(controller.recentStations.first.name, 'Jazz FM');
    });
  });

  group('player exclusivity', () {
    testWidgets('podcast playback shows the bottom player and hides the radio player', (tester) async {
      final PlaybackController controller = PlaybackController();
      await tester.pumpWidget(_shell(controller));

      controller.playRadioStation(mockStations.first);
      await tester.pumpAndSettle();
      expect(find.byType(RadioMiniPlayer), findsOneWidget);
      expect(find.byType(PodcastMiniPlayer), findsNothing);

      controller.playPodcastEpisode(mockPodcastEpisodes.first);
      await tester.pumpAndSettle();

      expect(find.byType(RadioMiniPlayer), findsNothing);
      expect(find.byType(PodcastMiniPlayer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PodcastMiniPlayer),
          matching: find.text('THE DAILY'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PodcastMiniPlayer),
          matching: find.text('The View From Gaza'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('stopping playback hides both players', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(_shell(controller));

      controller.playPodcastEpisode(mockPodcastEpisodes.first);
      await tester.pumpAndSettle();
      expect(find.byType(PodcastMiniPlayer), findsOneWidget);

      controller.stop();
      await tester.pumpAndSettle();

      expect(find.byType(RadioMiniPlayer), findsNothing);
      expect(find.byType(PodcastMiniPlayer), findsNothing);
    });

    testWidgets('radio player is anchored above the station list', (tester) async {
      final PlaybackController controller = newController();
      await tester.pumpWidget(_app(controller));

      controller.playRadioStation(mockStations.first);
      await tester.pumpAndSettle();

      final double radioTop = tester.getTopLeft(find.byType(RadioMiniPlayer)).dy;
      await reveal(tester, find.text('LIVE STATIONS'));
      final double listTop = tester.getTopLeft(find.text('LIVE STATIONS')).dy;
      expect(radioTop, lessThan(listTop), reason: 'radio player must appear above the station list');
    });
  });

  group('background', () {
    testWidgets('screen background is the flat off-white token', (tester) async {
      await tester.pumpWidget(_app(newController()));

      final Scaffold scaffold = tester.widget(find.byType(Scaffold));
      expect(scaffold.backgroundColor, isNull);
      final ThemeData theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(theme.scaffoldBackgroundColor, AppColors.light.background);
    });
  });
}