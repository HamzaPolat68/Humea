import 'dart:io'; // Cihaz içi dosyaları (File) okumak için eklendi
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:image_picker/image_picker.dart';
import 'package:humea/features/auth/login_page.dart';
import 'package:humea/profile/edit_profile_page.dart';

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

  // 100 Adet Benzersiz Avatar Üreten Dinamik Generator
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
    if (_user == null) return;

    try {
      // 1. ADIM: Firestore 'users' koleksiyonundan kullanıcının güncel profil resmini çek
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .get();

      String? firestoreImageUrl;
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        // Senin belirttiğin 'userImageUrl' alanına bakıyoruz
        firestoreImageUrl = userData['userImageUrl'] ?? userData['photoURL'];
      }

      // Eğer Firestore'da varsa onu kullan, yoksa Firebase Auth profilindeki resme (yedek) bak
      if (firestoreImageUrl != null && firestoreImageUrl.isNotEmpty) {
        _profileImageUrl = firestoreImageUrl;
      } else if (_user.photoURL != null && _user.photoURL!.isNotEmpty) {
        _profileImageUrl = _user.photoURL!;

        // EĞER FİRESTORE'DA YOKSA: Arama sayfasında da görünebilmesi için
        // Firestore dokümanını otomatik olarak mevcut fotoğrafla besle (Geriye dönük koruma)
        await FirebaseFirestore.instance.collection('users').doc(_user.uid).set({
          'userImageUrl': _user.photoURL,
          'photoURL': _user
              .photoURL, // Arama sayfasının patlamaması için ikisini de yazıyoruz
        }, SetOptions(merge: true));
      }

      // 2. ADIM: Duygu verilerini Firestore'dan çek
      final moodSnapshot = await FirebaseFirestore.instance
          .collection('moods')
          .where('userId', isEqualTo: _user.uid)
          .get();

      final moodDocs = moodSnapshot.docs;
      int totalMoodCount = moodDocs.length;

      // Emojileri skorlara göre eşleştir
      final Map<double, String> scoreToEmoji = {
        10.0: "😍", // Harika
        9.0: "🤩", // Heyecanlı
        8.0: "🙂", // İyi/Mutlu
        7.0: "😊", // Huzurlu/Pozitif
        6.0: "😞", // Hüzünlü
        5.0: "🤔", // Nötr/Düşünceli
        4.0: "😡", // Öfkeli
        3.0: "😟", // Endişeli
        2.0: "💤", // Yorgun
        1.0: "😰", // Çok Kaygılı
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

      // 3. ADIM: Gönderi sayısını Firestore'dan çek
      final postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: _user.uid)
          .get();

      int firestorePostCount = postSnapshot.docs.length;

      // 4. ADIM: UI'ı güncelle
      if (mounted) {
        setState(() {
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

  // Akıştaki tüm eski postların profil resmini bulutta günceller
  Future<void> _syncProfileImageWithFirestore(String newImageUrl) async {
    try {
      final userPosts = await FirebaseFirestore.instance
          .collection('posts')
          .where('userName', isEqualTo: _user?.displayName ?? "")
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in userPosts.docs) {
        batch.update(doc.reference, {'userImage': newImageUrl});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Akış resmi senkronizasyon hatası: $e");
    }
  }

  // Kameradan/Galeriden resim seçme işlemi
  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 400,
      );

      if (image != null) {
        await _user!.updatePhotoURL(image.path);
        await _syncProfileImageWithFirestore(image.path);

        setState(() {
          _profileImageUrl = image.path;
        });
        _showSnackBar("Profil fotoğrafı başarıyla güncellendi!", Colors.green);
      }
    } catch (e) {
      debugPrint("Resim seçme hatası: $e");
      _showSnackBar("Fotoğraf seçilirken bir sorun oluştu.", Colors.redAccent);
    }
  }

  // Avatar seçimi yapıldığında tetiklenen fonksiyon
  Future<void> _selectAvatar(String avatarUrl) async {
    try {
      await _user!.updatePhotoURL(avatarUrl);
      await _syncProfileImageWithFirestore(avatarUrl);

      if (mounted) {
        setState(() {
          _profileImageUrl = avatarUrl;
        });
        Navigator.pop(context); // BottomSheet'i kapatır
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

  // Profil fotoğrafı kaynağı seçimi alt menüsü
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

  // Avatar Seçim Penceresi
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

  // Hem URL'leri hem yerel dosyaları akıllıca ayırt eden fonksiyon
  ImageProvider _getProfileImage() {
    if (_profileImageUrl.startsWith('http://') ||
        _profileImageUrl.startsWith('https://')) {
      // Eğer değer internet linki ise (DiceBear veya placeholder) NetworkImage kullanıyoruz
      return NetworkImage(_profileImageUrl);
    } else {
      // Eğer internet linki değilse, cihazın kendi hafızasındaki yerel dosyadır (FileImage)
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
      body: _isLoadingStats
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
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
                                // YENİLİK: Resim kaynağı artık dinamik metot üzerinden besleniyor
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
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EditProfilePage(),
                              ),
                            );
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
                      // 1. TOPLAM DUYGU KAYDI (moods koleksiyonunu dinler)
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

                      // 2. AKIŞTA PAYLAŞIM (posts koleksiyonunu dinler)
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
                      // 3. En Fazla Paylaşılan (Bunu isterseniz yine Future ile initState'de yükleyebilirsiniz)
                      _buildStatCard(
                        "En Fazla Paylaştığın",
                        _mostFrequentEmoji == "Veri Yok" ? "Yok" : "",
                        emoji: _mostFrequentEmoji == "Veri Yok"
                            ? null
                            : _mostFrequentEmoji,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
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
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, {String? emoji}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        height: 110,
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
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            if (emoji != null) ...[
              Text(emoji, style: const TextStyle(fontSize: 26)),
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
      ),
    );
  }
}
