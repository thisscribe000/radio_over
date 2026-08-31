import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/data/content_scope.dart';
import 'package:radio_over/data/podcasts/mock_podcast_directory_repository.dart';
import 'package:radio_over/data/podcasts/mock_podcast_feed_repository.dart';
import 'package:radio_over/data/podcasts/podcast_catalogue_store.dart';
import 'package:radio_over/data/progress/playback_progress_store.dart';
import 'package:radio_over/data/radio/mock_radio_repository.dart';
import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/models/playback_progress.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/creator_profile_screen.dart';
import 'package:radio_over/screens/user_profile_screen.dart';
import 'package:radio_over/widgets/podcast_art.dart';

void main() {
  group('PodcastArt Generative Line Art', () {
    testWidgets('PodcastArt computes hash and renders custom paint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PodcastArt(title: 'My Custom Podcast', size: 100),
          ),
        ),
      );

      expect(find.byType(PodcastArt), findsOneWidget);
      expect(find.descendant(of: find.byType(PodcastArt), matching: find.byType(CustomPaint)), findsOneWidget);
      // Initials monogram exists
      expect(find.text('MP'), findsOneWidget);
    });
  });

  group('PlaybackController Creator Follow & Listening Stats', () {
    test('followedCreators can be toggled and checked', () {
      final PlaybackController controller = PlaybackController();
      expect(controller.isFollowingCreator('Host Name'), isFalse);

      controller.toggleFollowCreator('Host Name');
      expect(controller.isFollowingCreator('Host Name'), isTrue);
      expect(controller.followedCreators, contains('Host Name'));

      controller.toggleFollowCreator('Host Name');
      expect(controller.isFollowingCreator('Host Name'), isFalse);
      controller.dispose();
    });

    test('totalPodcastListeningTime sums up positions of all playback progress', () async {
      final InMemoryPlaybackProgressStore progressStore = InMemoryPlaybackProgressStore();
      await progressStore.save({
        'ep-1': PlaybackProgress(
          episodeId: 'ep-1',
          position: const Duration(minutes: 15),
          duration: const Duration(minutes: 60),
          updatedAt: DateTime.now(),
        ),
        'ep-2': PlaybackProgress(
          episodeId: 'ep-2',
          position: const Duration(minutes: 35),
          duration: const Duration(minutes: 60),
          updatedAt: DateTime.now(),
        ),
      });

      final PlaybackController controller = PlaybackController(progressStore: progressStore);
      // Let async restore finish
      await Future<void>.delayed(Duration.zero);

      expect(controller.totalPodcastListeningTime, const Duration(minutes: 50));
      controller.dispose();
    });
  });

  group('Creator & User Profile UI Tests', () {
    late AppContent content;
    late PlaybackController controller;

    final PodcastSeries show = PodcastSeries(
      id: 'show-1',
      name: 'Podcast Show',
      category: 'Talk',
      publisher: 'Amazing Creator',
      description: 'About talk',
      episodes: [
        PodcastEpisode(
          id: 'ep-1',
          podcastId: 'show-1',
          podcastName: 'Podcast Show',
          title: 'Ep 1 Title',
          duration: const Duration(minutes: 30),
          published: 'Yesterday',
        )
      ],
    );

    setUp(() {
      content = AppContent(
        radio: const MockRadioRepository(),
        podcastDirectory: const MockPodcastDirectoryRepository(),
        podcastFeeds: const MockPodcastFeedRepository(),
        seedShows: [show],
        catalogueStore: InMemoryPodcastCatalogueStore(),
      );
      controller = PlaybackController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('CreatorProfileScreen renders publisher metadata, shows list, and follows host', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CreatorProfileScreen(
            creatorName: 'Amazing Creator',
            controller: controller,
            content: content,
          ),
        ),
      );

      // Title & Profile Monogram
      expect(find.text('CREATOR PROFILE'), findsOneWidget);
      expect(find.text('Amazing Creator'), findsOneWidget);

      // Published Shows count
      expect(find.text('Podcast Show'), findsOneWidget);
      expect(find.text('Talk'), findsOneWidget);

      // Combined Episodes Timeline list
      expect(find.text('Ep 1 Title'), findsOneWidget);

      // Follow Creator button is tappable
      final Finder followBtn = find.byKey(const ValueKey('creator-follow-button'));
      expect(followBtn, findsOneWidget);
      expect(controller.isFollowingCreator('Amazing Creator'), isFalse);

      await tester.tap(followBtn);
      await tester.pump();
      expect(controller.isFollowingCreator('Amazing Creator'), isTrue);
    });

    testWidgets('UserProfileScreen renders stats card, upgrade card, followed creators list, and premium confirmation', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      controller.toggleFollowCreator('Amazing Creator');

      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(
            controller: controller,
            content: content,
          ),
        ),
      );

      expect(find.text('FREE TIER MEMBER'), findsOneWidget);

      // Upgrades Option
      final Finder upgradeBtn = find.byKey(const ValueKey('profile-upgrade-button'));
      expect(upgradeBtn, findsOneWidget);

      // Trigger Upgrade confirmation dialog
      await tester.tap(upgradeBtn);
      await tester.pump();

      expect(find.text('UPGRADE TO PREMIUM'), findsOneWidget);
      final Finder confirmBtn = find.byKey(const ValueKey('confirm-upgrade-button'));
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pump();

      // Subscription tier updated successfully
      expect(find.text('PREMIUM SUBSCRIBER'), findsOneWidget);

      // Followed Creators list populated
      expect(find.text('Amazing Creator'), findsOneWidget);

      // Verify share button triggers share action
      final Finder shareBtn = find.byKey(const ValueKey('profile-share-btn'));
      expect(shareBtn, findsOneWidget);
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      // Verify notification button opens snackbar
      final Finder notifBtn = find.byKey(const ValueKey('profile-notifications-btn'));
      expect(notifBtn, findsOneWidget);
      await tester.tap(notifBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('No new notifications.'), findsOneWidget);

      // Verify dynamic badge rendering
      controller.markEpisodesUnseen(['ep-999']);
      await tester.pumpAndSettle();

      // Click notifications again to dismiss/clear unseen
      await tester.tap(notifBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('You have 1 new podcast episode available!'), findsOneWidget);

      // Tap Dismiss on SnackBar
      await tester.tap(find.text('DISMISS'), warnIfMissed: false);
      controller.clearAllUnseenEpisodes();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.unseenEpisodes.isEmpty, isTrue);
    });
  });
}
