import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static Future<void> syncFcmTokenToFirestore({String? userId}) async {
    final resolvedUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      return;
    }

    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(resolvedUserId)
        .set(buildFcmTokenPayload(token), SetOptions(merge: true));
  }

  static Map<String, dynamic> buildFcmTokenPayload(String? token) {
    if (token == null || token.trim().isEmpty) {
      return {};
    }

    return {
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    };
  }
}
