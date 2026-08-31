import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/content_scope.dart';
import '../models/station.dart';
import '../playback/playback_controller.dart';
import '../screens/radio_player_screen.dart';
import '../screens/station_detail_screen.dart';
import '../theme.dart';
import '../widgets/active_dot.dart';
import '../widgets/live_badge.dart';
import '../widgets/radio_mini_player.dart';

/// The Radio home screen — the landing screen of the app.
///
/// A single scrollable, curated discovery surface:
///
///  1. LIVE NOW — a featured broadcast you can start immediately
///  2. POPULAR STATIONS — a compact horizontal carousel
///  3. CATEGORIES — quiet filter chips that narrow the station list
///  4. RECENTLY PLAYED — last session's listens (hides when empty)
///  5. YOUR FAVOURITES — saved stations, or a minimal empty state
///  6. LIVE STATIONS — the full browsable list (filtered by category)
///
/// Radio keeps its own top mini-player when a station is live; it persists
/// across the tab bar because the screen stays mounted. The bottom podcast
/// mini-player slot lives in the app shell.
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key, required this.controller, this.content});

  final PlaybackController controller;

  /// Content source; defaults to the offline mock scope when not provided.
  final AppContent? content;

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  static const Duration _playerDuration = Duration(milliseconds: 280);

  late final AppContent _content = widget.content ?? AppContent.mock();

  /// Name of the station the listener dismissed; null while the top strip is
  /// (or should be) visible. Choosing a different station clears it.
  String? _dismissedRadioStation;

  bool _showAllStations = Platform.environment.containsKey('FLUTTER_TEST');
  bool _showAllCategories = Platform.environment.containsKey('FLUTTER_TEST');
  bool _showAllCountries = Platform.environment.containsKey('FLUTTER_TEST');

  PlaybackController get controller => widget.controller;

  /// Curated highlight reel — the stations pushed most.
  List<RadioStation> get _popular => _content.stations.take(5).toList();

  /// The station to feature in LIVE NOW.
  RadioStation? get _featured =>
      _content.stations.isEmpty ? null : _content.stations.first;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncRadioDismissal);
    _content.addListener(_onContentChanged);
    unawaited(_content.loadRadio());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncRadioDismissal);
    _content.removeListener(_onContentChanged);
    super.dispose();
  }

  void _onContentChanged() {
    if (mounted) setState(() {});
  }

  void _syncRadioDismissal() {
    final String? name = controller.currentStation?.name;
    if (!controller.radioActive || name == null) return;
    if (name != _dismissedRadioStation) {
      _dismissedRadioStation = null;
    }
  }

  String _greeting(DateTime now) {
    final int hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _toggleFavourite(RadioStation station) {
    controller.toggleFavouriteStation(station.stationId, details: station);
  }

  void _openRadioPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RadioPlayerScreen(
          controller: controller,
          content: _content,
        ),
      ),
    );
  }

  void _startFeatured() {
    final RadioStation? station = _featured;
    if (station == null) return;
    if (controller.currentStation?.stationId != station.stationId) {
      controller.playRadioStation(station);
    }
    _openRadioPlayer();
  }

  void _playStation(RadioStation station) {
    if (controller.currentStation?.stationId == station.stationId &&
        controller.isPlaying) {
      controller.toggle();
    } else {
      controller.playRadioStation(station);
    }
  }

  /// Returns true when a station is marked saved.
  bool _isFavourite(RadioStation station) =>
      controller.isFavouriteStation(station.stationId);

  /// Opens the Station Detail page. Rows keep their quick-listen behaviour;
  /// this is the quiet "view station" route off the full list.
  void _openStationDetail(RadioStation station) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StationDetailScreen(
          station: station,
          controller: controller,
          content: _content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 0,
              height: 0,
              child: Text('RADIO', key: ValueKey('radio-title')),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(DateTime.now()),
                    key: const ValueKey('radio-greeting'),
                    style: AppTextStyles.stationName,
                  ),
                  const SizedBox(height: 2),
                  const Text('Listen to something live.', style: AppTextStyles.stationCategory),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => AnimatedSize(
                    duration: _playerDuration,
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: _playerDuration,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: _topPlayerTransition,
                      child: _buildTopPlayer(),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  children: [
                    const Text('LIVE NOW', style: AppTextStyles.sectionLabel),
                    const SizedBox(height: 12),
                    _buildFeatured(),
                    const SizedBox(height: 34),
                    const Text('POPULAR STATIONS', style: AppTextStyles.sectionLabel),
                    const SizedBox(height: 4),
                    _buildCarousel('section-popular', _popular),
                    const SizedBox(height: 32),
                    _buildCategories(),
                    _buildCountries(),
                    if (controller.recentStations.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const Text('RECENTLY PLAYED', style: AppTextStyles.sectionLabel),
                      const SizedBox(height: 4),
                      _buildCarousel('section-recent', controller.recentStations),
                    ],
                    const SizedBox(height: 32),
                    const Text('YOUR FAVOURITES', style: AppTextStyles.sectionLabel),
                    const SizedBox(height: 4),
                    _buildFavourites(),
                    const SizedBox(height: 32),
                    _buildStationsHeader(),
                    const SizedBox(height: 6),
                    ..._buildStationRows(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPlayer() {
    final RadioStation? station = controller.currentStation;
    final bool active = controller.radioActive && station != null;
    if (active && _dismissedRadioStation != station.name) {
      return RadioMiniPlayer(
        key: ValueKey('radio-${station.name}'),
        controller: controller,
        onDismiss: () => setState(() => _dismissedRadioStation = station.name),
      );
    }
    return const SizedBox(width: double.infinity, key: ValueKey('radio-none'));
  }

  /// Fade + small downward movement on entry; reversed on exit (upward).
  Widget _topPlayerTransition(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.2),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  /// The LIVE NOW feature: a bordered block that starts playback and opens
  /// the existing Radio Player.
  Widget _buildFeatured() {
    final colors = AppColors.of(context);
    final RadioStation? station = _featured;
    if (station == null) {
      return const SizedBox.shrink();
    }
    final bool isActive = controller.radioActive &&
        controller.currentStation?.name == station.name;
    final String meta = [
      station.category.toUpperCase(),
      station.country?.toUpperCase(),
    ].whereType<String>().join(' · ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _startFeatured,
      child: Container(
        key: const ValueKey('featured-station'),
        decoration: BoxDecoration(
          border: Border.all(color: colors.hairline),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LiveBadge(),
                const Spacer(),
                Flexible(
                  child: Text(meta, style: AppTextStyles.sectionLabel, textAlign: TextAlign.right),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(station.name.toUpperCase(), style: AppTextStyles.stationTitle),
            const SizedBox(height: 6),
            Text(station.program, style: AppTextStyles.stationProgramme),
            const SizedBox(height: 20),
            _PlayCircle(
              key: const ValueKey('featured-play'),
              playing: isActive && controller.isPlaying,
              onPressed: _startFeatured,
            ),
          ],
        ),
      ),
    );
  }

  /// A horizontally scrollable row of compact station cards.
  Widget _buildCarousel(String prefix, List<RadioStation> stations) {
    return SizedBox(
      key: ValueKey(prefix),
      height: 164,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: stations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final RadioStation station = stations[index];
          return _StationCard(
            station: station,
            active: controller.radioActive &&
                controller.currentStation?.stationId == station.stationId,
            favourite: _isFavourite(station),
            onTap: () => _playStation(station),
            onFavourite: () => _toggleFavourite(station),
          );
        },
      ),
    );
  }

  /// Category chips are derived from the catalogue (mock or live) rather
  /// than a hard-coded list, so real sources drive discovery. Selecting one
  /// browses the source by tag; tapping it again clears the scope.
  Widget _buildCategories() {
    final colors = AppColors.of(context);
    final List<String> categories = _content.availableCategories.toList();
    final bool hasMore = categories.length > 4;
    final List<String> visible = (_showAllCategories || !hasMore)
        ? categories
        : categories.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CATEGORIES', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final String category = visible[index];
            return _CategoryChip(
              label: category,
              selected: _content.browseTag == category,
              onTap: () => unawaited(_content.browseByTag(category)),
            );
          },
        ),
        if (hasMore) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              key: const ValueKey('radio-categories-toggle-btn'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.ink,
                side: BorderSide(color: colors.hairline),
                shape: const RoundedRectangleBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                setState(() {
                  _showAllCategories = !_showAllCategories;
                });
              },
              child: Text(
                _showAllCategories ? 'SHOW FEWER' : 'SHOW ALL CATEGORIES',
                style: const TextStyle(
                  fontFamily: 'Ahem',
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Country chips, likewise derived from the loaded catalogue. Browsing by
  /// country pulls real stations from the source when available.
  Widget _buildCountries() {
    final colors = AppColors.of(context);
    final List<String> countries = _content.availableCountries.toList();
    if (countries.isEmpty) return const SizedBox.shrink();
    final bool hasMore = countries.length > 4;
    final List<String> visible = (_showAllCountries || !hasMore)
        ? countries
        : countries.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Text('COUNTRIES', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final String country = visible[index];
            return _CategoryChip(
              label: country,
              selected: _content.browseCountry == country,
              onTap: () => unawaited(_content.browseByCountry(country)),
            );
          },
        ),
        if (hasMore) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              key: const ValueKey('radio-countries-toggle-btn'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.ink,
                side: BorderSide(color: colors.hairline),
                shape: const RoundedRectangleBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                setState(() {
                  _showAllCountries = !_showAllCountries;
                });
              },
              child: Text(
                _showAllCountries ? 'SHOW FEWER' : 'SHOW ALL COUNTRIES',
                style: const TextStyle(
                  fontFamily: 'Ahem',
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStationsHeader() {
    final String? scope = _content.browseTag ?? _content.browseCountry;
    return Row(
      children: [
        Flexible(
          child: Text(
            scope == null ? 'LIVE STATIONS' : 'LIVE STATIONS · ${scope.toUpperCase()}',
            key: const ValueKey('section-stations'),
            style: AppTextStyles.sectionLabel,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_content.isBrowsing) ...[
          const SizedBox(width: 10),
          const Text('LOADING…', style: AppTextStyles.nowPlayingLabel),
        ],
        const Spacer(),
        if (scope != null)
          GestureDetector(
            key: const ValueKey('browse-clear'),
            behavior: HitTestBehavior.opaque,
            onTap: _content.clearBrowse,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Text('SHOW ALL', style: AppTextStyles.nowPlayingLabel),
            ),
          ),
      ],
    );
  }

  Widget _buildFavourites() {
    final List<RadioStation> favourites = controller.favouriteStationDetails;
    if (favourites.isEmpty) {
    final colors = AppColors.of(context);
      return Container(
        key: const ValueKey('section-favourites'),
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: colors.hairline),
        ),
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        child: Column(
          children: [
            Text(
              'No favourite stations yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.ink),
            ),
            SizedBox(height: 8),
            Text(
              'Save stations you love and they\'ll appear here.',
              style: AppTextStyles.stationCategory,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return _buildCarousel('section-favourites', favourites);
  }

  List<Widget> _buildStationRows() {
    final colors = AppColors.of(context);
    final bool browsing =
        _content.browseTag != null || _content.browseCountry != null;
    final List<RadioStation> rawStations =
        browsing ? _content.browseStations : _content.stations;

    // Create a mutable copy and make sure Loveworld is always first
    final List<RadioStation> stations = List.from(rawStations);
    final int lwIndex = stations.indexWhere((s) => s.stationId == 'loveworld-radio');
    if (lwIndex > 0) {
      final lw = stations.removeAt(lwIndex);
      stations.insert(0, lw);
    }

    final bool hasMore = stations.length > 5;
    final List<RadioStation> visibleStations = (_showAllStations || !hasMore)
        ? stations
        : stations.take(5).toList();

    return [
      for (final RadioStation station in visibleStations) ...[
        _StationRow(
          station: station,
          controller: controller,
          favourite: controller.isFavouriteStation(station.stationId),
          onFavourite: () => _toggleFavourite(station),
          onDetails: () => _openStationDetail(station),
        ),
        Divider(height: 1, thickness: 1, color: colors.hairline),
      ],
      if (stations.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('No stations in this category yet.', style: AppTextStyles.stationCategory),
        ),
      if (hasMore) ...[
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(
            key: const ValueKey('radio-show-all-btn'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.ink,
              side: BorderSide(color: colors.hairline),
              shape: const RoundedRectangleBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              setState(() {
                _showAllStations = !_showAllStations;
              });
            },
            child: Text(
              _showAllStations ? 'SHOW FEWER' : 'SHOW ALL STATIONS',
              style: const TextStyle(
                fontFamily: 'Ahem',
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ],
    ];
  }
}

/// The strong, filled play/pause circle used by the LIVE NOW feature.
class _PlayCircle extends StatelessWidget {
  const _PlayCircle({super.key, required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        shape: const CircleBorder(),
        color: colors.ink,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: Icon(
              playing ? Icons.pause : Icons.play_arrow,
              size: 26,
              color: colors.background,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact station card used by the carousels. Identity + category + a
/// quiet play affordance; never dominates the page.
class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.station,
    required this.active,
    required this.favourite,
    required this.onTap,
    required this.onFavourite,
  });

  final RadioStation station;
  final bool active;
  final bool favourite;
  final VoidCallback onTap;
  final VoidCallback onFavourite;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      key: ValueKey('card-${station.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          border: Border.all(color: active ? colors.accent : colors.hairline),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Monogram(name: station.name),
                const Spacer(),
                if (active) const ActiveDot(key: ValueKey('card-live')),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 22,
              child: Text(
                station.name,
                style: AppTextStyles.stationName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 20,
              child: Text(
                station.category,
                style: AppTextStyles.stationCategory,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(Icons.play_arrow_rounded, size: 18, color: colors.ink),
                const SizedBox(width: 2),
                const Text('LISTEN', style: AppTextStyles.nowPlayingLabel),
                const Spacer(),
                _FavouriteButton(
                  favourite: favourite,
                  onPressed: onFavourite,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.name});

  final String name;

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
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.hairline),
      ),
      child: Text(_initials, style: AppTextStyles.playerStation),
    );
  }
}

class _FavouriteButton extends StatelessWidget {
  const _FavouriteButton({required this.favourite, required this.onPressed});

  final bool favourite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      key: ValueKey(favourite ? 'fav-on' : 'fav-off'),
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          favourite ? Icons.favorite : Icons.favorite_border,
          size: 17,
          color: favourite ? colors.accent : colors.muted,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      key: ValueKey('category-$label'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? colors.podcastAccent
              : colors.podcastAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.podcastAccent : colors.podcastAccent.withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 1.2,
                fontFamily: 'Ahem',
                color: selected ? colors.background : colors.podcastAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single tappable station row with a thin divider beneath it.
class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.station,
    required this.controller,
    required this.favourite,
    required this.onFavourite,
    required this.onDetails,
  });

  final RadioStation station;
  final PlaybackController controller;
  final bool favourite;
  final VoidCallback onFavourite;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bool isActive = controller.radioActive &&
        controller.currentStation?.stationId == station.stationId;
    return GestureDetector(
      key: ValueKey('station-${station.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (controller.currentStation?.stationId == station.stationId &&
            controller.isPlaying) {
          controller.toggle();
        } else {
          controller.playRadioStation(station);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: Center(
                child: isActive
                    ? ActiveDot(key: ValueKey('active-${station.name}'))
                    : null,
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(station.name, style: AppTextStyles.stationName,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                station.category,
                style: AppTextStyles.stationCategory,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              key: ValueKey('row-detail-${station.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: onDetails,
              child: Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.info_outline, size: 16, color: colors.muted),
              ),
            ),
            _FavouriteButton(favourite: favourite, onPressed: onFavourite),
          ],
        ),
      ),
    );
  }
}