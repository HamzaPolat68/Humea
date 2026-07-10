import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:humea/features/auth/login_page.dart';
import 'package:humea/mood/mood_chart_page.dart';
import 'package:humea/profile/profile.dart';
import 'package:humea/mood/note_page.dart';
import 'package:humea/feed/feed.dart';
import 'package:humea/ai/ai.dart';
import 'dart:io';
import 'package:humea/search/user_search_page.dart';

// --- VERİ MODELİ ---
class MoodEntry {
  final DateTime date;
  final double score;
  MoodEntry({required this.date, required this.score});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _selectedEmoji = "🙂";
  Color _selectedColor = Colors.lightBlue[300]!;

  // KULLANICININ TÜM ZAMANLARDA GİRDİĞİ HAM VERİ LİSTESİ
  List<MoodEntry> _allMoodEntries = [];

  // Geçmiş grafik navigasyonu için sayaçlar
  int _weeksAgo = 0;
  int _monthsAgo = 0;

  // MoodChartPage içerisindeki alt segment seçimini takip etmek için
  int _currentChartPeriod = 0;

  final Map<String, double> _emojiToScore = {
    "😍": 10.0, // Harika
    "🤩": 9.0, // Heyecanlı
    "🙂": 8.0, // İyi/Mutlu
    "😊": 7.0, // Huzurlu/Pozitif
    "😞": 6.0, // Hüzünlü
    "🤔": 5.0, // Nötr/Düşünceli
    "😡": 4.0, // Öfkeli
    "😟": 3.0, // Endişeli
    "💤": 2.0, // Yorgun
    "😰": 1.0, // Çok Kaygılı
  };

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setupNotifications(user.uid);
    }
    // Firebase Auth durumunu kontrol edip öyle yükleme yapın
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _loadMoodsFromFirestore();
        _loadStatsFromFirestore();
      }
    });
  }

  Future<void> setupNotifications(String userId) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);
    String? token = await messaging.getToken();

    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }
  }

  // --- FİREBASE'DEN VERİLERİ ÇEKME ---
  Future<void> _loadMoodsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('moods')
          .where('userId', isEqualTo: user.uid)
          .orderBy('date', descending: false)
          .get();

      // LİSTEYİ TAMAMEN DEĞİŞTİRİYORUZ
      setState(() {
        _allMoodEntries = snapshot.docs.map((doc) {
          final data = doc.data();
          return MoodEntry(
            date: (data['date'] as Timestamp).toDate(),
            score: (data['score'] as num).toDouble(),
          );
        }).toList();
      });
    } catch (e) {
      print("Veri çekme hatası: $e");
    }
  }

  // _HomePageState sınıfının içinde:
  // İstatistikleri Firebase'den çeken yeni fonksiyon
  Future<void> _loadStatsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('mood_stats')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      // Burada gelen istatistikleri kullanabilirsin.
      // Örneğin: double ortalama = doc.data()?['averageScore'];
      print("İstatistikler yüklendi: ${doc.data()}");
    }
  }

  Future<void> _updateStatsInFirebase(String userId) async {
    try {
      // 1. Veri kontrolü
      if (_allMoodEntries.isEmpty) {
        print("Kayıtlı mod girişi bulunamadı, istatistik hesaplanamadı.");
        return;
      }

      // 2. Ortalama hesaplama
      double totalScore = _allMoodEntries
          .map((e) => e.score)
          .reduce((a, b) => a + b);
      double averageScore = totalScore / _allMoodEntries.length;

      print(
        "İstatistik hesaplanıyor: Ortalama $averageScore, Adet ${_allMoodEntries.length}",
      );

      // 3. Yazma işlemi
      await FirebaseFirestore.instance
          .collection('mood_stats')
          .doc(userId) // Doküman ID'si kullanıcı ID'si olmalı
          .set({
            'averageScore': averageScore,
            'entryCount': _allMoodEntries.length,
            'lastUpdated':
                FieldValue.serverTimestamp(), // Daha güvenilir zaman damgası
          }, SetOptions(merge: true));

      print("Başarıyla Firestore'a kaydedildi.");
    } catch (e) {
      // Hatanın detaylı yazdırılması
      print("!!! İstatistik güncelleme hatası: $e");
    }
  }

  Future<void> _refreshData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Önce veriyi çek (listeyi en başta boşaltma!)
      final snapshot = await FirebaseFirestore.instance
          .collection('moods')
          .where('userId', isEqualTo: user.uid)
          .orderBy('date', descending: false)
          .get();

      // 2. Yeni listeyi hazırla
      final List<MoodEntry> updatedEntries = snapshot.docs.map((doc) {
        final data = doc.data();
        return MoodEntry(
          date: (data['date'] as Timestamp).toDate(),
          score: (data['score'] as num).toDouble(),
        );
      }).toList();

      // 3. Sadece veriler hazır olduğunda setState'i bir kez çağır
      setState(() {
        _allMoodEntries = updatedEntries;
      });
    } catch (e) {
      print("Veri yenileme hatası: $e");
      // Hata durumunda eski veriyi korumuş oluyoruz (çünkü listeyi silmedik)
    }
  }

  // --- FİREBASE'E VERİ YAZMA ---
  Future<bool> _saveTodayMood(String emoji) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lütfen önce giriş yapın!')));
      return false;
    }

    // DateTime.now() ile o anki saati alıyoruz, böylece aynı gün içinde
    // farklı saatlerde birden fazla kayıt oluşturulabilir.
    DateTime now = DateTime.now();
    double score = _emojiToScore[emoji] ?? 5.0;

    print("KAYDEDİLEN PUAN: $score"); // Konsolda kaç yazıyor?

    try {
      // Firestore'a doğrudan yeni kayıt ekle
      await FirebaseFirestore.instance.collection('moods').add({
        'userId': user.uid,
        'date': Timestamp.fromDate(now), // Timestamp saati de içerir
        'score': score,
      });
      await _updateStatsInFirebase(user.uid);
      // Yerel listeyi güncelle
      setState(() {
        _allMoodEntries.add(MoodEntry(date: now, score: score));
      });

      return true;
    } catch (e) {
      print("Kaydetme hatası: $e");
      return false;
    }
  }

  // --- DİNAMİK GRAFİK NOKTALARI VE HAM SKORLAR ---
  List<FlSpot> get _weeklySpots {
    DateTime now = DateTime.now();
    DateTime targetMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1 + (_weeksAgo * 7)));
    DateTime targetSunday = targetMonday.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );

    // 1. O haftaya ait tüm girişleri gruplayalım
    Map<int, List<double>> dailyScores = {
      0: [],
      1: [],
      2: [],
      3: [],
      4: [],
      5: [],
      6: [],
    };

    for (var entry in _allMoodEntries) {
      if (entry.date.isAfter(
            targetMonday.subtract(const Duration(seconds: 1)),
          ) &&
          entry.date.isBefore(targetSunday)) {
        int weekdayIndex = entry.date.weekday - 1; // Pzt=0, Paz=6
        dailyScores[weekdayIndex]?.add(entry.score);
      }
    }

    // 2. Gruplanan verilerin ortalamasını alıp FlSpot üretelim
    List<FlSpot> spots = [];
    for (int i = 0; i < 7; i++) {
      if (dailyScores[i]!.isNotEmpty) {
        double average =
            dailyScores[i]!.reduce((a, b) => a + b) / dailyScores[i]!.length;
        spots.add(FlSpot(i.toDouble(), average));
      }
    }

    return spots..sort((a, b) => a.x.compareTo(b.x));
  }

  List<FlSpot> get _monthlySpots {
    DateTime now = DateTime.now();
    DateTime targetDate = DateTime(now.year, now.month - _monthsAgo, 1);
    List<MoodEntry> targetMonthEntries = _allMoodEntries
        .where(
          (entry) =>
              entry.date.year == targetDate.year &&
              entry.date.month == targetDate.month,
        )
        .toList();
    Map<int, List<double>> weekGroups = {0: [], 1: [], 2: [], 3: []};
    for (var entry in targetMonthEntries) {
      int weekIndex = ((entry.date.day - 1) / 7).toInt().clamp(0, 3);
      weekGroups[weekIndex]!.add(entry.score);
    }
    List<FlSpot> spots = [];
    weekGroups.forEach((week, scores) {
      if (scores.isNotEmpty) {
        double avg = scores.reduce((a, b) => a + b) / scores.length;
        spots.add(FlSpot(week.toDouble(), avg));
      }
    });
    return spots..sort((a, b) => a.x.compareTo(b.x));
  }

  List<FlSpot> get _allTimeSpots {
    DateTime now = DateTime.now();
    List<MoodEntry> thisYearEntries = _allMoodEntries
        .where((entry) => entry.date.year == now.year)
        .toList();
    Map<int, List<double>> monthGroups = {for (var i = 1; i <= 12; i++) i: []};
    for (var entry in thisYearEntries) {
      monthGroups[entry.date.month]!.add(entry.score);
    }
    List<FlSpot> spots = [];
    monthGroups.forEach((month, scores) {
      if (scores.isNotEmpty) {
        double avg = scores.reduce((a, b) => a + b) / scores.length;
        spots.add(FlSpot((month - 1).toDouble(), avg));
      }
    });
    return spots..sort((a, b) => a.x.compareTo(b.x));
  }

  List<int> get _rawWeeklyScores {
    DateTime now = DateTime.now();
    DateTime targetMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1 + (_weeksAgo * 7)));
    DateTime targetSunday = targetMonday.add(
      const Duration(days: 6, hours: 23, minutes: 59),
    );
    return _allMoodEntries
        .where(
          (entry) =>
              entry.date.isAfter(
                targetMonday.subtract(const Duration(seconds: 1)),
              ) &&
              entry.date.isBefore(targetSunday),
        )
        .map((entry) => entry.score.round())
        .toList();
  }

  List<int> get _rawMonthlyScores {
    DateTime now = DateTime.now();
    DateTime targetDate = DateTime(now.year, now.month - _monthsAgo, 1);
    return _allMoodEntries
        .where(
          (entry) =>
              entry.date.year == targetDate.year &&
              entry.date.month == targetDate.month,
        )
        .map((entry) => entry.score.round())
        .toList();
  }

  Map<int, List<int>> get _rawAllTimeScoresMap {
    DateTime now = DateTime.now();
    final Map<int, List<int>> monthScores = {
      for (var i = 1; i <= 12; i++) i: [],
    };
    for (var entry in _allMoodEntries.where(
      (entry) => entry.date.year == now.year,
    )) {
      monthScores[entry.date.month]!.add(entry.score.round());
    }
    return monthScores;
  }

  String get _currentPeriodLabel {
    if (_selectedIndex != 2) return "";
    if (_currentChartPeriod == 0) {
      return _weeksAgo == 0
          ? "Bu Hafta"
          : (_weeksAgo == 1 ? "Geçen Hafta" : "$_weeksAgo Hafta Önce");
    }
    if (_currentChartPeriod == 1) {
      return _monthsAgo == 0
          ? "Bu Ay"
          : (_monthsAgo == 1 ? "Geçen Ay" : "$_monthsAgo Ay Önce");
    }
    return "Tüm Zamanlar (2026)";
  }

  String _getHomeProfileImage() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.photoURL != null && user.photoURL!.isNotEmpty) {
      return user.photoURL!;
    }
    return 'https://via.placeholder.com/150';
  }

  String _getUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Kullanıcı';
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Kullanıcı';
  }

  ImageProvider _resolveProfileImageProvider() {
    final String imagePath = _getHomeProfileImage();
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return NetworkImage(imagePath);
    }
    return FileImage(File(imagePath));
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeScreenBody();
      case 1:
        return SafeArea(
          child: FeedPage(
            onPostDeleted: () async {
              // Tek bir fonksiyon çağrısı yeterli
              await _refreshData();
            },
          ),
        );
      case 2:
        return SafeArea(
          child: MoodChartPage(
            userWeeklySpots: _weeklySpots,
            userMonthlySpots: _monthlySpots,
            userAllTimeSpots: _allTimeSpots,
            rawWeeklyScores: _rawWeeklyScores,
            rawMonthlyScores: _rawMonthlyScores,
            rawAllTimeScoresMap: _rawAllTimeScoresMap,
            currentPeriodLabel: _currentPeriodLabel,
            onPeriodTabChanged: (i) => setState(() => _currentChartPeriod = i),
            onPeriodChanged: (direction) => setState(() {
              if (_currentChartPeriod == 0) {
                if (direction == -1) {
                  _weeksAgo++;
                } else if (direction == 1 && _weeksAgo > 0)
                  _weeksAgo--;
              } else if (_currentChartPeriod == 1) {
                if (direction == -1) {
                  _monthsAgo++;
                } else if (direction == 1 && _monthsAgo > 0)
                  _monthsAgo--;
              }
            }),
          ),
        );
      case 3:
        return const SafeArea(child: AiRecommendationsScreen());
      case 4:
        return const SafeArea(child: ProfilePage());
      default:
        return _buildHomeScreenBody();
    }
  }

  Widget _buildHomeScreenBody() {
    return Container(
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
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 15.0,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    backgroundImage: _resolveProfileImageProvider(),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hoş Geldin',
                        style: TextStyle(
                          color: Color.fromARGB(255, 252, 252, 253),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getUserName(),
                        style: const TextStyle(
                          color: Color.fromARGB(255, 9, 9, 9),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserSearchPage(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          _buildMoodIcon(const Color(0xFF4CAF50), "😍"), // 10.0
                          const SizedBox(width: 12),
                          _buildMoodIcon(const Color(0xFF8BC34A), "🤩"), // 9.0
                          const SizedBox(width: 12),
                          _buildMoodIcon(const Color(0xFF2196F3), "🙂"), // 8.0
                          const SizedBox(width: 12),
                          _buildMoodIcon(const Color(0xFF81D4FA), "😊"), // 7.0
                          const SizedBox(width: 12),
                          _buildMoodIcon(const Color(0xFFFFCC80), "😞"), // 6.0
                          const SizedBox(width: 12),
                          _buildMoodIcon(const Color(0xFFCFD8DC), "🤔"), // 5.0
                          const SizedBox(width: 12),
                          _buildMoodIcon(const Color(0xFFFF9800), "😡"), // 4.0
                          const SizedBox(width: 12),
                          _buildMoodIcon(const Color(0xFFEF9A9A), "😟"), // 3.0
                          const SizedBox(width: 12),
                          _buildMoodIcon(const Color(0xFFB0BEC5), "💤"), // 2.0
                          const SizedBox(width: 12),
                          _buildMoodIcon(const Color(0xFFF44336), "😰"), // 1.0
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.cyanAccent, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: _selectedColor,
                        child: Text(
                          _selectedEmoji,
                          style: const TextStyle(fontSize: 45),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF42A5F5), Color(0xFFF06292)],
                        ),
                      ),
                      child: MaterialButton(
                        onPressed: () async {
                          bool isSaved = await _saveTodayMood(_selectedEmoji);
                          if (isSaved) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NotePage(
                                  selectedEmoji: _selectedEmoji,
                                  selectedColor: _selectedColor,
                                ),
                              ),
                            );
                          }
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          "Detay Ekle & Kaydet",
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 2) {
              _weeksAgo = 0;
              _monthsAgo = 0;
              _currentChartPeriod = 0;
            }
          });
          if (index == 0 || index == 2) _loadMoodsFromFirestore();
        },
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

  Widget _buildMoodIcon(Color color, String emoji) {
    return GestureDetector(
      onTap: () => setState(() {
        _selectedEmoji = emoji;
        _selectedColor = color;
      }),
      child: CircleAvatar(
        backgroundColor: color,
        radius: 30,
        child: Text(emoji, style: const TextStyle(fontSize: 35)),
      ),
    );
  }
}
