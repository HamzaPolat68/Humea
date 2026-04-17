import 'package:flutter/material.dart';
import 'package:humea/login_page.dart';
import 'package:humea/profile.dart';
import 'package:humea/note_page.dart';
import 'package:humea/feed.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // --- YENİ DEĞİŞKENLER: Seçili emoji ve rengi tutuyoruz ---
  String _selectedEmoji = "🙂";
  Color _selectedColor = Colors.greenAccent[400]!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 1
          ? const SafeArea(child: FeedPage())
          : _selectedIndex == 4
          ? const SafeArea(child: ProfilePage())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF42A5F5), Color(0xFFCE93D8)],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Üst Kısım
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 15.0,
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(
                              'https://via.placeholder.com/150',
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Humea ❤️',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.logout,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                                (Route<dynamic> route) => false,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Ortadaki Beyaz Kart
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 30,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const Text(
                              "Bugün Nasıl\nHissediyorsun?",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),

                            // Emoji Listesi (Yatay Kaydırılabilir)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildMoodIcon(
                                    Colors.greenAccent[400]!,
                                    "😍",
                                  ),
                                  const SizedBox(width: 15),
                                  _buildMoodIcon(Colors.lightBlue[300]!, "🙂"),
                                  const SizedBox(width: 15),
                                  _buildMoodIcon(Colors.orange, "😞"),
                                  const SizedBox(width: 15),
                                  _buildMoodIcon(Colors.redAccent[400]!, "😡"),
                                  const SizedBox(width: 15),
                                  _buildMoodIcon(const Color(0xFF0F111A), "💤"),
                                ],
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.cyanAccent,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: _selectedColor,
                                child: Text(
                                  _selectedEmoji, // Dinamik Emoji
                                  style: const TextStyle(fontSize: 45),
                                ),
                              ),
                            ),

                            // Detay Ekle Butonu
                            Container(
                              width: double.infinity,
                              height: 55,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF42A5F5),
                                    Color(0xFFF06292),
                                  ],
                                ),
                              ),
                              // Detay Ekle Butonu - onPressed kısmı
                              child: MaterialButton(
                                onPressed: () {
                                  // Navigasyon buraya ekleniyor:
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NotePage(
                                        selectedEmoji: _selectedEmoji,
                                        selectedColor: _selectedColor,
                                      ),
                                    ),
                                  );
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Text(
                                  "Detay Ekle",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana Sayfa'),
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: 'Akış',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Grafikler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            label: 'AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // --- GÜNCELLENMİŞ WIDGET: Tıklama özelliği eklendi ---
  Widget _buildMoodIcon(Color color, String emoji) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedEmoji = emoji; // Seçilen emojiyi güncelle
          _selectedColor = color; // Seçilen rengi güncelle
        });
      },
      child: CircleAvatar(
        backgroundColor: color,
        radius: 30,
        child: Text(emoji, style: const TextStyle(fontSize: 35)),
      ),
    );
  }
}
