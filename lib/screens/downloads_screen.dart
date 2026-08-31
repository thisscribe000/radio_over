import 'package:flutter/material.dart';

import '../data/content_scope.dart';
import '../models/download.dart';
import '../models/podcast_episode.dart';
import '../playback/playback_controller.dart';
import '../screens/podcast_player_screen.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Manages real podcast downloads: shows transfer progress, offline-ready
/// files, and the actions to pause/resume/cancel/retry/remove each one.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({
    super.key,
    required this.controller,
    required this.content,
  });

  final PlaybackController controller;
  final AppContent content;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('downloads-back'),
                    tooltip: 'Back',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back, size: 22, color: colors.ink),
                  ),
                  const Expanded(
                    child: Center(child: Text('DOWNLOADS', style: AppTextStyles.navLabel)),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final int completed = controller.downloads.completedCount;
                final int total = controller.downloads.totalBytes;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Row(
                    children: [
                      Text(
                        completed == 0
                            ? 'Nothing downloaded yet'
                            : '$completed episode${completed == 1 ? '' : 's'} · ${formatBytes(total)}',
                        style: AppTextStyles.sectionLabel,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final List<DownloadItem> items = controller.downloads.items;
                  if (items.isEmpty) {
                    return Center(
                      child: Container(
                        key: const ValueKey('downloads-empty'),
                        margin: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.hairline),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No downloads yet',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.ink,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Download episodes from the player to listen without internet.',
                              style: AppTextStyles.stationCategory,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    key: const ValueKey('downloads-list'),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      thickness: 1,
                      color: colors.hairline,
                    ),
                    itemBuilder: (context, index) =>
                        _DownloadRow(item: items[index], controller: controller, content: content),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({
    required this.item,
    required this.controller,
    required this.content,
  });

  final DownloadItem item;
  final PlaybackController controller;
  final AppContent content;

  PodcastEpisode? get _episode => content.episodeById(item.episodeId);
  String get _title => _episode?.title ?? item.fileName;
  String get _subtitle => _episode?.podcastName ?? item.podcastId;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final DownloadStatus status = item.status;
    return Padding(
      key: ValueKey('download-row-${item.episodeId}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: AppTextStyles.stationName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle.toUpperCase(),
                      style: AppTextStyles.timeLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Actions(
                status: status,
                canPlay: _episode != null,
                onPlay: () => _play(context),
                onPause: () => controller.pauseDownload(item.episodeId),
                onResume: () => controller.resumeDownload(item.episodeId),
                onCancel: () => controller.cancelDownload(item.episodeId),
                onRetry: () => controller.retryDownload(item.episodeId),
                onRemove: () => controller.removeDownload(item.episodeId),
                episodeId: item.episodeId,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (status == DownloadStatus.downloading) ...[
            LinearProgressIndicator(value: item.progress > 0 ? item.progress : null),
            const SizedBox(height: 4),
            Text(
              item.progress > 0
                  ? '${(item.progress * 100).round()}%'
                  : 'Starting…',
              style: AppTextStyles.timeLabel,
            ),
          ] else if (status == DownloadStatus.queued)
            const Text('QUEUED', style: AppTextStyles.timeLabel)
          else if (status == DownloadStatus.paused)
            Text('PAUSED', style: AppTextStyles.timeLabel)
          else if (status == DownloadStatus.failed)
            Text(
              item.error ?? 'Download failed',
              style: TextStyle(fontSize: 12, color: colors.podcastAccent),
            )
          else if (status == DownloadStatus.completed)
            Text(
              'READY OFFLINE · ${formatBytes(item.downloadedBytes)}',
              style: AppTextStyles.timeLabel,
            ),
        ],
      ),
    );
  }

  void _play(BuildContext context) {
    final PodcastEpisode? episode = _episode;
    if (episode == null) return;
    controller.playPodcastEpisode(episode);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PodcastPlayerScreen(controller: controller),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.status,
    required this.canPlay,
    required this.onPlay,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onRetry,
    required this.onRemove,
    required this.episodeId,
  });

  final DownloadStatus status;
  final bool canPlay;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final String episodeId;

  Widget _icon(AppColors colors, IconData icon, String key, VoidCallback onTap, {Color? color}) {
    return IconButton(
      key: ValueKey(key),
      icon: Icon(icon, size: 20, color: color ?? colors.ink),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    switch (status) {
      case DownloadStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canPlay) _icon(colors, Icons.play_arrow, 'download-play-$episodeId', onPlay),
            _icon(colors, Icons.delete_outline, 'download-remove-$episodeId', onRemove,
                color: colors.muted),
          ],
        );
      case DownloadStatus.queued:
      case DownloadStatus.downloading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _icon(colors, Icons.pause, 'download-pause-$episodeId', onPause),
            _icon(colors, Icons.close, 'download-cancel-$episodeId', onCancel,
                color: colors.muted),
          ],
        );
      case DownloadStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _icon(colors, Icons.play_arrow, 'download-resume-$episodeId', onResume,
                color: colors.podcastAccent),
            _icon(colors, Icons.close, 'download-cancel-$episodeId', onCancel,
                color: colors.muted),
          ],
        );
      case DownloadStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _icon(colors, Icons.refresh, 'download-retry-$episodeId', onRetry,
                color: colors.podcastAccent),
            _icon(colors, Icons.delete_outline, 'download-remove-$episodeId', onRemove,
                color: colors.muted),
          ],
        );
      case DownloadStatus.cancelled:
        return const SizedBox.shrink();
    }
  }
}
