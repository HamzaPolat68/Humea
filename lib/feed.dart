import 'package:flutter/material.dart';
import 'post_model.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (sharedPosts.isEmpty) {
      return const Center(
        child: Text(
          "Henüz bir paylaşım yok...",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: sharedPosts.length,
      // En yeni postun en üstte görünmesi için:
      itemBuilder: (context, index) {
        final post = sharedPosts.reversed.toList()[index];
        return _buildPostCard(post);
      },
    );
  }

  Widget _buildPostCard(Post post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15), // Görseldeki gibi daha az oval
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03), // Çok hafif bir gölge
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profil Bilgisi
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(post.userImage),
              ),
              const SizedBox(width: 10),
              Text(
                post.userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Duygu Başlığı ve Emoji
          Row(
            children: [
              Text(post.moodEmoji, style: const TextStyle(fontSize: 35)),
              const SizedBox(width: 12),
              Text(
                post.moodTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Kullanıcı Notu
          Text(
            post.note,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),

          const Divider(height: 30),

          // Beğen/Paylaş Alt Barı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_interactionButton(Icons.favorite_border, "Beğen")],
          ),
        ],
      ),
    );
  }

  Widget _interactionButton(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
