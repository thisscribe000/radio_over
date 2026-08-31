import 'package:flutter/material.dart';

import '../data/content_scope.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';

/// Clean Settings page allowing users to switch themes, configure streaming quality,
/// manage cache, and view app information.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.content,
  });

  final PlaybackController controller;
  final AppContent content;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PlaybackController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _clearHistory() {
    final colors = AppColors.of(context);
    controller.clearListeningHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Listening history cleared.'),
        backgroundColor: colors.ink,
      ),
    );
  }

  void _clearCache() {
    final colors = AppColors.of(context);
    // Clear all saved shows and episodes from the controller
    final List<String> savedShows = List.from(controller.savedShows);
    final List<String> savedEpisodes = List.from(controller.savedEpisodes);

    for (final id in savedShows) {
      controller.toggleSavedShow(id);
    }
    for (final id in savedEpisodes) {
      controller.toggleSavedEpisode(id);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved shows and episodes cleared.'),
        backgroundColor: colors.ink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ThemeMode activeMode = controller.themeMode;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('settings-back'),
          icon: Icon(Icons.arrow_back, color: colors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'SETTINGS',
          style: TextStyle(
            fontFamily: 'Ahem',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: colors.ink,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: colors.hairline,
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                children: [
                  // --- Theme Selection ---
                  const Text('THEME SELECTION', style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 10),
                  _buildThemeOption(ThemeMode.system, 'System default', activeMode),
                  _buildThemeOption(ThemeMode.light, 'Light mode', activeMode),
                  _buildThemeOption(ThemeMode.dark, 'Dark mode', activeMode),
                  const SizedBox(height: 28),

                   // --- Audio Settings ---
                  const Text('STREAMING QUALITY', style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    key: const ValueKey('settings-toggle-high-quality'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'High Quality Audio',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.ink),
                    ),
                    subtitle: Text(
                      'Prefer high bitrate streams when available (uses more data).',
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                    value: controller.highQualityAudio,
                    activeTrackColor: colors.podcastAccent,
                    onChanged: (val) => controller.setHighQualityAudio(val),
                  ),
                  const SizedBox(height: 28),

                  // --- Push Notifications ---
                  const Text('PUSH NOTIFICATIONS', style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    key: const ValueKey('settings-toggle-notifications'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Enable Notifications',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.ink),
                    ),
                    subtitle: Text(
                      'Get notified about app updates and features.',
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                    value: controller.enableNotifications,
                    activeTrackColor: colors.podcastAccent,
                    onChanged: (val) => controller.setEnableNotifications(val),
                  ),
                  Divider(color: colors.hairline),
                  SwitchListTile.adaptive(
                    key: const ValueKey('settings-toggle-alerts'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'New Episode Alerts',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.ink),
                    ),
                    subtitle: Text(
                      'Receive alerts when shows you follow release new episodes.',
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                    value: controller.newEpisodeAlerts,
                    activeTrackColor: colors.podcastAccent,
                    onChanged: (val) => controller.setNewEpisodeAlerts(val),
                  ),
                  const SizedBox(height: 28),

                  // --- Cache Management ---
                  const Text('CACHE MANAGEMENT', style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Clear Listening History',
                      style: TextStyle(fontSize: 14, color: colors.ink),
                    ),
                    subtitle: Text(
                      'Clears history of all recently played tracks.',
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                    trailing: Icon(Icons.delete_outline, size: 20, color: colors.muted),
                    onTap: _clearHistory,
                  ),
                  Divider(color: colors.hairline),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Clear Saved Content',
                      style: TextStyle(fontSize: 14, color: colors.ink),
                    ),
                    subtitle: Text(
                      'Un-saves all bookmarked shows and episodes.',
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                    trailing: Icon(Icons.delete_outline, size: 20, color: colors.muted),
                    onTap: _clearCache,
                  ),
                  const SizedBox(height: 28),

                  // --- About App ---
                  const Text('ABOUT', style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'App Version',
                      style: TextStyle(fontSize: 14, color: colors.ink),
                    ),
                    trailing: Text(
                      '1.0.0',
                      style: TextStyle(fontSize: 14, color: colors.muted, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Divider(color: colors.hairline),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Open Source Licenses',
                      style: TextStyle(fontSize: 14, color: colors.ink),
                    ),
                    trailing: Icon(Icons.chevron_right, size: 20, color: colors.muted),
                    onTap: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'Radio Over',
                        applicationVersion: '1.0.0',
                      );
                    },
                  ),
                  Divider(color: colors.hairline),
                  ListTile(
                    key: const ValueKey('settings-terms'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Terms of Service',
                      style: TextStyle(fontSize: 14, color: colors.ink),
                    ),
                    trailing: Icon(Icons.chevron_right, size: 20, color: colors.muted),
                    onTap: _showTermsDialog,
                  ),
                  Divider(color: colors.hairline),
                  ListTile(
                    key: const ValueKey('settings-privacy'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Privacy Policy',
                      style: TextStyle(fontSize: 14, color: colors.ink),
                    ),
                    trailing: Icon(Icons.chevron_right, size: 20, color: colors.muted),
                    onTap: _showPrivacyDialog,
                  ),
                ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(ThemeMode mode, String label, ThemeMode activeMode) {
    final colors = AppColors.of(context);
    final bool isSelected = activeMode == mode;
    final String keySuffix = mode == ThemeMode.system
        ? 'system'
        : mode == ThemeMode.light
            ? 'light'
            : 'dark';

    return ListTile(
      key: ValueKey('settings-theme-$keySuffix'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: colors.ink,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: colors.podcastAccent)
          : null,
      onTap: () => controller.setThemeMode(mode),
    );
  }

  void _showTermsDialog() {
    _showLegalSheet(
      title: 'TERMS OF SERVICE',
      text: _termsOfServiceText,
    );
  }

  void _showPrivacyDialog() {
    _showLegalSheet(
      title: 'PRIVACY POLICY',
      text: _privacyPolicyText,
    );
  }

  void _showLegalSheet({required String title, required String text}) {
    final colors = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.background,
      shape: const RoundedRectangleBorder(),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Ahem',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: colors.ink,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.ink),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: colors.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const String _termsOfServiceText = '''
Welcome to Radio Over. By using our application, you agree to these Terms of Service.

1. Acceptance of Terms
By accessing or using Radio Over, you agree to be bound by these terms. If you do not agree, do not use the app.

2. Description of Service
Radio Over provides a platform for streaming internet radio and podcast content. We do not guarantee the availability or accuracy of third-party audio feeds or directory data.

3. Account & Registration
When you sign up using Firebase Authentication or Google Sign-In, you agree to provide accurate information. You are responsible for keeping your credentials secure.

4. Intellectual Property
All content, trademarks, and design systems of Radio Over are owned by us or our licensors. You may not copy, reverse engineer, or reproduce any part of the app.

5. Termination
We reserve the right to terminate or restrict your access to the service at our sole discretion, without notice, for any violation of these terms.

6. Changes to Terms
We may modify these terms at any time. Your continued use of the app after modifications constitutes acceptance of the updated terms.
''';

  static const String _privacyPolicyText = '''
Your privacy is important to us. This Privacy Policy describes how we collect, use, and protect your information.

1. Information We Collect
- Profile Data: When you onboard, we collect your nickname, bio, selected interests, and premium subscription status.
- Auth Credentials: If you sign up using Email/Password or Google Sign-in, we use Firebase Authentication to securely store your sign-in details.
- Usage Data: We track listening history and saved shows/episodes locally on your device to enable playback features.

2. How We Use Information
We use your data to personalize your onboarding interest feed, sync your profile details across devices via Cloud Firestore, and store offline downloads.

3. Data Sharing
We do not sell, rent, or trade your personal data. We only share data with Firebase Services to perform authentication and database functions.

4. Data Retention
Your data is stored securely in Firebase and local device storage. You can delete your account and clear cache/history directly from the settings page.

5. Security
We implement industry-standard security measures (SSL, secure database rules) to protect your information from unauthorized access.
''';
}
