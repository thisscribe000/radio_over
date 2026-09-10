import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/content_scope.dart';
import '../data/podcasts/opml_service.dart';
import '../models/podcast_episode.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';

/// Modal dialog providing OPML export and import for podcast subscriptions.
class OpmlDialog extends StatefulWidget {
  const OpmlDialog({
    super.key,
    required this.controller,
    this.content,
  });

  final PlaybackController controller;
  final AppContent? content;

  static Future<void> show(
    BuildContext context, {
    required PlaybackController controller,
    AppContent? content,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => OpmlDialog(
        controller: controller,
        content: content,
      ),
    );
  }

  @override
  State<OpmlDialog> createState() => _OpmlDialogState();
}

class _OpmlDialogState extends State<OpmlDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _importController = TextEditingController();
  int? _importedCount;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _importController.dispose();
    super.dispose();
  }

  List<PodcastSeries> _resolveFollowedShows() {
    final Set<String> savedIds = widget.controller.savedShows;
    final List<PodcastSeries> allShows = widget.content?.shows ?? [];
    return allShows.where((s) => savedIds.contains(s.id)).toList();
  }

  Future<void> _exportOpml() async {
    final List<PodcastSeries> followed = _resolveFollowedShows();
    final String opml = OpmlService.exportOpml(
      shows: followed,
      title: 'Radio Over Podcast Subscriptions',
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: opml,
          subject: 'radio_over_subscriptions.opml',
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: opml));
      if (mounted) {
        setState(() {
          _statusMessage = 'OPML copied to clipboard!';
        });
      }
    }
  }

  void _importOpml() {
    final String text = _importController.text.trim();
    if (text.isEmpty) {
      setState(() => _statusMessage = 'Please paste valid OPML XML content.');
      return;
    }

    final List<OpmlFeed> feeds = OpmlService.parseOpml(text);
    if (feeds.isEmpty) {
      setState(() => _statusMessage = 'No podcast RSS feeds found in OPML.');
      return;
    }

    for (final feed in feeds) {
      widget.controller.toggleSavedShow(feed.feedUrl);
    }

    setState(() {
      _importedCount = feeds.length;
      _statusMessage = 'Successfully subscribed to ${feeds.length} podcasts!';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final followedCount = widget.controller.savedShows.length;

    return AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.hairline),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      title: Column(
        children: [
          Row(
            children: [
              Icon(Icons.import_export, color: colors.podcastAccent),
              const SizedBox(width: 8),
              Text(
                'OPML Subscriptions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.ink),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            labelColor: colors.podcastAccent,
            unselectedLabelColor: colors.muted,
            indicatorColor: colors.podcastAccent,
            tabs: const [
              Tab(text: 'EXPORT'),
              Tab(text: 'IMPORT'),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        height: 240,
        child: TabBarView(
          controller: _tabController,
          children: [
            // EXPORT TAB
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Export your podcast subscriptions to standard OPML format compatible with AntennaPod, Pocket Casts, and Apple Podcasts.',
                  style: TextStyle(fontSize: 12.5, color: colors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '$followedCount Shows Followed',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.ink),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  key: const ValueKey('opml-export-btn'),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('SHARE OPML FILE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.podcastAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: _exportOpml,
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(_statusMessage!, style: TextStyle(fontSize: 11, color: colors.accent)),
                ],
              ],
            ),

            // IMPORT TAB
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Paste OPML XML content to batch import subscriptions:',
                  style: TextStyle(fontSize: 11.5, color: colors.muted),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('opml-import-input'),
                    controller: _importController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: '<opml version="2.0">...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  key: const ValueKey('opml-import-btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.podcastAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _importOpml,
                  child: const Text('PARSE & SUBSCRIBE'),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 11,
                      color: _importedCount != null ? colors.accent : Colors.redAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CLOSE', style: TextStyle(color: colors.muted)),
        ),
      ],
    );
  }
}
