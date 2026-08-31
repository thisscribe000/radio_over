import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/data/content_scope.dart';
import 'package:radio_over/data/podcasts/mock_podcast_directory_repository.dart';
import 'package:radio_over/data/podcasts/mock_podcast_feed_repository.dart';
import 'package:radio_over/data/podcasts/podcast_catalogue_store.dart';
import 'package:radio_over/data/radio/mock_radio_repository.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/settings_screen.dart';

void main() {
  group('SettingsScreen Tests', () {
    late PlaybackController controller;
    late AppContent content;

    setUp(() {
      controller = PlaybackController();
      content = AppContent(
        radio: const MockRadioRepository(),
        podcastDirectory: const MockPodcastDirectoryRepository(),
        podcastFeeds: const MockPodcastFeedRepository(),
        catalogueStore: InMemoryPodcastCatalogueStore(),
        savedShowsProvider: () => {},
      );
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders all options and toggles theme modes successfully', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            controller: controller,
            content: content,
          ),
        ),
      );

      // Verify page title
      expect(find.text('SETTINGS'), findsOneWidget);

      // Verify sections
      expect(find.text('THEME SELECTION'), findsOneWidget);
      expect(find.text('STREAMING QUALITY'), findsOneWidget);
      expect(find.text('CACHE MANAGEMENT'), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);

      // Default theme is system
      expect(controller.themeMode, ThemeMode.system);

      // Tap Light Mode option
      final lightOption = find.byKey(const ValueKey('settings-theme-light'));
      expect(lightOption, findsOneWidget);
      await tester.tap(lightOption);
      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.light);

      // Tap Dark Mode option
      final darkOption = find.byKey(const ValueKey('settings-theme-dark'));
      expect(darkOption, findsOneWidget);
      await tester.tap(darkOption);
      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.dark);

      // Tap System Mode option
      final systemOption = find.byKey(const ValueKey('settings-theme-system'));
      expect(systemOption, findsOneWidget);
      await tester.tap(systemOption);
      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.system);
    });

    testWidgets('toggles settings preferences and triggers legal sheets', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            controller: controller,
            content: content,
          ),
        ),
      );

      // Verify default state values
      expect(controller.highQualityAudio, isTrue);
      expect(controller.enableNotifications, isFalse);
      expect(controller.newEpisodeAlerts, isFalse);

      // Toggle high quality audio switch
      final highQualityToggle = find.byKey(const ValueKey('settings-toggle-high-quality'));
      expect(highQualityToggle, findsOneWidget);
      await tester.tap(highQualityToggle);
      await tester.pumpAndSettle();
      expect(controller.highQualityAudio, isFalse);

      // Toggle notifications
      final notificationsToggle = find.byKey(const ValueKey('settings-toggle-notifications'));
      expect(notificationsToggle, findsOneWidget);
      await tester.tap(notificationsToggle);
      await tester.pumpAndSettle();
      expect(controller.enableNotifications, isTrue);

      // Toggle alerts
      final alertsToggle = find.byKey(const ValueKey('settings-toggle-alerts'));
      expect(alertsToggle, findsOneWidget);
      await tester.tap(alertsToggle);
      await tester.pumpAndSettle();
      expect(controller.newEpisodeAlerts, isTrue);

      // Tap Terms of Service and verify dialog opens
      final termsBtn = find.byKey(const ValueKey('settings-terms'));
      await tester.scrollUntilVisible(termsBtn, 100.0);
      expect(termsBtn, findsOneWidget);
      await tester.tap(termsBtn);
      await tester.pumpAndSettle();
      expect(find.text('TERMS OF SERVICE'), findsOneWidget);

      // Dismiss terms dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('TERMS OF SERVICE'), findsNothing);

      // Tap Privacy Policy and verify dialog opens
      final privacyBtn = find.byKey(const ValueKey('settings-privacy'));
      await tester.scrollUntilVisible(privacyBtn, 100.0);
      expect(privacyBtn, findsOneWidget);
      await tester.tap(privacyBtn);
      await tester.pumpAndSettle();
      expect(find.text('PRIVACY POLICY'), findsOneWidget);
    });
  });
}
