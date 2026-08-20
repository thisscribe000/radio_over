import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/models/playback.dart';
import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/models/station.dart';
import 'package:radio_over/navigation/app_shell.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/podcast_player_screen.dart';
import 'package:radio_over/screens/radio_player_screen.dart';
import 'package:radio_over/screens/radio_screen.dart';
import 'package:radio_over/theme.dart';
import 'package:radio_over/widgets/podcast_mini_player.dart';
import 'package:radio_over/widgets/radio_mini_player.dart';

const PodcastEpisode shortEpisode = PodcastEpisode(
  id: 'sleep-short',
  podcastId: 'sleep-test',
  podcastName: 'Sleep Test',
  title: 'Short One',
  duration: Duration(minutes: 1),
);

/// The radio player runs subtle looping animations, so pump bounded frames
/// instead of settling.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> openRadioPlayer(WidgetTester tester) async {
  final Finder row = find.byKey(const ValueKey('station-BBC World Service'));
  await tester.scrollUntilVisible(row, 250, scrollable: find.byType(Scrollable).first);
  await tester.pump();
  await tester.tap(row);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('BBC WORLD SERVICE'));
  await settle(tester);
}

Future<void> switchToPodcasts(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tab-PODCASTS')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
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

Future<void> openPodcastPlayer(WidgetTester tester) async {
  await switchToPodcasts(tester);
  await revealInPodcasts(tester, find.byKey(const ValueKey('latest-the-daily-gaza')));
  await tester.tap(find.byKey(const ValueKey('latest-the-daily-gaza')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder inPlayer(Finder matching) =>
    find.descendant(of: find.byType(PodcastPlayerScreen), matching: matching);

/// The live sleep countdown, scoped to whichever player is open.
Finder sleepCountdown() => find.textContaining('Sleep · ');

Future<void> openSleepSheet(WidgetTester tester, String triggerKey) async {
  await tester.tap(find.byKey(ValueKey(triggerKey)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Controller-only tests still need a pump to fire the periodic timers.
Future<void> withController(
  PlaybackController controller,
  Future<void> Function() body,
) async {
  try {
    await body();
  } finally {
    controller.dispose();
  }
}

void main() {
  group('radio player sleep timer', () {
    testWidgets('sleep sheet offers 15/30/45/60 and never END OF EPISODE', (tester) async {
      final PlaybackController controller = PlaybackController();
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: RadioScreen(controller: controller)),
      );
      try {
        await openRadioPlayer(tester);
        await openSleepSheet(tester, 'player-sleep');

        expect(find.text('15 MINUTES'), findsOneWidget);
        expect(find.text('30 MINUTES'), findsOneWidget);
        expect(find.text('45 MINUTES'), findsOneWidget);
        expect(find.text('60 MINUTES'), findsOneWidget);
        expect(find.byKey(const ValueKey('sleep-timer-off')), findsNothing);
        expect(find.byKey(const ValueKey('sleep-timer-end')), findsNothing);
        expect(find.text('END OF EPISODE'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });

    testWidgets('picking 15 minutes arms a duration timer and shows the countdown', (tester) async {
      final PlaybackController controller = PlaybackController();
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: RadioScreen(controller: controller)),
      );
      try {
        await openRadioPlayer(tester);
        await openSleepSheet(tester, 'player-sleep');
        await tester.tap(find.byKey(const ValueKey('sleep-timer-15')));
        await settle(tester);

        expect(controller.sleepActive, isTrue);
        expect(controller.sleepMode, SleepTimerMode.duration);
        expect(controller.isPlaying, isTrue);
        expect(controller.sleepRemaining!.inSeconds, greaterThan(14 * 60 + 55));
        expect(
          find.descendant(
            of: find.byType(RadioPlayerScreen),
            matching: sleepCountdown(),
          ),
          findsOneWidget,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });

    testWidgets('a new timer replaces the active one', (tester) async {
      DateTime now = DateTime(2026, 1, 1, 12);
      final PlaybackController controller = PlaybackController(clock: () => now);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: RadioScreen(controller: controller)),
      );
      try {
        controller.playRadioStation(mockStations.first);
        await tester.pump();
        controller.startSleepTimer(const Duration(minutes: 15));
        now = now.add(const Duration(minutes: 1));
        controller.startSleepTimer(const Duration(minutes: 60));
        await tester.pump();

        expect(controller.sleepMode, SleepTimerMode.duration);
        expect(controller.sleepRemaining!.inMinutes, inInclusiveRange(58, 60));

        now = now.add(const Duration(minutes: 14));
        await tester.pump(const Duration(seconds: 1));
        expect(controller.sleepActive, isTrue, reason: 'replaced timer supersedes the old one');
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });

    testWidgets('cancel via the sheet keeps audio playing', (tester) async {
      final PlaybackController controller = PlaybackController();
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: RadioScreen(controller: controller)),
      );
      try {
        await openRadioPlayer(tester);
        await openSleepSheet(tester, 'player-sleep');
        await tester.tap(find.byKey(const ValueKey('sleep-timer-15')));
        await settle(tester);
        expect(controller.sleepActive, isTrue);

        await openSleepSheet(tester, 'player-sleep');
        expect(find.text('TURN OFF SLEEP TIMER'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('sleep-timer-off')));
        await settle(tester);

        expect(controller.sleepActive, isFalse);
        expect(controller.isPlaying, isTrue, reason: 'cancelling must not stop audio');
        expect(sleepCountdown(), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });

    testWidgets('pause/resume keeps the timer running with the countdown continuing', (tester) async {
      DateTime now = DateTime(2026, 1, 1, 12);
      final PlaybackController controller = PlaybackController(clock: () => now);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: RadioScreen(controller: controller)),
      );
      try {
        controller.playRadioStation(mockStations.first);
        await tester.pump();
        controller.startSleepTimer(const Duration(minutes: 15));
        await tester.pump();

        controller.toggle();
        await tester.pump();
        expect(controller.status, PlayerStatus.paused);
        expect(controller.sleepActive, isTrue);

        now = now.add(const Duration(minutes: 5));
        await tester.pump(const Duration(seconds: 1));
        expect(controller.sleepActive, isTrue);
        expect(controller.sleepRemaining!.inMinutes, inInclusiveRange(9, 10));

        controller.toggle();
        await tester.pump();
        expect(controller.isPlaying, isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });

    testWidgets('expiry stops playback, closes the player, and play again works', (tester) async {
      DateTime now = DateTime(2026, 1, 1, 12);
      final PlaybackController controller = PlaybackController(clock: () => now);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: RadioScreen(controller: controller)),
      );
      try {
        await openRadioPlayer(tester);
        await openSleepSheet(tester, 'player-sleep');
        await tester.tap(find.byKey(const ValueKey('sleep-timer-15')));
        await settle(tester);
        expect(controller.sleepActive, isTrue);
        expect(find.byType(RadioPlayerScreen), findsOneWidget);

        now = now.add(const Duration(minutes: 15));
        await tester.pump(const Duration(seconds: 2));
        await settle(tester);

        expect(controller.sleepActive, isFalse);
        expect(controller.audioType, AudioType.none);
        expect(controller.status, PlayerStatus.stopped);
        expect(find.byType(RadioPlayerScreen), findsNothing);

        controller.playRadioStation(mockStations.first);
        await tester.pump();
        expect(controller.isPlaying, isTrue);
        expect(controller.audioType, AudioType.radio);
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });

    testWidgets('radio mini player shows a subtle bedtime icon while a timer runs', (tester) async {
      final PlaybackController controller = PlaybackController();
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: RadioScreen(controller: controller)),
      );
      try {
        controller.playRadioStation(mockStations.first);
        await tester.pump();
        controller.startSleepTimer(const Duration(minutes: 15));
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(RadioMiniPlayer),
            matching: find.byIcon(Icons.bedtime_outlined),
          ),
          findsOneWidget,
        );

        controller.cancelSleepTimer();
        await tester.pump();
        expect(
          find.descendant(
            of: find.byType(RadioMiniPlayer),
            matching: find.byIcon(Icons.bedtime_outlined),
          ),
          findsNothing,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });
  });

  group('podcast player sleep timer', () {
    testWidgets('sleep sheet offers END OF EPISODE alongside the durations', (tester) async {
      final PlaybackController controller = PlaybackController();
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: AppShell(controller: controller)),
      );
      try {
        await openPodcastPlayer(tester);
        await openSleepSheet(tester, 'podcast-sleep');

        expect(find.text('15 MINUTES'), findsOneWidget);
        expect(find.text('60 MINUTES'), findsOneWidget);
        expect(find.byKey(const ValueKey('sleep-timer-end')), findsOneWidget);
        expect(find.text('END OF EPISODE'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });

    testWidgets('picking END OF EPISODE counts down the remaining episode time', (tester) async {
      final PlaybackController controller = PlaybackController();
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: AppShell(controller: controller)),
      );
      try {
        await openPodcastPlayer(tester);
        await openSleepSheet(tester, 'podcast-sleep');
        await tester.tap(find.byKey(const ValueKey('sleep-timer-end')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(controller.sleepActive, isTrue);
        expect(controller.sleepMode, SleepTimerMode.endOfEpisode);
        expect(controller.sleepRemaining, isNotNull);
        expect(
          controller.sleepRemaining!.inSeconds,
          inInclusiveRange(31 * 60 + 55, 32 * 60),
        );
        expect(inPlayer(sleepCountdown()), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });

    testWidgets('END OF EPISODE stops playback at the episode end', (tester) async {
      final PlaybackController controller = PlaybackController();
      await withController(controller, () async {
        controller.playPodcastEpisode(shortEpisode);
        controller.startSleepTimerEndOfEpisode();
        expect(controller.status, PlayerStatus.playing);
        expect(controller.sleepActive, isTrue);

        await tester.pump(const Duration(seconds: 61));

        expect(controller.status, PlayerStatus.stopped);
        expect(controller.audioType, AudioType.none);
        expect(controller.sleepActive, isFalse);
        expect(controller.currentEpisode, isNull);
      });
    });

    testWidgets('an episode finishing under a duration timer only pauses it', (tester) async {
      final PlaybackController controller = PlaybackController();
      await withController(controller, () async {
        controller.playPodcastEpisode(shortEpisode);
        controller.startSleepTimer(const Duration(minutes: 30));
        await tester.pump(const Duration(seconds: 61));

        expect(controller.status, PlayerStatus.paused);
        expect(controller.audioType, AudioType.podcast);
        expect(controller.sleepActive, isTrue);
        expect(controller.sleepMode, SleepTimerMode.duration);
      });
    });

    testWidgets('expiry stops playback and dismisses the player and mini player', (tester) async {
      DateTime now = DateTime(2026, 1, 1, 12);
      final PlaybackController controller = PlaybackController(clock: () => now);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: AppShell(controller: controller)),
      );
      try {
        await openPodcastPlayer(tester);
        await openSleepSheet(tester, 'podcast-sleep');
        await tester.tap(find.byKey(const ValueKey('sleep-timer-15')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(controller.sleepActive, isTrue);
        expect(find.byType(PodcastPlayerScreen), findsOneWidget);

        now = now.add(const Duration(minutes: 15));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(controller.sleepActive, isFalse);
        expect(controller.audioType, AudioType.none);
        expect(find.byType(PodcastPlayerScreen), findsNothing);
        expect(find.byType(PodcastMiniPlayer), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });

    testWidgets('podcast mini player shows a subtle bedtime icon while a timer runs', (tester) async {
      final PlaybackController controller = PlaybackController();
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: AppShell(controller: controller)),
      );
      try {
        controller.playPodcastEpisode(mockPodcastEpisodes.first);
        await tester.pumpAndSettle();
        controller.startSleepTimer(const Duration(minutes: 30));
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(PodcastMiniPlayer),
            matching: find.byIcon(Icons.bedtime_outlined),
          ),
          findsOneWidget,
        );

        controller.cancelSleepTimer();
        await tester.pump();
        expect(
          find.descendant(
            of: find.byType(PodcastMiniPlayer),
            matching: find.byIcon(Icons.bedtime_outlined),
          ),
          findsNothing,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });
  });
}