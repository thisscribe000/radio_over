import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/data/timeline/comment_store.dart';
import 'package:radio_over/models/snippet_comment.dart';
import 'package:radio_over/models/user_role.dart';
import 'package:radio_over/playback/playback_controller.dart';

void main() {
  group('SnippetComment & UserRole tests', () {
    test('UserRole properties and labels', () {
      expect(UserRole.listener.label, 'LISTENER');
      expect(UserRole.listener.isCreator, false);

      expect(UserRole.creator.label, 'VERIFIED CREATOR');
      expect(UserRole.creator.isCreator, true);

      expect(UserRole.stationCurator.label, 'STATION CURATOR');
      expect(UserRole.stationCurator.isCurator, true);
    });

    test('SnippetComment toJson and fromJson serialization', () {
      final now = DateTime.now();
      final comment = SnippetComment(
        id: 'c-100',
        snippetId: 'snippet-abc',
        userId: 'u-1',
        userName: 'Host Person',
        isVerified: true,
        text: 'Host perspective on this clip',
        likesCount: 15,
        isLiked: true,
        createdAt: now,
      );

      final json = comment.toJson();
      final restored = SnippetComment.fromJson(json);

      expect(restored.id, 'c-100');
      expect(restored.snippetId, 'snippet-abc');
      expect(restored.userName, 'Host Person');
      expect(restored.isVerified, true);
      expect(restored.text, 'Host perspective on this clip');
      expect(restored.likesCount, 15);
      expect(restored.isLiked, true);
    });

    test('PlaybackController manages user roles, comments and comment likes', () async {
      final commentStore = InMemorySnippetCommentStore(initial: []);
      final controller = PlaybackController(commentStore: commentStore);

      expect(controller.userRole, UserRole.listener);
      controller.setUserRole(UserRole.creator);
      expect(controller.userRole, UserRole.creator);

      final comment = SnippetComment(
        id: 'c-new',
        snippetId: 's-1',
        userId: 'u-user',
        userName: 'Listener',
        text: 'Super insightful highlight!',
        createdAt: DateTime.now(),
      );

      await controller.addComment(comment);

      expect(controller.commentsCountFor('s-1'), 1);
      expect(controller.commentsFor('s-1').first.text, 'Super insightful highlight!');

      // Like comment
      await controller.toggleLikeComment('c-new');
      expect(controller.commentsFor('s-1').first.isLiked, true);
      expect(controller.commentsFor('s-1').first.likesCount, 1);

      // Unlike comment
      await controller.toggleLikeComment('c-new');
      expect(controller.commentsFor('s-1').first.isLiked, false);
      expect(controller.commentsFor('s-1').first.likesCount, 0);

      controller.dispose();
    });
  });
}
