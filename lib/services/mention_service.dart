class MentionService {
  static const String mentionPrefix = '@';

  static List<String> extractMentions(String input) {
    final matches = RegExp(r'@([a-zA-Z0-9_]+)').allMatches(input);
    final mentions = <String>[];

    for (final match in matches) {
      final username = match.group(1)?.trim().toLowerCase();
      if (username != null &&
          username.isNotEmpty &&
          !mentions.contains(username)) {
        mentions.add(username);
      }
    }

    return mentions;
  }
}

List<String> extractMentions(String input) =>
    MentionService.extractMentions(input);
