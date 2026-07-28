import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:humea/features/auth/login_page.dart';
import 'package:humea/home/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  // Mevcut kullanıcıyı kontrol et
  User? currentUser = FirebaseAuth.instance.currentUser;

  // Uygulamayı başlat
  runApp(MyApp(isLoggedIn: currentUser != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

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
      home: isLoggedIn ? const HomePage() : const LoginPage(),
    );
  }
}
