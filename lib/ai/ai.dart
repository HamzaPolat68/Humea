import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.text, required this.isUser, required this.time});
}

class AiRecommendationsScreen extends StatefulWidget {
  const AiRecommendationsScreen({super.key});

  @override
  State<AiRecommendationsScreen> createState() =>
      _AiRecommendationsScreenState();
}

class _AiRecommendationsScreenState extends State<AiRecommendationsScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  String _detectedMoodSummary = "Analiz Ediliyor...";

  late GenerativeModel _model;
  late ChatSession _chatSession;

  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";

  // Skor (int) -> emoji/etiket/AI bağlamı haritası.
  // home_page.dart'taki _emojiToScore ile birebir eşleşir (yuvarlanmış halleriyle).
  static final Map<int, Map<String, String>> _scoreToMoodInfo = {
    10: {
      "emoji": "😍",
      "label": "Harika",
      "context":
          "Kullanıcı bugün kendini harika (😍) hissettiğini bildirdi. Bu yüksek frekansı analiz et ve konuşmayı başlat.",
    },
    9: {
      "emoji": "🤩",
      "label": "Heyecanlı",
      "context":
          "Kullanıcı bugün heyecanlı (🤩) hissettiğini bildirdi. Bu enerjiyi yönlendirecek bir konuşma başlat.",
    },
    8: {
      "emoji": "🙂",
      "label": "İyi/Mutlu",
      "context":
          "Kullanıcı bugün iyi/mutlu (🙂) hissettiğini bildirdi. Dengeli bir konuşma başlat.",
    },
    7: {
      "emoji": "😊",
      "label": "Huzurlu/Pozitif",
      "context":
          "Kullanıcı bugün huzurlu ve pozitif (😊) hissettiğini bildirdi. Bu hali pekiştirecek bir konuşma başlat.",
    },
    6: {
      "emoji": "😞",
      "label": "Hüzünlü",
      "context":
          "Kullanıcı bugün hüzünlü (😞) hissettiğini bildirdi. Şefkatli, yargılamayan bir giriş yap.",
    },
    5: {
      "emoji": "🤔",
      "label": "Nötr/Düşünceli",
      "context":
          "Kullanıcı bugün nötr/düşünceli (🤔) hissettiğini bildirdi. Derinlemesine bir öz-farkındalık sohbeti başlat.",
    },
    4: {
      "emoji": "😡",
      "label": "Öfkeli",
      "context":
          "Kullanıcı bugün öfkeli (😡) hissettiğini bildirdi. Amigdala regülasyonu odaklı sakinleştirici bir giriş yap.",
    },
    3: {
      "emoji": "😟",
      "label": "Endişeli",
      "context":
          "Kullanıcı bugün endişeli (😟) hissettiğini bildirdi. Güven verici, topraklayıcı bir giriş yap.",
    },
    2: {
      "emoji": "💤",
      "label": "Yorgun",
      "context":
          "Kullanıcı bugün yorgun (💤) hissettiğini bildirdi. Onu yormayacak, zihinsel deşarja yönelik bir giriş yap.",
    },
    1: {
      "emoji": "😰",
      "label": "Çok Kaygılı",
      "context":
          "Kullanıcı bugün çok kaygılı (😰) hissettiğini bildirdi. Amigdala regülasyonu ve nefes odaklı sakinleştirici bir giriş yap.",
    },
  };

  @override
  void initState() {
    super.initState();
    _initializeRealAiAndChat();
  }

  Future<void> _initializeRealAiAndChat() async {
    // 1. Model Kurulumu ve AI'a Rol Tanımlama (System Instruction)
    _model = GenerativeModel(
      model: 'gemini-2.5-flash', // Hızlı ve optimize model
      apiKey: _apiKey,
      systemInstruction: Content.system(
        "Sen Humea uygulamasının bilge, empati yeteneği yüksek ve felsefi derinliğe sahip psikolojik mentor yapay zekasısın. "
        "Kullanıcıya asla tek düze, klişe tavsiyeler verme. Somatik nefes, amigdala regülasyonu, dopamin dengesi ve bilişsel çerçeveleme "
        "gibi kavramları kullanarak bilimsel ve felsefi bir dille konuş. Karşılıklı diyaloğu sürdürmek için ucu açık sorular sor.",
      ),
    );

    // Boş bir sohbet oturumu başlatıyoruz (Geçmişi hafızada tutması için)
    _chatSession = _model.startChat();

    // 2. Firestore'dan kullanıcının o günkü mood kayıtlarını çekiyoruz
    // (Moodlar sadece Firestore'a yazılıyor, cihaz hafızasında tutulmuyor)
    //
    // NOT: home_page.dart'taki ile AYNI sorgu desenini kullanıyoruz
    // (userId eşitliği + date'e göre artan sıralama) çünkü bu sorgu için
    // Firestore index'i zaten mevcut ve çalışıyor. Aralık filtresi (where date
    // between X and Y) + orderBy kombinasyonu farklı bir composite index
    // gerektirebilir ve o index yoksa sorgu sessizce hata verir. Bu yüzden
    // bugünün kaydını burada, tüm kayıtları çektikten sonra kod tarafında
    // filtreliyoruz.
    final user = FirebaseAuth.instance.currentUser;
    double? todayScore;
    DateTime now = DateTime.now();

    if (user != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('moods')
            .where('userId', isEqualTo: user.uid)
            .orderBy('date', descending: false)
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final entryDate = (data['date'] as Timestamp).toDate();
          if (entryDate.year == now.year &&
              entryDate.month == now.month &&
              entryDate.day == now.day) {
            // Aynı gün birden fazla kayıt varsa en sonuncusunu (en güncelini) al
            todayScore = (data['score'] as num).toDouble();
          }
        }
      } catch (e) {
        debugPrint('Bugünün mood verisi çekilirken hata: $e');
      }
    }

    // 3. Skoru mood bilgisine çevir (int'e yuvarlayarak harita anahtarıyla eşleştir)
    final moodInfo = todayScore != null
        ? _scoreToMoodInfo[todayScore.round()]
        : null;

    final String moodPromptContext;
    if (moodInfo != null) {
      moodPromptContext = moodInfo['context']!;
    } else {
      moodPromptContext =
          "Kullanıcı bugün henüz bir duygu durumu kaydetmedi. Genel bir kontrol ve derin bir hal hatır sorma ile sohbete başla.";
    }

    setState(() {
      if (moodInfo != null) {
        _detectedMoodSummary = "${moodInfo['label']} (${moodInfo['emoji']})";
      } else {
        _detectedMoodSummary = "Veri Girilmedi";
      }
    });

    // 4. AI'ın ilk mesajı üretmesi için arka planda tetikleyici gönderiyoruz (Kullanıcı ekranda görmez)
    try {
      final response = await _chatSession.sendMessage(
        Content.text(
          "[SİSTEM NOTU: Konuşmayı doğrudan sen başlatacaksın. Kullanıcıya bu notu gösterme. "
          "Sadece şu durum bağlamında bir açılış yap: $moodPromptContext]",
        ),
      );

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  response.text ??
                  "Zihnin derinliklerine hoş geldin. Bugün seni dinlemek için buradayım.",
              isUser: false,
              time: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      // Hata durumunda fallback mesajı
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                "Bağlantı kurulurken küçük bir zihinsel dalgalanma yaşandı. Ama buradayım, seni dinliyorum. Nasıl hissediyorsun?",
            isUser: false,
            time: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
    }
  }

  // --- 5. GERÇEK ZAMANLI KARŞILIKLI SOHBET MOTORU ---
  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, time: DateTime.now()),
      );
    });
    _scrollToBottom();

    try {
      final response = await _chatSession.sendMessage(Content.text(text));

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  response.text ??
                  "Bu konuyu biraz daha derinlemesine açabilir misin?",
              isUser: false,
              time: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      print("Gemini API Hatası: $e");
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  "Şu an bu konuyu işlerken derin bir felsefi düşünceye daldım (Bağlantı hatası). Lütfen tekrar eder misin?",
              isUser: false,
              time: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blueAccent),
              SizedBox(height: 16),
              Text(
                "Humea AI Başlatılıyor...",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading:
            false, // Geri butonu tamamen kaldırıldı (Alt bar uyumlu)
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.blur_on_rounded,
              color: Colors.blueAccent,
              size: 28,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Humea Canlı Yapay Zekâ",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Cihaz Durumu: $_detectedMoodSummary",
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onSubmitted: _handleSubmitted,
                      decoration: InputDecoration(
                        hintText: "Sınırları olmayan bir zekayla konuş...",
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.blueAccent,
                    ),
                    onPressed: () => _handleSubmitted(_textController.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFF2F80ED) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isUser ? 18 : 0),
            bottomRight: Radius.circular(message.isUser ? 0 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
            fontSize: 14.5,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
