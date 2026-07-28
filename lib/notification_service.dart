import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static Future<void> syncFcmTokenToFirestore({required String userId}) async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    // iOS için bildirim izinlerini istiyoruz
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // iOS cihazlarda APNS Token gelene kadar kısa süre bekleme kontrolü (özellikle simülatör için)
      if (Platform.isIOS) {
        String? apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          // APNS henüz hazır değilse biraz bekleyelim
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await messaging.getAPNSToken();
        }

        // Eğer simülatördeyseniz apnsToken null kalmaya devam edebilir
        if (apnsToken == null) {
          print(
            "APNS Token henüz hazır değil. FCM Token alma adımı atlanıyor.",
          );
          return;
        }
      }

      // APNS hazırsa veya Android ortamındaysak FCM token'ı alıyoruz
      String? fcmToken = await messaging.getToken();
      if (fcmToken != null) {
        // Firestore kaydınız:
        // await FirebaseFirestore.instance.collection('users').doc(userId).update({'fcmToken': fcmToken});
      }
    }
  }
}
