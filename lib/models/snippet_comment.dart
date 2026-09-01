/// Represents a comment/reply left on a podcast audio snippet or thread.
class SnippetComment {
  const SnippetComment({
    required this.id,
    required this.snippetId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    this.isVerified = false,
    required this.text,
    this.likesCount = 0,
    this.isLiked = false,
    required this.createdAt,
  });

  final String id;
  final String snippetId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final bool isVerified;
  final String text;
  final int likesCount;
  final bool isLiked;
  final DateTime createdAt;

  SnippetComment copyWith({
    String? id,
    String? snippetId,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    bool? isVerified,
    String? text,
    int? likesCount,
    bool? isLiked,
    DateTime? createdAt,
  }) {
    return SnippetComment(
      id: id ?? this.id,
      snippetId: snippetId ?? this.snippetId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      isVerified: isVerified ?? this.isVerified,
      text: text ?? this.text,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'snippetId': snippetId,
        'userId': userId,
        'userName': userName,
        'userAvatarUrl': userAvatarUrl,
        'isVerified': isVerified,
        'text': text,
        'likesCount': likesCount,
        'isLiked': isLiked,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SnippetComment.fromJson(Map<String, dynamic> json) {
    return SnippetComment(
      id: json['id'] as String,
      snippetId: json['snippetId'] as String,
      userId: json['userId'] as String? ?? 'anonymous',
      userName: json['userName'] as String? ?? 'Listener',
      userAvatarUrl: json['userAvatarUrl'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      text: json['text'] as String? ?? '',
      likesCount: json['likesCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
