import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/navigation/app_shell.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/podcast_detail_screen.dart';
import 'package:radio_over/screens/podcast_player_screen.dart';
import 'package:radio_over/screens/radio_player_screen.dart';
import 'package:radio_over/screens/search_screen.dart';
import 'package:radio_over/theme.dart';
import 'package:radio_over/widgets/podcast_mini_player.dart';
import 'package:radio_over/widgets/radio_mini_player.dart';

/// Scopes finders to the pushed search screen so the mounted tabs behind it
/// never interfere.
Finder inSearch(Finder matching) =>
    find.descendant(of: find.byType(SearchScreen), matching: matching);

Future<void> runSearchTest(
  WidgetTester tester,
  Future<void> Function(WidgetTester, PlaybackController) body,
) async {
  final PlaybackController controller = PlaybackController();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: AppShell(controller: controller),
    ),
  );
  try {
    await body(tester, controller);
  } finally {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  }
}

/// Switches to the podcasts tab and opens the global search screen.
Future<void> openSearch(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tab-PODCASTS')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(const ValueKey('podcast-search')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Types into the search field and waits out the debounce.
Future<void> typeQuery(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(const ValueKey('search-field')), query);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

/// The results list's own scrollable (the field/sections are not in a list,
/// so the first Scrollable under the results key is the content list).
Finder resultsList() => find
    .descendant(
      of: find.byKey(const ValueKey('search-results')),
      matching: find.byType(Scrollable),
    )
    .first;

/// The radio player never settles while playing (looping live animations), so
/// drive frames with bounded pumps instead of `pumpAndSettle`.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('Global search', () {
    testWidgets('opens from the podcast home affordance with a discovery state', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        await openSearch(tester);

        expect(find.byType(SearchScreen), findsOneWidget);
        expect(inSearch(find.text('Search radio, podcasts & episodes')), findsOneWidget);
        expect(find.byKey(const ValueKey('search-back')), findsOneWidget);
        expect(inSearch(find.text('TRENDING')), findsOneWidget);
        expect(inSearch(find.text('RECENT SEARCHES')), findsNothing);
        expect(
          find.byKey(const ValueKey('search-trend-BBC World Service')),
          findsOneWidget,
        );
      });
    });

    testWidgets('back returns to the podcast home', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        await openSearch(tester);
        await tester.tap(find.byKey(const ValueKey('search-back')));
        await tester.pumpAndSettle();

        expect(find.byType(SearchScreen), findsNothing);
        expect(find.byKey(const ValueKey('podcast-home-list')), findsOneWidget);
      });
    });

    testWidgets('trending chip searches immediately', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        await openSearch(tester);
        await tester.tap(find.byKey(const ValueKey('search-trend-BBC World Service')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byKey(const ValueKey('search-top-result')), findsOneWidget);
        expect(inSearch(find.text('BBC WORLD SERVICE')), findsWidgets);
      });
    });

    testWidgets('a contains-only match returns radio stations without a top result', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        await openSearch(tester);
        await typeQuery(tester, 'fm');

        expect(find.byKey(const ValueKey('search-top-result')), findsNothing);
        expect(inSearch(find.text('RADIO STATIONS')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('search-result-Jazz FM')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('search-result-Classic FM')),
          findsOneWidget,
        );
      });
    });

    testWidgets('a query surfaces stations, podcasts and episodes together', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        await openSearch(tester);
        await typeQuery(tester, 'the daily');

        expect(find.byKey(const ValueKey('search-top-result')), findsOneWidget);
        expect(inSearch(find.text('THE DAILY')), findsWidgets);

        await tester.scrollUntilVisible(
          find.text('EPISODES'),
          200,
          scrollable: resultsList(),
        );
        expect(find.text('EPISODES'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('The View From Gaza'),
          200,
          scrollable: resultsList(),
        );
        expect(find.text('The View From Gaza'), findsOneWidget);
      });
    });

    testWidgets('tapping a radio top result opens the existing radio player', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        await openSearch(tester);
        await typeQuery(tester, 'bbc');

        expect(find.byKey(const ValueKey('search-top-result')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('search-top-result')));
        await settle(tester);

        expect(controller.radioActive, isTrue);
        expect(controller.currentStation?.name, 'BBC World Service');
        expect(find.byType(RadioPlayerScreen), findsOneWidget);
      });
    });

    testWidgets('tapping a radio result row starts the station in the mini slot', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        await openSearch(tester);
        await typeQuery(tester, 'fm');

        await tester.tap(find.byKey(const ValueKey('search-result-Jazz FM')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.radioActive, isTrue);
        expect(controller.currentStation?.name, 'Jazz FM');
        expect(find.byType(RadioPlayerScreen), findsNothing);
        expect(inSearch(find.byType(RadioMiniPlayer)), findsOneWidget);
      });
    });

    testWidgets('tapping a podcast result opens the podcast detail screen', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        await openSearch(tester);
        await typeQuery(tester, 'production');

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('search-result-serial')),
          200,
          scrollable: resultsList(),
        );
        await tester.tap(find.byKey(const ValueKey('search-result-serial')));
        await tester.pumpAndSettle();

        expect(find.byType(PodcastDetailScreen), findsOneWidget);
        expect(find.text('SERIAL'), findsOneWidget);
      });
    });

    testWidgets('tapping an episode result plays it and opens the podcast player', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        await openSearch(tester);
        await typeQuery(tester, 'airport');

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('search-result-99pi-airport-codes')),
          200,
          scrollable: resultsList(),
        );
        await tester.tap(find.byKey(const ValueKey('search-result-99pi-airport-codes')));
        await tester.pumpAndSettle();

        expect(controller.podcastActive, isTrue);
        expect(controller.currentEpisode?.id, '99pi-airport-codes');
        expect(find.byType(PodcastPlayerScreen), findsOneWidget);
      });
    });

    testWidgets('episode rows show playback state for completed and in-progress episodes', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        await openSearch(tester);
        await typeQuery(tester, 'breakup');
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('search-episode-played-serial-breakup')),
          200,
          scrollable: resultsList(),
        );
        expect(
          find.byKey(const ValueKey('search-episode-played-serial-breakup')),
          findsOneWidget,
        );

        await typeQuery(tester, 'banking crisis');
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('search-episode-progress-the-daily-banking')),
          200,
          scrollable: resultsList(),
        );
        expect(
          find.byKey(const ValueKey('search-episode-progress-the-daily-banking')),
          findsOneWidget,
        );
      });
    });

    testWidgets('an unmatched query shows the thoughtful empty state', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        await openSearch(tester);
        await typeQuery(tester, 'zzzzz');

        expect(find.byKey(const ValueKey('search-no-results')), findsOneWidget);
        expect(inSearch(find.text('No results found')), findsOneWidget);
        expect(
          inSearch(find.text('Try searching for a station, podcast or episode.')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('search-suggest-News')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byKey(const ValueKey('search-no-results')), findsNothing);
        expect(inSearch(find.text('RADIO STATIONS')), findsOneWidget);
      });
    });

    testWidgets('clear button returns to the discovery state', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        await openSearch(tester);
        await typeQuery(tester, 'morning');
        expect(inSearch(find.text('RADIO STATIONS')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('search-clear')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(inSearch(find.text('TRENDING')), findsOneWidget);
        expect(inSearch(find.text('RADIO STATIONS')), findsNothing);
        expect(find.byKey(const ValueKey('search-clear')), findsNothing);
      });
    });

    testWidgets('recent searches are recorded, removed and cleared', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        await openSearch(tester);
        await typeQuery(tester, 'fm');
        await tester.tap(find.byKey(const ValueKey('search-result-Jazz FM')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byKey(const ValueKey('search-clear')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(inSearch(find.text('RECENT SEARCHES')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('search-recent-fm')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('search-recent-remove-fm')));
        await tester.pump();
        expect(inSearch(find.text('RECENT SEARCHES')), findsNothing);

        await typeQuery(tester, 'fm');
        await tester.tap(find.byKey(const ValueKey('search-result-Classic FM')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(const ValueKey('search-clear')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        await tester.tap(find.byKey(const ValueKey('search-recent-clear')));
        await tester.pump();
        expect(inSearch(find.text('RECENT SEARCHES')), findsNothing);
      });
    });

    testWidgets('the podcast mini player persists on the search screen', (tester) async {
      await runSearchTest(tester, (tester, controller) async {
        controller.playPodcastEpisode(mockPodcastEpisodes.first);
        await tester.pumpAndSettle();

        await openSearch(tester);

        expect(inSearch(find.byType(PodcastMiniPlayer)), findsOneWidget);
        expect(inSearch(find.text('The View From Gaza')), findsOneWidget);
        expect(controller.podcastActive, isTrue);
      });
    });
  });
}