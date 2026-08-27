import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:radio_over/data/content_scope.dart';
import 'package:radio_over/data/downloads/download_manager.dart';
import 'package:radio_over/data/downloads/download_store.dart';
import 'package:radio_over/models/download.dart';
import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/playback/audio_engine.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/downloads_screen.dart';
import 'package:radio_over/screens/podcast_player_screen.dart';
import 'package:radio_over/theme.dart';

/// Range-aware mock audio server used to drive real transfers in widget tests.
class MockServer {
  MockServer(this.bytes, {this.delay = Duration.zero});
  final List<int> bytes;
  final Duration delay;
  final List<String?> ranges = [];
  int requestCount = 0;

  Future<StreamedResponse> handler(BaseRequest request, ByteStream body) async {
    requestCount++;
    final String? range = request.headers['Range'];
    ranges.add(range);
    int offset = 0;
    if (range != null && range.startsWith('bytes=')) {
      offset = int.parse(range.substring(6).split('-').first);
    }
    final List<int> body2 = offset >= bytes.length ? <int>[] : bytes.sublist(offset);
    final Stream<List<int>> stream = _chunked(body2, delay);
    return StreamedResponse(stream, offset > 0 ? 206 : 200,
        contentLength: body2.length, request: request);
  }

  static Stream<List<int>> _chunked(List<int> bytes, Duration delay) async* {
    const int size = 10;
    for (int i = 0; i < bytes.length; i += size) {
      yield bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size);
      if (delay > Duration.zero) await Future.delayed(delay);
    }
  }

  Client get client => MockClient.streaming(handler);
}

class _Store implements DownloadStore {
  _Store(this.items);
  final List<DownloadItem> items;
  @override
  Future<List<DownloadItem>> load() async => List.of(items);
  @override
  Future<void> save(List<DownloadItem> items) async {}
}

PodcastEpisode episode({
  String id = 'the-daily-gaza',
  String audioUrl = 'https://remote.example.com/the-daily-gaza.mp3',
}) =>
    PodcastEpisode(
      id: id,
      podcastId: 'the-daily',
      podcastName: 'The Daily',
      title: 'The View From Gaza',
      duration: const Duration(minutes: 10),
      audioUrl: audioUrl,
    );

Future<DownloadManager> makeManager(
  WidgetTester tester,
  List<DownloadItem> items,
  Directory base,
) async {
  late DownloadManager manager;
  await tester.runAsync(() async {
    manager = DownloadManager(
      store: _Store(items),
      resolveBaseDir: () async => base,
    );
    await manager.restored;
  });
  return manager;
}

Future<void> waitForStatus(
  DownloadManager manager,
  String id,
  bool Function(DownloadItem?) predicate, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  final DateTime end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (predicate(manager.itemFor(id))) return;
    await Future.delayed(const Duration(milliseconds: 20));
  }
  fail('timed out waiting for download state');
}

void main() {
  group('DownloadsScreen', () {
    testWidgets('shows completed and failed rows with correct actions', (tester) async {
      late Directory base;
      await tester.runAsync(() async {
        base = await Directory.systemTemp.createTemp('dl-');
      });
      late File file;
      await tester.runAsync(() async {
        file = File('${base.path}/podcast_downloads/the-daily/episode_the-daily-gaza.mp3');
        await file.create(recursive: true);
        await file.writeAsBytes(const [1, 2, 3]);
      });

      final DownloadItem completed = DownloadItem(
        id: 'the-daily-gaza',
        episodeId: 'the-daily-gaza',
        podcastId: 'the-daily',
        audioUrl: 'https://remote.example.com/the-daily-gaza.mp3',
        localPath: file.path,
        fileName: 'episode_the-daily-gaza.mp3',
        status: DownloadStatus.completed,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        completedAt: DateTime.fromMillisecondsSinceEpoch(0),
        downloadedBytes: 3,
        totalBytes: 3,
        progress: 1,
      );
      final DownloadItem failed = DownloadItem(
        id: '99pi-airport-codes',
        episodeId: '99pi-airport-codes',
        podcastId: '99pi',
        audioUrl: 'https://x/y.mp3',
        localPath: '',
        fileName: 'episode_99pi-airport-codes.mp3',
        status: DownloadStatus.failed,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        error: 'Connection lost',
      );

      final DownloadManager manager = await makeManager(tester, [completed, failed], base);
      final controller = PlaybackController(downloads: manager);
      final AppContent content = AppContent.mock();

      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: DownloadsScreen(controller: controller, content: content)),
      );
      await tester.pump();

      expect(find.text('The View From Gaza'), findsOneWidget);
      expect(find.text('READY OFFLINE · 3 B'), findsOneWidget);
      expect(find.byKey(const ValueKey('download-play-the-daily-gaza')), findsOneWidget);
      expect(find.byKey(const ValueKey('download-remove-the-daily-gaza')), findsOneWidget);
      expect(find.byKey(const ValueKey('download-retry-99pi-airport-codes')), findsOneWidget);
      // Failed row surfaces the error text.
      expect(find.text('Connection lost'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('removing the only download shows the empty state', (tester) async {
      late Directory base;
      await tester.runAsync(() async {
        base = await Directory.systemTemp.createTemp('dl-');
      });
      late File file;
      await tester.runAsync(() async {
        file = File('${base.path}/podcast_downloads/the-daily/episode_the-daily-gaza.mp3');
        await file.create(recursive: true);
        await file.writeAsBytes(const [1, 2, 3]);
      });

      final DownloadItem completed = DownloadItem(
        id: 'the-daily-gaza',
        episodeId: 'the-daily-gaza',
        podcastId: 'the-daily',
        audioUrl: 'https://remote.example.com/the-daily-gaza.mp3',
        localPath: file.path,
        fileName: 'episode_the-daily-gaza.mp3',
        status: DownloadStatus.completed,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        completedAt: DateTime.fromMillisecondsSinceEpoch(0),
        downloadedBytes: 3,
        totalBytes: 3,
        progress: 1,
      );
      final DownloadManager manager = await makeManager(tester, [completed], base);
      final controller = PlaybackController(downloads: manager);
      final AppContent content = AppContent.mock();

      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: DownloadsScreen(controller: controller, content: content)),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('download-row-the-daily-gaza')), findsOneWidget);

      expect(manager.itemFor('the-daily-gaza'), isNotNull);
      await tester.runAsync(() => manager.remove('the-daily-gaza'));
      await tester.pump();

      expect(manager.itemFor('the-daily-gaza'), isNull);
      expect(find.byKey(const ValueKey('downloads-empty')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('shows live progress for an in-flight download then can cancel', (tester) async {
      late Directory base;
      await tester.runAsync(() async {
        base = await Directory.systemTemp.createTemp('dl-');
      });
      final List<int> payload = List<int>.generate(1000, (i) => i % 256);
      final MockServer server = MockServer(payload, delay: const Duration(milliseconds: 15));
      late DownloadManager manager;
      await tester.runAsync(() async {
        manager = DownloadManager(
          client: server.client,
          store: InMemoryDownloadStore(),
          resolveBaseDir: () async => base,
        );
        await manager.restored;
      });
      final controller = PlaybackController(downloads: manager);
      final AppContent content = AppContent.mock();

      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: DownloadsScreen(controller: controller, content: content)),
      );
      await tester.pump();

      // All file IO for the transfer must happen inside a single runAsync
      // window, otherwise the widget-test event loop deadlocks.
      await tester.runAsync(() async {
        manager.enqueue(episode());
        await waitForStatus(manager, 'the-daily-gaza',
            (i) => i?.status == DownloadStatus.downloading && (i?.downloadedBytes ?? 0) > 0);
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsWidgets);

        await manager.cancel('the-daily-gaza');
        await waitForStatus(manager, 'the-daily-gaza', (_) => manager.itemFor('the-daily-gaza') == null);
        await tester.pump();
      });
      expect(manager.itemFor('the-daily-gaza'), isNull);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });

  group('Offline playback', () {
    testWidgets('shows the offline hint only when a start fails and not downloaded', (tester) async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      late Directory base;
      await tester.runAsync(() async {
        base = await Directory.systemTemp.createTemp('dl-');
      });
      final DownloadManager manager = await makeManager(tester, [], base);
      final controller = PlaybackController(engine: engine, downloads: manager);

      controller.playPodcastEpisode(episode());
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: PodcastPlayerScreen(controller: controller)),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('offline-hint')), findsNothing);

      engine.simulateError();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.podcastStartFailed, isTrue);
      expect(find.byKey(const ValueKey('offline-hint')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('does not show the hint for a downloaded (offline) episode', (tester) async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      late Directory base;
      await tester.runAsync(() async {
        base = await Directory.systemTemp.createTemp('dl-');
      });
      late File file;
      await tester.runAsync(() async {
        file = File('${base.path}/podcast_downloads/the-daily/episode_the-daily-gaza.mp3');
        await file.create(recursive: true);
        await file.writeAsBytes(const [1, 2, 3]);
      });
      final DownloadItem completed = DownloadItem(
        id: 'the-daily-gaza',
        episodeId: 'the-daily-gaza',
        podcastId: 'the-daily',
        audioUrl: 'https://remote.example.com/the-daily-gaza.mp3',
        localPath: file.path,
        fileName: 'episode_the-daily-gaza.mp3',
        status: DownloadStatus.completed,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        completedAt: DateTime.fromMillisecondsSinceEpoch(0),
        downloadedBytes: 3,
        totalBytes: 3,
        progress: 1,
      );
      final DownloadManager manager = await makeManager(tester, [completed], base);
      final controller = PlaybackController(engine: engine, downloads: manager);

      controller.playPodcastEpisode(episode());
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: PodcastPlayerScreen(controller: controller)),
      );
      await tester.pump();
      engine.simulateError();
      await tester.pump();
      expect(find.byKey(const ValueKey('offline-hint')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    test('plays the local file path when the episode is downloaded', () async {
      final SimulatedAudioEngine engine = SimulatedAudioEngine();
      final Directory base = await Directory.systemTemp.createTemp('dl-');
      final File file = File('${base.path}/podcast_downloads/the-daily/episode_the-daily-gaza.mp3');
      await file.create(recursive: true);
      await file.writeAsBytes(utf8.encode('local-audio'));
      final DownloadItem completed = DownloadItem(
        id: 'the-daily-gaza',
        episodeId: 'the-daily-gaza',
        podcastId: 'the-daily',
        audioUrl: 'https://remote.example.com/the-daily-gaza.mp3',
        localPath: file.path,
        fileName: 'episode_the-daily-gaza.mp3',
        status: DownloadStatus.completed,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        completedAt: DateTime.fromMillisecondsSinceEpoch(0),
        downloadedBytes: 11,
        totalBytes: 11,
        progress: 1,
      );
      final DownloadManager manager = DownloadManager(
        store: _Store([completed]),
        resolveBaseDir: () async => base,
      );
      await manager.restored;
      final controller = PlaybackController(engine: engine, downloads: manager);

      controller.playPodcastEpisode(episode());

      expect(engine.currentUrl, file.path);
      expect(engine.currentUrl, isNot('https://remote.example.com/the-daily-gaza.mp3'));
      controller.dispose();
    });
  });
}
