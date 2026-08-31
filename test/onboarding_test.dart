import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/data/profile/user_profile_store.dart';
import 'package:radio_over/models/user_profile.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/onboarding_screen.dart';
import 'package:radio_over/screens/user_profile_screen.dart';
import 'package:radio_over/data/content_scope.dart';

void main() {
  group('UserProfile Model & Store Tests', () {
    test('UserProfile toJson and fromJson serialization works', () {
      const profile = UserProfile(
        username: 'Emmett',
        bio: 'Hello World',
        interests: ['Tech', 'Talk'],
        isPremium: true,
        hasCompletedOnboarding: true,
      );

      final json = profile.toJson();
      final decoded = UserProfile.fromJson(json);

      expect(decoded.username, 'Emmett');
      expect(decoded.bio, 'Hello World');
      expect(decoded.interests, containsAll(['Tech', 'Talk']));
      expect(decoded.isPremium, isTrue);
      expect(decoded.hasCompletedOnboarding, isTrue);
    });

    test('InMemoryUserProfileStore load and save profile', () async {
      final store = InMemoryUserProfileStore();
      var profile = await store.loadProfile();
      expect(profile.hasCompletedOnboarding, isFalse);

      await store.saveProfile(const UserProfile(username: 'Connie', hasCompletedOnboarding: true));
      profile = await store.loadProfile();
      expect(profile.username, 'Connie');
      expect(profile.hasCompletedOnboarding, isTrue);
    });
  });

  group('PlaybackController User Profile Integration', () {
    test('PlaybackController updates user profile and notifies listeners', () async {
      final store = InMemoryUserProfileStore();
      final controller = PlaybackController(profileStore: store);

      // Settle initial load
      await Future<void>.delayed(Duration.zero);

      expect(controller.username, '');
      expect(controller.hasCompletedOnboarding, isFalse);

      bool notified = false;
      controller.addListener(() => notified = true);

      await controller.updateUserProfile('TestName', 'TestBio', ['Tech']);
      expect(controller.username, 'TestName');
      expect(controller.bio, 'TestBio');
      expect(controller.interests, contains('Tech'));
      expect(notified, isTrue);

      notified = false;
      await controller.completeOnboarding();
      expect(controller.hasCompletedOnboarding, isTrue);
      expect(notified, isTrue);

      controller.dispose();
    });
  });

  group('OnboardingScreen Widget Tests', () {
    late PlaybackController controller;

    setUp(() {
      controller = PlaybackController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('Guides user through onboarding flow and completes sign up', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(controller: controller),
        ),
      );

      // Slide 1: Welcome Screen
      expect(find.text('INDEPENDENT\nAUDIO NETWORK.'), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-next')), findsOneWidget);

      // Tap Next to go to Slide 2: Interests
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();

      expect(find.text('WHAT INTERESTS\nYOU?'), findsOneWidget);

      // Tap a genre chip
      final techChip = find.byKey(const ValueKey('interest-chip-Tech'));
      expect(techChip, findsOneWidget);
      await tester.tap(techChip);
      await tester.pump();

      // Tap Next to go to Slide 3: Profile Settings
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();

      expect(find.text('SET UP YOUR\nPROFILE.'), findsOneWidget);

      // Input nickname and bio
      final nameInput = find.byKey(const ValueKey('onboarding-name-input'));
      final bioInput = find.byKey(const ValueKey('onboarding-bio-input'));
      expect(nameInput, findsOneWidget);
      expect(bioInput, findsOneWidget);

      await tester.enterText(nameInput, 'Alex');
      await tester.enterText(bioInput, 'Avid Listener');
      await tester.pump();

      // Tap Complete Sign Up
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();

      // Controller should be updated
      expect(controller.username, 'Alex');
      expect(controller.bio, 'Avid Listener');
      expect(controller.interests, contains('Tech'));
      expect(controller.hasCompletedOnboarding, isTrue);

      // Unmount the widget tree to avoid timer issues
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('UserProfileScreen Dynamic and Edit profile tests', () {
    late AppContent content;
    late PlaybackController controller;

    setUp(() {
      content = AppContent.mock();
      controller = PlaybackController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('UserProfileScreen renders dynamic data, edits profile, and handles premium', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Set initial profile state
      await controller.updateUserProfile('Sam', 'Podcast Lover', ['Music']);
      await controller.completeOnboarding();

      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(
            controller: controller,
            content: content,
          ),
        ),
      );

      // Ensure dynamic details are rendered
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Podcast Lover'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);

      // Tap edit avatar button
      final editBtn = find.byKey(const ValueKey('profile-edit-avatar-button'));
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Verify Edit Profile dialog components
      expect(find.text('EDIT PROFILE'), findsOneWidget);
      final editNameInput = find.byKey(const ValueKey('edit-profile-name-input'));
      final editBioInput = find.byKey(const ValueKey('edit-profile-bio-input'));
      final talkChip = find.byKey(const ValueKey('edit-interest-chip-Talk'));

      await tester.enterText(editNameInput, 'Samantha');
      await tester.enterText(editBioInput, 'Podcast Fanatic');
      await tester.tap(talkChip);
      await tester.pump();

      // Save changes
      final saveBtn = find.byKey(const ValueKey('save-profile-edit'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify controller and screen details updated
      expect(controller.username, 'Samantha');
      expect(controller.bio, 'Podcast Fanatic');
      expect(controller.interests, containsAll(['Music', 'Talk']));
      expect(find.text('Samantha'), findsOneWidget);
      expect(find.text('Podcast Fanatic'), findsOneWidget);

      // Test Premium upgrade updates state in controller
      expect(controller.isPremium, isFalse);
      final upgradeBtn = find.byKey(const ValueKey('profile-upgrade-button'));
      await tester.tap(upgradeBtn);
      await tester.pumpAndSettle();

      final confirmBtn = find.byKey(const ValueKey('confirm-upgrade-button'));
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(controller.isPremium, isTrue);
      expect(find.text('PREMIUM SUBSCRIBER'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
