import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:humea/features/auth/login_page.dart';
import 'package:humea/home/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';

// 1. Arka plan bildirim işleyicisi (Main'in dışında, en üstte)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Bildirim (Kapalıyken) geldi: ${message.messageId}");
}

void main() async {
  // Flutter binding başlat
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('tr_TR', null);

  // Firebase ve Dotenv başlat
  await dotenv.load(fileName: "assets/.env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Arka plan işleyiciyi kaydet
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Uygulamayı başlat
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Humea',
      locale: const Locale('tr', 'TR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthGate(),
    );
  }
}

/// Oturum ve Ban Durumunu Yöneten Geçit (AuthGate)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Bağlantı beklenirken yüklenme ekranı
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Oturum açmış kullanıcı varsa Ban Kontrol Katmanına yönlendir
        if (snapshot.hasData && snapshot.data != null) {
          return BanCheckWrapper(user: snapshot.data!);
        }

        // Oturum kapalıysa Doğrudan Login Ekranı
        return const LoginPage();
      },
    );
  }
}

/// Kullanıcının Ban Durumunu Canlı Dinleyen Wrapper Widget
class BanCheckWrapper extends StatefulWidget {
  final User user;
  const BanCheckWrapper({super.key, required this.user});

  @override
  State<BanCheckWrapper> createState() => _BanCheckWrapperState();
}

class _BanCheckWrapperState extends State<BanCheckWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;

          // Kullanıcı banlanmış mı kontrol et
          if (userData != null && userData['isBanned'] == true) {
            // Asenkron çıkış işlemini ilk kare çizildikten sonra güvenle çalıştır
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text("Uzaklaştırıldınız"),
                    content: const Text(
                      "Topluluk kurallarını ihlal ettiğiniz için hesabınız askıya alınmıştır.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text("Tamam"),
                      ),
                    ],
                  ),
                );
              }
            });

            return const LoginPage();
          }
        }

        // Ban durumu yoksa kullanıcı Ana Sayfaya erişebilir
        return const HomePage();
      },
    );
  }
}
