import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

String buildNotificationMessage(Map<String, dynamic>? data) {
  final senderName = (data?['senderName'] ?? 'Birisi').toString();
  final type = (data?['type'] ?? '').toString();

  switch (type) {
    case 'comment':
      return '$senderName yorum bıraktı.';
    case 'reply':
    case 'reply_reply':
      return '$senderName yanıt verdi.';
    case 'comment_like':
      return '$senderName yorumunu beğendi.';
    case 'reply_like':
      return '$senderName yanıtını beğendi.';
    case 'like':
      return '$senderName gönderini beğendi.';
    default:
      return '$senderName yeni bir bildirim gönderdi.';
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  // Bildirim tipine göre İkon seçici
  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'comment':
      case 'reply':
      case 'reply_reply':
        return Icons.chat_bubble_outline_rounded;
      case 'like':
      case 'comment_like':
      case 'reply_like':
        return Icons.favorite_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  // Bildirim tipine göre Renk seçici
  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'comment':
      case 'reply':
      case 'reply_reply':
        return Colors.blue;
      case 'like':
      case 'comment_like':
      case 'reply_like':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  // Göreceli zaman formatlayıcı (ör: 5 dk önce)
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Az önce';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dk önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Tüm bildirimleri okundu olarak işaretleme
  Future<void> _markAllAsRead(String uid) async {
    final unreadDocs = await FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in unreadDocs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Tekil bildirimi okundu işaretleme
  Future<void> _markAsRead(String docId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});
  }

  // Bildirimi silme
  Future<void> _deleteNotification(String docId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Giriş yapmalısınız.')));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Bildirimler',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Tümünü okundu işaretle',
            icon: const Icon(Icons.done_all_rounded, color: Colors.blueAccent),
            onPressed: () => _markAllAsRead(currentUser.uid),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientId', isEqualTo: currentUser.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata oluştu: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz bildiriminiz yok.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final isRead = data['isRead'] == true;
              final type = (data['type'] ?? '').toString();
              final message = buildNotificationMessage(data);
              final senderImageUrl = data['senderImageUrl'] as String?;
              final timestamp = data['timestamp'] as Timestamp?;

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _deleteNotification(doc.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                child: Material(
                  color: isRead ? Colors.white : Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (!isRead) _markAsRead(doc.id);
                      // TODO: Bildirime tıklandığında ilgili gönderiye/yorma gitme mantığı buraya eklenebilir.
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Profil / İkon Avatarı
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey[200],
                                backgroundImage:
                                    senderImageUrl != null &&
                                        senderImageUrl.isNotEmpty
                                    ? NetworkImage(senderImageUrl)
                                    : null,
                                child:
                                    senderImageUrl == null ||
                                        senderImageUrl.isEmpty
                                    ? Icon(
                                        _getNotificationIcon(type),
                                        color: _getNotificationColor(type),
                                      )
                                    : null,
                              ),
                              // Eğer resim varsa sağ altına küçük tip ikonu ekleme
                              if (senderImageUrl != null &&
                                  senderImageUrl.isNotEmpty)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 9,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      _getNotificationIcon(type),
                                      size: 10,
                                      color: _getNotificationColor(type),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Mesaj ve Zaman
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimestamp(timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Okunmadı Noktası
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: const BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
