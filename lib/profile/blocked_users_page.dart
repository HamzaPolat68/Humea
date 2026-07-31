import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockedUsersPage extends StatelessWidget {
  const BlockedUsersPage({super.key});

  Future<void> _unblockUser(
    BuildContext context,
    String currentUserId,
    String blockedUserId,
    String blockedUserName,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Engeli Kaldır"),
        content: Text(
          "$blockedUserName kullanıcısının engelini kaldırmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Engeli Kaldır",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('blocked_users')
            .doc(blockedUserId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "$blockedUserName kullanıcısının engeli kaldırıldı.",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Engel kaldırılırken hata oluştu: $e"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Engellenen Kullanıcılar",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: currentUserId == null
          ? const Center(child: Text("Oturum açılmamış."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .collection('blocked_users')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.block, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          "Engellediğiniz hiç kullanıcı yok.",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String blockedUserId =
                        data['blockedUserId'] ?? docs[index].id;
                    final String blockedUserName =
                        data['blockedUserName'] ?? 'Bilinmeyen Kullanıcı';

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red[100],
                          child: Text(
                            blockedUserName.isNotEmpty
                                ? blockedUserName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          blockedUserName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          "ID: $blockedUserId",
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _unblockUser(
                            context,
                            currentUserId,
                            blockedUserId,
                            blockedUserName,
                          ),
                          child: const Text("Engeli Kaldır"),
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
