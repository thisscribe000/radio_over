import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/snippet_comment.dart';

/// Abstract store for persisting community snippet comments.
abstract class SnippetCommentStore {
  Future<List<SnippetComment>> loadComments();
  Future<void> saveComments(List<SnippetComment> comments);
}

/// In-memory implementation used for deterministic widget and unit testing.
class InMemorySnippetCommentStore implements SnippetCommentStore {
  InMemorySnippetCommentStore({List<SnippetComment>? initial})
      : _comments = initial != null ? List.from(initial) : _mockStarterComments();

  final List<SnippetComment> _comments;

  @override
  Future<List<SnippetComment>> loadComments() async => List.unmodifiable(_comments);

  @override
  Future<void> saveComments(List<SnippetComment> comments) async {
    _comments
      ..clear()
      ..addAll(comments);
  }

  static List<SnippetComment> _mockStarterComments() {
    final DateTime now = DateTime.now();
    return [
      SnippetComment(
        id: 'c-1',
        snippetId: 'snippet-starter-1',
        userId: 'u-steve',
        userName: 'Steve Host',
        isVerified: true,
        text: 'Thanks for highlighting this part! In the upcoming episode we explore this even deeper.',
        likesCount: 14,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      SnippetComment(
        id: 'c-2',
        snippetId: 'snippet-starter-1',
        userId: 'u-sarah',
        userName: 'Sarah K.',
        isVerified: false,
        text: 'This exact quote changed how I think about focus.',
        likesCount: 5,
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
      SnippetComment(
        id: 'c-3',
        snippetId: 'snippet-starter-2',
        userId: 'u-tech',
        userName: 'Tech Fan',
        isVerified: false,
        text: 'The explanation on system architecture here was so crisp!',
        likesCount: 8,
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
    ];
  }
}

/// SharedPreferences-backed comment store for device persistence.
class SharedPreferencesSnippetCommentStore implements SnippetCommentStore {
  SharedPreferencesSnippetCommentStore({this.storageKey = 'snippet-comments-v1'});

  final String storageKey;

  @override
  Future<List<SnippetComment>> loadComments() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return InMemorySnippetCommentStore._mockStarterComments();
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => SnippetComment.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return InMemorySnippetCommentStore._mockStarterComments();
    }
  }

  @override
  Future<void> saveComments(List<SnippetComment> comments) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded =
        jsonEncode(comments.map((c) => c.toJson()).toList());
    await prefs.setString(storageKey, encoded);
  }
}
