import 'package:flutter_test/flutter_test.dart';
import 'package:humea/services/notification_service.dart';

void main() {
  group('NotificationService', () {
    test('builds payload for a non-empty token', () {
      final payload = NotificationService.buildFcmTokenPayload('token-123');

      expect(payload['fcmToken'], 'token-123');
      expect(payload.containsKey('fcmTokenUpdatedAt'), isTrue);
    });

    test('returns empty payload when token is null or empty', () {
      expect(NotificationService.buildFcmTokenPayload(null), isEmpty);
      expect(NotificationService.buildFcmTokenPayload(''), isEmpty);
    });
  });
}
