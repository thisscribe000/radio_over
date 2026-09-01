import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/data/timeline/snippet_store.dart';
import 'package:radio_over/models/audio_snippet.dart';
import 'package:radio_over/playback/playback_controller.dart';

void main() {
  group('AudioSnippet Model', () {
    test('computes snippetDuration and thread properties correctly', () {
      final AudioSnippet snippet = AudioSnippet(
        id: 'test-1',
        userId: 'u-1',
        userName: 'Alex',
        podcastId: 'pod-1',
        podcastName: 'Science Hour',
        episodeId: 'ep-1',
        episodeTitle: 'Quantum Physics',
        start: const Duration(seconds: 30),
        end: const Duration(seconds: 75),
        caption: 'Great moment',
        threadId: 'thread-123',
        threadIndex: 1,
        threadTotal: 3,
        createdAt: DateTime.now(),
      );

      expect(snippet.snippetDuration, const Duration(seconds: 45));
      expect(snippet.isThread, isTrue);
      expect(snippet.isThreadRoot, isTrue);

      final AudioSnippet part2 = snippet.copyWith(threadIndex: 2);
      expect(part2.isThreadRoot, isFalse);
    });

    test('serializes to JSON and deserializes correctly', () {
      final DateTime now = DateTime(2026, 9, 1, 10, 30);
      final AudioSnippet snippet = AudioSnippet(
        id: 'test-2',
        userId: 'u-2',
        userName: 'Jordan',
        podcastId: 'pod-2',
        podcastName: 'Tech Today',
        episodeId: 'ep-2',
        episodeTitle: 'AI Breakthroughs',
        audioUrl: 'https://example.com/ep2.mp3',
        start: const Duration(minutes: 1),
        end: const Duration(minutes: 1, seconds: 30),
        caption: 'Fascinating quote',
        likesCount: 12,
        isLiked: true,
        threadId: 'thread-999',
        threadIndex: 2,
        threadTotal: 4,
        createdAt: now,
      );

      final Map<String, dynamic> json = snippet.toJson();
      final AudioSnippet fromJson = AudioSnippet.fromJson(json);

      expect(fromJson.id, snippet.id);
      expect(fromJson.userName, snippet.userName);
      expect(fromJson.caption, snippet.caption);
      expect(fromJson.start, snippet.start);
      expect(fromJson.end, snippet.end);
      expect(fromJson.likesCount, 12);
      expect(fromJson.isLiked, isTrue);
      expect(fromJson.threadId, 'thread-999');
      expect(fromJson.threadIndex, 2);
      expect(fromJson.threadTotal, 4);
    });
  });

  group('PlaybackController - Snippets & Threads', () {
    test('creates snippet and toggles like state', () async {
      final store = InMemorySnippetStore(initial: []);
      final controller = PlaybackController(snippetStore: store);

      expect(controller.snippets, isEmpty);

      final AudioSnippet snippet = AudioSnippet(
        id: 's-101',
        userId: 'u-1',
        userName: 'Tester',
        podcastId: 'p-1',
        podcastName: 'Show',
        episodeId: 'e-1',
        episodeTitle: 'Episode',
        start: const Duration(seconds: 10),
        end: const Duration(seconds: 40),
        caption: 'Awesome insight',
        createdAt: DateTime.now(),
      );

      await controller.createSnippet(snippet);
      expect(controller.snippets.length, 1);
      expect(controller.snippets.first.id, 's-101');
      expect(controller.snippets.first.likesCount, 0);

      // Toggle like
      await controller.toggleLikeSnippet('s-101');
      expect(controller.snippets.first.isLiked, isTrue);
      expect(controller.snippets.first.likesCount, 1);

      // Toggle unlike
      await controller.toggleLikeSnippet('s-101');
      expect(controller.snippets.first.isLiked, isFalse);
      expect(controller.snippets.first.likesCount, 0);

      controller.dispose();
    });

    test('creates multi-part thread and queries threadSnippets', () async {
      final store = InMemorySnippetStore(initial: []);
      final controller = PlaybackController(snippetStore: store);

      final List<AudioSnippet> threadParts = [
        AudioSnippet(
          id: 'thread-1-part-1',
          userId: 'u-1',
          userName: 'Tester',
          podcastId: 'p-1',
          podcastName: 'Show',
          episodeId: 'e-1',
          episodeTitle: 'Episode',
          start: const Duration(seconds: 0),
          end: const Duration(seconds: 60),
          caption: '(1/2) Part 1',
          threadId: 't-1',
          threadIndex: 1,
          threadTotal: 2,
          createdAt: DateTime.now(),
        ),
        AudioSnippet(
          id: 'thread-1-part-2',
          userId: 'u-1',
          userName: 'Tester',
          podcastId: 'p-1',
          podcastName: 'Show',
          episodeId: 'e-1',
          episodeTitle: 'Episode',
          start: const Duration(seconds: 60),
          end: const Duration(seconds: 110),
          caption: '(2/2) Part 2',
          threadId: 't-1',
          threadIndex: 2,
          threadTotal: 2,
          createdAt: DateTime.now(),
        ),
      ];

      await controller.createSnippetThread(threadParts);
      expect(controller.snippets.length, 2);

      final retrievedParts = controller.threadSnippets('t-1');
      expect(retrievedParts.length, 2);
      expect(retrievedParts[0].threadIndex, 1);
      expect(retrievedParts[1].threadIndex, 2);

      controller.dispose();
    });
  });
}
