/// Represents an audio highlight snippet trimmed from a podcast episode
/// and shared to the community timeline. Supports single highlights and multi-part threads.
class AudioSnippet {
  const AudioSnippet({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    this.isVerified = false,
    required this.podcastId,
    required this.podcastName,
    required this.episodeId,
    required this.episodeTitle,
    this.episodeImageUrl,
    this.audioUrl,
    required this.start,
    required this.end,
    required this.caption,
    this.likesCount = 0,
    this.isLiked = false,
    this.commentsCount = 0,
    this.threadId,
    this.threadIndex = 1,
    this.threadTotal = 1,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final bool isVerified;
  final String podcastId;
  final String podcastName;
  final String episodeId;
  final String episodeTitle;
  final String? episodeImageUrl;
  final String? audioUrl;
  final Duration start;
  final Duration end;
  final String caption;
  final int likesCount;
  final bool isLiked;
  final int commentsCount;
  final String? threadId;
  final int threadIndex;
  final int threadTotal;
  final DateTime createdAt;

  Duration get snippetDuration => end > start ? end - start : Duration.zero;

  /// Whether this snippet is part of an audio thread (> 1 clip).
  bool get isThread => threadTotal > 1;

  /// Whether this snippet is the root (first card) of an audio thread or standalone.
  bool get isThreadRoot => threadIndex == 1;

  AudioSnippet copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    bool? isVerified,
    String? podcastId,
    String? podcastName,
    String? episodeId,
    String? episodeTitle,
    String? episodeImageUrl,
    String? audioUrl,
    Duration? start,
    Duration? end,
    String? caption,
    int? likesCount,
    bool? isLiked,
    int? commentsCount,
    String? threadId,
    int? threadIndex,
    int? threadTotal,
    DateTime? createdAt,
  }) {
    return AudioSnippet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      isVerified: isVerified ?? this.isVerified,
      podcastId: podcastId ?? this.podcastId,
      podcastName: podcastName ?? this.podcastName,
      episodeId: episodeId ?? this.episodeId,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      episodeImageUrl: episodeImageUrl ?? this.episodeImageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      start: start ?? this.start,
      end: end ?? this.end,
      caption: caption ?? this.caption,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      commentsCount: commentsCount ?? this.commentsCount,
      threadId: threadId ?? this.threadId,
      threadIndex: threadIndex ?? this.threadIndex,
      threadTotal: threadTotal ?? this.threadTotal,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'userName': userName,
        'userAvatarUrl': userAvatarUrl,
        'isVerified': isVerified,
        'podcastId': podcastId,
        'podcastName': podcastName,
        'episodeId': episodeId,
        'episodeTitle': episodeTitle,
        'episodeImageUrl': episodeImageUrl,
        'audioUrl': audioUrl,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'caption': caption,
        'likesCount': likesCount,
        'isLiked': isLiked,
        'commentsCount': commentsCount,
        'threadId': threadId,
        'threadIndex': threadIndex,
        'threadTotal': threadTotal,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AudioSnippet.fromJson(Map<String, dynamic> json) {
    return AudioSnippet(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? 'anonymous',
      userName: json['userName'] as String? ?? 'Listener',
      userAvatarUrl: json['userAvatarUrl'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      podcastId: json['podcastId'] as String,
      podcastName: json['podcastName'] as String,
      episodeId: json['episodeId'] as String,
      episodeTitle: json['episodeTitle'] as String,
      episodeImageUrl: json['episodeImageUrl'] as String?,
      audioUrl: json['audioUrl'] as String?,
      start: Duration(milliseconds: json['startMs'] as int? ?? 0),
      end: Duration(milliseconds: json['endMs'] as int? ?? 30000),
      caption: json['caption'] as String? ?? '',
      likesCount: json['likesCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      commentsCount: json['commentsCount'] as int? ?? 0,
      threadId: json['threadId'] as String?,
      threadIndex: json['threadIndex'] as int? ?? 1,
      threadTotal: json['threadTotal'] as int? ?? 1,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
