import 'package:flutter/material.dart';

class Post {
  final String userName;
  final String userImage;
  final String moodTitle;
  final String moodEmoji;
  final String note;
  final int likeCount;

  Post({
    required this.userName,
    required this.userImage,
    required this.moodTitle,
    required this.moodEmoji,
    required this.note,
    required this.likeCount,
  });
}

List<Post> sharedPosts = [];
