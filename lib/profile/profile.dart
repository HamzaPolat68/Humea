import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:humea/features/auth/login_page.dart';
import 'package:humea/profile/edit_profile_page.dart';
import 'package:humea/admin/admin_reports_page.dart';
import 'package:humea/profile/blocked_users_page.dart';

// ---------------------------------------------------------------------------
// ADMIN ERİŞİM KARTI
// ---------------------------------------------------------------------------
class AdminAccessTile extends StatelessWidget {
  const AdminAccessTile({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final String role = userData?['role']?.toString() ?? '';

        if (role != 'admin') {
          return const SizedBox.shrink();
        }

        return Card(
          color: Colors.red[50],
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          margin: const EdgeInsets.only(bottom: 15),
          child: ListTile(
            leading: const Icon(
              Icons.admin_panel_settings,
              color: Colors.red,
              size: 28,
            ),
            title: const Text(
              "Admin Moderasyon Paneli",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 16,
              ),
            ),
            subtitle: const Text("Şikayet edilen içerikleri incele ve yönet"),
            trailing: const Icon(Icons.chevron_right, color: Colors.red),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminReportsPage(),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// ENGELLENENLER KARTI
// ---------------------------------------------------------------------------
class BlockedUsersTile extends StatelessWidget {
  const BlockedUsersTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 20),
      child: ListTile(
        leading: const Icon(Icons.block, color: Colors.black87, size: 26),
        title: const Text(
          "Engellenen Kullanıcılar",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: const Text("Engellediğin kişileri yönet ve engelleri kaldır"),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BlockedUsersPage()),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PROFİL SAYFASI
// ---------------------------------------------------------------------------
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? _user = FirebaseAuth.instance.currentUser;

  int _totalMoodCount = 0;
  int _feedPostCount = 0;
  String _mostFrequentEmoji = "Veri Yok";
  String _profileImageUrl = 'https://via.placeholder.com/150';
  bool _isLoadingStats = true;
  bool _isDeletingAccount = false;

  final List<String> _avatarDatabase = List.generate(100, (index) {
    List<String> styles = [
      'bottts',
      'avataaars',
      'fun-emoji',
      'lorelei',
      'pixel-art',
    ];
    String selectedStyle = styles[index % styles.length];
    return 'https://api.dicebear.com/7.x/$selectedStyle/png?seed=HumeaSeed$index';
  });

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    await _user?.reload();
    final User? updatedUser = FirebaseAuth.instance.currentUser;
    if (updatedUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(updatedUser.uid)
          .get();

      String? firestoreImageUrl;
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        firestoreImageUrl = userData['userImageUrl'] ?? userData['photoURL'];
      }

      String targetUrl = 'https://via.placeholder.com/150';

      if (firestoreImageUrl != null && firestoreImageUrl.isNotEmpty) {
        targetUrl = firestoreImageUrl;
      } else if (updatedUser.photoURL != null &&
          updatedUser.photoURL!.isNotEmpty) {
        targetUrl = updatedUser.photoURL!;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(updatedUser.uid)
            .set({
              'userImageUrl': updatedUser.photoURL,
              'photoURL': updatedUser.photoURL,
            }, SetOptions(merge: true));
      }

      final moodSnapshot = await FirebaseFirestore.instance
          .collection('moods')
          .where('userId', isEqualTo: updatedUser.uid)
          .get();

      final moodDocs = moodSnapshot.docs;
      int totalMoodCount = moodDocs.length;

      final Map<double, String> scoreToEmoji = {
        10.0: "😍",
        9.0: "🤩",
        8.0: "🙂",
        7.0: "😊",
        6.0: "😞",
        5.0: "🤔",
        4.0: "😡",
        3.0: "😟",
        2.0: "💤",
        1.0: "😰",
      };

      Map<String, int> emojiCounts = {};
      for (var doc in moodDocs) {
        double score = (doc.data()['score'] as num).toDouble();
        String? emoji = scoreToEmoji[score];
        if (emoji != null) {
          emojiCounts[emoji] = (emojiCounts[emoji] ?? 0) + 1;
        }
      }

      String topEmoji = emojiCounts.isNotEmpty
          ? emojiCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : "Veri Yok";

      final postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: updatedUser.uid)
          .get();

      int firestorePostCount = postSnapshot.docs.length;

      if (mounted) {
        setState(() {
          _profileImageUrl = targetUrl;
          _totalMoodCount = totalMoodCount;
          _mostFrequentEmoji = topEmoji;
          _feedPostCount = firestorePostCount;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint("Profil verisi yükleme hatası: $e");
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  // ===========================================================================
  // KALICI HESAP VE VERİ SİLME MEKANİZMASI
  // ===========================================================================
  Future<void> _confirmAndDeleteAccount() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text("Hesabı Sil"),
          ],
        ),
        content: const Text(
          "Hesabınızı silmek istediğinize emin misiniz?\n\nBu işlem geri alınamaz. Paylaşımlarınız, duygu kayıtlarınız ve tüm profil verileriniz sistemden kalıcı olarak silinecektir.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Evet, Kalıcı Olarak Sil",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteAccountAndData();
    }
  }

  Future<void> _deleteAccountAndData() async {
    if (_user == null) return;
    final uid = _user.uid;

    setState(() => _isDeletingAccount = true);

    try {
      final firestore = FirebaseFirestore.instance;

      final postsQuery = await firestore
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in postsQuery.docs) {
        await doc.reference.delete();
      }

      final moodsQuery = await firestore
          .collection('moods')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in moodsQuery.docs) {
        await doc.reference.delete();
      }

      await firestore.collection('mood_stats').doc(uid).delete();
      await firestore.collection('users').doc(uid).delete();

      try {
        await FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child(uid)
            .child('profile.jpg')
            .delete();
      } catch (e) {
        debugPrint("Storage resim silme uyarısı/hatası: $e");
      }

      await _user.delete();

      if (mounted) {
        _showSnackBar(
          "Hesabınız ve tüm verileriniz başarıyla silindi.",
          Colors.green,
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Auth silme hatası: ${e.code}");
      if (mounted) {
        setState(() => _isDeletingAccount = false);
        if (e.code == 'requires-recent-login') {
          _showSnackBar(
            "Güvenlik gereği hesabınızı silebilmek için yeniden giriş yapmalısınız.",
            Colors.redAccent,
          );
        } else {
          _showSnackBar(
            "Hesap silinirken bir sorun oluştu: ${e.message}",
            Colors.redAccent,
          );
        }
      }
    } catch (e) {
      debugPrint("Hesap silme genel hata: $e");
      if (mounted) {
        setState(() => _isDeletingAccount = false);
        _showSnackBar(
          "İşlem tamamlanamadı. Lütfen daha sonra tekrar deneyin.",
          Colors.redAccent,
        );
      }
    }
  }

  Future<void> _syncProfileImageWithFirestore(String newImageUrl) async {
    try {
      final userId = _user?.uid ?? "";
      if (userId.isEmpty) return;

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'userImageUrl': newImageUrl,
        'photoURL': newImageUrl,
      }, SetOptions(merge: true));

      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .get();

      for (final postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        if (postData['userId']?.toString() == userId) {
          await postDoc.reference.update({'userImage': newImageUrl});
        }

        final commentsSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postDoc.id)
            .collection('comments')
            .get();

        for (final commentDoc in commentsSnapshot.docs) {
          final commentData = commentDoc.data();
          if (commentData['userId']?.toString() == userId) {
            await commentDoc.reference.update({'userImage': newImageUrl});
          }

          final repliesSnapshot = await FirebaseFirestore.instance
              .collection('posts')
              .doc(postDoc.id)
              .collection('comments')
              .doc(commentDoc.id)
              .collection('replies')
              .get();

          for (final replyDoc in repliesSnapshot.docs) {
            final replyData = replyDoc.data();
            if (replyData['userId']?.toString() == userId) {
              await replyDoc.reference.update({'userImage': newImageUrl});
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Akış resmi senkronizasyon hatası: $e");
    }
  }

  Future<String?> _uploadImageToStorage(String localPath) async {
    try {
      if (_user == null) return null;

      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint("Seçilen yerel dosya bulunamadı: $localPath");
        return null;
      }

      final String fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(_user.uid)
          .child(fileName);

      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Storage yükleme hatası detay: $e");
      return null;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 400,
      );

      if (image != null) {
        _showSnackBar("Fotoğraf yükleniyor...", Colors.blue);

        final downloadUrl = await _uploadImageToStorage(image.path);

        if (downloadUrl == null) {
          _showSnackBar(
            "Fotoğraf yüklenemedi, tekrar deneyin.",
            Colors.redAccent,
          );
          return;
        }

        await _user!.updatePhotoURL(downloadUrl);
        await _syncProfileImageWithFirestore(downloadUrl);
        await FirebaseFirestore.instance.collection('users').doc(_user.uid).set(
          {'userImageUrl': downloadUrl, 'photoURL': downloadUrl},
          SetOptions(merge: true),
        );

        if (mounted) {
          await _loadProfileData();
          _showSnackBar(
            "Profil fotoğrafı başarıyla güncellendi!",
            Colors.green,
          );
        }
      }
    } catch (e) {
      debugPrint("Resim seçme hatası: $e");
      _showSnackBar("Fotoğraf seçilirken bir sorun oluştu.", Colors.redAccent);
    }
  }

  Future<void> _selectAvatar(String avatarUrl) async {
    try {
      await _user!.updatePhotoURL(avatarUrl);
      await _syncProfileImageWithFirestore(avatarUrl);

      await FirebaseFirestore.instance.collection('users').doc(_user.uid).set({
        'userImageUrl': avatarUrl,
        'photoURL': avatarUrl,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        await _loadProfileData();
        _showSnackBar("Avatarınız başarıyla güncellendi! ✨", Colors.green);
      }
    } catch (e) {
      debugPrint("Avatar seçim hatası: $e");
      _showSnackBar(
        "Avatar güncellenemedi, lütfen tekrar deneyin.",
        Colors.redAccent,
      );
    }
  }

  void _showImageSourceSelection() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(18.0),
                child: Text(
                  "Profil Fotoğrafı Değiştir",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text("Kamerayı Aç"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text("Galeriden Seç"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.face, color: Colors.purple),
                title: const Text("Avatar Koleksiyonundan Seç"),
                onTap: () {
                  Navigator.pop(context);
                  _openAvatarSelectionDialog();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _openAvatarSelectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Bir Humea Avatarı Seçin",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  itemCount: _avatarDatabase.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemBuilder: (context, index) {
                    final avatarUrl = _avatarDatabase[index];
                    return GestureDetector(
                      onTap: () => _selectAvatar(avatarUrl),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 2,
                          ),
                          color: Colors.grey[50],
                        ),
                        child: ClipOval(
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.account_circle,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String text, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  ImageProvider _getProfileImage() {
    if (_profileImageUrl.startsWith('http://') ||
        _profileImageUrl.startsWith('https://')) {
      return NetworkImage(_profileImageUrl);
    } else {
      return FileImage(File(_profileImageUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayName = _user?.displayName ?? "Kullanıcı";

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 185, 185, 184),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profil',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: (_isLoadingStats || _isDeletingAccount)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.red),
                  if (_isDeletingAccount) ...[
                    const SizedBox(height: 16),
                    const Text(
                      "Hesabınız ve verileriniz siliniyor...",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _showImageSourceSelection,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.white,
                                backgroundImage: _getProfileImage(),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EditProfilePage(),
                              ),
                            );
                            if (mounted) {
                              await _loadProfileData();
                            }
                          },
                          icon: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.blue,
                          ),
                          label: const Text(
                            "Profili Düzenle",
                            style: TextStyle(fontSize: 14, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('moods')
                              .where('userId', isEqualTo: _user!.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            int count = snapshot.hasData
                                ? snapshot.data!.docs.length
                                : 0;
                            return _buildStatCard(
                              "Toplam Duygu Kaydı",
                              "$count",
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .where('userId', isEqualTo: _user.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            int count = snapshot.hasData
                                ? snapshot.data!.docs.length
                                : 0;
                            return _buildStatCard("Akışta Paylaşım", "$count");
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          "En Fazla Paylaştığın",
                          _mostFrequentEmoji == "Veri Yok" ? "Yok" : "",
                          emoji: _mostFrequentEmoji == "Veri Yok"
                              ? null
                              : _mostFrequentEmoji,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // ADMIN KARTI
                  const AdminAccessTile(),

                  // ENGELLENEN KULLANICILAR KARTI (Buraya eklendi)
                  const BlockedUsersTile(),

                  // ÇIKIŞ YAP BUTONU
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        "Çıkış Yap",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 5, 6, 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // HESABI SİL BUTONU
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: _confirmAndDeleteAccount,
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        "Hesabımı Sil",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        backgroundColor: Colors.red.withOpacity(0.05),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, {String? emoji}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      constraints: const BoxConstraints(minHeight: 100),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          if (emoji != null) ...[
            Text(emoji, style: const TextStyle(fontSize: 24)),
          ] else ...[
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
