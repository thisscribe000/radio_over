import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/models/station.dart';
import 'package:radio_over/navigation/app_shell.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/history_screen.dart';
import 'package:radio_over/screens/podcast_player_screen.dart';
import 'package:radio_over/screens/station_detail_screen.dart';
import 'package:radio_over/theme.dart';
import 'package:radio_over/utils/format.dart';
import 'package:radio_over/widgets/podcast_mini_player.dart';
import 'package:radio_over/widgets/radio_mini_player.dart';

/// Runs a test against the shell. The tree is unmounted before the controller
/// is disposed so the playback clock is always cancelled before the framework
/// checks for pending timers.
Future<void> runHistoryTest(
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

Future<void> switchToLibrary(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tab-LIBRARY')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder libraryList() => find
    .descendant(
      of: find.byKey(const ValueKey('library-list')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> openHistory(WidgetTester tester) async {
  await switchToLibrary(tester);
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('library-history')),
    250,
    scrollable: libraryList(),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('library-history')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder inHistory(Finder matching) =>
    find.descendant(of: find.byType(HistoryScreen), matching: matching);

Finder historyText(String text) => inHistory(find.text(text));

void main() {
  group('Listening history screen', () {
    test('recording listens fills the bounded history and deduplicates', () {
      final PlaybackController controller = PlaybackController();
      PodcastEpisode episodeFor(int i) => PodcastEpisode(
            id: 'ep-$i',
            podcastId: 'show',
            podcastName: 'Show',
            title: 'Episode $i',
            duration: const Duration(minutes: 30),
          );
      try {
        for (int i = 0; i < 160; i++) {
          controller.playPodcastEpisode(episodeFor(i));
        }
        expect(controller.listeningHistory.length, PlaybackController.maxListeningHistoryEntries);
        expect(controller.listeningHistory.first.contentId, 'ep-159');
        expect(controller.listeningHistory.last.contentId, 'ep-10');

        // A repeat listen moves to the front without duplicating.
        controller.playPodcastEpisode(episodeFor(100));
        expect(controller.listeningHistory.length, PlaybackController.maxListeningHistoryEntries);
        expect(controller.listeningHistory.first.contentId, 'ep-100');

        controller.clearListeningHistory();
        expect(controller.listeningHistory, isEmpty);
        expect(controller.recentHistory, isEmpty);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('opens from the library and shows an empty state for a new user', (tester) async {
      await runHistoryTest(tester, (tester, controller) async {
        await openHistory(tester);

        expect(find.byKey(const ValueKey('history-back')), findsOneWidget);
        expect(historyText('HISTORY'), findsWidgets);
        expect(find.byKey(const ValueKey('history-list')), findsOneWidget);
        expect(find.byKey(const ValueKey('history-empty')), findsOneWidget);
        expect(historyText('No listening history yet'), findsOneWidget);
        expect(historyText('Start listening and your recent activity will appear here.'),
            findsOneWidget);
        expect(find.byKey(const ValueKey('history-explore')), findsOneWidget);
        expect(find.byKey(const ValueKey('history-clear')), findsNothing);
      });
    });

    testWidgets('EXPLORE AUDIO returns to the discovery home', (tester) async {
      await runHistoryTest(tester, (tester, controller) async {
        await openHistory(tester);
        await tester.tap(find.byKey(const ValueKey('history-explore')));
        await tester.pumpAndSettle();

        final IndexedStack stack = tester.widget(find.byType(IndexedStack));
        expect(stack.index, 1);
        expect(find.byKey(const ValueKey('history-back')), findsNothing);
      });
    });

    testWidgets('groups radio and podcast listens under TODAY with their details', (tester) async {
      await runHistoryTest(tester, (tester, controller) async {
        final DateTime stationAt = DateTime.now();
        controller.playRadioStation(mockStations.first);
        final DateTime episodeAt = DateTime.now();
        controller.playPodcastEpisode(mockPodcastEpisodes.first);
        await tester.pumpAndSettle();
        await openHistory(tester);

        expect(historyText('TODAY'), findsOneWidget);
        expect(find.byKey(const ValueKey('history-station-bbc-world-service')), findsOneWidget);
        expect(historyText('BBC World Service'), findsOneWidget);
        expect(historyText(formatListenedAt(stationAt)), findsWidgets);

        expect(find.byKey(const ValueKey('history-episode-the-daily-gaza')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('history-episode-the-daily-gaza')),
            matching: find.text('The View From Gaza'),
          ),
          findsOneWidget,
        );
        expect(historyText(formatListenedAt(episodeAt)), findsWidgets);
      });
    });

    testWidgets('tapping a radio row opens the Station Detail screen', (tester) async {
      await runHistoryTest(tester, (tester, controller) async {
        controller.playRadioStation(mockStations.first);
        await tester.pumpAndSettle();
        await openHistory(tester);

        await tester.tap(find.byKey(const ValueKey('history-station-bbc-world-service')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(StationDetailScreen), findsOneWidget);
      });
    });

    testWidgets('tapping a podcast row resumes in the existing podcast player', (tester) async {
      await runHistoryTest(tester, (tester, controller) async {
        controller.playPodcastEpisode(mockPodcastEpisodes.first);
        await tester.pumpAndSettle();
        await openHistory(tester);

        await tester.tap(find.byKey(const ValueKey('history-episode-the-daily-gaza')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(PodcastPlayerScreen), findsOneWidget);
        expect(controller.currentEpisode?.id, 'the-daily-gaza');
      });
    });

    testWidgets('shows radio progress-free and podcast progress-aware rows', (tester) async {
      await runHistoryTest(tester, (tester, controller) async {
        controller.playRadioStation(mockStations.first);
        controller.playPodcastEpisode(mockPodcastEpisodes[1]); // the-daily-banking 11:42/28:00
        await tester.pump();
        await openHistory(tester);

        // The episode's seeded progress is shown subtly under the row. The
        // clock advances while the mock playback runs, so match the total.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('history-episode-the-daily-banking')),
            matching: find.textContaining('/ 28:00'),
          ),
          findsOneWidget,
        );
        // The radio row keeps its programme line instead of progress.
        expect(historyText('World News Today · NEWS'), findsOneWidget);
      });
    });

    testWidgets('the row menu offers Open and Remove from history', (tester) async {
      await runHistoryTest(tester, (tester, controller) async {
        controller.playPodcastEpisode(mockPodcastEpisodes.first);
        controller.playRadioStation(mockStations.first);
        await tester.pumpAndSettle();
        await openHistory(tester);

        await tester.tap(find.byKey(const ValueKey('history-more-episode:the-daily-gaza')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('history-sheet')), findsOneWidget);
        expect(find.byKey(const ValueKey('history-sheet-open-episode:the-daily-gaza')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('history-sheet-remove-episode:the-daily-gaza')),
            findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('history-sheet-remove-episode:the-daily-gaza')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('history-episode-the-daily-gaza')), findsNothing);
        expect(controller.listeningHistory.any((h) => h.contentId == 'the-daily-gaza'), isFalse);
        // The station listen remains untouched.
        expect(find.byKey(const ValueKey('history-station-bbc-world-service')), findsOneWidget);
      });
    });

    testWidgets('Clear asks for confirmation, clears on confirm and keeps on cancel', (tester) async {
      await runHistoryTest(tester, (tester, controller) async {
        controller.playRadioStation(mockStations.first);
        controller.playPodcastEpisode(mockPodcastEpisodes.first);
        await tester.pumpAndSettle();
        await openHistory(tester);

        await tester.tap(find.byKey(const ValueKey('history-clear')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('history-clear-dialog')), findsOneWidget);
        expect(find.text('Clear listening history?'), findsOneWidget);
        expect(find.text('This will remove your recent listening activity.'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('history-clear-cancel')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('history-clear-dialog')), findsNothing);
        expect(controller.listeningHistory.length, 2);

        await tester.tap(find.byKey(const ValueKey('history-clear')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('history-clear-confirm')));
        await tester.pumpAndSettle();

        expect(controller.listeningHistory, isEmpty);
        expect(controller.recentHistory, isEmpty);
        expect(find.byKey(const ValueKey('history-empty')), findsOneWidget);
      });
    });

    testWidgets('keeps the radio mini player visible while browsing history', (tester) async {
      await runHistoryTest(tester, (tester, controller) async {
        controller.playRadioStation(mockStations.first);
        await tester.pumpAndSettle();
        await openHistory(tester);

        final Finder strip = find.descendant(
          of: find.byType(HistoryScreen),
          matching: find.byType(RadioMiniPlayer),
        );
        expect(strip, findsOneWidget);
        expect(
          find.descendant(of: strip, matching: find.text('BBC WORLD SERVICE')),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(of: strip, matching: find.byKey(const ValueKey('radio-mini-dismiss'))),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('history-audio-none')), findsOneWidget);
      });
    });

    testWidgets('keeps the podcast mini player visible while browsing history', (tester) async {
      await runHistoryTest(tester, (tester, controller) async {
        controller.playPodcastEpisode(mockPodcastEpisodes.first);
        await tester.pumpAndSettle();
        await openHistory(tester);

        final Finder strip = find.descendant(
          of: find.byType(HistoryScreen),
          matching: find.byType(PodcastMiniPlayer),
        );
        expect(strip, findsOneWidget);
        expect(
          find.descendant(of: strip, matching: find.text('The View From Gaza')),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(of: strip, matching: find.text('The View From Gaza')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(PodcastPlayerScreen), findsOneWidget);
      });
    });

    testWidgets('back returns to the library tab', (tester) async {
      await runHistoryTest(tester, (tester, controller) async {
        await openHistory(tester);
        await tester.tap(find.byKey(const ValueKey('history-back')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('history-back')), findsNothing);
        final IndexedStack stack = tester.widget(find.byType(IndexedStack));
        expect(stack.index, 2);
        expect(find.byKey(const ValueKey('library-list')), findsOneWidget);
      });
    });
  });
}