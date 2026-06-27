import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId; // Firebase'deki döküman ID'sini tutmak için şart
  final String userName;
  final String userImage;
  final String moodEmoji;
  final String moodTitle;
  final String note;
  final DateTime timestamp;
  final int likes;

  Post({
    required this.id,
    required this.userId, // ID artık zorunlu
    required this.userName,
    required this.userImage,
    required this.moodEmoji,
    required this.moodTitle,
    required this.note,
    required this.timestamp,
    required this.likes,
  });

  // Buluttan (Firebase) gelen veriyi bizim Post modeline çevirir
  factory Post.fromFirestore(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? '',
      userId:
          json['userId'] ??
          '', // FeedPage'de eşlediğimiz döküman ID'sini alıyor
      userName: json['userName'] ?? 'Anonim',
      userImage: json['userImage'] ?? 'https://via.placeholder.com/150',
      moodEmoji: json['moodEmoji'] ?? '🙂',
      moodTitle: json['moodTitle'] ?? 'Normal',
      note: json['note'] ?? '',
      // Eğer Firebase'de henüz likes alanı yoksa varsayılan olarak 0 kabul et
      likes: json['likes'] ?? 0,
      // Firebase'in özel Timestamp tipini DateTime'a çeviriyoruz
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Bizim Post modelini Firebase'in anlayacağı Map formatına çevirir
  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'userName': userName,
    'userImage': userImage,
    'moodEmoji': moodEmoji,
    'moodTitle': moodTitle,
    'note': note,
    'likes': likes,
    'timestamp': FieldValue.serverTimestamp(), // Sunucu saatini baz alır
  };
}
