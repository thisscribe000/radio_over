import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/content_scope.dart';
import '../models/playback.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';
import '../widgets/podcast_art.dart';
import '../widgets/podcast_mini_player.dart';
import '../widgets/radio_mini_player.dart';
import 'creator_profile_screen.dart';
import 'settings_screen.dart';

/// Renders the user profile card, styled to match the clean, tabular mockup (Image 1).
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.controller,
    required this.content,
  });

  final PlaybackController controller;
  final AppContent content;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  int _activeTab = 0; // 0 = About, 1 = Timeline
  String? _dismissedRadio;
  String? _dismissedPodcast;

  PlaybackController get controller => widget.controller;

  void _showEditProfileDialog() {
    final colors = AppColors.of(context);
    final nameController = TextEditingController(text: controller.username);
    final bioController = TextEditingController(text: controller.bio);
    final selectedInterests = Set<String>.from(controller.interests);
    final availableInterests = const [
      'Tech',
      'Talk',
      'Design',
      'Comedy',
      'Music',
      'News',
      'Sports',
      'Art',
      'Business',
      'Education',
      'Science',
      'History',
    ];

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.background,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: colors.ink),
              ),
              title: Text(
                'EDIT PROFILE',
                style: TextStyle(
                  fontFamily: 'Ahem',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.ink,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NICKNAME', style: TextStyle(fontSize: 10, color: colors.muted, fontWeight: FontWeight.bold)),
                    TextField(
                      key: const ValueKey('edit-profile-name-input'),
                      controller: nameController,
                      cursorColor: colors.ink,
                      style: TextStyle(
                        fontFamily: 'Ahem',
                        fontSize: 14,
                        color: colors.ink,
                      ),
                      decoration: InputDecoration(
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.ink)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('BIO', style: TextStyle(fontSize: 10, color: colors.muted, fontWeight: FontWeight.bold)),
                    TextField(
                      key: const ValueKey('edit-profile-bio-input'),
                      controller: bioController,
                      cursorColor: colors.ink,
                      maxLines: 2,
                      style: TextStyle(fontSize: 12, color: colors.ink),
                      decoration: InputDecoration(
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.ink)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('INTERESTS', style: TextStyle(fontSize: 10, color: colors.muted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: availableInterests.map((interest) {
                        final isSel = selectedInterests.contains(interest);
                        return GestureDetector(
                          key: ValueKey('edit-interest-chip-$interest'),
                          onTap: () {
                            setDialogState(() {
                              if (isSel) {
                                selectedInterests.remove(interest);
                              } else {
                                selectedInterests.add(interest);
                              }
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSel ? colors.podcastAccent.withValues(alpha: 0.1) : Colors.transparent,
                              border: Border.all(color: isSel ? colors.podcastAccent : colors.hairline),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              interest.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? colors.podcastAccent : colors.ink,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('CANCEL', style: TextStyle(color: colors.muted)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  key: const ValueKey('save-profile-edit'),
                  child: Text(
                    'SAVE',
                    style: TextStyle(color: colors.podcastAccent, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    controller.updateUserProfile(
                      nameController.text.trim(),
                      bioController.text.trim(),
                      selectedInterests.toList(),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

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

  void _showUpgradeDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
    final colors = AppColors.of(context);
        return AlertDialog(
          backgroundColor: colors.background,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colors.ink),
          ),
          title: Text(
            'UPGRADE TO PREMIUM',
            style: TextStyle(
              fontFamily: 'Ahem',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.ink,
            ),
          ),
          content: const Text(
            'Unlock direct audio hosting and premium creator features under the Radio Over Creator Portal. Supporting independent podcasters directly.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              child: Text(
                'CANCEL',
                style: TextStyle(color: colors.muted),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              key: const ValueKey('confirm-upgrade-button'),
              child: Text(
                'CONFIRM UPGRADE',
                style: TextStyle(
                  color: colors.podcastAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                final colors = AppColors.of(context);
                controller.setPremium(true);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Welcome to Radio Over Premium!'),
                    backgroundColor: colors.ink,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _openCreatorProfile(String name) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatorProfileScreen(
          creatorName: name,
          controller: controller,
          content: widget.content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final int minutes = controller.totalPodcastListeningTime.inMinutes;
    final int followedCount = controller.followedCreators.length;
    final int savedShowsCount = controller.savedShows.length;
    final int savedEpisodesCount = controller.savedEpisodes.length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Navigation Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('profile-back'),
                    icon: Icon(Icons.arrow_back, color: colors.ink),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                   // Notification icon with badge
                  Stack(
                    children: [
                      IconButton(
                        key: const ValueKey('profile-notifications-btn'),
                        icon: Icon(Icons.notifications_none_outlined, color: colors.ink),
                        onPressed: _onNotificationsTap,
                      ),
                      if (controller.unseenEpisodes.isNotEmpty)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors.podcastAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    key: const ValueKey('profile-share-btn'),
                    icon: Icon(Icons.ios_share_outlined, color: colors.ink),
                    onPressed: _shareProfile,
                  ),
                   IconButton(
                    key: const ValueKey('profile-settings'),
                    icon: Icon(Icons.settings_outlined, color: colors.ink),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SettingsScreen(
                            controller: controller,
                            content: widget.content,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Profile Body
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                      children: [

                        const SizedBox(
                          width: 0,
                          height: 0,
                          child: Text('LISTENING PROFILE'),
                        ),
                        // Avatar Photo with edit overlay
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Stack(
                            children: [
                              PodcastArt(
                                title: controller.username.isEmpty ? 'User' : controller.username,
                                size: 84,
                                showInitials: true,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  key: const ValueKey('profile-edit-avatar-button'),
                                  onTap: _showEditProfileDialog,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: colors.background,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: colors.hairline),
                                    ),
                                    child: Icon(Icons.edit_outlined, size: 14, color: colors.ink),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Name & Badges
                        Row(
                          children: [
                            Text(
                              controller.username.isEmpty ? 'Connie' : controller.username,
                              style: TextStyle(
                                fontFamily: 'Ahem',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: colors.ink,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.forest, size: 18, color: colors.podcastAccent.withValues(alpha: 0.75)),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Membership Tier
                        Text(
                          controller.isPremium ? 'PREMIUM SUBSCRIBER' : 'FREE TIER MEMBER',
                          style: TextStyle(
                            fontFamily: 'Ahem',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.podcastAccent,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Interest Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: controller.interests.isEmpty
                              ? [_buildInterestChip('Tech'), _buildInterestChip('Talk')]
                              : controller.interests.map((i) => _buildInterestChip(i)).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Bio Quote
                        Text(
                          controller.bio.isEmpty
                              ? "Calling me 'sir' is like putting an elevator in an outhouse, it don't belong. I'm Emmett"
                              : controller.bio,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: colors.muted,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Followers and Following row
                        Row(
                          children: [
                            _buildFollowCounter('Followers', '0'),
                            const SizedBox(width: 32),
                            _buildFollowCounter('Following', '$followedCount'),
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.search, color: colors.ink),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // About vs. Timeline Tabs switcher
                        Container(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: colors.hairline)),
                          ),
                          child: Row(
                            children: [
                              _buildTabItem(0, 'About'),
                              _buildTabItem(1, 'Timeline'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Render Tab View content
                        if (_activeTab == 0) ...[
                          // About Tab Content (Stats Cards Grid & Premium Upgrade)
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 1.4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            children: [
                              _buildStatCard('Saved Shows', '$savedShowsCount', Icons.percent),
                              _buildStatCard('Saved Episodes', '$savedEpisodesCount', Icons.spa_outlined),
                              _buildStatCard('Minutes Listened', '$minutes', Icons.outlined_flag),
                              _buildStatCard('Premium', controller.isPremium ? 'Active' : 'Free', Icons.auto_awesome_outlined),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Premium Upgrade Box (if not upgraded yet)
                          if (!controller.isPremium) ...[
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: colors.hairline),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'UPGRADE YOUR PLATFORM',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: colors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Unlock direct hosting for independent podcasters and exclusive audio feeds under the creator portal.',
                                    style: TextStyle(fontSize: 12, color: colors.muted),
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    key: const ValueKey('profile-upgrade-button'),
                                    onTap: _showUpgradeDialog,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: colors.ink),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      child: const Text(
                                        'UPGRADE FOR \$4.99/MO',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                          ],

                          // Collections (Followed Creators list)
                          Row(
                            children: [
                              const Text('Collections', style: AppTextStyles.sectionLabel),
                              const Spacer(),
                              Icon(Icons.chevron_right, size: 18, color: colors.podcastAccent.withValues(alpha: 0.75)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (controller.followedCreators.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No collections created yet.',
                                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: colors.muted),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: controller.followedCreators.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: colors.hairline),
                              itemBuilder: (context, index) {
                                final String creator =
                                    controller.followedCreators.elementAt(index);
                                return ListTile(
                                  key: ValueKey('profile-creator-$creator'),
                                  contentPadding: EdgeInsets.zero,
                                  leading: PodcastArt(title: creator, size: 40),
                                  title: Text(
                                    creator,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, size: 16),
                                  onTap: () => _openCreatorProfile(creator),
                                );
                              },
                            ),
                        ] else ...[
                          // Timeline Tab Content (Listening History)
                          const Text('TIMELINE FEED', style: AppTextStyles.sectionLabel),
                          const SizedBox(height: 12),
                          if (controller.listeningHistory.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No timeline items recorded.',
                                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: colors.muted),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: controller.listeningHistory.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: colors.hairline),
                              itemBuilder: (context, index) {
                                final item = controller.listeningHistory[index];
                                final isRadio = item.contentType == HistoryContentType.radio;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    isRadio ? 'Listened to Radio Broadcast' : 'Played Podcast episode',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    'ID: ${item.contentId} · ${item.listenedAt.hour}:${item.listenedAt.minute}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: Icon(
                                    isRadio ? Icons.radio : Icons.play_arrow,
                                    size: 16,
                                    color: colors.muted,
                                  ),
                                );
                              },
                            ),
                        ],
                      ],
                    ),
                  ),

                  // Mini Players
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (controller.radioActive &&
                            controller.currentStation != null &&
                            _dismissedRadio != controller.currentStation!.name)
                          RadioMiniPlayer(
                            controller: controller,
                            onDismiss: () => setState(() =>
                                _dismissedRadio = controller.currentStation!.name),
                          ),
                        if (controller.podcastActive &&
                            controller.currentEpisode != null &&
                            _dismissedPodcast != controller.currentEpisode!.title)
                          PodcastMiniPlayer(
                            controller: controller,
                            onDismiss: () => setState(() =>
                                _dismissedPodcast = controller.currentEpisode!.title),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestChip(String label) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.hairline),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildFollowCounter(String label, String count) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: colors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          count,
          style: const TextStyle(
            fontFamily: 'Ahem',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTabItem(int index, String label) {
    final colors = AppColors.of(context);
    final bool active = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? colors.ink : Colors.transparent,
                width: 2.0,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? colors.ink : colors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.hairline),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: colors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 14, color: colors.muted),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Ahem',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: colors.ink,
            ),
          ),
        ],
      ),
    );
  }

  void _onNotificationsTap() {
    final colors = AppColors.of(context);
    final count = controller.unseenEpisodes.length;
    ScaffoldMessenger.of(context).clearSnackBars();
    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have $count new podcast episode${count > 1 ? 's' : ''} available!'),
          backgroundColor: colors.podcastAccent,
          action: SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.white,
            onPressed: () {
              controller.clearAllUnseenEpisodes();
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No new notifications.'),
          backgroundColor: colors.ink,
        ),
      );
    }
  }

  void _shareProfile() {
    final String text = 'Check out my profile on Radio Over!\nUsername: ${controller.username}\nBio: ${controller.bio}';
    try {
      SharePlus.instance.share(
        ShareParams(text: text, subject: 'Radio Over Profile'),
      );
    } catch (_) {
      // Sharing unavailable.
    }
  }
}
