import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String userName;
  final String userImage;
  final String moodEmoji;
  final String moodTitle;
  final String note;
  final String? imageUrl;
  final List<String> mentions;
  final DateTime timestamp;
  final int likes;
  final int commentsCount; // Yeni: Yorum sayısı
  final List<Map<String, dynamic>> likesList; // Yeni: Beğenenlerin ID listesi

  Post({
    required this.imageUrl,
    required this.id,
    required this.userId,
    required this.userName,
    required this.userImage,
    required this.moodEmoji,
    required this.moodTitle,
    required this.note,
    required this.mentions,
    required this.timestamp,
    required this.likes,
    required this.commentsCount,
    required this.likesList,
  });

  factory Post.fromFirestore(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Anonim',
      userImage: json['userImage'] ?? 'https://via.placeholder.com/150',
      moodEmoji: json['moodEmoji'] ?? '🙂',
      moodTitle: json['moodTitle'] ?? 'Normal',
      note: json['note'] ?? '',
      imageUrl: json['imageUrl'],
      mentions: List<String>.from(
        (json['mentions'] as List<dynamic>? ?? []).map(
          (mention) => mention.toString().toLowerCase(),
        ),
      ),
      likes: json['likes'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0, // Yeni: Yorum sayısı
      // Firebase'den gelen listeyi al, eğer yoksa boş liste döndür
      likesList: List<Map<String, dynamic>>.from(json['likesList'] ?? []),
      timestamp: _parseTimestamp(json['timestamp']),
    );
  }

  static DateTime _parseTimestamp(dynamic ts) {
    if (ts == null) return DateTime.now();
    // If it's a Firestore Timestamp
    if (ts is Timestamp) return ts.toDate();
    // If it's already a DateTime
    if (ts is DateTime) return ts;
    // If it's milliseconds since epoch
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    // If it's a map with seconds/nanoseconds (possible when decoding JSON)
    if (ts is Map<String, dynamic>) {
      if (ts.containsKey('_seconds')) {
        final seconds = ts['_seconds'] as int? ?? 0;
        final nanos = ts['_nanoseconds'] as int? ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanos / 1000000).round(),
        );
      }
      if (ts.containsKey('seconds')) {
        final seconds = ts['seconds'] as int? ?? 0;
        final nanos = ts['nanoseconds'] as int? ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanos / 1000000).round(),
        );
      }
    }
    // Fallback
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'userName': userName,
    'userImage': userImage,
    'moodEmoji': moodEmoji,
    'moodTitle': moodTitle,
    'note': note,
    'imageUrl': imageUrl,
    'mentions': mentions,
    'likes': likes,
    'likesList': likesList, // Firestore'a kaydederken ekle
    'timestamp': FieldValue.serverTimestamp(),
  };
}
