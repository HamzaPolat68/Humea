import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'other_user_profile_page.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  String _searchQuery = "";
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'Ad Soyad ile ara...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white60),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          onChanged: (value) {
            setState(() {
              // Arama terimini küçük harfe çeviriyoruz (karşılaştırma için)
              _searchQuery = value.trim().toLowerCase();
            });
          },
        ),
        backgroundColor: const Color(0xFF039BE5),
      ),
      body: _searchQuery.isEmpty
          ? const Center(
              child: Text(
                "Aramak istediğiniz kişinin adını yazın.",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              // Eski kullanıcıları da kapsamak için tüm kullanıcıları dinliyoruz.
              // (Gelişmiş projelerde buraya limit konulabilir, şu an tüm listeyi güvenle filtreler)
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Kullanıcı bulunamadı."));
                }

                // 1. Önce kendimizi listeden çıkarıyoruz
                // 2. Ardından hem eski hem yeni kullanıcıların 'name' alanını küçük harfe çevirip arama sorgumuzla eşleştiriyoruz
                final filteredUsers = snapshot.data!.docs.where((doc) {
                  final userData = doc.data() as Map<String, dynamic>;
                  final String userId = doc.id;

                  // SignUpPage'den gelen orijinal 'name' alanı
                  final String name = (userData['name'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();

                  // Kendimizi aramıyoruz ve isim arama sorgusunu içeriyor mu bakıyoruz
                  return userId != _currentUid && name.contains(_searchQuery);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(child: Text("Kullanıcı bulunamadı."));
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final userData =
                        filteredUsers[index].data() as Map<String, dynamic>;
                    final String userId = filteredUsers[index].id;

                    // Ekranda gösterirken orijinal büyük/küçük harfli ismi kullanıyoruz
                    final String fullName =
                        userData['name'] ?? 'İsimsiz Kullanıcı';
                    final String photoUrl =
                        userData['photoURL'] ??
                        'https://via.placeholder.com/150';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(photoUrl),
                        backgroundColor: Colors.grey[200],
                      ),
                      title: Text(
                        fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(userData['email'] ?? ''),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OtherUserProfilePage(
                              targetUserId: userId,
                              targetUserName: fullName,
                              targetPhotoUrl: photoUrl,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
