import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:radio_over/data/downloads/download_manager.dart';
import 'package:radio_over/data/downloads/download_store.dart';
import 'package:radio_over/models/download.dart';
import 'package:radio_over/models/podcast_episode.dart';

/// A scriptable mock podcast audio server.
///
/// By default it honours HTTP Range requests (206 + sliced body), which is
/// exactly what the manager's resume path expects. With [honorRange] false it
/// ignores Range and always returns the full body (200), forcing the manager
/// to restart cleanly.
class MockServer {
  MockServer(this.bytes, {this.honorRange = true, this.delay = Duration.zero});

  final List<int> bytes;
  final bool honorRange;
  final Duration delay;
  final List<String?> ranges = [];
  int requestCount = 0;

  Future<StreamedResponse> handler(BaseRequest request, ByteStream bodyStream) async {
    requestCount++;
    final String? range = request.headers['Range'];
    ranges.add(range);
    int offset = 0;
    if (honorRange && range != null && range.startsWith('bytes=')) {
      offset = int.parse(range.substring(6).split('-').first);
    }
    final List<int> body = offset >= bytes.length ? <int>[] : bytes.sublist(offset);
    final Stream<List<int>> stream = _chunked(body, delay);
    return StreamedResponse(
      stream,
      offset > 0 && honorRange ? 206 : 200,
      contentLength: body.length,
      request: request,
    );
  }

  static Stream<List<int>> _chunked(List<int> bytes, Duration delay) async* {
    const int size = 10;
    for (int i = 0; i < bytes.length; i += size) {
      yield bytes.sublist(i, min(i + size, bytes.length));
      if (delay > Duration.zero) await Future.delayed(delay);
    }
  }

  Client get client => MockClient.streaming(handler);
}

/// Resolves once [predicate] holds for the item, or throws after [timeout].
Future<void> waitUntil(
  DownloadManager manager,
  String id,
  bool Function(DownloadItem?) predicate, {
  Duration timeout = const Duration(seconds: 5),
}) {
  final Completer<void> done = Completer<void>();
  late void Function() listener;
  listener = () {
    if (predicate(manager.itemFor(id))) {
      if (!done.isCompleted) done.complete();
    }
  };
  manager.addListener(listener);
  if (predicate(manager.itemFor(id)) && !done.isCompleted) done.complete();
  return done.future.timeout(timeout).whenComplete(
        () => manager.removeListener(listener),
      );
}

PodcastEpisode episode({
  String id = 'ep-1',
  String podcastId = 'show-1',
  String audioUrl = 'https://example.com/ep-1.mp3',
}) =>
    PodcastEpisode(
      id: id,
      podcastId: podcastId,
      podcastName: 'Show',
      title: 'Episode',
      duration: const Duration(minutes: 10),
      audioUrl: audioUrl,
    );

void main() {
  group('DownloadManager', () {
    test('completes a download and writes a real, intact file', () async {
      final List<int> payload = utf8.encode('audio-bytes-payload');
      final server = MockServer(payload);
      final Directory base = await Directory.systemTemp.createTemp('dl-');
      final manager = DownloadManager(
        client: server.client,
        store: InMemoryDownloadStore(),
        resolveBaseDir: () async => base,
      );
      await manager.restored;

      manager.addListener(() {}); // ensure listener path exercised
      await manager.enqueue(episode());
      await waitUntil(manager, 'ep-1', (i) => i?.status == DownloadStatus.completed);

      final DownloadItem? item = manager.itemFor('ep-1');
      expect(item?.status, DownloadStatus.completed);
      expect(item?.downloadedBytes, payload.length);
      expect(item?.localPath, isNotEmpty);
      final File file = File(item!.localPath);
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), payload);
      expect(manager.isDownloaded('ep-1'), isTrue);
      expect(manager.completedCount, 1);
      expect(manager.totalBytes, payload.length);
    });

    test('does not download an already-completed episode twice', () async {
      final List<int> payload = utf8.encode('abc');
      final server = MockServer(payload);
      final Directory base = await Directory.systemTemp.createTemp('dl-');
      final manager = DownloadManager(
        client: server.client,
        store: InMemoryDownloadStore(),
        resolveBaseDir: () async => base,
      );
      await manager.restored;

      await manager.enqueue(episode());
      await waitUntil(manager, 'ep-1', (i) => i?.status == DownloadStatus.completed);
      server.requestCount = 0;

      await manager.enqueue(episode()); // duplicate, should be a no-op
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(server.requestCount, 0);
      expect(manager.itemFor('ep-1')?.status, DownloadStatus.completed);
    });

    test('pauses mid-transfer and resumes with a Range request', () async {
      final List<int> payload = List<int>.generate(100, (i) => i % 256);
      final server = MockServer(payload, delay: const Duration(milliseconds: 15));
      final Directory base = await Directory.systemTemp.createTemp('dl-');
      final manager = DownloadManager(
        client: server.client,
        store: InMemoryDownloadStore(),
        resolveBaseDir: () async => base,
      );
      await manager.restored;

      final Future<void> enqueued = manager.enqueue(episode());
      // Wait until at least one chunk landed (offset > 0 on disk).
      await waitUntil(
        manager,
        'ep-1',
        (i) => (i?.downloadedBytes ?? 0) > 0 && i?.status == DownloadStatus.downloading,
      );
      manager.pause('ep-1');
      await waitUntil(manager, 'ep-1', (i) => i?.status == DownloadStatus.paused);
      await enqueued;

      final DownloadItem? paused = manager.itemFor('ep-1');
      expect(paused?.status, DownloadStatus.paused);
      expect(paused?.downloadedBytes, greaterThan(0));
      expect(server.ranges.first, isNull); // first request had no Range

      // Resume — should send a Range header and append.
      manager.resume('ep-1');
      await waitUntil(manager, 'ep-1', (i) => i?.status == DownloadStatus.completed);

      expect(server.ranges.any((r) => r != null && r.startsWith('bytes=')), isTrue);
      final File file = File(manager.itemFor('ep-1')!.localPath);
      expect(await file.readAsBytes(), payload);
    });

    test('restarts cleanly when the server ignores Range (200)', () async {
      final List<int> payload = List<int>.generate(60, (i) => i % 256);
      // honorRange=false: always returns full body even with a Range header.
      final server = MockServer(payload, honorRange: false, delay: const Duration(milliseconds: 10));
      final Directory base = await Directory.systemTemp.createTemp('dl-');
      final manager = DownloadManager(
        client: server.client,
        store: InMemoryDownloadStore(),
        resolveBaseDir: () async => base,
      );
      await manager.restored;

      final Future<void> enqueued = manager.enqueue(episode());
      await waitUntil(
        manager,
        'ep-1',
        (i) => (i?.downloadedBytes ?? 0) > 0 && i?.status == DownloadStatus.downloading,
      );
      manager.pause('ep-1');
      await waitUntil(manager, 'ep-1', (i) => i?.status == DownloadStatus.paused);
      await enqueued;

      manager.resume('ep-1');
      await waitUntil(manager, 'ep-1', (i) => i?.status == DownloadStatus.completed);

      // The resume request sent a Range (which triggered the 200 restart);
      // the restart must not append to a 200 body.
      expect(server.ranges.any((r) => r != null && r.startsWith('bytes=')), isTrue);
      final File file = File(manager.itemFor('ep-1')!.localPath);
      expect(await file.readAsBytes(), payload);
    });

    test('cancel deletes the partial file', () async {
      final List<int> payload = List<int>.generate(100, (i) => i % 256);
      final server = MockServer(payload, delay: const Duration(milliseconds: 15));
      final Directory base = await Directory.systemTemp.createTemp('dl-');
      final manager = DownloadManager(
        client: server.client,
        store: InMemoryDownloadStore(),
        resolveBaseDir: () async => base,
      );
      await manager.restored;

      final Future<void> enqueued = manager.enqueue(episode());
      await waitUntil(
        manager,
        'ep-1',
        (i) => (i?.downloadedBytes ?? 0) > 0 && i?.status == DownloadStatus.downloading,
      );
      await manager.cancel('ep-1');
      await enqueued;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(manager.itemFor('ep-1'), isNull);
      final File part = File(
        '${base.path}/podcast_downloads/show-1/episode_ep-1.mp3.part',
      );
      expect(await part.exists(), isFalse);
    });

    test('failed transfer becomes retryable, then succeeds on retry', () async {
      // A server that always errors.
      final Client failing = MockClient.streaming((request, body) async {
        return StreamedResponse(
          Stream<List<int>>.empty(),
          500,
          contentLength: 0,
          request: request,
        );
      });
      final Directory base = await Directory.systemTemp.createTemp('dl-');
      final manager = DownloadManager(
        client: failing,
        store: InMemoryDownloadStore(),
        resolveBaseDir: () async => base,
      );
      await manager.restored;

      await manager.enqueue(episode());
      await waitUntil(manager, 'ep-1', (i) => i?.status == DownloadStatus.failed);
      expect(manager.itemFor('ep-1')?.error, isNotNull);

      // Swap in a working server and retry.
      final List<int> payload = utf8.encode('recovered');
      final server = MockServer(payload);
      manager.attachClientForTest(server.client);
      await manager.retry('ep-1');
      await waitUntil(manager, 'ep-1', (i) => i?.status == DownloadStatus.completed);
      expect(await File(manager.itemFor('ep-1')!.localPath).readAsBytes(), payload);
    });

    test('recovers on restart: completed kept, interrupted marked paused', () async {
      final Directory base = await Directory.systemTemp.createTemp('dl-');
      final File done = File('${base.path}/podcast_downloads/show-1/episode_done.mp3');
      await done.create(recursive: true);
      await done.writeAsBytes(utf8.encode('done'));

      final DownloadStore store = _FixedStore([
        DownloadItem(
          id: 'done',
          episodeId: 'done',
          podcastId: 'show-1',
          audioUrl: 'https://example.com/done.mp3',
          localPath: done.path,
          fileName: 'episode_done.mp3',
          status: DownloadStatus.completed,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          completedAt: DateTime.fromMillisecondsSinceEpoch(0),
          downloadedBytes: 4,
          totalBytes: 4,
          progress: 1,
        ),
        DownloadItem(
          id: 'mid',
          episodeId: 'mid',
          podcastId: 'show-1',
          audioUrl: 'https://example.com/mid.mp3',
          localPath: '',
          fileName: 'episode_mid.mp3',
          status: DownloadStatus.downloading,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          downloadedBytes: 10,
          totalBytes: 100,
        ),
      ]);
      final manager = DownloadManager(
        store: store,
        resolveBaseDir: () async => base,
      );
      await manager.restored;

      expect(manager.isDownloaded('done'), isTrue);
      expect(manager.itemFor('mid')?.status, DownloadStatus.paused);
      expect(manager.itemFor('mid')?.error, 'Interrupted');
    });

    test('sanitizes filenames and avoids collisions across episodes', () async {
      final String safe = DownloadManager.sanitize('weird/name*with chars');
      expect(safe, 'weird_name_with_chars');
      // Two episodes with different ids map to different files.
      final a = DownloadManager.fileNameFor('ep/a', 'https://x.com/a.mp3');
      final b = DownloadManager.fileNameFor('ep/b', 'https://x.com/b.mp3');
      expect(a, 'episode_ep_a.mp3');
      expect(b, 'episode_ep_b.mp3');
      expect(a == b, isFalse);
    });

    test('derives extension from the audio URL', () {
      expect(DownloadManager.extensionForUrl('https://x.com/a.M4A'), 'm4a');
      expect(DownloadManager.extensionForUrl('https://x.com/a.unknownext'), 'mp3');
      expect(DownloadManager.extensionForUrl('https://x.com/noext'), 'mp3');
    });
  });
}

class _FixedStore implements DownloadStore {
  _FixedStore(this.items);
  final List<DownloadItem> items;
  @override
  Future<List<DownloadItem>> load() async => List.of(items);
  @override
  Future<void> save(List<DownloadItem> items) async {}
}
