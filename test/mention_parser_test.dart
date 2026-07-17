import 'package:flutter_test/flutter_test.dart';
import 'package:humea/services/mention_service.dart';

void main() {
  group('mention parsing', () {
    test('extracts unique mentions from text', () {
      const text =
          'Merhaba @ali, bugün @ayse ile buluşacağım. @ali tekrar etiketlendi.';

      final mentions = extractMentions(text);

      expect(mentions, ['ali', 'ayse']);
    });

    test('returns empty list when there are no mentions', () {
      expect(extractMentions('Sadece normal bir metin'), isEmpty);
    });
  });
}
