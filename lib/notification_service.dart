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

      // 2. iOS Kontrolü
      if (Platform.isIOS) {
        String? apnsToken;

        // APNs token alma işlemini de try-catch içine alıyoruz
        try {
          apnsToken = await messaging.getAPNSToken();

          int retryCount = 0;
          while (apnsToken == null && retryCount < 3) {
            await Future.delayed(const Duration(seconds: 1));
            apnsToken = await messaging.getAPNSToken();
            retryCount++;
          }
        } catch (e) {
          // getAPNSToken() metodunun fırlattığı [firebase_messaging/apns-token-not-set] burada yakalanır
          print(
            "APNs Token alınırken hata yakalandı (Simülatör veya APNs yok): $e",
          );
        }

        // Eğer APNs token gelmediyse FCM token istemeden fonksiyondan çık
        if (apnsToken == null) {
          print(
            "APNs Token bulunamadı. Kayıt işlemine FCM olmadan devam ediliyor.",
          );
          return;
        }
      }

      // 3. FCM Token Al
      String? fcmToken = await messaging.getToken();

      if (fcmToken != null) {
        print("FCM Token Başarıyla Alındı: $fcmToken");
        // Firestore Güncellemesi
      }
    } catch (e) {
      // Dışarıya hiçbir kırmızı hata uyarısı sızmaması için ana catch
      print("NotificationService Genel Hata Yakalandı: $e");
    }
  }
}
