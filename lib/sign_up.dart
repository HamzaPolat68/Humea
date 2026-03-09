import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1F5FE), // Açık mavi arka plan
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          width: double.infinity,
          height: MediaQuery.of(context).size.height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              // Logo
              FadeInDown(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Humea",
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.favorite, color: Colors.red, size: 30),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Kayıt Ol Başlığı
              FadeInLeft(
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Kayıt Ol",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Form Alanları
              FadeInUp(
                child: Column(
                  children: [
                    _buildTextField("Adınız ve Soyadınız"),
                    const SizedBox(height: 15),
                    _buildTextField("E-posta"),
                    const SizedBox(height: 15),
                    _buildTextField("Şifre", isPassword: true),
                    const SizedBox(height: 15),
                    _buildTextField("Şifre Tekrarı", isPassword: true),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Hesap Oluştur Butonu
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: _buildGradientButton("Hesap Oluştur", () {
                  // Kayıt işlemleri
                }),
              ),
              const SizedBox(height: 20),

              // Giriş Yap Yönlendirmesi
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    const Text(
                      "Zaten Hesabınız Var mı?",
                      style: TextStyle(color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Giriş sayfasına geri döner
                      },
                      child: const Text(
                        "Giriş Yap",
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Sosyal Medya İkonları
              const SizedBox(height: 20),
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialIcon("google"),
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

  // Yardımcı Metot: TextField Tasarımı
  Widget _buildTextField(String hint, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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

  // Yardımcı Metot: Degrade Buton
  Widget _buildGradientButton(String text, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF039BE5),
            Color(0xFFBA68C8),
          ], // Görseldeki mavi-mor tonları
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

  Widget _socialIcon(String type) {
    // Örnek Google ikonu için placeholder
    return Image.network(
      "https://pngimg.com/uploads/google/google_PNG19635.png",
      height: 30,
    );
  }
}
