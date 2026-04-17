import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'post_model.dart';

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
  // Yazılan notu kontrol etmek için controller
  final TextEditingController _noteController = TextEditingController();

  // Emojiye göre başlık belirleyen yardımcı fonksiyon
  String _getMoodTitle(String emoji) {
    switch (emoji) {
      case "😍":
        return "Harika!";
      case "🙂":
        return "İyi";
      case "😞":
        return "Hüzünlü";
      case "😡":
        return "Sinirli";
      case "💤":
        return "Yorgun";
      default:
        return "Normal";
    }
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
              // Seçilen emojiyi tepede gösterelim
              Text(widget.selectedEmoji, style: const TextStyle(fontSize: 60)),
              const SizedBox(height: 10),
              const Text(
                "Bugün neler oldu? Neler hissediyorsun?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _noteController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: "Duygularını buraya dök...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 30),

              // PAYLAŞ BUTONU
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
                  onPressed: () {
                    // 1. Firebase'den aktif kullanıcıyı alıyoruz
                    final User? user = FirebaseAuth.instance.currentUser;

                    // Kullanıcı bilgilerini kontrol et
                    final String displayName =
                        user?.displayName ?? "Anonim Kullanıcı";
                    final String photoUrl =
                        user?.photoURL ?? "https://via.placeholder.com/150";

                    // Not boşsa paylaşmaya izin verme (Opsiyonel)
                    if (_noteController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Lütfen bir şeyler yazın."),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      sharedPosts.add(
                        Post(
                          userName: displayName,
                          userImage: photoUrl,
                          moodEmoji: widget.selectedEmoji,
                          moodTitle: _getMoodTitle(widget.selectedEmoji),
                          note: _noteController.text,
                          likeCount: 0,
                        ),
                      );
                    });

                    // 3. Başarılı mesajı göster ve geri dön
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Duygun akışta paylaşıldı! ✨"),
                      ),
                    );
                    Navigator.pop(context);
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
