import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/models/playback.dart';
import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/navigation/app_shell.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/podcast_detail_screen.dart';
import 'package:radio_over/screens/podcast_player_screen.dart';
import 'package:radio_over/theme.dart';
import 'package:radio_over/utils/format.dart';
import 'package:radio_over/widgets/live_badge.dart';
import 'package:radio_over/widgets/podcast_art.dart';
import 'package:radio_over/widgets/podcast_captions.dart';
import 'package:radio_over/widgets/podcast_chapters.dart';
import 'package:radio_over/widgets/podcast_mini_player.dart';
import 'package:radio_over/widgets/podcast_progress.dart';
import 'package:radio_over/widgets/radio_waveform.dart';

/// Routes below a pushed player and hidden IndexedStack tabs stay mounted and
/// findable, so all player assertions are scoped to the player itself.
Finder inPlayer(Finder matching) =>
    find.descendant(of: find.byType(PodcastPlayerScreen), matching: matching);

Finder playerText(String text) => inPlayer(find.text(text));

Finder playerIcon(IconData icon) => inPlayer(find.byIcon(icon));

Finder inMiniPlayer(Finder matching) =>
    find.descendant(of: find.byType(PodcastMiniPlayer), matching: matching);

/// Runs a test against the shell. The widget tree is unmounted before the
/// controller is disposed so the playback clock is always cancelled before
/// the framework checks for pending timers.
Future<void> runPodcastTest(
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

/// The podcasts screen's outer vertical list. Its own Scrollable is always
/// the first one beneath the keyed ListView (the horizontal carousels are
/// nested deeper), so this stays unambiguous inside the shell's IndexedStack.
Finder podcastList() => find
    .descendant(
      of: find.byKey(const ValueKey('podcast-home-list')),
      matching: find.byType(Scrollable),
    )
    .first;

/// Scrolls the podcast home list until [finder] is on screen.
Future<void> revealInPodcasts(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: podcastList());
  await tester.pumpAndSettle();
}

Future<void> openPodcastPlayer(WidgetTester tester) async {
  await switchToPodcasts(tester);
  await revealInPodcasts(tester, find.byKey(const ValueKey('latest-the-daily-gaza')));
  await tester.tap(find.byKey(const ValueKey('latest-the-daily-gaza')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Opens a show's detail screen from the popular-shows carousel.
Future<void> openShowDetail(WidgetTester tester, String showId) async {
  await switchToPodcasts(tester);
  await revealInPodcasts(tester, find.byKey(ValueKey('show-$showId')));
  await tester.tap(find.byKey(ValueKey('show-$showId')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder inDetail(Finder matching) =>
    find.descendant(of: find.byType(PodcastDetailScreen), matching: matching);

Finder detailList() => find
    .descendant(
      of: find.byKey(const ValueKey('podcast-detail-list')),
      matching: find.byType(Scrollable),
    )
    .first;

/// Scrolls the detail screen's list until [finder] is on screen.
Future<void> revealInDetail(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: detailList());
  await tester.pumpAndSettle();
}

void main() {
  group('Podcasts screen', () {
    testWidgets('tab bar switches to the podcast discovery home', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        expect(find.text('LIVE NOW'), findsOneWidget);

        await switchToPodcasts(tester);

        final IndexedStack stack = tester.widget(find.byType(IndexedStack));
        expect(stack.index, 1);
        expect(find.byKey(const ValueKey('podcasts-title')), findsOneWidget);
        expect(find.text('Find something worth hearing.'), findsOneWidget);
        expect(find.text('CONTINUE LISTENING'), findsOneWidget);
        expect(find.text('FEATURED'), findsOneWidget);

        expect(find.byKey(const ValueKey('continue-the-daily-banking')), findsOneWidget);
        expect(find.byKey(const ValueKey('continue-99pi-banyan')), findsOneWidget);

        await revealInPodcasts(tester, find.text('POPULAR SHOWS'));
        expect(find.text('POPULAR SHOWS'), findsOneWidget);
        expect(find.byKey(const ValueKey('show-the-daily')), findsOneWidget);
        expect(find.byKey(const ValueKey('show-99pi')), findsOneWidget);
        expect(find.byKey(const ValueKey('show-serial')), findsOneWidget);
      });
    });

    testWidgets('latest episodes show duration and publication date', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await switchToPodcasts(tester);

        await revealInPodcasts(tester, find.byKey(const ValueKey('latest-the-daily-gaza')));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('latest-the-daily-gaza')),
            matching: find.text('32:00'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('latest-the-daily-gaza')),
            matching: find.text('AUG 18'),
          ),
          findsOneWidget,
        );

        await revealInPodcasts(tester, find.byKey(const ValueKey('latest-99pi-airport-codes')));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('latest-99pi-airport-codes')),
            matching: find.text('38:00'),
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets('continue listening resumes an episode from its saved position', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await switchToPodcasts(tester);

        expect(find.byKey(const ValueKey('continue-the-daily-banking')), findsOneWidget);
        expect(find.byKey(const ValueKey('continue-99pi-banyan')), findsOneWidget);
        expect(find.text('11:42 / 28:00'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('continue-the-daily-banking')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(controller.podcastActive, isTrue);
        expect(controller.currentEpisode?.title, 'Inside the Banking Crisis');
        expect(controller.podcastPosition.inMinutes, 11);
        expect(find.byType(PodcastPlayerScreen), findsOneWidget);
        expect(playerText('11:42'), findsOneWidget);
      });
    });

    testWidgets('featured block opens the show detail screen', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await switchToPodcasts(tester);

        await tester.tap(find.byKey(const ValueKey('podcast-featured')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(controller.podcastActive, isFalse);
        expect(find.byType(PodcastDetailScreen), findsOneWidget);
      });
    });

    testWidgets('explore chips are selectable and clear on re-tap', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await switchToPodcasts(tester);

        await revealInPodcasts(tester, find.byKey(const ValueKey('podcast-category-News')));
        await tester.tap(find.byKey(const ValueKey('podcast-category-News')));
        await tester.pumpAndSettle();

        final AnimatedDefaultTextStyle selected = tester.widget(
          find.descendant(
            of: find.byKey(const ValueKey('podcast-category-News')),
            matching: find.byType(AnimatedDefaultTextStyle),
          ),
        );
        expect(selected.style.fontWeight, FontWeight.w700);

        await tester.tap(find.byKey(const ValueKey('podcast-category-News')));
        await tester.pumpAndSettle();

        final AnimatedDefaultTextStyle cleared = tester.widget(
          find.descendant(
            of: find.byKey(const ValueKey('podcast-category-News')),
            matching: find.byType(AnimatedDefaultTextStyle),
          ),
        );
        expect(cleared.style.fontWeight, FontWeight.w600);
      });
    });

    testWidgets('saving a show fills YOUR SAVED PODCASTS', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await switchToPodcasts(tester);

        await revealInPodcasts(tester, find.text('YOUR SAVED PODCASTS'));
        expect(find.byKey(const ValueKey('podcast-saved-empty')), findsOneWidget);
        expect(find.text('Nothing saved yet'), findsOneWidget);

        await revealInPodcasts(tester, find.byKey(const ValueKey('save-the-daily')));
        await tester.tap(find.byKey(const ValueKey('save-the-daily')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('podcast-saved-empty')), findsNothing);
        await revealInPodcasts(tester, find.byKey(const ValueKey('saved-the-daily')));
        expect(find.byKey(const ValueKey('saved-the-daily')), findsOneWidget);
      });
    });
  });

  group('PodcastDetailScreen', () {
    testWidgets('opens from a popular show with the catalogue header', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openShowDetail(tester, 'the-daily');

        expect(find.byType(PodcastDetailScreen), findsOneWidget);
        expect(inDetail(find.text('THE DAILY')), findsOneWidget);
        expect(inDetail(find.text('The New York Times')), findsOneWidget);
        expect(inDetail(find.text('NEWS')), findsOneWidget);
        expect(inDetail(find.text('EPISODES')), findsOneWidget);
        expect(inDetail(find.text('FOLLOW')), findsOneWidget);
        expect(find.byKey(const ValueKey('detail-back')), findsOneWidget);
      });
    });

    testWidgets('follow toggles between FOLLOW and SAVED', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openShowDetail(tester, 'the-daily');

        expect(inDetail(find.text('FOLLOW')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('detail-follow')));
        await tester.pump();
        expect(inDetail(find.text('SAVED')), findsOneWidget);
        expect(inDetail(find.text('FOLLOW')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('detail-follow')));
        await tester.pump();
        expect(inDetail(find.text('FOLLOW')), findsOneWidget);
      });
    });

    testWidgets('following on the detail reaches YOUR SAVED PODCASTS', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openShowDetail(tester, 'the-daily');

        await tester.tap(find.byKey(const ValueKey('detail-follow')));
        await tester.pump();
        expect(inDetail(find.text('SAVED')), findsOneWidget);
        expect(controller.isSavedShow('the-daily'), isTrue);

        await tester.tap(find.byKey(const ValueKey('detail-back')));
        await tester.pumpAndSettle();

        await revealInPodcasts(tester, find.byKey(const ValueKey('saved-the-daily')));
        expect(find.byKey(const ValueKey('saved-the-daily')), findsOneWidget);
      });
    });

    testWidgets('saving on the home shows SAVED on the show detail', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await switchToPodcasts(tester);

        await revealInPodcasts(tester, find.byKey(const ValueKey('save-the-daily')));
        await tester.tap(find.byKey(const ValueKey('save-the-daily')));
        await tester.pumpAndSettle();
        expect(controller.isSavedShow('the-daily'), isTrue);

        await openShowDetail(tester, 'the-daily');
        expect(inDetail(find.text('SAVED')), findsOneWidget);
        expect(inDetail(find.text('FOLLOW')), findsNothing);
      });
    });

    testWidgets('episode list shows partial progress and completed states', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openShowDetail(tester, 'the-daily');
        expect(
          inDetail(find.byKey(const ValueKey('detail-progress-the-daily-banking'))),
          findsOneWidget,
        );
        expect(
          inDetail(find.byKey(const ValueKey('detail-progress-the-daily-gaza'))),
          findsNothing,
        );

        await tester.tap(find.byKey(const ValueKey('detail-back')));
        await tester.pumpAndSettle();
        await openShowDetail(tester, 'serial');
        expect(inDetail(find.text('PLAYED')), findsOneWidget);
        expect(inDetail(find.byIcon(Icons.check_circle_outline)), findsOneWidget);
      });
    });

    testWidgets('tapping an episode opens the existing podcast player', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openShowDetail(tester, 'the-daily');

        await tester.tap(find.byKey(const ValueKey('detail-row-the-daily-gaza')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(PodcastPlayerScreen), findsOneWidget);
        expect(controller.podcastActive, isTrue);
        expect(controller.currentEpisode?.id, 'the-daily-gaza');
      });
    });

    testWidgets('play icon starts playback directly and keeps the mini player', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openShowDetail(tester, 'the-daily');

        await tester.tap(find.byKey(const ValueKey('detail-play-the-daily-banking')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(controller.podcastActive, isTrue);
        expect(controller.currentEpisode?.id, 'the-daily-banking');
        expect(find.byType(PodcastPlayerScreen), findsNothing);
        expect(find.byType(PodcastMiniPlayer), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(PodcastMiniPlayer),
            matching: find.text('Inside the Banking Crisis'),
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets('latest/oldest sort reorders the episode list', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openShowDetail(tester, 'the-daily');

        final double gazaTop =
            tester.getTopLeft(find.byKey(const ValueKey('detail-row-the-daily-gaza'))).dy;
        final double bankingTop =
            tester.getTopLeft(find.byKey(const ValueKey('detail-row-the-daily-banking'))).dy;
        expect(gazaTop, lessThan(bankingTop));

        await tester.tap(find.byKey(const ValueKey('detail-sort-oldest')));
        await tester.pump();

        final double gazaTopAfter =
            tester.getTopLeft(find.byKey(const ValueKey('detail-row-the-daily-gaza'))).dy;
        final double bankingTopAfter =
            tester.getTopLeft(find.byKey(const ValueKey('detail-row-the-daily-banking'))).dy;
        expect(bankingTopAfter, lessThan(gazaTopAfter));
      });
    });

    testWidgets('about expands with publisher, release frequency and category', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openShowDetail(tester, 'the-daily');

        await revealInDetail(tester, find.byKey(const ValueKey('detail-about-toggle')));
        await tester.tap(find.byKey(const ValueKey('detail-about-toggle')));
        await tester.pumpAndSettle();

        expect(inDetail(find.text('PUBLISHED BY')), findsOneWidget);
        expect(inDetail(find.text('RELEASES')), findsOneWidget);
        expect(inDetail(find.text('CATEGORY')), findsOneWidget);
        expect(inDetail(find.text('The New York Times')), findsOneWidget);
        expect(inDetail(find.text('Every weekday')), findsOneWidget);
      });
    });

    testWidgets('related shows open another detail screen', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openShowDetail(tester, 'the-daily');

        await revealInDetail(tester, find.byKey(const ValueKey('related-99pi')));
        await tester.tap(find.byKey(const ValueKey('related-99pi')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(PodcastDetailScreen), findsNWidgets(2));
        expect(find.text('99% INVISIBLE'), findsOneWidget);
      });
    });

    testWidgets('back returns to the podcast home', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openShowDetail(tester, 'the-daily');

        await tester.tap(find.byKey(const ValueKey('detail-back')));
        await tester.pumpAndSettle();

        expect(find.byType(PodcastDetailScreen), findsNothing);
        expect(find.byKey(const ValueKey('podcast-home-list')), findsOneWidget);
      });
    });
  });

  group('PodcastPlayerScreen', () {
    testWidgets('tapping an episode starts it and opens the podcast player', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);

        expect(controller.podcastActive, isTrue);
        expect(controller.currentEpisode?.title, 'The View From Gaza');
        expect(controller.isPlaying, isTrue);
        expect(find.byType(PodcastPlayerScreen), findsOneWidget);
        expect(playerText('PODCAST'), findsOneWidget);
        expect(playerText('The View From Gaza'), findsAtLeastNWidgets(1));
        expect(find.byType(PodcastProgress), findsOneWidget);
      });
    });

    testWidgets('podcast player uses on-demand language, not the live radio language', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);

        expect(inPlayer(find.byType(LiveBadge)), findsNothing);
        expect(inPlayer(find.byType(RadioWaveform)), findsNothing);
        expect(playerText('LIVE'), findsNothing);
        expect(find.byType(PodcastProgress), findsOneWidget);
      });
    });

    testWidgets('big play/pause toggles podcast playback', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);
        expect(playerIcon(Icons.pause), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('podcast-play-pause')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.status, PlayerStatus.paused);
        expect(playerIcon(Icons.play_arrow), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('podcast-play-pause')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.isPlaying, isTrue);
      });
    });

    testWidgets('rewind and forward seek by ten seconds', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);

        for (int i = 0; i < 3; i++) {
          await tester.tap(find.byKey(const ValueKey('podcast-forward')));
          await tester.pump();
        }
        expect(playerText('0:30'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('podcast-rewind')));
        await tester.pump();
        expect(playerText('0:20'), findsOneWidget);
      });
    });

    testWidgets('tapping the progress field seeks to that position', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);

        await tester.tapAt(tester.getCenter(find.byType(PodcastProgress)));
        await tester.pump();

        expect(controller.podcastPosition.inSeconds, closeTo(32 * 60 ~/ 2, 2));
        expect(playerText('16:00'), findsOneWidget);
      });
    });

    testWidgets('position advances while playing', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);
        expect(playerText('0:00'), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));

        expect(playerText('0:03'), findsOneWidget);
      });
    });

    testWidgets('favourite toggles between selected and unselected', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);
        expect(playerIcon(Icons.favorite_border), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('podcast-favourite')));
        await tester.pump();
        expect(playerIcon(Icons.favorite), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('podcast-favourite')));
        await tester.pump();
        expect(playerIcon(Icons.favorite_border), findsOneWidget);
      });
    });

    testWidgets('back returns to the podcasts screen', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);
        await tester.tap(find.byKey(const ValueKey('podcast-back')));
        await tester.pumpAndSettle();

        expect(find.byType(PodcastPlayerScreen), findsNothing);
        await revealInPodcasts(tester, find.text('LATEST EPISODES'));
        expect(find.text('LATEST EPISODES'), findsOneWidget);
      });
    });

    testWidgets('podcast mini player persists across tabs and opens the player', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        controller.playPodcastEpisode(mockPodcastEpisodes.first);
        await tester.pumpAndSettle();
        expect(find.byType(PodcastMiniPlayer), findsOneWidget);
        expect(inMiniPlayer(find.text('The View From Gaza')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('tab-RADIO')));
        await tester.pump();
        expect(find.byType(PodcastMiniPlayer), findsOneWidget);
        expect(inMiniPlayer(find.text('The View From Gaza')), findsOneWidget);

        await tester.tap(inMiniPlayer(find.text('The View From Gaza')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(PodcastPlayerScreen), findsOneWidget);
      });
    });

    testWidgets('dismissing the mini player hides it until a new episode is chosen', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        controller.playPodcastEpisode(mockPodcastEpisodes.first);
        await tester.pumpAndSettle();
        expect(find.byType(PodcastMiniPlayer), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('podcast-mini-dismiss')));
        await tester.pumpAndSettle();
        expect(find.byType(PodcastMiniPlayer), findsNothing);

        controller.playPodcastEpisode(mockPodcastEpisodes[1]);
        await tester.pumpAndSettle();
        expect(find.byType(PodcastMiniPlayer), findsOneWidget);
        expect(inMiniPlayer(find.text(mockPodcastEpisodes[1].title)), findsOneWidget);
      });
    });

    testWidgets('podcast player surfaces artwork, about section and secondary actions', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);

        expect(inPlayer(find.byType(PodcastArt)), findsOneWidget);
        expect(playerText('EPISODE 184'), findsOneWidget);
        expect(playerText('AUG 18'), findsOneWidget);
        expect(playerText('ABOUT THIS EPISODE'), findsOneWidget);

        await tester.ensureVisible(find.byKey(const ValueKey('podcast-about-toggle')));
        await tester.tap(find.byKey(const ValueKey('podcast-about-toggle')));
        await tester.pumpAndSettle();
        expect(find.text(mockPodcastEpisodes.first.about!), findsOneWidget);

        expect(find.text('1x'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('podcast-speed')));
        await tester.pump();
        expect(find.text('1.5x'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('podcast-download')));
        await tester.pump();
        expect(playerIcon(Icons.download_done), findsOneWidget);
      });
    });
  });

  group('podcast captions', () {
    final PodcastEpisode episode = mockPodcastEpisodes[0];

    AnimatedDefaultTextStyle captionStyle(WidgetTester tester, int index) {
      return tester.widget<AnimatedDefaultTextStyle>(
        find.descendant(
          of: find.byKey(ValueKey('caption-$index')),
          matching: find.byType(AnimatedDefaultTextStyle),
        ),
      );
    }

    Future<void> openChapters(WidgetTester tester) async {
      await tester.fling(
        find.byKey(const ValueKey('podcast-episode-title')),
        const Offset(-400, 0),
        1200,
      );
      await tester.pumpAndSettle();
    }

    Future<void> openCaptions(WidgetTester tester) async {
      await openChapters(tester);
      await tester.fling(
        find.byType(PodcastChapters),
        const Offset(-400, 0),
        1200,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('swiping left reveals the Spotify-style captions view', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);

        expect(find.byType(PodcastCaptions), findsNothing);
        expect(find.byType(PodcastProgress), findsOneWidget);

        await openCaptions(tester);

        expect(find.byType(PodcastCaptions), findsOneWidget);
        expect(episode.captions.first.text, 'This is The View From Gaza.');
        expect(find.text(episode.captions.first.text), findsOneWidget);
      });
    });

    testWidgets('tapping a caption seeks to that moment and highlights it', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);
        await openCaptions(tester);

        final PodcastCaption target = episode.captions[1];
        await tester.tap(find.text(target.text));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          controller.podcastPosition.inSeconds,
          closeTo(target.start.inSeconds, 1),
          reason: 'position may tick forward one second before the assertion',
        );
        expect(captionStyle(tester, 1).style.fontWeight, FontWeight.w600);
      });
    });

    testWidgets('captions track playback position with the active line highlighted', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);
        await openCaptions(tester);

        controller.seek(episode.captions[1].start);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(captionStyle(tester, 1).style.fontWeight, FontWeight.w600);

        controller.seek(episode.captions[2].start);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(captionStyle(tester, 2).style.fontWeight, FontWeight.w600);
        expect(captionStyle(tester, 1).style.fontWeight, FontWeight.w400);
      });
    });

    testWidgets('swiping right returns to the episode view', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);
        await openCaptions(tester);
        expect(find.byType(PodcastCaptions), findsOneWidget);

        await tester.fling(
          find.text(episode.captions.first.text),
          const Offset(400, 0),
          1200,
        );
        await tester.pumpAndSettle();
        await tester.fling(
          find.byType(PodcastChapters),
          const Offset(400, 0),
          1200,
        );
        await tester.pumpAndSettle();

        expect(find.byType(PodcastChapters), findsNothing);
        expect(find.byType(PodcastCaptions), findsNothing);
        expect(find.byType(PodcastProgress), findsOneWidget);
      });
    });
  });

  group('podcast chapters', () {
    final PodcastEpisode episode = mockPodcastEpisodes[0];

    AnimatedDefaultTextStyle chapterStyle(WidgetTester tester, int index) {
      return tester.widget<AnimatedDefaultTextStyle>(
        find.descendant(
          of: find.byKey(ValueKey('chapter-$index')),
          matching: find.byType(AnimatedDefaultTextStyle),
        ),
      );
    }

    Future<void> openChapters(WidgetTester tester) async {
      await tester.fling(
        find.byKey(const ValueKey('podcast-episode-title')),
        const Offset(-400, 0),
        1200,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('swiping left once reveals the chapter list', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);

        expect(find.byType(PodcastChapters), findsNothing);
        expect(playerText('CHAPTERS'), findsOneWidget);

        await openChapters(tester);

        expect(find.byType(PodcastChapters), findsOneWidget);
        expect(find.text(episode.chapters.first.title), findsOneWidget);
        expect(find.text(formatDuration(episode.chapters.first.start)), findsOneWidget);
      });
    });

    testWidgets('tapping a chapter seeks to that moment and highlights it', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);
        await openChapters(tester);

        final PodcastChapter target = episode.chapters[1];
        await tester.tap(find.text(target.title));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          controller.podcastPosition.inSeconds,
          closeTo(target.start.inSeconds, 2),
          reason: 'position may tick forward before the assertion',
        );
        expect(chapterStyle(tester, 1).style.fontWeight, FontWeight.w600);
      });
    });

    testWidgets('chapter highlight follows playback position', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openPodcastPlayer(tester);
        await openChapters(tester);

        controller.seek(episode.chapters[1].start);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(chapterStyle(tester, 1).style.fontWeight, FontWeight.w600);

        controller.seek(episode.chapters[2].start);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(chapterStyle(tester, 2).style.fontWeight, FontWeight.w600);
        expect(chapterStyle(tester, 1).style.fontWeight, FontWeight.w400);
      });
    });

    testWidgets('captions page shows a placeholder when no transcript exists', (tester) async {
      await runPodcastTest(tester, (tester, controller) async {
        await openShowDetail(tester, 'the-daily');
        await tester.tap(find.byKey(const ValueKey('detail-row-the-daily-banking')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(controller.currentEpisode?.id, 'the-daily-banking');
        await openChapters(tester);
        await tester.fling(
          find.byType(PodcastChapters),
          const Offset(-400, 0),
          1200,
        );
        await tester.pumpAndSettle();

        expect(find.byType(PodcastCaptions), findsNothing);
        expect(find.byKey(const ValueKey('transcript-placeholder')), findsOneWidget);
      });
    });
  });
}