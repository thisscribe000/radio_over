import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/content_scope.dart';
import '../models/playback.dart';
import '../models/station.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';
import '../widgets/live_badge.dart';
import '../widgets/now_playing_info.dart';
import '../widgets/play_pause_button.dart';
import '../widgets/player_icon_button.dart';
import '../widgets/player_top_bar.dart';
import '../widgets/radio_waveform.dart';
import '../widgets/sleep_timer_indicator.dart';
import '../widgets/sleep_timer_sheet.dart';

/// Full-screen live-radio player.
///
/// Establishes the shared player design language (which the podcast player
/// shares) while keeping a broadcast-like, live personality: no track
/// timelines, no scrub — just the station, the current programme, and the
/// broadcast activity line.
class RadioPlayerScreen extends StatefulWidget {
  const RadioPlayerScreen({super.key, required this.controller, this.content});

  final PlaybackController controller;

  /// Content catalogue used for NEXC/PREVIOUS station ordering. Defaults to
  /// the offline mock scope when not provided.
  final AppContent? content;

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen> {
  late final AppContent _content = widget.content ?? AppContent.mock();

  /// Set once the underlying listen stops (e.g. the sleep timer expires) so
  /// the route pops itself exactly once instead of once per rebuild.
  bool _exiting = false;

  /// While connecting or buffering the badge must not claim a live broadcast.
  bool get _isBufferingLike {
    final RadioConnectionState state = widget.controller.radioState;
    return state == RadioConnectionState.connecting ||
        state == RadioConnectionState.buffering;
  }

  /// Quiet, honest stream status under the programme line: what the player
  /// is actually doing, with an explicit TRY AGAIN once automatic
  /// reconnection has been exhausted.
  Widget _buildStreamStatus() {
    final PlaybackController controller = widget.controller;
    switch (controller.radioState) {
      case RadioConnectionState.connecting:
        return const Text(
          'CONNECTING…',
          key: ValueKey('stream-status'),
          style: AppTextStyles.nowPlayingLabel,
        );
      case RadioConnectionState.buffering:
        return const Text(
          'BUFFERING…',
          key: ValueKey('stream-status'),
          style: AppTextStyles.nowPlayingLabel,
        );
      case RadioConnectionState.error:
        return GestureDetector(
          key: const ValueKey('stream-retry'),
          behavior: HitTestBehavior.opaque,
          onTap: controller.retryRadio,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              "UNABLE TO CONNECT · TRY AGAIN",
              key: ValueKey('stream-status'),
              style: AppTextStyles.nowPlayingLabel,
            ),
          ),
        );
      case RadioConnectionState.idle:
      case RadioConnectionState.playing:
        return const SizedBox.shrink();
    }
  }

  void _switchStation(int delta) {
    final RadioStation? station = widget.controller.currentStation;
    if (station == null || _content.stations.isEmpty) return;
    final int index = _content.stations.indexWhere(
      (s) => s.stationId == station.stationId,
    );
    if (index < 0) return;
    final List<RadioStation> stations = _content.stations;
    widget.controller.playRadioStation(
      stations[(index + delta) % stations.length],
    );
  }

  /// Unavoidably a platform action: shares the current listen via the native
  /// share sheet. Guarded so the app stays quiet when sharing is unavailable
  /// (for example in the headless widget-test environment).
  Future<void> _share(RadioStation station) async {
    final String text =
        'Listening live to ${station.name} — ${station.program}.';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Radio — ${station.name}'),
      );
    } catch (_) {
      // Sharing unavailable here; nothing to do.
    }
  }

  Future<void> _openSleepTimer(BuildContext context) {
    return SleepTimerSheet.show(
      context,
      controller: widget.controller,
      showEndOfEpisode: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (!widget.controller.radioActive) {
          if (!_exiting) {
            _exiting = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).maybePop();
              }
            });
          }
          return const Scaffold(body: SizedBox.shrink());
        }
        final RadioStation station = widget.controller.currentStation!;
        final bool playing = widget.controller.isPlaying;
        final bool favourite = widget.controller.isFavouriteStation(
          station.stationId,
        );
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const PlayerTopBar(
                    label: 'RADIO',
                    backKey: ValueKey('player-back'),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        LiveBadge(animate: playing && !_isBufferingLike),
                        const SizedBox(height: 16),
                        Text(
                          station.name.toUpperCase(),
                          style: AppTextStyles.stationTitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.controller.radioNowPlaying ?? station.program,
                          key: const ValueKey('player-program'),
                          style: AppTextStyles.stationProgramme,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        _buildStreamStatus(),
                        const Spacer(flex: 1),
                        Flexible(
                          flex: 4,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: RadioWaveform(active: playing),
                            ),
                          ),
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                  _RadioControls(
                    playing: playing,
                    onPlayPause: () =>
                        widget.controller.radioState ==
                            RadioConnectionState.error
                        ? widget.controller.retryRadio()
                        : widget.controller.toggle(),
                    onPrevious: () => _switchStation(-1),
                    onNext: () => _switchStation(1),
                  ),
                  const SizedBox(height: 18),
                  _RadioSecondaryActions(
                    favourite: favourite,
                    onFavourite: () => widget.controller.toggleFavouriteStation(
                      station.stationId,
                      details: station,
                    ),
                    onShare: () => _share(station),
                    sleepActive: widget.controller.sleepActive,
                    onSleep: () => _openSleepTimer(context),
                  ),
                  if (widget.controller.sleepActive) ...[
                    const SizedBox(height: 12),
                    SleepTimerIndicator(controller: widget.controller),
                  ],
                  const SizedBox(height: 28),
                  NowPlayingInfo(
                    title: station.program,
                    subtitle: station.name,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RadioControls extends StatelessWidget {
  const _RadioControls({
    required this.playing,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
  });

  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerIconButton(
                key: const ValueKey('player-previous'),
                tooltip: 'Previous station',
                onPressed: onPrevious,
                icon: const Icon(
                  Icons.navigate_before,
                  size: 28,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          PlayPauseButton(
            key: const ValueKey('player-play-pause'),
            playing: playing,
            onPressed: onPlayPause,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerIconButton(
                key: const ValueKey('player-next'),
                tooltip: 'Next station',
                onPressed: onNext,
                icon: const Icon(
                  Icons.navigate_next,
                  size: 28,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadioSecondaryActions extends StatelessWidget {
  const _RadioSecondaryActions({
    required this.favourite,
    required this.onFavourite,
    required this.onShare,
    required this.sleepActive,
    required this.onSleep,
  });

  final bool favourite;
  final VoidCallback onFavourite;
  final VoidCallback onShare;
  final bool sleepActive;
  final VoidCallback onSleep;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PlayerIconButton(
            key: const ValueKey('player-favourite'),
            tooltip: 'Toggle favourite',
            onPressed: onFavourite,
            icon: Icon(
              favourite ? Icons.favorite : Icons.favorite_border,
              size: 22,
              color: favourite ? AppColors.accent : AppColors.ink,
            ),
          ),
          PlayerIconButton(
            key: const ValueKey('player-share'),
            tooltip: 'Share',
            onPressed: onShare,
            icon: const Icon(Icons.ios_share, size: 22, color: AppColors.ink),
          ),
          PlayerIconButton(
            key: const ValueKey('player-sleep'),
            tooltip: 'Sleep timer',
            onPressed: onSleep,
            icon: Icon(
              Icons.bedtime_outlined,
              size: 22,
              color: sleepActive ? AppColors.accent : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
