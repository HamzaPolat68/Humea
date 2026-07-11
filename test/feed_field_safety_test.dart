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
  });
}
