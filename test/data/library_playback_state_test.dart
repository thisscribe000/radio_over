import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/data/library/library_store.dart';
import 'package:radio_over/data/progress/playback_progress_store.dart';
import 'package:radio_over/models/playback_progress.dart';
import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/navigation/app_shell.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/library_screen.dart';
import 'package:radio_over/theme.dart';

PodcastEpisode _episode(
  String id, {
  Duration duration = const Duration(minutes: 30),
}) =>
    PodcastEpisode(
      id: id,
      podcastId: 'show-$id',
      podcastName: 'Show',
      title: 'Episode $id',
      duration: duration,
    );

/// Waits for the controller's async persistence/restore futures (all session
/// stores complete on microtasks) so assertions run after they settle.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  group('library + playback state persistence', () {
    test('saved episodes and saved shows survive a restart', () async {
      final InMemoryLibraryStore library = InMemoryLibraryStore();
      final PlaybackProgressStore progress = InMemoryPlaybackProgressStore();

      final PlaybackController first =
          PlaybackController(libraryStore: library, progressStore: progress);
      first.toggleSavedEpisode('ep-a');
      first.toggleSavedEpisode('ep-b');
      first.toggleSavedShow('show-x');
      await _settle();
      first.dispose();

      final PlaybackController second =
          PlaybackController(libraryStore: library, progressStore: progress);
      await _settle();
      expect(second.isSavedEpisode('ep-a'), isTrue);
      expect(second.isSavedEpisode('ep-b'), isTrue);
      expect(second.isSavedEpisode('ep-c'), isFalse);
      expect(second.isSavedShow('show-x'), isTrue);
      expect(second.isSavedShow('show-y'), isFalse);
      second.dispose();
    });

    test('playback position is saved and restored on a restart', () async {
      final InMemoryLibraryStore library = InMemoryLibraryStore();
      final PlaybackProgressStore progress = InMemoryPlaybackProgressStore();

      final PlaybackController first =
          PlaybackController(libraryStore: library, progressStore: progress);
      first.playPodcastEpisode(_episode('ep-prog'));
      first.seek(const Duration(minutes: 4));
      await _settle();
      first.dispose();

      final PlaybackController second =
          PlaybackController(libraryStore: library, progressStore: progress);
      await _settle();
      second.playPodcastEpisode(_episode('ep-prog'));
      expect(second.currentEpisode?.position, const Duration(minutes: 4));
      second.dispose();
    });

    test('a completed episode is not continue-listening and replays from start',
        () async {
      final PlaybackProgressStore progress = InMemoryPlaybackProgressStore();
      await progress.save({
        'ep-done': PlaybackProgress(
          episodeId: 'ep-done',
          position: const Duration(minutes: 30),
          duration: const Duration(minutes: 30),
          updatedAt: DateTime(2024, 1, 1),
          completed: true,
        ),
      });

      final PlaybackController controller =
          PlaybackController(progressStore: progress);
      await _settle();

      expect(controller.progressForEpisode(_episode('ep-done')), isNull);
      expect(
        controller.continueListening.map((p) => p.episodeId),
        isNot(contains('ep-done')),
      );

      controller.playPodcastEpisode(_episode('ep-done'));
      expect(controller.currentEpisode?.position, Duration.zero);
      controller.dispose();
    });

    test('continueListening ranks most-recently-updated first, exclusions win',
        () async {
      final PlaybackProgressStore progress = InMemoryPlaybackProgressStore();
      final DateTime base = DateTime(2024, 1, 1, 12);
      await progress.save({
        'old': PlaybackProgress(
          episodeId: 'old',
          position: const Duration(minutes: 1),
          duration: const Duration(minutes: 30),
          updatedAt: base,
        ),
        'new': PlaybackProgress(
          episodeId: 'new',
          position: const Duration(minutes: 2),
          duration: const Duration(minutes: 30),
          updatedAt: base.add(const Duration(seconds: 30)),
        ),
        'done': PlaybackProgress(
          episodeId: 'done',
          position: const Duration(minutes: 30),
          duration: const Duration(minutes: 30),
          updatedAt: base.add(const Duration(seconds: 60)),
          completed: true,
        ),
      });

      final PlaybackController controller =
          PlaybackController(progressStore: progress);
      await _settle();

      expect(
        controller.continueListening.map((p) => p.episodeId).toList(),
        ['new', 'old'],
      );
      controller.dispose();
    });

    test('progress is written on the interval while playing, not per tick',
        () async {
      final PlaybackProgressStore progress = InMemoryPlaybackProgressStore();
      final PlaybackController controller = PlaybackController(
        progressStore: progress,
        progressPersistInterval: const Duration(milliseconds: 40),
      );

      controller.playPodcastEpisode(_episode('ep-throttle'));
      await Future<void>.delayed(const Duration(milliseconds: 130));

      final Map<String, PlaybackProgress> saved = await progress.load();
      expect(saved.containsKey('ep-throttle'), isTrue);
      controller.dispose();
    });

    test('unsaving an episode does not wipe its saved progress', () async {
      final InMemoryLibraryStore library = InMemoryLibraryStore();
      final PlaybackProgressStore progress = InMemoryPlaybackProgressStore();

      final PlaybackController first =
          PlaybackController(libraryStore: library, progressStore: progress);
      first.playPodcastEpisode(_episode('ep-both'));
      first.seek(const Duration(minutes: 3));
      first.toggleSavedEpisode('ep-both');
      await _settle();
      first.toggleSavedEpisode('ep-both'); // unsave
      await _settle();
      first.dispose();

      final PlaybackController second =
          PlaybackController(libraryStore: library, progressStore: progress);
      await _settle();
      expect(second.isSavedEpisode('ep-both'), isFalse);
      second.playPodcastEpisode(_episode('ep-both'));
      expect(second.currentEpisode?.position, const Duration(minutes: 3));
      second.dispose();
    });
  });

  group('library continue listening reads persisted progress', () {
    testWidgets('shows a saved position for a restarted episode',
        (tester) async {
      final PlaybackProgressStore progress = InMemoryPlaybackProgressStore();
      await progress.save({
        'the-daily-banking': PlaybackProgress(
          episodeId: 'the-daily-banking',
          position: const Duration(minutes: 9),
          duration: const Duration(minutes: 28),
          updatedAt: DateTime(2024, 2, 1, 10),
        ),
      });
      final PlaybackController controller =
          PlaybackController(progressStore: progress);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AppShell(controller: controller),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('tab-LIBRARY')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final Finder libraryList = find
          .descendant(
            of: find.byKey(const ValueKey('library-list')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('library-continue-the-daily-banking')),
        250,
        scrollable: libraryList,
      );
      await tester.pumpAndSettle();

      final Finder inLibrary = find.descendant(
        of: find.byType(LibraryScreen),
        matching: find.text('9:00 / 28:00'),
      );
      expect(inLibrary, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });
}
