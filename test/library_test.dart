import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/models/station.dart';
import 'package:radio_over/navigation/app_shell.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/library_screen.dart';
import 'package:radio_over/screens/podcast_detail_screen.dart';
import 'package:radio_over/screens/podcast_player_screen.dart';
import 'package:radio_over/screens/station_detail_screen.dart';
import 'package:radio_over/theme.dart';
import 'package:radio_over/utils/format.dart';
import 'package:radio_over/widgets/podcast_mini_player.dart';
import 'package:radio_over/widgets/radio_mini_player.dart';

/// Runs a test against the shell. The tree is unmounted before the controller
/// is disposed so the playback clock is always cancelled before the framework
/// checks for pending timers.
Future<void> runLibraryTest(
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

Future<void> switchToPodcasts(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tab-PODCASTS')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> switchToLibrary(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tab-LIBRARY')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Scope to the library tab so assertions stay unambiguous while the hidden
/// radio/podcast tabs remain mounted inside the shell's IndexedStack.
Finder inLibrary(Finder matching) =>
    find.descendant(of: find.byType(LibraryScreen), matching: matching);

Finder libraryText(String text) => inLibrary(find.text(text));

Finder libraryList() => find
    .descendant(
      of: find.byKey(const ValueKey('library-list')),
      matching: find.byType(Scrollable),
    )
    .first;

/// Scrolls the library list until [finder] is on screen.
Future<void> revealInLibrary(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: libraryList());
  await tester.pumpAndSettle();
}

Finder podcastList() => find
    .descendant(
      of: find.byKey(const ValueKey('podcast-home-list')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> revealInPodcasts(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: podcastList());
  await tester.pumpAndSettle();
}

/// Opens the podcast player from the podcasts home, like the podcast tests.
Future<void> openPodcastPlayer(WidgetTester tester) async {
  await switchToPodcasts(tester);
  await revealInPodcasts(tester, find.byKey(const ValueKey('latest-the-daily-gaza')));
  await tester.tap(find.byKey(const ValueKey('latest-the-daily-gaza')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('Library screen', () {
    testWidgets('tab bar switches to the library', (tester) async {
      await runLibraryTest(tester, (tester, controller) async {
        await switchToLibrary(tester);

        final IndexedStack stack = tester.widget(find.byType(IndexedStack));
        expect(stack.index, 2);
        expect(find.byKey(const ValueKey('library-title')), findsOneWidget);
        expect(libraryText('Your saved audio, in one place.'), findsOneWidget);
        expect(find.byKey(const ValueKey('library-filter-all')), findsOneWidget);
        expect(find.byKey(const ValueKey('library-filter-podcasts')), findsOneWidget);
        expect(find.byKey(const ValueKey('library-filter-radio')), findsOneWidget);
      });
    });

    testWidgets('shows a calm empty state for a brand-new user', (tester) async {
      await runLibraryTest(tester, (tester, controller) async {
        await switchToLibrary(tester);

        await revealInLibrary(tester, find.byKey(const ValueKey('library-empty')));
        expect(find.byKey(const ValueKey('library-empty')), findsOneWidget);
        expect(libraryText('Your library is empty'), findsOneWidget);
        expect(libraryText('EXPLORE AUDIO'), findsOneWidget);
        expect(libraryText('Save stations, podcasts and episodes and they\'ll appear here.'), findsOneWidget);

        await revealInLibrary(tester, find.byKey(const ValueKey('library-downloads')));
        expect(libraryText('DOWNLOADS'), findsOneWidget);
        expect(libraryText('Nothing downloaded yet'), findsOneWidget);
      });
    });

    testWidgets('EXPLORE AUDIO returns to the discovery home', (tester) async {
      await runLibraryTest(tester, (tester, controller) async {
        await switchToLibrary(tester);
        await revealInLibrary(tester, find.byKey(const ValueKey('library-explore')));

        await tester.tap(find.byKey(const ValueKey('library-explore')));
        await tester.pump();

        final IndexedStack stack = tester.widget(find.byType(IndexedStack));
        expect(stack.index, 1);
        expect(find.byKey(const ValueKey('podcasts-title')), findsOneWidget);
      });
    });

    testWidgets('continue listening lists in-progress episodes and resumes them', (tester) async {
      await runLibraryTest(tester, (tester, controller) async {
        await switchToLibrary(tester);

        expect(find.byKey(const ValueKey('library-continue-the-daily-banking')), findsOneWidget);
        expect(find.byKey(const ValueKey('library-continue-99pi-banyan')), findsOneWidget);
        expect(libraryText('11:42 / 28:00'), findsOneWidget);
        expect(libraryText('RESUME'), findsWidgets);

        await tester.tap(find.byKey(const ValueKey('library-continue-the-daily-banking')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(PodcastPlayerScreen), findsOneWidget);
        expect(controller.currentEpisode?.id, 'the-daily-banking');
      });
    });

    testWidgets('saving a show fills SAVED PODCASTS and opens the show detail', (tester) async {
      await runLibraryTest(tester, (tester, controller) async {
        controller.toggleSavedShow('the-daily');
        await switchToLibrary(tester);

        expect(find.byKey(const ValueKey('library-empty')), findsNothing);
        await revealInLibrary(tester, find.byKey(const ValueKey('library-saved-show-the-daily')));
        expect(find.byKey(const ValueKey('library-saved-show-the-daily')), findsOneWidget);
        expect(libraryText('The Daily'), findsOneWidget);
        expect(libraryText('NEWS · 2 EPISODES'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('library-saved-show-the-daily')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(PodcastDetailScreen), findsOneWidget);
      });
    });

    testWidgets('favouriting a station fills FAVOURITE STATIONS and opens its detail', (tester) async {
      await runLibraryTest(tester, (tester, controller) async {
        controller.toggleFavouriteStation('Jazz FM');
        await switchToLibrary(tester);

        expect(find.byKey(const ValueKey('library-empty')), findsNothing);
        await revealInLibrary(tester, find.byKey(const ValueKey('library-station-Jazz FM')));
        expect(find.byKey(const ValueKey('library-station-Jazz FM')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('library-station-Jazz FM')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(StationDetailScreen), findsOneWidget);
      });
    });

    testWidgets('saving an episode in the player reaches the library', (tester) async {
      await runLibraryTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);

        await tester.tap(find.byKey(const ValueKey('podcast-favourite')));
        await tester.pump();
        expect(controller.isSavedEpisode('the-daily-gaza'), isTrue);

        await tester.tap(find.byKey(const ValueKey('podcast-back')));
        await tester.pumpAndSettle();

        await switchToLibrary(tester);
        await revealInLibrary(tester, find.byKey(const ValueKey('library-saved-episode-the-daily-gaza')));
        expect(find.byKey(const ValueKey('library-saved-episode-the-daily-gaza')), findsOneWidget);
        expect(libraryText('The View From Gaza'), findsOneWidget);
      });
    });

    testWidgets('recently played interleaves stations and episodes', (tester) async {
      await runLibraryTest(tester, (tester, controller) async {
        final DateTime stationAt = DateTime.now();
        controller.playRadioStation(mockStations.first);
        final DateTime episodeAt = DateTime.now();
        controller.playPodcastEpisode(mockPodcastEpisodes.first);
        await switchToLibrary(tester);

        await revealInLibrary(tester, find.byKey(const ValueKey('library-recent-episode-the-daily-gaza')));
        expect(find.byKey(const ValueKey('library-recent-episode-the-daily-gaza')), findsOneWidget);
        // Both listens happened moments ago, so both labels read "TODAY · HH:MM".
        expect(libraryText(formatListenedAt(episodeAt)), findsWidgets);

        await revealInLibrary(tester, find.byKey(const ValueKey('library-recent-station-BBC World Service')));
        expect(find.byKey(const ValueKey('library-recent-station-BBC World Service')), findsOneWidget);
        expect(libraryText(formatListenedAt(stationAt)), findsWidgets);
        expect(libraryText('BBC World Service'), findsOneWidget);
      });
    });

    testWidgets('podcast mini player persists onto the library tab', (tester) async {
      await runLibraryTest(tester, (tester, controller) async {
        controller.playPodcastEpisode(mockPodcastEpisodes.first);
        await tester.pumpAndSettle();

        await switchToLibrary(tester);
        expect(find.byType(PodcastMiniPlayer), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(PodcastMiniPlayer),
            matching: find.text('The View From Gaza'),
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(
            of: find.byType(PodcastMiniPlayer),
            matching: find.text('The View From Gaza'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(PodcastPlayerScreen), findsOneWidget);
      });
    });

    testWidgets('radio mini player stays on the library tab while a station is live', (tester) async {
      await runLibraryTest(tester, (tester, controller) async {
        controller.playRadioStation(mockStations.first);
        await tester.pumpAndSettle();
        await switchToLibrary(tester);

        final Finder strip = find.descendant(
          of: find.byType(LibraryScreen),
          matching: find.byType(RadioMiniPlayer),
        );
        expect(strip, findsOneWidget);
        // The strip renders the station name in its uppercase player styling.
        expect(
          find.descendant(of: strip, matching: find.text('BBC WORLD SERVICE')),
          findsOneWidget,
        );
      });
    });

    testWidgets('downloads entry counts episodes and opens its route', (tester) async {
      await runLibraryTest(tester, (tester, controller) async {
        controller.toggleDownloaded('99pi-airport-codes');
        await switchToLibrary(tester);

        await revealInLibrary(tester, find.byKey(const ValueKey('library-downloads')));
        expect(libraryText('1 episode available offline'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('library-downloads')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.descendant(
            of: find.byKey(const ValueKey('downloads-list')),
            matching: find.text('The Secret Lives of Airport Codes'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('downloads-empty')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('downloads-back')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('library-list')), findsOneWidget);
      });
    });

    testWidgets('filters narrow the library content without navigating away', (tester) async {
      await runLibraryTest(tester, (tester, controller) async {
        controller.toggleFavouriteStation('Jazz FM');
        controller.toggleSavedShow('the-daily');
        await switchToLibrary(tester);

        Future<void> resetToTop() async {
          await tester.drag(libraryList(), const Offset(0, 4000));
          await tester.pumpAndSettle();
        }

        await tester.tap(find.byKey(const ValueKey('library-filter-podcasts')));
        await tester.pump();
        await revealInLibrary(tester, find.byKey(const ValueKey('library-saved-show-the-daily')));
        expect(find.byKey(const ValueKey('library-saved-show-the-daily')), findsOneWidget);
        expect(find.byKey(const ValueKey('library-station-Jazz FM')), findsNothing);

        await resetToTop();
        await tester.tap(find.byKey(const ValueKey('library-filter-radio')));
        await tester.pump();
        await revealInLibrary(tester, find.byKey(const ValueKey('library-station-Jazz FM')));
        expect(find.byKey(const ValueKey('library-station-Jazz FM')), findsOneWidget);
        expect(find.byKey(const ValueKey('library-saved-show-the-daily')), findsNothing);

        await resetToTop();
        await tester.tap(find.byKey(const ValueKey('library-filter-all')));
        await tester.pump();
        await revealInLibrary(tester, find.byKey(const ValueKey('library-saved-show-the-daily')));
        expect(find.byKey(const ValueKey('library-saved-show-the-daily')), findsOneWidget);
        await revealInLibrary(tester, find.byKey(const ValueKey('library-station-Jazz FM')));
        expect(find.byKey(const ValueKey('library-station-Jazz FM')), findsOneWidget);
        final IndexedStack stack = tester.widget(find.byType(IndexedStack));
        expect(stack.index, 2);
      });
    });
  });
}