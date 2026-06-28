import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/post_model.dart';

class FeedPage extends StatefulWidget {
  final Future<void> Function() onPostDeleted;
  const FeedPage({super.key, required this.onPostDeleted});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<String> _likedPostIds = [];
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final String? _currentUserName =
      FirebaseAuth.instance.currentUser?.displayName;

  // KAYDIRMA ÇUBUĞU İÇİN KONTROLLER
  final ScrollController _feedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLikedPosts();
  }

  // Bellek sızıntısını önlemek için controller temizleniyor
  @override
  void dispose() {
    _feedScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLikedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _likedPostIds = prefs.getStringList('liked_posts_history') ?? [];
    });
  }

  Future<void> _toggleLike(String docId) async {
    final prefs = await SharedPreferences.getInstance();
    final bool isAlreadyLiked = _likedPostIds.contains(docId);

    try {
      if (isAlreadyLiked) {
        await FirebaseFirestore.instance.collection('posts').doc(docId).update({
          'likes': FieldValue.increment(-1),
        });
        _likedPostIds.remove(docId);
      } else {
        await FirebaseFirestore.instance.collection('posts').doc(docId).update({
          'likes': FieldValue.increment(1),
        });
        _likedPostIds.add(docId);
      }
      await prefs.setStringList('liked_posts_history', _likedPostIds);
      setState(() {});
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
        final moodData = doc.data() as Map<String, dynamic>;
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
              return _buildPostCard(bulutPostlari[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildPostCard(Post post) {
    final bool isPostLikedByMe = _likedPostIds.contains(post.id);
    final bool isMyPost =
        _currentUserName != null && post.userName == _currentUserName;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 236, 234, 234),
        borderRadius: BorderRadius.circular(24), // Daha yuvarlak köşeler
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
        ), // Çok hafif bir çerçeve
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
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
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: post.userImage.isNotEmpty
                      ? NetworkImage(post.userImage)
                      : null,
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
            child: _interactionButton(
              icon: isPostLikedByMe ? Icons.favorite : Icons.favorite_border,
              label: "Beğen",
              likeCount: post.likes,
              isLiked: isPostLikedByMe,
              onTap: () => _toggleLike(post.id),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(
              icon,
              color: isLiked
                  ? Colors.red
                  : (likeCount > 0 ? Colors.red[300] : Colors.grey[600]),
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              likeCount > 0 ? "$label  •  $likeCount" : label,
              style: TextStyle(
                color: isLiked
                    ? Colors.red[700]
                    : (likeCount > 0 ? Colors.red[300] : Colors.grey[600]),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
