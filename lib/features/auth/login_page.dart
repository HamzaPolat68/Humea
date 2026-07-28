import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:humea/features/auth/sign_up.dart';
import 'package:humea/home/home_page.dart';
import 'package:humea/services/notification_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;

class LoginPage extends StatefulWidget {
  final String? initialEmail;
  final String? initialPassword;

  const LoginPage({super.key, this.initialEmail, this.initialPassword});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? "";
    _passwordController.text = widget.initialPassword ?? "";
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  Future<void> _handleAction(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? "Bir hata oluştu", Colors.redAccent);
    } catch (e) {
      _showMessage("Hata: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    // 1. Firebase Auth ile giriş yapılıyor
    UserCredential userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

    // ==================== ESKİ KULLANICI KONTROLÜ VE EKLEME ====================
    User? user = userCredential.user;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        String calculatedName =
            user.displayName ?? _emailController.text.trim().split('@').first;

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'userImageUrl': user.photoURL ?? '',
          'name': calculatedName,
          'searchName': calculatedName.toLowerCase(),
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print("Eski kullanıcının eksik Firestore kaydı başarıyla oluşturuldu.");
      }

      // GÜNCELLEME BURADA: FCM Hatası Giriş İşlemini Engellemesin
      try {
        await NotificationService.syncFcmTokenToFirestore(userId: user.uid);
      } catch (e) {
        print("FCM Token senkronizasyon hatası es geçildi: $e");
      }
    }
    // ===========================================================================

    if (mounted) _navigateToHome();
  }

  Future<void> _signInWithGoogle() async {
    try {
      const String webClientId =
          '885686922988-u4g39no20kmdtreri7kn1akmbu5fdb61.apps.googleusercontent.com';

      // GoogleService-Info.plist dosyanızdaki gerçek iOS CLIENT_ID
      const String iosClientId =
          '885686922988-9ghv15k6bvuth3hcql8vg7ei9qj12r46.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
        serverClientId: webClientId,
        clientId: Platform.isIOS ? iosClientId : null, // ✅ DOĞRU (iOS ID'si)
      );

      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      User? user = userCredential.user;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          String calculatedName =
              user.displayName ?? user.email!.split('@').first;

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'uid': user.uid,
                'name': calculatedName,
                'searchName': calculatedName.toLowerCase(),
                'email': user.email,
                'createdAt': FieldValue.serverTimestamp(),
              });
        }

        // Notification senkronizasyonunu ayrı bir try-catch'e alıyoruz
        // ki bildirim hatası giriş yapmayı engellemesin/çökertmesin:
        try {
          await NotificationService.syncFcmTokenToFirestore(userId: user.uid);
        } catch (e) {
          print(
            "FCM Token alınamadı (Simülatörde veya bildirim izni yoksa normaldir): $e",
          );
        }
      }

      _showMessage("Google ile başarıyla giriş yapıldı!", Colors.green);
      _navigateToHome();
    } catch (e) {
      print("Google Giriş Hatası: $e");
      _showMessage("Google girişi başarısız oldu.", Colors.redAccent);
    }
  }

  Future<void> _signInWithApple() async {
    try {
      UserCredential userCredential;

      if (Platform.isAndroid) {
        final appleProvider = AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');

        userCredential = await FirebaseAuth.instance.signInWithProvider(
          appleProvider,
        );
      } else {
        final rawNonce = _generateNonce();
        final hashedNonce = _sha256ofString(rawNonce);

        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: hashedNonce,
        );

        final oauthCredential = OAuthProvider("apple.com").credential(
          idToken: appleCredential.identityToken,
          rawNonce: rawNonce,
        );

        userCredential = await FirebaseAuth.instance.signInWithCredential(
          oauthCredential,
        );

        String? displayName;
        if (appleCredential.givenName != null ||
            appleCredential.familyName != null) {
          displayName =
              "${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}"
                  .trim();
        }

        User? user = userCredential.user;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (!userDoc.exists) {
            String calculatedName =
                displayName ??
                user.displayName ??
                (user.email != null
                    ? user.email!.split('@').first
                    : "Kullanıcı");

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
                  'uid': user.uid,
                  'name': calculatedName,
                  'searchName': calculatedName.toLowerCase(),
                  'email': user.email ?? appleCredential.email ?? '',
                  'createdAt': FieldValue.serverTimestamp(),
                });
          }
          try {
            await NotificationService.syncFcmTokenToFirestore(userId: user.uid);
          } catch (e) {
            print("FCM Token senkronizasyon hatası es geçildi: $e");
          }
        }
      }

      _showMessage("Apple ile başarıyla giriş yapıldı!", Colors.green);
      _navigateToHome();
    } catch (e) {
      print("Apple Giriş Hatası: $e");
      _showMessage("Apple girişi başarısız oldu.", Colors.redAccent);
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/arka_plan.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeInDown(
                          child: const Icon(
                            Icons.favorite,
                            size: 60,
                            color: Color(0xFFEF5350),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Humea",
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 40),

                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 25,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildTextField(
                                _emailController,
                                "E-posta",
                                Icons.email_outlined,
                              ),
                              const SizedBox(height: 15),
                              _buildTextField(
                                _passwordController,
                                "Şifre",
                                Icons.lock_outline,
                                isPassword: true,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordSheet,
                                  child: const Text(
                                    "Şifremi Unuttum?",
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 213, 46, 8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildGradientButton(
                                "Giriş Yap",
                                () => _handleAction(_login),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildGradientButton(
                          "Yeni Hesap Oluştur",
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignUpPage(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        FadeInUp(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialIconButton(
                                onPressed: () =>
                                    _handleAction(_signInWithGoogle),
                                iconWidget: Image.network(
                                  "https://pngimg.com/uploads/google/google_PNG19635.png",
                                  height: 28,
                                ),
                              ),
                              const SizedBox(width: 20),
                              _buildSocialIconButton(
                                onPressed: () =>
                                    _handleAction(_signInWithApple),
                                iconWidget: const Icon(
                                  Icons.apple,
                                  size: 32,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 15,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildGradientButton(String text, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF64B5F6), Color(0xFFBA68C8)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: MaterialButton(
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
      ),
    );
  }

  Widget _buildSocialIconButton({
    required VoidCallback onPressed,
    required Widget iconWidget,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: iconWidget,
      ),
    );
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(_resetEmailController, "E-posta", Icons.email),
            const SizedBox(height: 20),
            _buildGradientButton(
              "Sıfırlama Bağlantısı Gönder",
              () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
