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

  // HAZIR YAZILAR LİSTESİ
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

              // HAZIR YAZILAR (CHIPS)
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
              const SizedBox(height: 20),

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
                  onPressed: () async {
                    final User? user = FirebaseAuth.instance.currentUser;

                    final String finalNote = _noteController.text.trim();
                    final String generatedId = FirebaseFirestore.instance
                        .collection('posts')
                        .doc()
                        .id;

                    final Post newPost = Post(
                      id: generatedId,
                      userName: user?.displayName ?? "Anonim",
                      userImage:
                          user?.photoURL ?? "https://via.placeholder.com/150",
                      moodEmoji: widget.selectedEmoji,
                      moodTitle: _getMoodTitle(widget.selectedEmoji),
                      note: finalNote,
                      timestamp: DateTime.now(),
                      likes: 0,
                      commentsCount: 0,
                      userId: user?.uid ?? 'unknown',
                      likesList: [],
                    );

                    try {
                      await FirebaseFirestore.instance
                          .collection('posts')
                          .doc(generatedId)
                          .set(newPost.toFirestore());
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Duygun paylaşıldı! ✨")),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      debugPrint("Hata: $e");
                    }
                  },
                  child: const Text(
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
