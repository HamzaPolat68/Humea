import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:humea/features/auth/sign_up.dart';
import 'package:humea/home/home_page.dart';
import 'package:humea/services/notification_service.dart';

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
          'searchName': calculatedName
              .toLowerCase(), // Arama için küçük harf indeks
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print("Eski kullanıcının eksik Firestore kaydı başarıyla oluşturuldu.");
      }

      await NotificationService.syncFcmTokenToFirestore(userId: user.uid);
    }
    // ===========================================================================

    if (mounted) _navigateToHome();
  }

  Future<void> _signInWithGoogle() async {
    try {
      // ⚠️ Firebase Console / Google Cloud Console üzerindeki "Web Client ID" bilgisini buraya yazın:
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
        serverClientId:
            '885686922988-u4g39no20kmdtreri7kn1akmbu5fdb61.apps.googleusercontent.com',
      );

      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null)
        return; // Kullanıcı seçim yapmadan pencereyi kapattıysa

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      // Google ile Firebase Auth girişi yapılıyor
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      // ==================== GOOGLE İÇİN ESKİ KULLANICI KONTROLÜ ====================
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
                'searchName': calculatedName
                    .toLowerCase(), // Arama için küçük harf indeks
                'email': user.email,
                'createdAt': FieldValue.serverTimestamp(),
              });
          print(
            "Google ile giren eski kullanıcının eksik Firestore kaydı oluşturuldu.",
          );
        }

        await NotificationService.syncFcmTokenToFirestore(userId: user.uid);
      }
      // =============================================================================

      _showMessage("Google ile başarıyla giriş yapıldı! 🎉", Colors.green);
      _navigateToHome();
    } catch (e) {
      _showMessage("Google girişinde hata oluştu: $e", Colors.redAccent);
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
                          child: _buildSocialIconButton(
                            onPressed: () => _handleAction(_signInWithGoogle),
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

  Widget _buildSocialIconButton({required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Image.network(
          "https://pngimg.com/uploads/google/google_PNG19635.png",
          height: 28,
        ),
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
