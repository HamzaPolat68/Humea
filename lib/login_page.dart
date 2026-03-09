import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:humea/sign_up.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 60),
              // Logo
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

              // Giriş Başlığı
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

              // Giriş Formu
              FadeInUp(
                child: Column(
                  children: [
                    _buildTextField("E-posta"),
                    const SizedBox(height: 15),
                    _buildTextField("Şifre", isPassword: true),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Giriş Yap Butonu (Degrade)
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: _buildGradientButton("Giriş Yap", () {}),
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

              // Yeni Hesap Oluştur Butonu
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: _buildGradientButton("Yeni Bir Hesap Oluştur", () {
                  // SAYFA GEÇİŞ KOMUTU BURADA:
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
                    _socialIcon(
                      'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                      isSvg: false,
                    ), // Asset eklemeyi unutmayın
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

  // Textfield Tasarımı
  Widget _buildTextField(String hint, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
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

  // Degrade Buton Tasarımı
  Widget _buildGradientButton(String text, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFFCE93D8)], // Mavi-Mor degrade
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

  Widget _socialIcon(String path, {bool isSvg = false}) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.transparent,
      child: Image.network(
        "https://pngimg.com/uploads/google/google_PNG19635.png",
        height: 30,
      ), // Örnek google ikonu
    );
  }
}
