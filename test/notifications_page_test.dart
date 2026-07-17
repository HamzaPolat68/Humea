import 'package:flutter_test/flutter_test.dart';
import 'package:humea/notifications/notifications_page.dart';

void main() {
  group('notification message builder', () {
    test('returns the right copy for reply notifications', () {
      final message = buildNotificationMessage({
        'type': 'reply',
        'senderName': 'Ada',
      });

      expect(message, 'Ada yanıt verdi.');
    });

    test('returns the right copy for like notifications', () {
      final message = buildNotificationMessage({
        'type': 'like',
        'senderName': 'Efe',
      });

      expect(message, 'Efe gönderini beğendi.');
    });
  });
}
