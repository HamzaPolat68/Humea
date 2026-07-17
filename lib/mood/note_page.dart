import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/post_model.dart';

class NotePage extends StatefulWidget {
  final String selectedEmoji;
  final Color selectedColor;

  const NotePage({
    super.key,
    required this.selectedEmoji,
    required this.selectedColor,
  });

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  File? _selectedImage;
  bool _isUploading = false;

  final List<String> _suggestions = [
    "Bugün harika bir gün geçirdim! 🌟",
    "Biraz yorgunum ama huzurluyum. 😌",
    "Yeni şeyler öğrendiğim için heyecanlıyım! 🚀",
    "Bugün biraz dinlenmeye ihtiyacım var. ☕",
    "Çok verimli bir gün oldu! 💪",
  ];

  String _getMoodTitle(String emoji) {
    switch (emoji) {
      case "😍":
        return "Harika!";
      case "🤩":
        return "Heyecanlı";
      case "🙂":
        return "İyi";
      case "😊":
        return "Huzurlu";
      case "😞":
        return "Hüzünlü";
      case "🤔":
        return "Düşünceli";
      case "😡":
        return "Öfkeli";
      case "😟":
        return "Endişeli";
      case "💤":
        return "Yorgun";
      case "😰":
        return "Çok Kaygılı";
      default:
        return "Normal";
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // GALERİDEN VEYA KAMERADAN FOTOĞRAF SEÇME
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1080,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Fotoğraf Çek"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Galeriden Seç"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // FIREBASE STORAGE'A YÜKLEME
  Future<String?> _uploadImage(File imageFile, String postId) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('post_images')
          .child('$postId.jpg');

      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Fotoğraf yükleme hatası: $e");
      return null;
    }
  }

  Future<void> _addComment(String postId, String commentText) async {
    if (commentText.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add({
          'text': commentText,
          'userName': user?.displayName ?? "Anonim",
          'userImage': user?.photoURL ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          'userId': user?.uid,
          'likesCount': 0,
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Günün Notu"),
        backgroundColor: widget.selectedColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(widget.selectedEmoji, style: const TextStyle(fontSize: 60)),
              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _suggestions
                    .map(
                      (suggestion) => ActionChip(
                        label: Text(
                          suggestion,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: widget.selectedColor.withOpacity(0.5),
                        ),
                        onPressed: () {
                          _noteController.text = suggestion;
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _showImageSourceSheet,
                icon: const Icon(Icons.add_a_photo),
                label: const Text("Fotoğraf Ekle"),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: widget.selectedColor),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: "Duygularını buraya dök (Opsiyonel)...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // FOTOĞRAF ÖNİZLEME VE EKLEME BUTONU
              if (_selectedImage != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(
                        _selectedImage!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton(
                      icon: const CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, color: Colors.white),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                    ),
                  ],
                )
              else
                const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.selectedColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _isUploading
                      ? null
                      : () async {
                          final User? user = FirebaseAuth.instance.currentUser;

                          final String finalNote = _noteController.text.trim();
                          final String generatedId = FirebaseFirestore.instance
                              .collection('posts')
                              .doc()
                              .id;

                          setState(() => _isUploading = true);

                          // FOTOĞRAF VARSA ÖNCE YÜKLE
                          String? uploadedImageUrl;
                          if (_selectedImage != null) {
                            uploadedImageUrl = await _uploadImage(
                              _selectedImage!,
                              generatedId,
                            );
                          }

                          final Post newPost = Post(
                            id: generatedId,
                            userName: user?.displayName ?? "Anonim",
                            userImage:
                                user?.photoURL ??
                                "https://via.placeholder.com/150",
                            moodEmoji: widget.selectedEmoji,
                            moodTitle: _getMoodTitle(widget.selectedEmoji),
                            note: finalNote,
                            mentions: const [],
                            timestamp: DateTime.now(),
                            likes: 0,
                            commentsCount: 0,
                            userId: user?.uid ?? 'unknown',
                            likesList: [],
                            imageUrl: uploadedImageUrl,
                          );

                          try {
                            await FirebaseFirestore.instance
                                .collection('posts')
                                .doc(generatedId)
                                .set(newPost.toFirestore());
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Duygun paylaşıldı! ✨"),
                                ),
                              );
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            debugPrint("Hata: $e");
                          } finally {
                            if (mounted) setState(() => _isUploading = false);
                          }
                        },
                  child: _isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Paylaş",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
