import 'package:flutter/material.dart';

import '../models/audio_snippet.dart';
import '../models/snippet_comment.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'verified_badge.dart';

/// Modal bottom sheet allowing users and creators to discuss podcast audio highlights and threads.
class SnippetCommentsSheet extends StatefulWidget {
  const SnippetCommentsSheet({
    super.key,
    required this.controller,
    required this.snippet,
  });

  final PlaybackController controller;
  final AudioSnippet snippet;

  static Future<void> show(
    BuildContext context, {
    required PlaybackController controller,
    required AudioSnippet snippet,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SnippetCommentsSheet(
        controller: controller,
        snippet: snippet,
      ),
    );
  }

  @override
  State<SnippetCommentsSheet> createState() => _SnippetCommentsSheetState();
}

class _SnippetCommentsSheetState extends State<SnippetCommentsSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final String text = _textController.text.trim();
    if (text.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    final String currentUserName = widget.controller.username.isNotEmpty
        ? widget.controller.username
        : 'Community Listener';

    final bool isUserVerified = widget.controller.userRole.isCreator;

    final SnippetComment comment = SnippetComment(
      id: 'comment-${DateTime.now().millisecondsSinceEpoch}',
      snippetId: widget.snippet.id,
      userId: 'user-current',
      userName: currentUserName,
      isVerified: isUserVerified,
      text: text,
      createdAt: DateTime.now(),
    );

    await widget.controller.addComment(comment);
    _textController.clear();

    if (mounted) {
      setState(() => _submitting = false);
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final List<SnippetComment> comments =
            widget.controller.commentsFor(widget.snippet.id);

        return Container(
          key: const ValueKey('snippet-comments-sheet'),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: colors.hairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 18, color: colors.podcastAccent),
                  const SizedBox(width: 8),
                  Text(
                    'DISCUSSION (${comments.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: colors.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: colors.muted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              // Snippet Context Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.hairline),
                ),
                child: Row(
                  children: [
                    Icon(Icons.format_quote_rounded,
                        size: 16, color: colors.podcastAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.snippet.caption,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: colors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.hairline),

              // Comments List
              Expanded(
                child: comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forum_outlined,
                                size: 36, color: colors.muted.withValues(alpha: 0.5)),
                            const SizedBox(height: 10),
                            Text(
                              'NO COMMENTS YET',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: colors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Be the first to share your thoughts on this moment.',
                              style: TextStyle(fontSize: 11, color: colors.muted),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        itemCount: comments.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final SnippetComment comment = comments[index];
                          final String initial = comment.userName.isNotEmpty
                              ? comment.userName[0].toUpperCase()
                              : 'U';

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: comment.isVerified
                                    ? colors.accent.withValues(alpha: 0.2)
                                    : colors.podcastAccent.withValues(alpha: 0.15),
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: comment.isVerified
                                        ? colors.accent
                                        : colors.podcastAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          comment.userName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: colors.ink,
                                          ),
                                        ),
                                        if (comment.isVerified) ...[
                                          const SizedBox(width: 4),
                                          const VerifiedBadge(size: 11),
                                        ],
                                        const SizedBox(width: 6),
                                        Text(
                                          '• ${formatUpdatedAgo(comment.createdAt)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      comment.text,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.35,
                                        color: colors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  comment.isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 14,
                                  color: comment.isLiked
                                      ? Colors.redAccent
                                      : colors.muted,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => widget.controller
                                    .toggleLikeComment(comment.id),
                              ),
                            ],
                          );
                        },
                      ),
              ),

              // Bottom Composer
              Divider(height: 1, color: colors.hairline),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('comment-input'),
                      controller: _textController,
                      style: TextStyle(fontSize: 13, color: colors.ink),
                      decoration: InputDecoration(
                        hintText: widget.controller.userRole.isCreator
                            ? 'Reply as verified creator...'
                            : 'Add a thought or reply...',
                        hintStyle:
                            TextStyle(fontSize: 12, color: colors.muted),
                        filled: true,
                        fillColor: colors.background,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.hairline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.hairline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: colors.podcastAccent),
                        ),
                      ),
                      onSubmitted: (_) => _postComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const ValueKey('comment-send-btn'),
                    icon: Icon(Icons.send_rounded,
                        size: 20, color: colors.podcastAccent),
                    onPressed: _submitting ? null : _postComment,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
