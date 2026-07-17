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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Giriş yapmalısınız.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henüz bildirim yok.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final message = buildNotificationMessage(data);
              final timestamp = data['timestamp'] is Timestamp
                  ? (data['timestamp'] as Timestamp).toDate()
                  : null;

              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.notifications, color: Colors.white),
                ),
                title: Text(message),
                subtitle: Text(
                  timestamp != null
                      ? '${timestamp.day}/${timestamp.month}/${timestamp.year}'
                      : 'Az önce',
                ),
                trailing: data['isRead'] == true
                    ? const Icon(Icons.done, color: Colors.green)
                    : const Icon(Icons.fiber_new, color: Colors.orange),
              );
            },
          );
        },
      ),
    );
  }
}
