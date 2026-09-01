import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/content_scope.dart';
import '../models/podcast_episode.dart';
import '../models/station.dart';
import '../playback/playback_controller.dart';
import '../screens/radio_player_screen.dart';
import '../theme.dart';
import '../widgets/live_badge.dart';
import '../widgets/podcast_mini_player.dart';
import '../widgets/radio_mini_player.dart';

/// The Radio Station Detail screen — the live sibling of Podcast Detail.
///
/// Where Podcast Detail answers "what can I play?", this page answers "what is
/// happening on this station right now?": a calm identity header, one primary
/// LISTEN LIVE action, NOW PLAYING / UP NEXT / SCHEDULE, then ABOUT and related
/// stations. The actual listening experience stays in the existing
/// [RadioPlayerScreen]; this screen only hands over to it.
///
/// Saved state is not local: favourites live on the shared
/// [PlaybackController], so SAVE here is instantly reflected on the radio
/// home and vice-versa.
class StationDetailScreen extends StatefulWidget {
  const StationDetailScreen({
    super.key,
    required this.station,
    required this.controller,
    this.content,
  });

  final RadioStation station;
  final PlaybackController controller;

  /// Content source; defaults to the offline mock scope when not provided.
  final AppContent? content;

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  late final AppContent _content = widget.content ?? AppContent.mock();
  String _day = 'TODAY';
  String? _dismissedEpisode;
  String? _dismissedRadio;

  PlaybackController get controller => widget.controller;
  RadioStation get station => widget.station;

  static const List<String> _days = ['TODAY', 'FRI', 'SAT', 'SUN'];

  @override
  void initState() {
    super.initState();
    controller.addListener(_syncDismissal);
  }

  @override
  void dispose() {
    controller.removeListener(_syncDismissal);
    super.dispose();
  }

  void _syncDismissal() {
    final PodcastEpisode? episode = controller.currentEpisode;
    if (controller.podcastActive && episode != null && episode.id != _dismissedEpisode) {
      _dismissedEpisode = null;
    }
    final RadioStation? active = controller.currentStation;
    if (controller.radioActive && active != null && active.stationId != _dismissedRadio) {
      _dismissedRadio = null;
    }
  }

  /// Starts (or switches to) the station and hands the listening experience to
  /// the existing Radio Player. When the station is already on air, the button
  /// reads PLAYING NOW and simply reopens the player.
  void _listenLive() {
    final RadioStation? active = controller.currentStation;
    if (active == null || active.stationId != station.stationId) {
      controller.playRadioStation(station);
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RadioPlayerScreen(controller: controller),
      ),
    );
  }

  void _openStation(RadioStation other) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StationDetailScreen(
          station: other,
          controller: controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: ListView(
                    key: const ValueKey('station-detail-list'),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildListen(),
                      const SizedBox(height: 24),
                      _buildFavourite(),
                      const SizedBox(height: 28),
                      _buildNowPlaying(),
                      const SizedBox(height: 28),
                      _buildUpNext(),
                      const SizedBox(height: 28),
                      _buildSchedule(),
                      const SizedBox(height: 28),
                      _buildAbout(),
                      if (_details.isNotEmpty) ...[const SizedBox(height: 28), _buildDetails()],
                      const SizedBox(height: 28),
                      _buildRelated(),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
                _buildMiniSlot(),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- Top ----------------------------------------------------------------

  void _shareStation() async {
    final st = station;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Listen live to ${st.name} (${st.location ?? "Live Radio"}) on radio_over!',
          subject: st.name,
        ),
      );
    } catch (_) {}
  }

  Widget _buildTopBar() {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('station-detail-back'),
            tooltip: 'Back',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, size: 22, color: colors.ink),
          ),
          Expanded(
            child: Center(
              child: Text('RADIO', style: AppTextStyles.navLabel),
            ),
          ),
          IconButton(
            key: const ValueKey('station-detail-share'),
            tooltip: 'Share',
            visualDensity: VisualDensity.compact,
            onPressed: _shareStation,
            icon: Icon(Icons.share_outlined, size: 18, color: colors.muted),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final String? location = station.location;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StationMonogram(name: station.name, size: 88),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LiveBadge(),
              const SizedBox(height: 12),
              Text(
                station.name.toUpperCase(),
                style: AppTextStyles.stationTitle,
              ),
              const SizedBox(height: 10),
              Text(
                station.category.toUpperCase(),
                style: AppTextStyles.sectionLabel,
              ),
              if (location != null) ...[
                const SizedBox(height: 4),
                Text(location, style: AppTextStyles.stationCategory),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // --- Primary actions ----------------------------------------------------

  Widget _buildListen() {
    final colors = AppColors.of(context);
    final bool playing = controller.radioActive &&
        controller.currentStation?.stationId == station.stationId &&
        controller.isPlaying;
    return GestureDetector(
      key: const ValueKey('detail-listen'),
      behavior: HitTestBehavior.opaque,
      onTap: _listenLive,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: playing ? colors.ink : colors.background,
          border: Border.all(color: playing ? colors.ink : colors.hairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              playing ? Icons.pause : Icons.play_arrow,
              size: 18,
              color: playing ? colors.background : colors.ink,
            ),
            const SizedBox(width: 10),
            Text(
              playing ? 'PLAYING NOW' : 'LISTEN LIVE',
              style: AppTextStyles.navLabel.copyWith(
                color: playing ? colors.background : colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavourite() {
    final colors = AppColors.of(context);
    final bool favourite = controller.isFavouriteStation(station.stationId);
    return GestureDetector(
      key: const ValueKey('detail-favourite'),
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          controller.toggleFavouriteStation(station.stationId, details: station),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: favourite ? colors.ink : colors.hairline,
          ),
        ),
        child: Text(
          favourite ? '♥ SAVED' : '♡ SAVE STATION',
          style: AppTextStyles.nowPlayingLabel.copyWith(
            color: favourite ? colors.ink : colors.muted,
          ),
        ),
      ),
    );
  }

  // --- Live now -----------------------------------------------------------

  Widget _buildNowPlaying() {
    final colors = AppColors.of(context);
    final RadioProgramme? current = station.currentProgramme;
    final String title = current?.title ?? station.program;
    final String? host = current?.host;
    final String times = current == null ? '' : '${current.start} – ${current.end}';

    return Column(
      key: const ValueKey('detail-now-playing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('NOW PLAYING', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            border: Border.all(color: colors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const LiveBadge(),
                  const Spacer(),
                  if (times.isNotEmpty) Text(times, style: AppTextStyles.timeLabel),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title.toUpperCase(),
                style: AppTextStyles.stationTitle.copyWith(fontSize: 20),
              ),
              if (host != null) ...[
                const SizedBox(height: 6),
                Text(host, style: AppTextStyles.stationProgramme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpNext() {
    final colors = AppColors.of(context);
    final RadioProgramme? next = station.nextProgramme;
    if (next == null) return const SizedBox.shrink();

    return Column(
      key: const ValueKey('detail-up-next'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('UP NEXT', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            border: Border.all(color: colors.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(next.title, style: AppTextStyles.playerProgram),
                    if (next.description != null) ...[
                      const SizedBox(height: 4),
                      Text(next.description!, style: AppTextStyles.stationCategory),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(next.start, style: AppTextStyles.nowPlayingLabel),
            ],
          ),
        ),
      ],
    );
  }

  // --- Schedule -----------------------------------------------------------

  Widget _buildSchedule() {
    final colors = AppColors.of(context);
    final List<RadioProgramme> programmes = [
      for (final RadioProgramme p in station.schedule)
        if (p.day == _day) p,
    ];

    return Column(
      key: const ValueKey('detail-schedule'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SCHEDULE', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final String day in _days)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  key: ValueKey('schedule-day-$day'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _day = day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _day == day ? colors.ink : colors.hairline,
                      ),
                    ),
                    child: Text(
                      day,
                      style: AppTextStyles.nowPlayingLabel.copyWith(
                        color: _day == day ? colors.ink : colors.muted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (programmes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nothing scheduled for this day yet.',
              style: AppTextStyles.stationCategory,
            ),
          )
        else
          for (final RadioProgramme p in programmes) ...[
            Row(
              key: ValueKey('schedule-${p.id}'),
              children: [
                SizedBox(
                  width: 56,
                  child: Text(p.start, style: AppTextStyles.timeLabel),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(p.title, style: AppTextStyles.stationName),
                  ),
                ),
              ],
            ),
            Divider(height: 1, thickness: 1, color: colors.hairline),
          ],
      ],
    );
  }

  // --- About + details ----------------------------------------------------

  Widget _buildAbout() {
    return Column(
      key: const ValueKey('detail-about'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ABOUT THIS STATION', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        _ExpandableDescription(description: station.description ?? station.program),
      ],
    );
  }

  List<(String, String)> get _details {
    return [
      ('GENRE', station.category),
      if (station.country != null) ('COUNTRY', station.country!),
      if (station.language != null) ('LANGUAGE', station.language!),
      if (station.website != null) ('WEBSITE', station.website!),
    ];
  }

  Widget _buildDetails() {
    final colors = AppColors.of(context);
    return Column(
      key: const ValueKey('detail-details'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('STATION DETAILS', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 8),
        for (final (String label, String value) in _details) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(label, style: AppTextStyles.timeLabel),
                ),
                Expanded(
                  child: Text(value, style: AppTextStyles.stationName),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: colors.hairline),
        ],
      ],
    );
  }

  // --- Related ------------------------------------------------------------

  Widget _buildRelated() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('YOU MAY ALSO LIKE', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        SizedBox(
          height: 168,
          child: ListView(
            key: const ValueKey('related-list'),
            scrollDirection: Axis.horizontal,
            children: [
              for (final RadioStation other in _relatedStations())
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _StationCard(
                    station: other,
                    onTap: () => _openStation(other),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<RadioStation> _relatedStations() {
    final List<RadioStation> others = [
      for (final RadioStation s in _content.stations)
        if (s.name != station.name) s,
    ];
    others.sort((a, b) {
      final int byCategory =
          (a.category == station.category ? 0 : 1).compareTo(
            b.category == station.category ? 0 : 1,
          );
      if (byCategory != 0) return byCategory;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return others.take(5).toList();
  }

  // --- Mini slot ----------------------------------------------------------

  Widget _buildMiniSlot() {
    final PodcastEpisode? episode = controller.currentEpisode;
    final bool podcastActive = controller.podcastActive && episode != null;
    final bool ended = controller.podcastDuration > Duration.zero &&
        controller.podcastPosition >= controller.podcastDuration;

    if (controller.radioActive &&
        controller.currentStation != null &&
        _dismissedRadio != controller.currentStation!.stationId) {
      return RadioMiniPlayer(
        key: ValueKey('station-detail-radio-${controller.currentStation!.name}'),
        controller: controller,
        onDismiss: () => setState(() {
          _dismissedRadio = controller.currentStation!.stationId;
        }),
      );
    }
    if (podcastActive && !ended && _dismissedEpisode != episode.id) {
      return MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: PodcastMiniPlayer(
          key: ValueKey('station-detail-episode-${episode.id}'),
          controller: controller,
          onDismiss: () => setState(() {
            _dismissedEpisode = episode.id;
          }),
        ),
      );
    }
    return const SizedBox(width: double.infinity);
  }
}

// --- Local widgets ---------------------------------------------------------

/// A quiet radio monogram circle, matching the home screen's artwork language:
/// hairline border, initials only. Deliberately not an album cover.
class _StationMonogram extends StatelessWidget {
  const _StationMonogram({required this.name, required this.size});

  final String name;
  final double size;

  String get _initials {
    final List<String> parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.hairline),
      ),
      child: Text(_initials, style: AppTextStyles.playerStation),
    );
  }
}

/// Expandable editorial description, same language as Podcast Detail.
class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.description});

  final String description;

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: Text(
            widget.description,
            maxLines: _expanded ? null : 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.nowPlayingProgramme,
          ),
        ),
        if (widget.description.length > 100) ...[
          const SizedBox(height: 8),
          GestureDetector(
            key: const ValueKey('station-about-toggle'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(_expanded ? 'LESS' : 'MORE', style: AppTextStyles.navLabel),
            ),
          ),
        ],
      ],
    );
  }
}

/// A narrow station card for the related row, mirroring the home screen's card
/// language: monogram, name, category and a quiet LISTEN action.
class _StationCard extends StatelessWidget {
  const _StationCard({required this.station, required this.onTap});

  final RadioStation station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      key: ValueKey('related-${station.stationId}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 158,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StationMonogram(name: station.name, size: 84),
            const SizedBox(height: 10),
            Text(
              station.name,
              style: AppTextStyles.stationName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(station.category.toUpperCase(), style: AppTextStyles.sectionLabel),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('LISTEN', style: AppTextStyles.nowPlayingLabel),
                const Spacer(),
                Icon(Icons.play_arrow, size: 16, color: colors.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}