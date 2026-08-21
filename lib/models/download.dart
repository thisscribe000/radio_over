/// A podcast episode download: transfer state plus where the audio lives on
/// disk. Deliberately references the episode by id — the full episode object
/// stays in the content catalogue so downloads never duplicate it.
enum DownloadStatus { queued, downloading, paused, completed, failed, cancelled }

class DownloadItem {
  const DownloadItem({
    required this.id,
    required this.episodeId,
    required this.podcastId,
    required this.audioUrl,
    required this.localPath,
    required this.fileName,
    required this.status,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    required this.createdAt,
    this.completedAt,
    this.error,
  });

  /// Stable identifier; one download per episode, so this is the episode id.
  final String id;
  final String episodeId;
  final String podcastId;

  /// The remote source the file came from (kept for re-download/retry).
  final String audioUrl;

  /// Absolute path of the completed audio file. Empty until completion.
  final String localPath;
  final String fileName;
  final DownloadStatus status;

  /// 0..1 when the total size is known; otherwise indeterminate.
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final DateTime createdAt;
  final DateTime? completedAt;

  /// Human-readable failure reason; null unless status is failed.
  final String? error;

  bool get isActive => status == DownloadStatus.queued || status == DownloadStatus.downloading;
  bool get isCompleted => status == DownloadStatus.completed;

  DownloadItem copyWith({
    DownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? localPath,
    DateTime? completedAt,
    String? error,
  }) {
    return DownloadItem(
      id: id,
      episodeId: episodeId,
      podcastId: podcastId,
      audioUrl: audioUrl,
      localPath: localPath ?? this.localPath,
      fileName: fileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'episodeId': episodeId,
        'podcastId': podcastId,
        'audioUrl': audioUrl,
        'localPath': localPath,
        'fileName': fileName,
        'status': status.name,
        'progress': progress,
        'downloadedBytes': downloadedBytes,
        'totalBytes': totalBytes,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'error': error,
      };

  static DownloadItem fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String,
      episodeId: json['episodeId'] as String,
      podcastId: json['podcastId'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      localPath: json['localPath'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      status: DownloadStatus.values.firstWhere(
        (DownloadStatus s) => s.name == json['status'],
        orElse: () => DownloadStatus.failed,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'] as String),
      error: json['error'] as String?,
    );
  }
}
