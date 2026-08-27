import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import '../models/podcast_episode.dart';
import '../models/playback.dart';
import '../models/station.dart';
import 'playback_controller.dart';

/// Bridges [PlaybackController] to the system media session.
///
/// Forwards play/pause/stop/seek/skip commands from lock-screen / notification /
/// Android Auto / CarPlay TO the controller, and pushes state changes (playing,
/// paused, metadata, position) FROM the controller back to the system so the
/// media notification, lock-screen controls and control centre stay accurate.
///
/// This class owns the [AudioSession] configuration and should be created once
/// at app startup (before [AudioService.init]).
class PlaybackService extends BaseAudioHandler {
  final PlaybackController _controller;
  final Future<void> Function() _configureSession;

  /// [configureSession] lets tests replace the platform audio-session setup
  /// with a no-op (no device code runs in the widget-test suite). It defaults
  /// to configuring the OS session for music playback.
  PlaybackService({
    required PlaybackController controller,
    Future<void> Function()? configureSession,
  })  : _controller = controller,
        _configureSession = configureSession ?? _defaultSessionConfig {
    _controller.addListener(_syncAll);
    _syncAll();
    unawaited(_runSessionConfig());
  }

  static Future<void> _defaultSessionConfig() async {
    final AudioSession session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> _runSessionConfig() async {
    try {
      await _configureSession();
    } on Exception {
      // Platform session unavailable (e.g. widget tests): sync still works.
    }
  }

  // ------------------------------------------------------------------
  // Commands FROM the system → controller
  // ------------------------------------------------------------------

  @override
  Future<void> play() async {
    if (!_controller.isPlaying) _controller.toggle();
  }

  @override
  Future<void> pause() async {
    if (_controller.isPlaying) _controller.toggle();
  }

  @override
  Future<void> stop() async {
    _controller.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    _controller.seek(position);
  }

  /// Fast-forward by [AudioServiceConfig.fastForwardInterval] (default 10 s).
  @override
  Future<void> fastForward() async {
    if (_controller.audioType != AudioType.podcast) return;
    final Duration current = _controller.podcastPosition;
    final Duration total = _controller.podcastDuration;
    final Duration target = current + const Duration(seconds: 10);
    _controller.seek(target > total ? total : target);
  }

  /// Rewind by [AudioServiceConfig.rewindInterval] (default 10 s).
  @override
  Future<void> rewind() async {
    if (_controller.audioType != AudioType.podcast) return;
    final Duration current = _controller.podcastPosition;
    final Duration target = current - const Duration(seconds: 10);
    _controller.seek(target.isNegative ? Duration.zero : target);
  }

  @override
  Future<void> onTaskRemoved() async {
    _controller.stop();
  }

  // ------------------------------------------------------------------
  // State sync: controller → system
  // ------------------------------------------------------------------

  void _syncAll() {
    _syncMediaItem();
    _syncPlaybackState();
  }

  void _syncMediaItem() {
    final PodcastEpisode? episode = _controller.currentEpisode;
    if (episode != null) {
      final Uri? artUri =
          episode.imageUrl != null ? Uri.parse(episode.imageUrl!) : null;
      mediaItem.add(MediaItem(
        id: 'episode:${episode.id}',
        title: episode.title,
        album: episode.podcastName,
        artist: episode.podcastName,
        duration: episode.duration,
        artUri: artUri,
      ));
      return;
    }
    final RadioStation? station = _controller.currentStation;
    if (station != null) {
      final Uri? artUri = _resolveStationArt(station);
      mediaItem.add(MediaItem(
        id: 'station:${station.stationId}',
        title: station.name,
        artist: station.program,
        isLive: true,
        artUri: artUri,
      ));
      return;
    }
    mediaItem.add(null);
  }

  Uri? _resolveStationArt(RadioStation station) {
    if (station.logoUrl != null && station.logoUrl!.isNotEmpty) {
      return Uri.parse(station.logoUrl!);
    }
    if (station.favicon != null && station.favicon!.isNotEmpty) {
      return Uri.parse(station.favicon!);
    }
    return null;
  }

  void _syncPlaybackState() {
    final AudioType type = _controller.audioType;
    final bool playing = _controller.isPlaying;
    final List<MediaControl> controls = <MediaControl>[
      MediaControl.stop,
      if (playing) MediaControl.pause else MediaControl.play,
      if (type == AudioType.podcast) ...<MediaControl>[
        MediaControl.skipToPrevious,
        MediaControl.skipToNext,
      ],
    ];

    final AudioProcessingState processingState;
    if (type == AudioType.none) {
      processingState = AudioProcessingState.idle;
    } else if (type == AudioType.radio) {
      switch (_controller.radioState) {
        case RadioConnectionState.connecting:
          processingState = AudioProcessingState.buffering;
        case RadioConnectionState.buffering:
          processingState = AudioProcessingState.buffering;
        case RadioConnectionState.playing:
          processingState = AudioProcessingState.ready;
        case RadioConnectionState.error:
          processingState = AudioProcessingState.idle;
        case RadioConnectionState.idle:
          processingState = AudioProcessingState.idle;
      }
    } else {
      // podcast
      processingState = playing
          ? AudioProcessingState.ready
          : AudioProcessingState.completed;
    }

    final Duration position;
    if (type == AudioType.podcast) {
      position = _controller.podcastPosition;
    } else {
      position = Duration.zero;
    }

    playbackState.add(playbackState.value.copyWith(
      processingState: processingState,
      playing: playing,
      controls: controls,
      systemActions: const <MediaAction>{
        MediaAction.seek,
      },
      updatePosition: position,
      speed: 1.0,
    ));
  }

  void dispose() => _controller.removeListener(_syncAll);
}
