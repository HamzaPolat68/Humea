import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static Future<void> syncFcmTokenToFirestore({required String userId}) async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    try {
      // 1. Bildirim İznini İste
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print("Kullanıcı bildirim izni vermedi.");
        return;
      }

      // 2. iOS için APNs Token Kontrolü (Retry Mekanizmalı)
      if (Platform.isIOS) {
        String? apnsToken = await messaging.getAPNSToken();

        // APNs token gelene kadar kısa aralıklarla dene (Maksimum ~5 saniye)
        int retryCount = 0;
        while (apnsToken == null && retryCount < 5) {
          await Future.delayed(const Duration(seconds: 1));
          apnsToken = await messaging.getAPNSToken();
          retryCount++;
        }

        // Eğer simülatördeyseniz veya APNs alınamadıysa dur
        if (apnsToken == null) {
          print(
            "APNs Token alınamadı (Simülatör veya APNs yapılandırma eksikliği). FCM pas geçiliyor.",
          );
          return;
        }
      }

      // 3. FCM Token Al
      String? fcmToken = await messaging.getToken();

      if (fcmToken != null) {
        print("FCM Token Başarıyla Alındı: $fcmToken");

        // Firestore Güncellemesi:
        // await FirebaseFirestore.instance
        //     .collection('users')
        //     .doc(userId)
        //     .update({'fcmToken': fcmToken});
      }
    } catch (e) {
      // Olası bir [firebase_messaging/apns-token-not-set] veya ağ hatasını yakala
      print("FCM Token alma/senkronize etme hatası: $e");
    }
  }
}
