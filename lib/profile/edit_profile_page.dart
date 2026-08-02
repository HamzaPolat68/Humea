import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  DateTime? _selectedDate;
  bool _isLoading = false;
  final User? _user = FirebaseAuth.instance.currentUser;
  String _currentProfileImageUrl = '';

  final List<String> _avatarDatabase = List.generate(100, (index) {
    final styles = ['bottts', 'avataaars', 'fun-emoji', 'lorelei', 'pixel-art'];
    final selectedStyle = styles[index % styles.length];
    return 'https://api.dicebear.com/7.x/$selectedStyle/png?seed=HumeaSeed$index';
  });

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;
    _nameController.text = _user.displayName ?? "";
    _emailController.text = _user.email ?? "";

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>?;
      final savedImageUrl = (data?['userImageUrl'] ?? data?['photoURL'] ?? '')
          .toString();

      if (savedImageUrl.isNotEmpty) {
        setState(() => _currentProfileImageUrl = savedImageUrl);
      } else if (_user.photoURL != null && _user.photoURL!.isNotEmpty) {
        setState(() => _currentProfileImageUrl = _user.photoURL!);
      }

      if (data != null &&
          data.containsKey('birthDate') &&
          data['birthDate'] != null) {
        try {
          setState(() {
            _selectedDate = DateTime.parse(data['birthDate']);
          });
        } catch (e) {
          debugPrint("Tarih formatı hatalı: $e");
          setState(() => _selectedDate = null);
        }
      }
    }
  }

  Future<void> _pickAndCropProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Fotoğrafı Kırp',
          toolbarColor: Colors.blue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          hideBottomControls: false,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Fotoğrafı Kırp', minimumAspectRatio: 1),
      ],
    );

    if (cropped == null) return;

    setState(() => _isLoading = true);

    try {
      final downloadUrl = await _uploadImageToStorage(File(cropped.path));
      if (downloadUrl == null || downloadUrl.isEmpty) {
        throw Exception('Fotoğraf yüklenemedi.');
      }

      await _user?.updatePhotoURL(downloadUrl);
      await _user?.reload();

      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'userImageUrl': downloadUrl,
        'photoURL': downloadUrl,
      }, SetOptions(merge: true));

      await _syncProfileImageWithFirestore(downloadUrl);

      if (mounted) {
        setState(() => _currentProfileImageUrl = downloadUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil fotoğrafı güncellendi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fotoğraf güncellenemedi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _uploadImageToStorage(File imageFile) async {
    try {
      final currentUid = _user?.uid;
      if (currentUid == null || currentUid.isEmpty) return null;

      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(currentUid)
          .child(fileName);

      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Profil fotoğrafı yükleme hatası: $e');
      return null;
    }
  }

  Future<void> _syncProfileImageWithFirestore(String newImageUrl) async {
    try {
      final userId = _user?.uid ?? '';
      if (userId.isEmpty) return;

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
      debugPrint('Profil fotoğrafı senkronizasyon hatası: $e');
    }
  }

  Future<void> _selectAvatar(String avatarUrl) async {
    try {
      setState(() => _isLoading = true);
      await _user?.updatePhotoURL(avatarUrl);
      await _user?.reload();

      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'userImageUrl': avatarUrl,
        'photoURL': avatarUrl,
      }, SetOptions(merge: true));

      await _syncProfileImageWithFirestore(avatarUrl);

      if (mounted) {
        setState(() {
          _currentProfileImageUrl = avatarUrl;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar başarıyla güncellendi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Avatar seçilemedi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAvatarSelectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Text(
                  'Avatar Koleksiyonundan Seç',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 300,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(24, (index) {
                        final avatarUrl = _avatarDatabase[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _selectAvatar(avatarUrl);
                          },
                          child: SizedBox(
                            width: 88,
                            height: 88,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 180,
                                cacheHeight: 180,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      // 1. Şifre Değiştirme
      if (_newPasswordController.text.isNotEmpty) {
        if (_oldPasswordController.text.isEmpty) {
          throw "Şifre değiştirmek için eski şifrenizi girmelisiniz.";
        }
        AuthCredential credential = EmailAuthProvider.credential(
          email: _user!.email!,
          password: _oldPasswordController.text,
        );
        await _user.reauthenticateWithCredential(credential);
        await _user.updatePassword(_newPasswordController.text);
      }

      // 2. E-posta Değiştirme (Firebase süreci)
      if (_emailController.text != _user!.email) {
        await _user.verifyBeforeUpdateEmail(_emailController.text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Yeni e-posta adresinize doğrulama gönderildi!"),
          ),
        );
      }

      // 3. Profil ve Firestore Güncelleme
      await _user.updateDisplayName(_nameController.text);

      final Map<String, dynamic> userUpdateData = {
        'name': _nameController.text,
      };

      if (_selectedDate != null) {
        userUpdateData['birthDate'] = _selectedDate!.toIso8601String();
        userUpdateData['birthMonthDay'] =
            "${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .set(userUpdateData, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Profil güncellendi! 🚀")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Kullanıcı Bilgileri",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profil Başlığı
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade100, Colors.purple.shade100],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickAndCropProfileImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          backgroundImage: _currentProfileImageUrl.isNotEmpty
                              ? NetworkImage(_currentProfileImageUrl)
                              : null,
                          child: _currentProfileImageUrl.isEmpty
                              ? const Icon(Icons.person, size: 40)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _user?.displayName ?? "Kullanıcı",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: _pickAndCropProfileImage,
                              icon: const Icon(
                                Icons.photo_camera_outlined,
                                size: 16,
                              ),
                              label: const Text("Fotoğrafı değiştir"),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _showAvatarSelectionDialog,
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text("Avatar seç"),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _buildTextField("Ad Soyad", _nameController, Icons.person),
            const SizedBox(height: 15),
            _buildTextField(
              "E-posta",
              _emailController,
              Icons.email,
            ), // E-posta kutusu
            const SizedBox(height: 15),

            // Doğum Tarihi Alanı
            ListTile(
              onTap: () => _selectDate(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              leading: const Icon(Icons.cake, color: Colors.blueAccent),
              title: const Text("Doğum Tarihi"),
              subtitle: Text(
                _selectedDate == null
                    ? "Tarih seçilmedi"
                    : DateFormat(
                        'dd MMMM yyyy',
                        'tr_TR',
                      ).format(_selectedDate!),
              ),
              trailing: const Icon(Icons.edit),
            ),

            const SizedBox(height: 15),
            ExpansionTile(
              title: const Text(
                "Şifreyi Değiştir",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.lock_reset),
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      _buildTextField(
                        "Yeni Şifre",
                        _newPasswordController,
                        Icons.vpn_key,
                        obscure: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                fixedSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Değişiklikleri Kaydet"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
