import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/data/timeline/snippet_store.dart';
import 'package:radio_over/models/audio_snippet.dart';
import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/timeline_screen.dart';
import 'package:radio_over/theme.dart';
import 'package:radio_over/widgets/podcast_snippet_clipper_sheet.dart';

void main() {
  testWidgets('TimelineScreen renders snippet cards and handles likes', (tester) async {
    final AudioSnippet sampleSnippet = AudioSnippet(
      id: 'snippet-test-1',
      userId: 'user-test',
      userName: 'Test User',
      podcastId: 'pod-1',
      podcastName: 'Test Podcast',
      episodeId: 'ep-1',
      episodeTitle: 'Test Episode Title',
      start: const Duration(seconds: 15),
      end: const Duration(seconds: 45),
      caption: 'Memorable moment from the show',
      likesCount: 10,
      createdAt: DateTime.now(),
    );

    final store = InMemorySnippetStore(initial: [sampleSnippet]);
    final controller = PlaybackController(snippetStore: store);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: TimelineScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header and snippet content
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('Memorable moment from the show'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);

    // Tap Like button
    final likeFinder = find.byKey(const ValueKey('snippet-like-snippet-test-1'));
    expect(likeFinder, findsOneWidget);
    await tester.tap(likeFinder);
    await tester.pumpAndSettle();

    // Count should be 11
    expect(find.text('11'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('TimelineScreen renders stacked thread card and opens SnippetThreadSheet',
      (tester) async {
    final List<AudioSnippet> threadSnippets = [
      AudioSnippet(
        id: 't-part-1',
        userId: 'u-thread',
        userName: 'Thread Creator',
        podcastId: 'pod-1',
        podcastName: 'Pod Show',
        episodeId: 'ep-1',
        episodeTitle: 'Long Form Episode',
        start: const Duration(seconds: 0),
        end: const Duration(seconds: 60),
        caption: '(1/2) Thread Part 1',
        threadId: 'thread-main',
        threadIndex: 1,
        threadTotal: 2,
        createdAt: DateTime.now(),
      ),
      AudioSnippet(
        id: 't-part-2',
        userId: 'u-thread',
        userName: 'Thread Creator',
        podcastId: 'pod-1',
        podcastName: 'Pod Show',
        episodeId: 'ep-1',
        episodeTitle: 'Long Form Episode',
        start: const Duration(seconds: 60),
        end: const Duration(seconds: 100),
        caption: '(2/2) Thread Part 2',
        threadId: 'thread-main',
        threadIndex: 2,
        threadTotal: 2,
        createdAt: DateTime.now().add(const Duration(seconds: 1)),
      ),
    ];

    final store = InMemorySnippetStore(initial: threadSnippets);
    final controller = PlaybackController(snippetStore: store);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: TimelineScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    // Root thread card is visible
    expect(find.text('THREAD (2 CLIPS)'), findsOneWidget);
    expect(find.text('(1/2) Thread Part 1'), findsOneWidget);

    // Tap View Full Thread
    final viewThreadBtn = find.text('VIEW FULL THREAD (2 CLIPS)');
    expect(viewThreadBtn, findsOneWidget);
    await tester.tap(viewThreadBtn);
    await tester.pumpAndSettle();

    // Verify SnippetThreadSheet opened
    expect(find.byKey(const ValueKey('snippet-thread-sheet')), findsOneWidget);
    expect(find.text('PART 1 OF 2'), findsOneWidget);
    expect(find.text('PART 2 OF 2'), findsOneWidget);
    expect(find.text('(2/2) Thread Part 2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('PodcastSnippetClipperSheet allows trimming and posting highlight',
      (tester) async {
    final store = InMemorySnippetStore(initial: []);
    final controller = PlaybackController(snippetStore: store);

    const episode = PodcastEpisode(
      id: 'ep-trim-1',
      podcastId: 'show-1',
      podcastName: 'Show Name',
      title: 'Episode For Trimming',
      duration: Duration(minutes: 20),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => PodcastSnippetClipperSheet.show(
                context,
                controller: controller,
                episode: episode,
              ),
              child: const Text('OPEN CLIPPER'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN CLIPPER'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('clipper-sheet')), findsOneWidget);
    expect(find.text('CLIP AUDIO SNIPPET'), findsOneWidget);

    // Enter caption
    final captionInput = find.byKey(const ValueKey('clipper-caption-input'));
    expect(captionInput, findsOneWidget);
    await tester.enterText(captionInput, 'My favorite quote ever!');
    await tester.pumpAndSettle();

    // Tap Post
    final postBtn = find.byKey(const ValueKey('clipper-post-btn'));
    expect(postBtn, findsOneWidget);
    await tester.ensureVisible(postBtn);
    await tester.tap(postBtn);
    await tester.pumpAndSettle();

    // Verify snippet was posted to controller
    expect(controller.snippets.length, 1);
    expect(controller.snippets.first.caption, 'My favorite quote ever!');
    expect(controller.snippets.first.episodeTitle, 'Episode For Trimming');

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('PodcastSnippetClipperSheet with >60s selection splits into thread',
      (tester) async {
    final store = InMemorySnippetStore(initial: []);
    final controller = PlaybackController(snippetStore: store);

    const episode = PodcastEpisode(
      id: 'ep-trim-thread',
      podcastId: 'show-1',
      podcastName: 'Show Name',
      title: 'Long Episode For Threading',
      duration: Duration(minutes: 20),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => PodcastSnippetClipperSheet.show(
                context,
                controller: controller,
                episode: episode,
              ),
              child: const Text('OPEN CLIPPER'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN CLIPPER'));
    await tester.pumpAndSettle();

    // Tap 2m preset chip
    final chip2m = find.text('2m');
    expect(chip2m, findsOneWidget);
    await tester.tap(chip2m);
    await tester.pumpAndSettle();

    // Thread notice and share thread button should appear
    expect(find.text('AUDIO THREAD · 2 PARTS'), findsOneWidget);
    expect(find.text('SHARE THREAD (2 PARTS)'), findsOneWidget);

    // Tap Post Thread
    final threadPostBtn = find.byKey(const ValueKey('clipper-post-btn'));
    await tester.ensureVisible(threadPostBtn);
    await tester.tap(threadPostBtn);
    await tester.pumpAndSettle();

    // Controller should now have 2 snippet parts in the thread
    expect(controller.snippets.length, 2);
    expect(controller.snippets[0].threadTotal, 2);
    expect(controller.snippets[1].threadTotal, 2);
    expect(controller.snippets[0].threadId, isNotNull);
    expect(controller.snippets[0].threadId, controller.snippets[1].threadId);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('TimelineScreen opens comments sheet, adds comment and updates count',
      (tester) async {
    final AudioSnippet sampleSnippet = AudioSnippet(
      id: 'snippet-comment-1',
      userId: 'user-creator',
      userName: 'Verified Creator',
      isVerified: true,
      podcastId: 'pod-1',
      podcastName: 'Test Podcast',
      episodeId: 'ep-1',
      episodeTitle: 'Test Episode Title',
      start: const Duration(seconds: 15),
      end: const Duration(seconds: 45),
      caption: 'Comment discussion highlight moment',
      likesCount: 5,
      commentsCount: 0,
      createdAt: DateTime.now(),
    );

    final store = InMemorySnippetStore(initial: [sampleSnippet]);
    final controller = PlaybackController(snippetStore: store);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: TimelineScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    // Verify VerifiedBadge is rendered next to user name
    expect(find.text('Verified Creator'), findsOneWidget);

    // Tap comment button
    final commentBtn = find.byKey(const ValueKey('snippet-comment-snippet-comment-1'));
    expect(commentBtn, findsOneWidget);
    await tester.tap(commentBtn);
    await tester.pumpAndSettle();

    // Comments sheet should be open
    expect(find.byKey(const ValueKey('snippet-comments-sheet')), findsOneWidget);
    expect(find.text('NO COMMENTS YET'), findsOneWidget);

    // Enter comment text
    final inputFinder = find.byKey(const ValueKey('comment-input'));
    expect(inputFinder, findsOneWidget);
    await tester.enterText(inputFinder, 'Brilliant point made here!');
    await tester.pumpAndSettle();

    // Send comment
    final sendBtn = find.byKey(const ValueKey('comment-send-btn'));
    await tester.tap(sendBtn);
    await tester.pumpAndSettle();

    // Comment should now be visible in list
    expect(find.text('Brilliant point made here!'), findsOneWidget);

    // Close sheet
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Snippet card comments count should now be 1
    expect(controller.commentsCountFor('snippet-comment-1'), 1);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
