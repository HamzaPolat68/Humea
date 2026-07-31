import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  // 1. İçeriği Silme Aksiyonu
  Future<void> _deleteContent({
    required String reportId,
    required String targetType,
    required String targetId,
    required String? postId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    if (targetType == 'post') {
      await firestore.collection('posts').doc(targetId).delete();
    } else if (targetType == 'comment' && postId != null) {
      await firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(targetId)
          .delete();
      await firestore.collection('posts').doc(postId).update({
        'commentsCount': FieldValue.increment(-1),
      });
    }

    // Şikayet durumunu 'müdahale edildi' yap
    await firestore.collection('reports').doc(reportId).update({
      'status': 'action_taken',
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("İçerik sistemden silindi.")),
      );
    }
  }

  // 2. Kullanıcıyı Engelleme (Eject) Aksiyonu
  Future<void> _banUser({
    required String reportId,
    required String userId,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isBanned': true,
      'bannedAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('reports').doc(reportId).update(
      {'status': 'action_taken', 'reviewedAt': FieldValue.serverTimestamp()},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kullanıcı sistemden uzaklaştırıldı (Ejected)."),
        ),
      );
    }
  }

  // 3. Şikayeti Yoksay (Aksiyon almadan kapat)
  Future<void> _dismissReport(String reportId) async {
    await FirebaseFirestore.instance.collection('reports').doc(reportId).update(
      {'status': 'dismissed', 'reviewedAt': FieldValue.serverTimestamp()},
    );
  }

  // Kullanıcı adını Firestore'dan getiren yardımcı metot
  Future<String> _getUserName(String userId) async {
    if (userId.isEmpty) return "Bilinmeyen Kullanıcı";
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        return data?['displayName'] ??
            data?['name'] ??
            data?['userName'] ??
            userId;
      }
    } catch (_) {}
    return userId;
  }

  // İçeriğin detayını (Gönderi veya yorum metnini) getiren yardımcı metot
  Future<String> _getContentText({
    required String targetType,
    required String targetId,
    String? postId,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      if (targetType == 'post') {
        final doc = await firestore.collection('posts').doc(targetId).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          return data['note'] ??
              data['content'] ??
              data['text'] ??
              data['mesaj'] ??
              "İçerik metni boş";
        }
      } else if (targetType == 'comment' && postId != null) {
        final doc = await firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(targetId)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          return data['comment'] ??
              data['text'] ??
              data['content'] ??
              "Yorum metni boş";
        }
      }
    } catch (_) {}
    return "İçerik bulunamadı veya silinmiş olabilir.";
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Moderasyon Paneli"),
          backgroundColor: Colors.redAccent,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.flag), text: "İçerik Şikayetleri"),
              Tab(icon: Icon(Icons.block), text: "Engelleme Bildirimleri"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // =================================================================
            // SEKME 1: İÇERİK ŞİKAYETLERİ
            // =================================================================
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('status', isEqualTo: 'pending')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Bekleyen şikayet yok 🎉"));
                }

                final reports = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final data = report.data() as Map<String, dynamic>;

                    final String targetType = data['targetType'] ?? 'post';
                    final String reportedUserId = data['reportedUserId'] ?? '';
                    final String targetId = data['targetId'] ?? '';
                    final String? postId = data['postId'];

                    return Card(
                      margin: const EdgeInsets.all(10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Başlık Etiketi ve Şikayet Nedeni
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Chip(
                                  label: Text(
                                    targetType.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: Colors.deepOrange,
                                ),
                                Expanded(
                                  child: Text(
                                    "Neden: ${data['reason'] ?? 'Belirtilmedi'}",
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // 1. ŞİKAYET EDİLEN KİŞİ (Kullanıcı Adı)
                            FutureBuilder<String>(
                              future: _getUserName(reportedUserId),
                              builder: (context, userSnap) {
                                return Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Şikayet Edilen: ",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        userSnap.data ?? "Yükleniyor...",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),

                            // 2. ŞİKAYET EDİLEN İÇERİK/MESAJ
                            FutureBuilder<String>(
                              future: _getContentText(
                                targetType: targetType,
                                targetId: targetId,
                                postId: postId,
                              ),
                              builder: (context, contentSnap) {
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "İçerik / Mesaj:",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        contentSnap.data ??
                                            "İçerik yükleniyor...",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 25),

                            // 3. AKSİYON BUTONLARI (Overflow önleyici Wrap kullanımı)
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () => _dismissReport(report.id),
                                  child: const Text("Yoksay"),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                  ),
                                  onPressed: () => _deleteContent(
                                    reportId: report.id,
                                    targetType: targetType,
                                    targetId: targetId,
                                    postId: postId,
                                  ),
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    "İçeriği Sil",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () => _banUser(
                                    reportId: report.id,
                                    userId: reportedUserId,
                                  ),
                                  icon: const Icon(
                                    Icons.block,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    "Banla (Eject)",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // =================================================================
            // SEKME 2: ENGELLEME BİLDİRİMLERİ
            // =================================================================
            // =================================================================
            // SEKME 2: ENGELLEME BİLDİRİMLERİ (YENİLENMİŞ - İSİMLİ GÖSTERİM)
            // =================================================================
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('admin_notifications')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("Henüz engelleme bildirimi bulunmuyor."),
                  );
                }

                final notifications = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final data =
                        notifications[index].data() as Map<String, dynamic>;

                    final String reporterId = data['reporterUserId'] ?? '';
                    final String blockedId = data['blockedUserId'] ?? '';
                    final String? rawMessage = data['message'];

                    final Timestamp? ts = data['timestamp'] as Timestamp?;
                    String timeStr = ts != null
                        ? "${ts.toDate().day.toString().padLeft(2, '0')}/${ts.toDate().month.toString().padLeft(2, '0')}/${ts.toDate().year} ${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}"
                        : "Yeni";

                    return FutureBuilder<List<String>>(
                      future: Future.wait([
                        _getUserName(reporterId),
                        _getUserName(blockedId),
                      ]),
                      builder: (context, namesSnap) {
                        String reporterName =
                            data['reporterUserName'] ?? "Bir kullanıcı";
                        String blockedName =
                            data['blockedUserName'] ?? "Kullanıcı";

                        if (namesSnap.hasData) {
                          if (namesSnap.data![0] != reporterId) {
                            reporterName = namesSnap.data![0];
                          }
                          if (namesSnap.data![1] != blockedId) {
                            blockedName = namesSnap.data![1];
                          }
                        }

                        // Mesaj oluşturma
                        String displayMessage =
                            "$reporterName kullanıcısı, $blockedName kullanıcısını engelledi.";

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: const CircleAvatar(
                              backgroundColor: Colors.redAccent,
                              child: Icon(Icons.block, color: Colors.white),
                            ),
                            title: Text(
                              displayMessage,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                "Tarih: $timeStr",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
