import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';

class FeedPage extends StatefulWidget {
  final Future<void> Function() onPostDeleted;
  const FeedPage({super.key, required this.onPostDeleted});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  Set<String> _likedCommentIds = {};
  bool isPostLikedByMe = false;

  final String? _currentUserName =
      FirebaseAuth.instance.currentUser?.displayName;

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

    if (mounted) {
      setState(() {
        _likedCommentIds = likedCommentIds;
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
        if (post.userId != user.uid) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'recipientId': post.userId,
            'senderId': user.uid,
            'senderName': user.displayName ?? 'Anonim',
            'type': 'like',
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint("Beğeni hatası: $e");
    }
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
    final bool isMyPost =
        _currentUserName != null && post.userName == _currentUserName;

    debugPrint(
      "DEBUG - Post ID: ${post.id} - User Image Değeri: '${post.userImage}'",
    );

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
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: CircleAvatar(
                  radius: 20,
                  // backgroundImage için ternary operatörü kullanarak mantığı kuruyoruz
                  backgroundImage: post.userImage.isNotEmpty
                      ? (post.userImage.startsWith('http')
                            ? NetworkImage(post.userImage) as ImageProvider
                            : FileImage(File(post.userImage)) as ImageProvider)
                      : null,

                  // Eğer hiç resim yoksa ismin baş harfini göster
                  child: post.userImage.isEmpty
                      ? Text(post.userName[0].toUpperCase())
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _formatDate(post.timestamp),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
              const Spacer(),
              if (isMyPost)
                IconButton(
                  onPressed: () => _deletePostAndMood(post.id, post.timestamp),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color.fromARGB(255, 242, 53, 6),
                  ),
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
          Text(
            post.note,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.4,
            ),
          ),

          const SizedBox(height: 16),
          // Beğeni Barı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Mevcut butonunuza dokunmadık
                _interactionButton(
                  icon: isPostLikedByMe
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: "Beğen",
                  likeCount: post.likes,
                  isLiked: isPostLikedByMe,
                  onLikeToggle: () => _toggleLike(post), // Kalbe basınca
                  onShowLikes: () => _showLikesDialog(
                    context,
                    post.likesList,
                  ), // Sayıya basınca
                ),
                const SizedBox(width: 8),
                // Yeni Yorum Butonu
                // Yorum Butonu
                Expanded(
                  child: _interactionButton(
                    icon: Icons.chat_bubble_outline,
                    label: "Yorum  ",
                    likeCount: post.commentsCount,
                    isLiked: false,
                    onTap: () {
                      // Yorum yazmak için geçici bir controller
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
                          // Klavyenin modalı yukarı itmesini sağlar
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: DraggableScrollableSheet(
                            initialChildSize: 0.6,
                            minChildSize: 0.3,
                            maxChildSize: 0.9,
                            expand: false,
                            builder: (context, scrollController) {
                              return Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    child: const Text(
                                      "Yorumlar",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  // YORUMLARI LİSTELEME
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
                                            child: CircularProgressIndicator(),
                                          );
                                        }

                                        // StreamBuilder içindeki ListView.builder kısmını güncelle
                                        return ListView.builder(
                                          controller: scrollController,
                                          itemCount: snapshot.data!.docs.length,
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
                                                doc['userId'] == currentUserId;
                                            final bool isCommentLiked =
                                                _likedCommentIds.contains(
                                                  doc.id,
                                                );

                                            return ListTile(
                                              title: Text(
                                                doc['userName'] ?? "Anonim",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              subtitle: Text(doc['text'] ?? ""),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Beğeni Sayısı ve Butonu
                                                  Text(
                                                    "${doc['likesCount'] ?? 0}",
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      isCommentLiked
                                                          ? Icons.favorite
                                                          : Icons
                                                                .favorite_border,
                                                      color: isCommentLiked
                                                          ? Colors.grey
                                                          : Colors.red,
                                                    ),
                                                    onPressed: () =>
                                                        _toggleCommentLike(
                                                          post.id,
                                                          doc.id,
                                                        ),
                                                  ),
                                                  // Silme Butonu
                                                  if (isMyComment)
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.delete_outline,

                                                        color: Colors.red,
                                                      ),
                                                      onPressed: () =>
                                                          _deleteComment(
                                                            post.id,
                                                            doc.id,
                                                          ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),

                                  // YORUM YAZMA ALANI
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: commentFieldController,
                                            decoration: InputDecoration(
                                              hintText: "Yorum ekle...",
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.send,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () {
                                            if (commentFieldController.text
                                                .trim()
                                                .isNotEmpty) {
                                              // Yorumu ekle
                                              _addComment(
                                                post.id,
                                                commentFieldController.text,
                                              );
                                              commentFieldController.clear();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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

  Future<void> _addComment(String postId, String text) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final commentText = text.trim();
      if (commentText.isEmpty) return;

      final commentData = {
        'text': commentText,
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonim',
        'timestamp': FieldValue.serverTimestamp(),
        'likesCount': 0, // Başlangıç beğeni sayısı
      };

      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId);
      await postRef.collection('comments').add(commentData);
      await postRef.update({'commentsCount': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('Yorum ekleme hatası: $e');
    }
  }

  Future<void> _toggleCommentLike(String postId, String commentId) async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'liked_comment_$commentId';
    bool isAlreadyLiked = _likedCommentIds.contains(commentId);

    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    await commentRef.update({
      'likesCount': FieldValue.increment(isAlreadyLiked ? -1 : 1),
    });

    await prefs.setBool(key, !isAlreadyLiked);

    if (mounted) {
      setState(() {
        if (isAlreadyLiked) {
          _likedCommentIds.remove(commentId);
        } else {
          _likedCommentIds.add(commentId);
        }
      });
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

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: userImage.isNotEmpty
                              ? (userImage.startsWith('http')
                                    ? NetworkImage(userImage)
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
