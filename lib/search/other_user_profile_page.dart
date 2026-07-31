import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth eklendi
import 'package:fl_chart/fl_chart.dart';

class OtherUserProfilePage extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final String targetPhotoUrl;

  const OtherUserProfilePage({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    required this.targetPhotoUrl,
  });

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> {
  bool _isBlocking = false;

  // DİNAMİK ENGELLEME FONKSİYONU (Tüm Kullanıcılar İçin)
  Future<void> _blockUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;

    if (currentUserId == null || currentUserId == widget.targetUserId) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${widget.targetUserName} Engellensin mi?"),
        content: const Text(
          "Bu kullanıcıyı engellediğinizde paylaşımlarını artık akışınızda görmeyeceksiniz. Bu durum inceleme için geliştirici ekibine bildirilecektir.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Engelle", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isBlocking = true);

      try {
        final firestore = FirebaseFirestore.instance;

        // Engellemeye çalışan kullanıcının ismini alalım
        final reporterUserName = currentUser?.displayName ?? "Bir kullanıcı";

        // 1. Kendi engellenenler koleksiyonumuza ekle
        await firestore
            .collection('users')
            .doc(currentUserId)
            .collection('blocked_users')
            .doc(widget.targetUserId)
            .set({
              'blockedUserId': widget.targetUserId,
              'blockedUserName': widget.targetUserName,
              'timestamp': FieldValue.serverTimestamp(),
            });

        // 2. GELİŞTİRİCİ EKİBİNE / ADMİNE BİLDİRİM GÖNDER
        await firestore.collection('admin_notifications').add({
          'type': 'user_blocked',
          'reporterUserId': currentUserId,
          'reporterUserName': reporterUserName,
          'blockedUserId': widget.targetUserId,
          'blockedUserName': widget.targetUserName,
          'message':
              "$reporterUserName kullanıcısı, ${widget.targetUserName} kullanıcısını engelledi.",
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${widget.targetUserName} engellendi."),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint("Engelleme hatası: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Engelleme işlemi sırasında bir sorun oluştu."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isBlocking = false);
      }
    }
  }

  ImageProvider _resolveImageProvider(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    }
    return FileImage(File(url));
  }

  Widget _buildAvatarPlaceholder(
    String name, {
    double radius = 50,
    double fontSize = 32,
  }) {
    String initials = "";
    List<String> nameParts = name.trim().split(" ");
    if (nameParts.isNotEmpty && nameParts.first.isNotEmpty) {
      initials += nameParts.first[0].toUpperCase();
      if (nameParts.length > 1 && nameParts.last.isNotEmpty) {
        initials += nameParts.last[0].toUpperCase();
      }
    } else {
      initials = "?";
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blueAccent.withOpacity(0.2),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.blue[800],
        ),
      ),
    );
  }

  String _getPostContent(Map<String, dynamic> post) {
    final candidates = [
      post['note'],
      post['content'],
      post['text'],
      post['gonderi'],
      post['mesaj'],
      post['description'],
      post['title'],
    ];

    for (final value in candidates) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) {
        return value.toString();
      }
    }

    return '';
  }

  List<FlSpot> _getWeeklySpots(List<QueryDocumentSnapshot> moodDocs) {
    DateTime now = DateTime.now();
    DateTime targetMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    DateTime targetSunday = targetMonday.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );

    Map<int, List<double>> dailyScores = {
      0: [],
      1: [],
      2: [],
      3: [],
      4: [],
      5: [],
      6: [],
    };

    for (var doc in moodDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['date'] == null || data['score'] == null) continue;

      final DateTime date = (data['date'] as Timestamp).toDate();
      final double score = (data['score'] as num).toDouble();

      if (date.isAfter(targetMonday.subtract(const Duration(seconds: 1))) &&
          date.isBefore(targetSunday)) {
        int weekdayIndex = date.weekday - 1;
        dailyScores[weekdayIndex]?.add(score);
      }
    }

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

  @override
  Widget build(BuildContext context) {
    bool hasValidPhoto =
        widget.targetPhotoUrl.isNotEmpty &&
        widget.targetPhotoUrl != 'https://via.placeholder.com/150';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.targetUserName),
        backgroundColor: const Color(0xFF039BE5),
        // --- DİNAMİK ENGELLE (BLOCK) BUTONU ---
        actions: [
          IconButton(
            icon: _isBlocking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.block, color: Colors.white),
            tooltip: "Kullanıcıyı Engelle",
            onPressed: _isBlocking ? null : _blockUser,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --- ANA PROFİL FOTOĞRAFI ---
            hasValidPhoto
                ? CircleAvatar(
                    radius: 50,
                    backgroundImage: _resolveImageProvider(
                      widget.targetPhotoUrl,
                    ),
                    backgroundColor: Colors.grey[200],
                  )
                : _buildAvatarPlaceholder(
                    widget.targetUserName,
                    radius: 50,
                    fontSize: 32,
                  ),

            const SizedBox(height: 10),
            Text(
              widget.targetUserName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 40, thickness: 1),

            // --- BÖLÜM 1: GRAFİK ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Bu Haftaki Ruh Hali Grafiği",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 180,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('moods')
                    .where('userId', isEqualTo: widget.targetUserId)
                    .orderBy('date', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text("Bu hafta kaydedilmiş mod yok."),
                    );
                  }
                  List<FlSpot> spots = _getWeeklySpots(snapshot.data!.docs);
                  if (spots.isEmpty) {
                    return const Center(
                      child: Text("Bu haftaya ait veri yok."),
                    );
                  }

                  return LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final labels = [
                                'Pzt',
                                'Sal',
                                'Çrş',
                                'Prş',
                                'Cum',
                                'Cmt',
                                'Paz',
                              ];
                              if (value.toInt() < 0 ||
                                  value.toInt() >= labels.length) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  labels[value.toInt()],
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 6,
                      minY: 0,
                      maxY: 10,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          barWidth: 4,
                          color: Colors.purpleAccent,
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.purpleAccent.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 40, thickness: 1),

            // --- BÖLÜM 2: GÖNDERİLER ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Paylaştığı Gönderiler",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('userId', isEqualTo: widget.targetUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text("Henüz hiç gönderi paylaşmamış."),
                  );
                }

                final docs = snapshot.data!.docs;

                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;

                  final aTime =
                      aData['createdAt'] ??
                      aData['date'] ??
                      aData['timestamp'] ??
                      aData['tarih'];
                  final bTime =
                      bData['createdAt'] ??
                      bData['date'] ??
                      bData['timestamp'] ??
                      bData['tarih'];

                  if (aTime == null || bTime == null) return 0;
                  return (bTime as Timestamp).compareTo(aTime as Timestamp);
                });

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final post = docs[index].data() as Map<String, dynamic>;

                    String timeText = "Bilinmeyen Tarih";
                    final dynamic rawDate =
                        post['createdAt'] ??
                        post['date'] ??
                        post['timestamp'] ??
                        post['tarih'];
                    if (rawDate != null && rawDate is Timestamp) {
                      final date = rawDate.toDate();
                      timeText =
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                    }

                    String postContent = _getPostContent(post);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: hasValidPhoto
                            ? CircleAvatar(
                                backgroundColor: Colors.grey[200],
                                child: Text(
                                  timeText,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : _buildAvatarPlaceholder(
                                widget.targetUserName,
                                radius: 22,
                                fontSize: 14,
                              ),
                        title: Text(
                          postContent.isEmpty ? 'Yazı yok' : postContent,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            timeText,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
