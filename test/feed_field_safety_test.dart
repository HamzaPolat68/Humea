import 'package:flutter_test/flutter_test.dart';
import 'package:humea/feed/feed.dart';

void main() {
  group('safe Firestore field reads', () {
    test('returns fallback for missing fields without throwing', () {
      final data = <String, dynamic>{};

      expect(
        () => readSafeStringField(data, 'userImage', fallback: ''),
        returnsNormally,
      );
      expect(readSafeStringField(data, 'userImage', fallback: ''), isEmpty);
      expect(readSafeStringField({'userName': 'Ada'}, 'userName'), 'Ada');
    });

    test('buildNotificationPayload keeps reply context fields', () {
      final payload = buildNotificationPayload(
        recipientId: 'user-2',
        senderId: 'user-1',
        senderName: 'Ada',
        type: 'reply_reply',
        postId: 'post-1',
        commentId: 'comment-1',
        replyId: 'reply-2',
        parentReplyId: 'reply-1',
      );

      expect(payload['recipientId'], 'user-2');
      expect(payload['type'], 'reply_reply');
      expect(payload['commentId'], 'comment-1');
      expect(payload['replyId'], 'reply-2');
      expect(payload['parentReplyId'], 'reply-1');
      expect(payload['isRead'], isFalse);
    });
  });
}
