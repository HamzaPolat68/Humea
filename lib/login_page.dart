import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:humea/sign_up.dart';
import 'package:humea/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 1. Controller'ları tanımlıyoruz
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 2. Firebase Giriş Fonksiyonu
  Future<void> _login() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage("Lütfen e-posta ve şifrenizi girin.");
      return;
    }

    try {
      // Firebase ile giriş yapma işlemi
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Giriş başarılıysa ana sayfaya yönlendir
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Hata yönetimi
      String message = "Bir hata oluştu";
      if (e.code == 'user-not-found') {
        message = "Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı.";
      } else if (e.code == 'wrong-password') {
        message = "Hatalı şifre girdiniz.";
      } else if (e.code == 'invalid-email') {
        message = "Geçersiz e-posta formatı.";
      }
      _showMessage(message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1F5FE),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          height: MediaQuery.of(context).size.height,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 60),
              FadeInDown(
                duration: const Duration(milliseconds: 1000),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Humea",
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.favorite, color: Colors.red, size: 30),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              FadeInLeft(
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Giriş Yap",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Giriş Formu - Controllerlar eklendi
              FadeInUp(
                child: Column(
                  children: [
                    _buildTextField("E-posta", _emailController),
                    const SizedBox(height: 15),
                    _buildTextField(
                      "Şifre",
                      _passwordController,
                      isPassword: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Giriş Yap Butonu
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: _buildGradientButton("Giriş Yap", _login),
              ),

              const SizedBox(height: 15),
              FadeInUp(
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    "Şifremi Unuttum?",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Yeni Hesap Oluştur
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: _buildGradientButton("Yeni Bir Hesap Oluştur", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignUpPage()),
                  );
                }),
              ),
              const SizedBox(height: 30),

              // Sosyal Medya İkonları
              FadeInUp(
                delay: const Duration(milliseconds: 600),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialIcon('google'),
                    const SizedBox(width: 25),
                    const Icon(Icons.apple, size: 40),
                    const SizedBox(width: 25),
                    const Icon(Icons.facebook, color: Colors.blue, size: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController controller, {
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          const BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildGradientButton(String text, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFFCE93D8)],
        ),
      ),
      child: MaterialButton(
        onPressed: onPressed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Text(
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

  Widget _socialIcon(String path) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.transparent,
      child: Image.network(
        "https://pngimg.com/uploads/google/google_PNG19635.png",
        height: 30,
      ),
    );
  }
}
