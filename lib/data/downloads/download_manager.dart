import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/download.dart';
import '../../models/podcast_episode.dart';
import 'download_store.dart';

/// Owns podcast episode downloads: a single sequential queue, resumable
/// transfers, and persistence of transfer state across restarts.
///
/// Files never touch platform channels at construction time — the base
/// directory is resolved lazily on the first real transfer (or injected in
/// tests), so a plain `DownloadManager()` is safe to create anywhere.
class DownloadManager extends ChangeNotifier {
  /// Allowed audio extensions for the on-disk file name; anything else
  /// defaults to mp3.
  static const List<String> _allowedExtensions = <String>[
    'mp3', 'm4a', 'aac', 'mp4', 'ogg', 'oga', 'opus', 'wav',
  ];

  static const String _downloadsDir = 'podcast_downloads';

  DownloadManager({
    http.Client? client,
    DownloadStore? store,
    Future<Directory> Function()? resolveBaseDir,
    DateTime Function()? clock,
    Duration? chunkIdleTimeout,
  })  : _client = client ?? http.Client(),
        _store = store ?? InMemoryDownloadStore(),
        _resolveBaseDir = resolveBaseDir ?? getApplicationSupportDirectory,
        _clock = clock ?? DateTime.now,
        _idleTimeout = chunkIdleTimeout ?? const Duration(seconds: 30) {
    unawaited(_restore());
  }

  http.Client _client;
  final DownloadStore _store;
  final Future<Directory> Function() _resolveBaseDir;
  final DateTime Function() _clock;
  final Duration _idleTimeout;

  final Map<String, DownloadItem> _items = {};
  final List<String> _queue = [];
  final Set<String> _paused = {};
  final Set<String> _cancelled = {};

  bool _pumping = false;
  Directory? _baseDir;
  final Completer<void> _restored = Completer<void>();

  /// Resolves once the persisted state has been restored (or failed). Callers
  /// that need a consistent starting point `await` this before mutating.
  Future<void> get restored => _restored.future;

  // --- Read surface --------------------------------------------------------

  /// All downloads, ordered active → paused → failed → completed.
  List<DownloadItem> get items {
    final List<DownloadItem> ordered = [];
    for (final String id in _queue) {
      final DownloadItem? item = _items[id];
      if (item != null && item.isActive) ordered.add(item);
    }
    for (final DownloadItem item in _items.values) {
      if (item.isActive) continue;
      if (item.status == DownloadStatus.paused) {
        ordered.add(item);
      } else if (item.status == DownloadStatus.failed) {
        ordered.add(item);
      } else if (item.status == DownloadStatus.completed) {
        ordered.add(item);
      }
    }
    return List<DownloadItem>.unmodifiable(ordered);
  }

  DownloadItem? itemFor(String episodeId) => _items[episodeId];

  /// Episode ids whose download has completed (the offline set).
  Set<String> get completedIds => _items.entries
      .where((e) => e.value.status == DownloadStatus.completed)
      .map((e) => e.key)
      .toSet();

  /// Swaps the HTTP client (used by tests to simulate failure then recovery).
  void attachClientForTest(http.Client client) => _client = client;

  /// Public wrappers over the private naming helpers, for tests.
  static String sanitize(String input) => _sanitize(input);
  static String extensionForUrl(String url) => _extensionFor(url);
  static String fileNameFor(String episodeId, String? audioUrl) =>
      _fileNameFor(episodeId, audioUrl);

  bool isDownloaded(String episodeId) =>
      _items[episodeId]?.status == DownloadStatus.completed;

  /// Local file path, available only once the episode has completed.
  String? localPathFor(String episodeId) {
    final DownloadItem? item = _items[episodeId];
    if (item == null || item.status != DownloadStatus.completed) return null;
    return item.localPath;
  }

  int get completedCount =>
      _items.values.where((i) => i.status == DownloadStatus.completed).length;

  /// Sum of the real byte sizes of every completed download.
  int get totalBytes => _items.values
      .where((i) => i.status == DownloadStatus.completed)
      .fold(0, (sum, i) => sum + i.downloadedBytes);

  // --- Commands ------------------------------------------------------------

  /// Requests a download for [episode]. No-op if already completed or actively
  /// transferring; re-enqueues from failed/paused/cancelled so a sticky state
  /// can always be retried by tapping again.
  Future<void> enqueue(PodcastEpisode episode) async {
    await _restored.future;
    final String id = episode.id;
    final DownloadItem? existing = _items[id];
    if (existing != null && existing.status == DownloadStatus.completed) return;
    if (existing != null && existing.isActive) return;

    final DownloadItem item = _makeItem(episode, existing);
    _items[id] = item;
    _paused.remove(id);
    _cancelled.remove(id);
    if (!_queue.contains(id)) _queue.add(id);
    _setItem(item);
    _persist();
    _pump();
  }

  /// Pauses an in-flight transfer, keeping the partial `.part` for resume.
  void pause(String episodeId) {
    final DownloadItem? item = _items[episodeId];
    if (item == null || !item.isActive) return;
    _paused.add(episodeId);
  }

  /// Resumes a paused (or interrupted) transfer from where it left off.
  void resume(String episodeId) {
    final DownloadItem? item = _items[episodeId];
    if (item == null || item.status != DownloadStatus.paused) return;
    _paused.remove(episodeId);
    _cancelled.remove(episodeId);
    _items[episodeId] = item.copyWith(
      status: DownloadStatus.queued,
      error: null,
    );
    if (!_queue.contains(episodeId)) _queue.add(episodeId);
    _setItem(_items[episodeId]!);
    _persist();
    _pump();
  }

  /// Cancels an in-flight transfer (deletes the partial file) or removes a
  /// paused/failed/completed one entirely.
  Future<void> cancel(String episodeId) async {
    await _restored.future;
    final DownloadItem? item = _items[episodeId];
    if (item == null) return;
    if (item.isActive) {
      _cancelled.add(episodeId);
      return;
    }
    await _removeItem(episodeId);
  }

  /// Restarts a failed download from scratch.
  Future<void> retry(String episodeId) async {
    await _restored.future;
    final DownloadItem? item = _items[episodeId];
    if (item == null || item.status != DownloadStatus.failed) return;
    await enqueueFromItem(item);
  }

  /// Removes a download entirely (deletes the file for completed items).
  Future<void> remove(String episodeId) async {
    await _restored.future;
    if (_items.containsKey(episodeId)) await _removeItem(episodeId);
  }

  /// Lower-level re-enqueue used by [retry]; accepts a pre-built item.
  Future<void> enqueueFromItem(DownloadItem item) async {
    await _restored.future;
    final String id = item.id;
    if (_items[id]?.status == DownloadStatus.completed) return;
    if (_items[id]?.isActive ?? false) return;
    final DownloadItem reset = item.copyWith(
      status: DownloadStatus.queued,
      progress: 0,
      downloadedBytes: 0,
      totalBytes: 0,
      error: null,
    );
    _items[id] = reset;
    _paused.remove(id);
    _cancelled.remove(id);
    if (!_queue.contains(id)) _queue.add(id);
    _setItem(reset);
    _persist();
    _pump();
  }

  // --- Internals -----------------------------------------------------------

  DownloadItem _makeItem(PodcastEpisode episode, DownloadItem? existing) {
    final String fileName = _fileNameFor(episode.id, episode.audioUrl);
    return DownloadItem(
      id: episode.id,
      episodeId: episode.id,
      podcastId: episode.podcastId,
      audioUrl: episode.audioUrl ?? '',
      localPath: '',
      fileName: fileName,
      status: DownloadStatus.queued,
      createdAt: existing?.createdAt ?? _clock(),
    );
  }

  void _setItem(DownloadItem item) {
    _items[item.id] = item;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _store.save(_items.values.toList());
    } on Exception {
      // Best-effort persistence; the in-memory map stays authoritative.
    }
  }

  void _fail(String id, String reason) {
    final DownloadItem? item = _items[id];
    if (item == null) return;
    final DownloadItem failed = item.copyWith(
      status: DownloadStatus.failed,
      error: reason,
    );
    _setItem(failed);
    _persist();
  }

  Future<void> _removeItem(String id) async {
    final DownloadItem? item = _items[id];
    _items.remove(id);
    _queue.remove(id);
    _paused.remove(id);
    _cancelled.remove(id);
    notifyListeners();
    _persist();
    if (item != null) {
      try {
        final Directory base = await _resolveBase();
        final File part = _partFile(base, item);
        final File finalFile = _finalFile(base, item);
        if (await part.exists()) await part.delete();
        if (await finalFile.exists()) await finalFile.delete();
      } on Exception {
        // File system cleanup is best-effort.
      }
    }
  }

  Future<Directory> _resolveBase() async {
    return _baseDir ??= await _resolveBaseDir();
  }

  void _pump() {
    if (_pumping) return;
    _pumping = true;
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      while (_queue.isNotEmpty) {
        final String id = _queue.first;
        final DownloadItem? item = _items[id];
        if (item == null) {
          _queue.removeAt(0);
          continue;
        }
        _setItem(item.copyWith(status: DownloadStatus.downloading));
        await _streamDownload(item, await _resolveBase());
        if (!_items.containsKey(id)) continue; // cancelled/removed mid-flight
        _queue.removeAt(0);
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _streamDownload(
    DownloadItem item,
    Directory base, {
    bool useRange = true,
    int attempt = 0,
  }) async {
    final String id = item.id;
    final File partFile = _partFile(base, item);
    int offset = 0;
    if (useRange && await partFile.exists()) {
      offset = await partFile.length();
    } else if (await partFile.exists()) {
      await partFile.delete();
    }

    final http.Request request =
        http.Request('GET', Uri.parse(item.audioUrl));
    if (useRange && offset > 0) {
      request.headers['Range'] = 'bytes=$offset-';
    }

    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(const Duration(seconds: 15));
    } on SocketException {
      _fail(id, 'Connection lost');
      return;
    } on http.ClientException {
      _fail(id, 'Connection lost');
      return;
    } on Exception {
      _fail(id, 'Connection lost');
      return;
    }

    final int status = response.statusCode;
    if (status == 416) {
      if (await partFile.exists()) await partFile.delete();
      if (useRange && attempt == 0) {
        await _streamDownload(item, base, useRange: false, attempt: attempt + 1);
        return;
      }
      _fail(id, 'Connection lost');
      return;
    }
    if (useRange && offset > 0 && status == 200) {
      // Server ignored the Range header and sent the whole file; restart
      // cleanly from zero without Range so we do not append to a 200 body.
      if (await partFile.exists()) await partFile.delete();
      await _streamDownload(item, base, useRange: false, attempt: attempt + 1);
      return;
    }

    final int remaining = response.contentLength ?? -1;
    final int total = remaining < 0 ? -1 : offset + remaining;

    final bool append = status == 206;
    await partFile.parent.create(recursive: true);
    final IOSink sink = partFile.openWrite(
      mode: append ? FileMode.append : FileMode.write,
    );

    int downloaded = offset;
    int lastPercent = -1;
    try {
      await for (final List<int> chunk
          in response.stream.timeout(_idleTimeout)) {
        if (_cancelled.contains(id)) {
          await sink.close();
          await _removeItem(id);
          return;
        }
        if (_paused.contains(id)) {
          await sink.close();
          final DownloadItem paused = _items[id]?.copyWith(
                status: DownloadStatus.paused,
                progress: total > 0 ? downloaded / total : 0,
                downloadedBytes: downloaded,
                totalBytes: total < 0 ? 0 : total,
              ) ??
              item;
          _setItem(paused);
          _persist();
          return;
        }
        sink.add(chunk);
        downloaded += chunk.length;
        if (total > 0) {
          final int percent = (downloaded / total * 100).floor();
          if (percent != lastPercent) {
            lastPercent = percent;
            _setItem(_items[id]!.copyWith(
              status: DownloadStatus.downloading,
              progress: percent / 100,
              downloadedBytes: downloaded,
              totalBytes: total,
            ));
          }
        }
      }
      await sink.close();

      final String localPath = _finalPath(base, item);
      final File finalFile = File(localPath);
      await finalFile.parent.create(recursive: true);
      if (await finalFile.exists()) await finalFile.delete();
      await partFile.rename(localPath);

      final bool exists = await finalFile.exists();
      final int length = exists ? await finalFile.length() : 0;
      if (exists && length > 0) {
        _setItem(_items[id]!.copyWith(
          status: DownloadStatus.completed,
          progress: 1,
          downloadedBytes: length,
          totalBytes: length,
          localPath: localPath,
          completedAt: _clock(),
          error: null,
        ));
        _persist();
      } else {
        _fail(id, 'Storage error');
      }
    } on TimeoutException {
      await sink.close();
      _fail(id, 'Connection lost');
    } on SocketException {
      await sink.close();
      _fail(id, 'Connection lost');
    } on http.ClientException {
      await sink.close();
      _fail(id, 'Connection lost');
    } on FileSystemException {
      await sink.close();
      _fail(id, 'Storage error');
    } catch (e) {
      await sink.close();
      _fail(id, e.toString());
    }
  }

  Future<void> _restore() async {
    try {
      final List<DownloadItem> loaded = await _store.load();
      for (final DownloadItem item in loaded) {
        if (item.isActive) {
          // Interrupted transfers are never silently resumed.
          _items[item.id] = item.copyWith(
            status: DownloadStatus.paused,
            error: 'Interrupted',
          );
        } else if (item.status == DownloadStatus.completed) {
          _items[item.id] = item;
          unawaited(_verifyCompleted(item));
        } else {
          _items[item.id] = item;
        }
      }
    } on Exception {
      // No persisted state or storage unavailable: start clean.
    }
    if (!_restored.isCompleted) _restored.complete();
    notifyListeners();
  }

  Future<void> _verifyCompleted(DownloadItem item) async {
    try {
      final Directory base = await _resolveBase();
      final File file = _finalFile(base, item);
      final bool exists = await file.exists();
      final int length = exists ? await file.length() : 0;
      if (!exists || length == 0) {
        _setItem(item.copyWith(
          status: DownloadStatus.failed,
          error: 'File missing',
          localPath: '',
        ));
        _persist();
      }
    } on Exception {
      // If we cannot verify, trust the persisted record.
    }
  }

  // --- Paths ---------------------------------------------------------------

  File _partFile(Directory base, DownloadItem item) =>
      File('${_finalPath(base, item)}.part');

  File _finalFile(Directory base, DownloadItem item) =>
      File(_finalPath(base, item));

  String _finalPath(Directory base, DownloadItem item) {
    final String podcastDir = _sanitize(item.podcastId);
    return p.join(
      base.path,
      _downloadsDir,
      podcastDir,
      item.fileName,
    );
  }

  static String _fileNameFor(String episodeId, String? audioUrl) {
    final String ext = _extensionFor(audioUrl ?? '');
    return 'episode_${_sanitize(episodeId)}.$ext';
  }

  static String _extensionFor(String url) {
    final String path = Uri.parse(url).path;
    final String segment = path.split('/').last;
    final int dot = segment.lastIndexOf('.');
    if (dot >= 0) {
      final String ext = segment.substring(dot + 1).toLowerCase();
      if (_allowedExtensions.contains(ext)) return ext;
    }
    return 'mp3';
  }

  /// Keeps `[A-Za-z0-9_-]` and replaces everything else with `_`, capping the
  /// result at 80 characters so it cannot overflow filesystem limits.
  static String _sanitize(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in input.runes) {
      final String ch = String.fromCharCode(rune);
      buffer.write(RegExp(r'[A-Za-z0-9_-]').hasMatch(ch) ? ch : '_');
    }
    String out = buffer.toString();
    if (out.length > 80) out = out.substring(0, 80);
    return out;
  }
}
