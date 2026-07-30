import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:humea/models/post_model.dart';
import 'package:humea/search/other_user_profile_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

String readSafeStringField(
  Object? data,
  String fieldName, {
  String fallback = '',
}) {
  if (data is Map) {
    final value = data[fieldName];
    if (value == null) {
      return fallback;
    }
    return value.toString();
  }
  return fallback;
}

int readSafeIntField(Object? data, String fieldName, {int fallback = 0}) {
  if (data is Map) {
    final value = data[fieldName];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

// Extract first http(s) URL from a possibly-wrapped string like
// "[https://via.placeholder.com/150]()" or other markdown-like wrappers.
String? extractFirstUrl(String input) {
  try {
    final match = RegExp(r'https?:\/\/[^\s)\]]+').firstMatch(input);
    return match?.group(0);
  } catch (_) {
    return null;
  }
}

Future<void> _launchUrl(String url) async {
  String fixedUrl = url;
  if (!fixedUrl.startsWith('http://') && !fixedUrl.startsWith('https://')) {
    fixedUrl = 'https://$fixedUrl';
  }
  final uri = Uri.tryParse(fixedUrl);
  if (uri == null) return;
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint('Link açılamadı: $fixedUrl');
  }
}

// Metindeki linkleri tıklanabilir yapan RichText widget'ı üretir.
Widget buildLinkifiedText(
  String text, {
  TextStyle? style,
  TextStyle? linkStyle,
}) {
  final RegExp urlRegex = RegExp(r'(https?:\/\/[^\s]+|www\.[^\s]+)');
  final List<InlineSpan> spans = [];
  int lastEnd = 0;

  for (final match in urlRegex.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }

    final String url = match.group(0)!;
    spans.add(
      TextSpan(
        text: url,
        style:
            linkStyle ??
            const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
        recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(url),
      ),
    );

    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }

  return RichText(
    text: TextSpan(
      style: style ?? const TextStyle(color: Colors.black),
      children: spans,
    ),
  );
}

Map<String, dynamic> buildNotificationPayload({
  required String recipientId,
  required String senderId,
  required String senderName,
  required String type,
  required String postId,
  String? commentId,
  String? replyId,
  String? parentReplyId,
}) {
  final payload = <String, dynamic>{
    'recipientId': recipientId,
    'senderId': senderId,
    'senderName': senderName,
    'type': type,
    'postId': postId,
    'isRead': false,
    'timestamp': FieldValue.serverTimestamp(),
  };

  if (commentId != null && commentId.isNotEmpty) {
    payload['commentId'] = commentId;
  }
  if (replyId != null && replyId.isNotEmpty) {
    payload['replyId'] = replyId;
  }
  if (parentReplyId != null && parentReplyId.isNotEmpty) {
    payload['parentReplyId'] = parentReplyId;
  }

  return payload;
}

class FeedPage extends StatefulWidget {
  final Future<void> Function() onPostDeleted;
  const FeedPage({super.key, required this.onPostDeleted});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  Set<String> _likedCommentIds = {};
  Set<String> _likedReplyIds = {};
  final Set<String> _likedPostIds = {};
  bool isPostLikedByMe = false;

  // KAYDIRMA ÇUBUĞU İÇİN KONTROLLER
  final ScrollController _feedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLikedPosts();
    _loadLikedComments();
  }

  // Bellek sızıntısını önlemek için controller temizleniyor
  @override
  void dispose() {
    _feedScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLikedPosts() async {
    // SharedPreferences for liked posts can be managed locally if needed
  }

  Future<void> _loadLikedComments() async {
    final prefs = await SharedPreferences.getInstance();
    final likedCommentIds = prefs
        .getKeys()
        .where((key) => key.startsWith('liked_comment_'))
        .map((key) => key.substring('liked_comment_'.length))
        .toSet();

    final likedReplyIds = prefs
        .getKeys()
        .where((key) => key.startsWith('liked_reply_'))
        .map((key) => key.substring('liked_reply_'.length))
        .toSet();

    if (mounted) {
      setState(() {
        _likedCommentIds = likedCommentIds;
        _likedReplyIds = likedReplyIds;
      });
    }
  }

  Future<void> _toggleLike(Post post) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('posts').doc(post.id);

    // HER SEFERİNDE GÜNCEL LİSTEYE BAKARAK KONTROL ET
    final bool isCurrentlyLiked = post.likesList.any(
      (like) => like['userId'] == user.uid,
    );

    try {
      if (isCurrentlyLiked) {
        // Beğeniyi kaldır
        await docRef.update({
          'likes': FieldValue.increment(-1),
          'likesList': FieldValue.arrayRemove([
            {
              'userId': user.uid,
              'userName': user.displayName ?? 'Anonim',
              'userImage': user.photoURL ?? '',
            },
          ]),
        });
      } else {
        // Beğeniyi ekle
        await docRef.update({
          'likes': FieldValue.increment(1),
          'likesList': FieldValue.arrayUnion([
            {
              'userId': user.uid,
              'userName': user.displayName ?? 'Anonim',
              'userImage': user.photoURL ?? '',
            },
          ]),
        });

        // Bildirim kısmı...
        // Bildirim kısmı...
        if (post.userId != user.uid) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'recipientId': post.userId,
            'senderId': user.uid,
            'senderName': user.displayName ?? 'Anonim',
            'type': 'like',
            'postId': post.id,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint("Beğeni hatası: $e");
    }
  }

  Future<void> _editPost(Post post) async {
    final TextEditingController editController = TextEditingController(
      text: post.note,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Paylaşımı Düzenle"),
        content: TextField(
          controller: editController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: "Yeni düşüncelerinizi yazın...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(post.id)
                    .update({'note': editController.text.trim()});
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePostAndMood(String docId, DateTime postDate) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) return;

      // 1. Paylaşımı Sil
      await firestore.collection('posts').doc(docId).delete();

      // 2. İlgili mood kaydını bul ve sil
      double deletedMoodValue = 0.0;
      bool moodDeleted = false;
      final moodQuery = await firestore
          .collection('moods')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in moodQuery.docs) {
        final moodData = doc.data();
        final Timestamp ts = moodData['date'] as Timestamp;
        final DateTime moodDate = ts.toDate();

        if (moodDate.year == postDate.year &&
            moodDate.month == postDate.month &&
            moodDate.day == postDate.day) {
          final dynamic moodValueRaw =
              moodData['moodValue'] ??
              moodData['value'] ??
              moodData['score'] ??
              moodData['mood_score'];

          if (moodValueRaw is num) {
            deletedMoodValue = moodValueRaw.toDouble();
          } else if (moodValueRaw is String) {
            deletedMoodValue = double.tryParse(moodValueRaw) ?? 0.0;
          }

          await doc.reference.delete();
          moodDeleted = true;
          break;
        }
      }

      if (moodDeleted) {
        // 3. mood_stats Güncelleme (Atomic Transaction kullanılması önerilir)
        await firestore.runTransaction((transaction) async {
          DocumentReference statsRef = firestore
              .collection('mood_stats')
              .doc(userId);
          DocumentSnapshot statsSnapshot = await transaction.get(statsRef);

          if (statsSnapshot.exists) {
            Map<String, dynamic> data =
                statsSnapshot.data() as Map<String, dynamic>;

            // Örnek: Toplam puan ve sayı üzerinden yeni ortalama hesaplama
            int currentCount = data['count'] ?? 1;
            double currentTotal = (data['totalScore'] ?? deletedMoodValue)
                .toDouble();

            int newCount = currentCount > 1 ? currentCount - 1 : 0;
            double newTotal = currentTotal - deletedMoodValue;
            double newAverage = newCount > 0 ? (newTotal / newCount) : 0;

            transaction.update(statsRef, {
              'totalScore': newTotal,
              'count': newCount,
              'averageScore': newAverage,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }
        });
      }

      // 4. UI'ı Güncelle
      await widget.onPostDeleted();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Kayıt ve istatistikler başarıyla güncellendi."),
          ),
        );
      }
    } catch (e) {
      debugPrint("Silme hatası: $e");
    }
  }

  Future<void> _editComment(
    String postId,
    String commentId,
    String currentText,
  ) async {
    final TextEditingController editController = TextEditingController(
      text: currentText,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yorumu Düzenle"),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Yeni yorumunuzu girin"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .collection('comments')
                    .doc(commentId)
                    .update({'text': editController.text.trim()});
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  void _openUserProfile(
    BuildContext context, {
    required String userId,
    required String userName,
    required String userImage,
  }) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (userId.isEmpty || userId == currentUserId) {
      return; // kendi profiline gitmesin
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfilePage(
          targetUserId: userId,
          targetUserName: userName,
          targetPhotoUrl: userImage,
        ),
      ),
    );
  }

  // TARİH FORMATLAMA FONKSİYONU (Paketsiz Türkçe Format)
  String _formatDate(DateTime dateTime) {
    final List<String> months = [
      "Ocak",
      "Şubat",
      "Mart",
      "Nisan",
      "Mayıs",
      "Haziran",
      "Temmuz",
      "Ağustos",
      "Eylül",
      "Ekim",
      "Kasım",
      "Aralık",
    ];

    final String day = dateTime.day.toString();
    final String month = months[dateTime.month - 1];
    final String year = dateTime.year.toString();
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');

    return "$day $month $year - $hour:$minute";
  }

  String? _resolveDisplayUserImage({
    required String userId,
    required String fallbackImage,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.uid == userId) {
      final liveImage = currentUser.photoURL?.trim();
      if (liveImage != null && liveImage.isNotEmpty) {
        return liveImage;
      }
    }

    final trimmedFallback = fallbackImage.trim();
    return trimmedFallback.isNotEmpty ? trimmedFallback : null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Hata: ${snapshot.error}",
              style: const TextStyle(color: Colors.white),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "Henüz bir paylaşım yok...",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final List<Post> bulutPostlari = [];

        for (var doc in docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            if (data['timestamp'] == null) continue;
            data['id'] = doc.id;
            bulutPostlari.add(Post.fromFirestore(data));
          } catch (e) {
            debugPrint("Dönüşüm hatası: $e");
          }
        }

        // ETKİLEŞİMLİ VE ŞIK KAYDIRMA ÇUBUĞU
        return Scrollbar(
          controller: _feedScrollController,
          thumbVisibility: true,
          trackVisibility: false,
          thickness: 6.0,
          radius: const Radius.circular(10),
          interactive: true,
          child: ListView.builder(
            controller: _feedScrollController,
            padding: const EdgeInsets.all(15),
            physics: const BouncingScrollPhysics(),
            itemCount: bulutPostlari.length,
            itemBuilder: (context, index) {
              final post = bulutPostlari[index];
              return _buildPostCard(
                post,
                key: ValueKey(post.id),
              ); // ValueKey ekledik
            },
          ),
        );
      },
    );
  }

  Widget _buildPostCard(Post post, {Key? key}) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool isPostLikedByMe =
        currentUserId != null &&
        post.likesList.any((like) => like['userId'] == currentUserId);
    final bool isMyPost = currentUserId != null && post.userId == currentUserId;

    debugPrint(
      "DEBUG - Post ID: ${post.id} - User Image Değeri: '${post.userImage}'",
    );

    final String? effectivePostImage = _resolveDisplayUserImage(
      userId: post.userId,
      fallbackImage: post.userImage,
    );
    final String? postImageUrl = effectivePostImage != null
        ? extractFirstUrl(effectivePostImage)
        : null;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 20),

      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 236, 234, 234),
        borderRadius: BorderRadius.circular(24), // Daha yuvarlak köşeler
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
        ), // Çok hafif bir çerçeve
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20), // İç boşlukları artırdık
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openUserProfile(
                    context,
                    userId: post.userId,
                    userName: post.userName,
                    userImage: post.userImage,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: effectivePostImage != null
                              ? (postImageUrl != null
                                    ? NetworkImage(postImageUrl)
                                          as ImageProvider
                                    : FileImage(File(effectivePostImage))
                                          as ImageProvider)
                              : null,
                          child: effectivePostImage == null
                              ? Text(post.userName[0].toUpperCase())
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.userName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _formatDate(post.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 3. Butonlar (SABİT GENİŞLİKLİ - Taşmayı tamamen engeller)
              if (isMyPost)
                Row(
                  mainAxisSize:
                      MainAxisSize.min, // Sadece butonlar kadar yer kapla
                  children: [
                    IconButton(
                      padding: EdgeInsets.all(
                        4,
                      ), // Çok küçük bir padding verelim
                      constraints:
                          const BoxConstraints(), // Padding dışı alanı sıfırla
                      onPressed: () => _editPost(post),
                      icon: const Icon(
                        Icons.edit_note,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          _deletePostAndMood(post.id, post.timestamp),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Mood Bölümü
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 61, 71, 78),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  post.moodEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                post.moodTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          buildLinkifiedText(
            post.note,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.4,
            ),
          ),

          // PAYLAŞILAN FOTOĞRAF (varsa göster)
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                post.imageUrl!,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 250,
                    alignment: Alignment.center,
                    color: Colors.grey[200],
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  alignment: Alignment.center,
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: 40,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          // Beğeni Barı
          // Beğeni Barı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Beğeni Butonu
                Expanded(
                  child: _interactionButton(
                    icon: isPostLikedByMe
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: "Beğen",
                    likeCount: post.likes,
                    isLiked: isPostLikedByMe,
                    onLikeToggle: () => _toggleLike(post),
                    onShowLikes: () =>
                        _showLikesDialog(context, post.likesList),
                  ),
                ),
                const SizedBox(width: 4),
                // Yorum Butonu
                Expanded(
                  child: _interactionButton(
                    icon: Icons.chat_bubble_outline,
                    label: "Yorum",
                    likeCount: post.commentsCount,
                    isLiked: false,
                    onTap: () {
                      final TextEditingController commentFieldController =
                          TextEditingController();

                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (context) => Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: DraggableScrollableSheet(
                            initialChildSize: 0.6,
                            minChildSize: 0.3,
                            maxChildSize: 0.9,
                            expand: false,
                            builder: (context, scrollController) {
                              return StatefulBuilder(
                                builder: (context, modalSetState) {
                                  return Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        child: const Text(
                                          "Yorumlar",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('posts')
                                              .doc(post.id)
                                              .collection('comments')
                                              .orderBy(
                                                'timestamp',
                                                descending: true,
                                              )
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData) {
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            }

                                            if (snapshot.data!.docs.isEmpty) {
                                              return const Center(
                                                child: Text(
                                                  "Henüz yorum yapılmamış.",
                                                  style: TextStyle(
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              );
                                            }

                                            return ListView.builder(
                                              controller: scrollController,
                                              itemCount:
                                                  snapshot.data!.docs.length,
                                              itemBuilder: (context, index) {
                                                var doc =
                                                    snapshot.data!.docs[index];
                                                final String currentUserId =
                                                    FirebaseAuth
                                                        .instance
                                                        .currentUser
                                                        ?.uid ??
                                                    "";
                                                final bool isMyComment =
                                                    doc['userId'] ==
                                                    currentUserId;
                                                final bool isCommentLiked =
                                                    _likedCommentIds.contains(
                                                      doc.id,
                                                    );

                                                return _buildCommentItem(
                                                  postId: post.id,
                                                  doc: doc,
                                                  isMyComment: isMyComment,
                                                  isCommentLiked:
                                                      isCommentLiked,
                                                  onLikePressed: () {
                                                    modalSetState(() {
                                                      _toggleCommentLike(
                                                        post.id,
                                                        doc.id,
                                                        avoidParentSetState:
                                                            true,
                                                      );
                                                    });
                                                  },
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller:
                                                    commentFieldController,
                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText: "Yorum ekle...",
                                                  hintStyle: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                  filled: true,
                                                  fillColor: Colors.grey[100],
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color:
                                                                  Colors.blue,
                                                            ),
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color:
                                                              Colors.grey[300]!,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.send,
                                                color: Colors.blue,
                                              ),
                                              onPressed: () {
                                                if (commentFieldController.text
                                                    .trim()
                                                    .isNotEmpty) {
                                                  _addComment(
                                                    post.id,
                                                    commentFieldController.text,
                                                    post.userId,
                                                  );
                                                  commentFieldController
                                                      .clear();
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _interactionButton({
    required IconData icon,
    required String label,
    required int likeCount,
    required bool isLiked,
    VoidCallback? onLikeToggle,
    VoidCallback? onShowLikes,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            // Kalp İkonu
            IconButton(
              icon: Icon(icon, color: isLiked ? Colors.red : Colors.grey[600]),
              onPressed: onLikeToggle,
              constraints: const BoxConstraints(), // Padding'i küçültmek için
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 6),
            // Sayı ve Label (Tıklanınca beğenenleri gösterir)
            GestureDetector(
              onTap: onShowLikes,
              child: Text(
                likeCount > 0 ? "$label • $likeCount" : label,
                style: TextStyle(
                  color: isLiked ? Colors.red[700] : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  decoration: onShowLikes != null
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReplyDialog({
    required String postId,
    required String commentId,
    required String recipientId,
    String? parentReplyId,
  }) async {
    final TextEditingController replyController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yanıtla'),
        content: TextField(
          controller: replyController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Yanıtınızı yazın'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final replyText = replyController.text.trim();
              if (replyText.isEmpty) return;

              await _addReply(
                postId,
                commentId,
                replyText,
                recipientId,
                parentReplyId: parentReplyId,
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  Future<void> _addComment(
    String postId,
    String text,
    String recipientUserId,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final commentText = text.trim();
      if (commentText.isEmpty) return;

      final commentData = {
        'text': commentText,
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonim',
        'userImage': user.photoURL ?? '',
        // Use a client-side timestamp so the comment appears immediately
        // in queries that order by 'timestamp'. ServerTimestamp can be
        // null until the server writes it, which may hide the doc in
        // ordered queries temporarily.
        'timestamp': Timestamp.now(),
        'likesCount': 0, // Başlangıç beğeni sayısı
      };

      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId);
      await postRef.collection('comments').add(commentData);
      await postRef.update({'commentsCount': FieldValue.increment(1)});

      if (recipientUserId != user.uid) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .add(
              buildNotificationPayload(
                recipientId: recipientUserId,
                senderId: user.uid,
                senderName: user.displayName ?? 'Anonim',
                type: 'comment',
                postId: postId,
              ),
            );
      }
    } catch (e) {
      debugPrint('Yorum ekleme hatası: $e');
    }
  }

  Future<void> _addReply(
    String postId,
    String commentId,
    String text,
    String recipientUserId, {
    String? parentReplyId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final replyText = text.trim();
      if (replyText.isEmpty) return;

      final replyData = {
        'text': replyText,
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonim',
        'userImage': user.photoURL ?? '',
        // Use local timestamp for immediate visibility in the UI
        'timestamp': Timestamp.now(),
        'likesCount': 0,
        'parentReplyId': parentReplyId ?? '',
      };

      final commentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      final replyDocRef = await commentRef.collection('replies').add(replyData);
      await commentRef.update({'repliesCount': FieldValue.increment(1)});

      if (recipientUserId != user.uid) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .add(
              buildNotificationPayload(
                recipientId: recipientUserId,
                senderId: user.uid,
                senderName: user.displayName ?? 'Anonim',
                type: parentReplyId != null && parentReplyId.isNotEmpty
                    ? 'reply_reply'
                    : 'reply',
                postId: postId,
                commentId: commentId,
                replyId: replyDocRef.id,
                parentReplyId: parentReplyId,
              ),
            );
      }
    } catch (e) {
      debugPrint('Yanıt ekleme hatası: $e');
    }
  }

  Future<void> _toggleCommentLike(
    String postId,
    String commentId, {
    bool avoidParentSetState = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'liked_comment_$commentId';
    bool isAlreadyLiked = _likedCommentIds.contains(commentId);

    if (isAlreadyLiked) {
      _likedCommentIds.remove(commentId);
    } else {
      _likedCommentIds.add(commentId);
    }

    // If caller wants the parent to rebuild, trigger setState here.
    if (!avoidParentSetState && mounted) {
      setState(() {});
    }

    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    try {
      await commentRef.update({
        'likesCount': FieldValue.increment(isAlreadyLiked ? -1 : 1),
      });

      if (!isAlreadyLiked) {
        final commentDoc = await commentRef.get();
        final commentData = commentDoc.data();
        final String commentOwnerId = commentData?['userId']?.toString() ?? '';
        final String senderName =
            FirebaseAuth.instance.currentUser?.displayName ?? 'Anonim';

        if (commentOwnerId.isNotEmpty &&
            commentOwnerId != FirebaseAuth.instance.currentUser?.uid) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'recipientId': commentOwnerId,
            'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
            'senderName': senderName,
            'type': 'comment_like',
            'postId': postId,
            'commentId': commentId,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      await prefs.setBool(key, !isAlreadyLiked);
    } catch (e) {
      debugPrint('Yorum beğeni güncelleme hatası: $e');
      // Revert optimistic change on error
      if (isAlreadyLiked) {
        _likedCommentIds.add(commentId);
      } else {
        _likedCommentIds.remove(commentId);
      }
      if (!avoidParentSetState && mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _toggleReplyLike(
    String postId,
    String commentId,
    String replyId, {
    bool avoidParentSetState = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'liked_reply_$replyId';
    bool isAlreadyLiked = _likedReplyIds.contains(replyId);

    if (isAlreadyLiked) {
      _likedReplyIds.remove(replyId);
    } else {
      _likedReplyIds.add(replyId);
    }

    if (!avoidParentSetState && mounted) setState(() {});

    final replyRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);

    try {
      await replyRef.update({
        'likesCount': FieldValue.increment(isAlreadyLiked ? -1 : 1),
      });

      if (!isAlreadyLiked) {
        final replyDoc = await replyRef.get();
        final replyData = replyDoc.data();
        final String replyOwnerId = replyData?['userId']?.toString() ?? '';
        final String senderName =
            FirebaseAuth.instance.currentUser?.displayName ?? 'Anonim';

        if (replyOwnerId.isNotEmpty &&
            replyOwnerId != FirebaseAuth.instance.currentUser?.uid) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'recipientId': replyOwnerId,
            'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
            'senderName': senderName,
            'type': 'reply_like',
            'postId': postId,
            'commentId': commentId,
            'replyId': replyId,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      await prefs.setBool(key, !isAlreadyLiked);
    } catch (e) {
      debugPrint('Reply like update error: $e');
      if (isAlreadyLiked) {
        _likedReplyIds.add(replyId);
      } else {
        _likedReplyIds.remove(replyId);
      }
      if (!avoidParentSetState && mounted) setState(() {});
    }
  }

  Future<void> _deleteComment(String postId, String commentId) async {
    try {
      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId);
      await postRef.collection('comments').doc(commentId).delete();
      await postRef.update({'commentsCount': FieldValue.increment(-1)});
    } catch (e) {
      debugPrint('Yorum silme hatası: $e');
    }
  }

  Future<void> _deleteReply(
    String postId,
    String commentId,
    String replyId,
  ) async {
    try {
      final commentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      await commentRef.collection('replies').doc(replyId).delete();
      await commentRef.update({'repliesCount': FieldValue.increment(-1)});
    } catch (e) {
      debugPrint('Yanıt silme hatası: $e');
    }
  }

  Widget _buildCommentItem({
    required String postId,
    required QueryDocumentSnapshot doc,
    required bool isMyComment,
    required bool isCommentLiked,
    VoidCallback? onLikePressed,
  }) {
    final commentData = doc.data();
    final String userImage = readSafeStringField(commentData, 'userImage');
    final String userName = readSafeStringField(
      commentData,
      'userName',
      fallback: 'Anonim',
    );
    final String commentText = readSafeStringField(commentData, 'text');
    final int likesCount = readSafeIntField(commentData, 'likesCount');
    final Timestamp? timestamp = (commentData is Map)
        ? (commentData['timestamp'] as Timestamp?)
        : null;
    final String commentOwnerId = readSafeStringField(commentData, 'userId');
    final String? effectiveCommentImage = _resolveDisplayUserImage(
      userId: commentOwnerId,
      fallbackImage: userImage,
    );
    final String? commentImageUrl = effectiveCommentImage != null
        ? extractFirstUrl(effectiveCommentImage)
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blueGrey[50],
                backgroundImage: effectiveCommentImage != null
                    ? (commentImageUrl != null
                          ? NetworkImage(commentImageUrl) as ImageProvider
                          : FileImage(File(effectiveCommentImage))
                                as ImageProvider)
                    : null,
                child: effectiveCommentImage == null
                    ? Text(
                        userName.isNotEmpty
                            ? userName.substring(0, 1).toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              GestureDetector(
                                onTap: () => _openUserProfile(
                                  context,
                                  userId: readSafeStringField(
                                    commentData,
                                    'userId',
                                  ),
                                  userName: userName,
                                  userImage: userImage,
                                ),
                                child: Text(
                                  userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Text(
                                _formatDate(
                                  timestamp?.toDate() ?? DateTime.now(),
                                ),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // YORUM METNİ (DÜZELTİLEN KISIM)
                    buildLinkifiedText(
                      commentText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      linkStyle: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),

                    const SizedBox(height: 8),
                    // Replies (yorum yanıtları) görüntüleme
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(postId)
                          .collection('comments')
                          .doc(doc.id)
                          .collection('replies')
                          .orderBy('timestamp', descending: false)
                          .snapshots(),
                      builder: (context, replySnap) {
                        if (!replySnap.hasData ||
                            replySnap.data!.docs.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          children: replySnap.data!.docs.map((replyDoc) {
                            final reply =
                                replyDoc.data() as Map<String, dynamic>;
                            final String rUserName = readSafeStringField(
                              reply,
                              'userName',
                              fallback: 'Anonim',
                            );
                            final String rText = readSafeStringField(
                              reply,
                              'text',
                            );
                            final Timestamp? rTs =
                                reply['timestamp'] as Timestamp?;
                            final String rTime = _formatDate(
                              rTs?.toDate() ?? DateTime.now(),
                            );
                            final String rUserImg = readSafeStringField(
                              reply,
                              'userImage',
                            );
                            final String rOwnerId = readSafeStringField(
                              reply,
                              'userId',
                            );
                            final String? effectiveReplyImage =
                                _resolveDisplayUserImage(
                                  userId: rOwnerId,
                                  fallbackImage: rUserImg,
                                );
                            final String? rImageUrl =
                                effectiveReplyImage != null
                                ? extractFirstUrl(effectiveReplyImage)
                                : null;
                            final int rLikesCount = readSafeIntField(
                              reply,
                              'likesCount',
                            );
                            final bool isReplyLiked = _likedReplyIds.contains(
                              replyDoc.id,
                            );
                            final bool isMyReply =
                                rOwnerId.isNotEmpty &&
                                rOwnerId ==
                                    FirebaseAuth.instance.currentUser?.uid;

                            return Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundImage: effectiveReplyImage != null
                                        ? (rImageUrl != null
                                                  ? NetworkImage(rImageUrl)
                                                  : FileImage(
                                                      File(effectiveReplyImage),
                                                    ))
                                              as ImageProvider
                                        : null,
                                    child: effectiveReplyImage == null
                                        ? Text(
                                            rUserName.isNotEmpty
                                                ? rUserName[0].toUpperCase()
                                                : 'A',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          rUserName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          rText,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          rTime,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: () => _showReplyDialog(
                                            postId: postId,
                                            commentId: doc.id,
                                            recipientId: rOwnerId,
                                            parentReplyId: replyDoc.id,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.reply,
                                                size: 14,
                                                color: Colors.blue,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Yanıtla',
                                                style: TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('posts')
                                              .doc(postId)
                                              .collection('comments')
                                              .doc(doc.id)
                                              .collection('replies')
                                              .where(
                                                'parentReplyId',
                                                isEqualTo: replyDoc.id,
                                              )
                                              .snapshots(),
                                          builder: (context, childReplySnap) {
                                            if (!childReplySnap.hasData ||
                                                childReplySnap
                                                    .data!
                                                    .docs
                                                    .isEmpty) {
                                              return const SizedBox.shrink();
                                            }

                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                                left: 6,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: childReplySnap.data!.docs.map((
                                                  childReplyDoc,
                                                ) {
                                                  final childReply =
                                                      childReplyDoc.data()
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >;
                                                  final childUserName =
                                                      readSafeStringField(
                                                        childReply,
                                                        'userName',
                                                        fallback: 'Anonim',
                                                      );
                                                  final childText =
                                                      readSafeStringField(
                                                        childReply,
                                                        'text',
                                                      );
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 4,
                                                        ),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .subdirectory_arrow_right,
                                                          size: 12,
                                                          color:
                                                              Colors.blueGrey,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            '$childUserName: $childText',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .blueGrey[700],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _toggleReplyLike(
                                          postId,
                                          doc.id,
                                          replyDoc.id,
                                        ),
                                        icon: Icon(
                                          isReplyLiked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: isReplyLiked
                                              ? Colors.red
                                              : Colors.grey,
                                          size: 18,
                                        ),
                                      ),
                                      Text(
                                        '$rLikesCount',
                                        style: TextStyle(
                                          color: isReplyLiked
                                              ? Colors.red[700]
                                              : Colors.grey[600],
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (isMyReply)
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _deleteReply(
                                            postId,
                                            doc.id,
                                            replyDoc.id,
                                          ),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed:
                        onLikePressed ??
                        () => _toggleCommentLike(postId, doc.id),
                    icon: Icon(
                      isCommentLiked ? Icons.favorite : Icons.favorite_border,
                      color: isCommentLiked ? Colors.red : Colors.grey,
                      size: 22,
                    ),
                  ),
                  Text(
                    '$likesCount',
                    style: TextStyle(
                      color: isCommentLiked
                          ? Colors.red[700]
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showReplyDialog(
                  postId: postId,
                  commentId: doc.id,
                  recipientId: readSafeStringField(commentData, 'userId'),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.reply, size: 18, color: Colors.blue),
                      SizedBox(width: 6),
                      Text(
                        'Yanıtla',
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (isMyComment) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _editComment(postId, doc.id, commentText),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                        SizedBox(width: 6),
                        Text(
                          'Düzenle',
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _deleteComment(postId, doc.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 6),
                        Text(
                          'Sil',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

void _showLikesDialog(
  BuildContext context,
  List<Map<String, dynamic>> likesList,
) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Beğenenler",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: likesList.isEmpty
                ? const Center(child: Text("Henüz beğenen yok."))
                : ListView.builder(
                    itemCount: likesList.length,
                    itemBuilder: (context, index) {
                      final like = likesList[index];
                      final String userImage = (like['userImage'] ?? '')
                          .toString();
                      final String userName = (like['userName'] ?? 'Anonim')
                          .toString();

                      final String? likeImageUrl = extractFirstUrl(userImage);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: userImage.isNotEmpty
                              ? (likeImageUrl != null
                                    ? NetworkImage(likeImageUrl)
                                    : FileImage(File(userImage)))
                              : null,
                          child: userImage.isEmpty
                              ? Text(
                                  userName.isNotEmpty
                                      ? userName[0].toUpperCase()
                                      : 'A',
                                )
                              : null,
                        ),
                        title: Text(userName),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );
}
