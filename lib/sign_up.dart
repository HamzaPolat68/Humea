import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // 1. Verileri almak için Controller'ları tanımlıyoruz
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // 2. Firebase Kayıt Fonksiyonu
  Future<void> _registerUser() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    // Basit kontroller
    if (email.isEmpty || password.isEmpty || _nameController.text.isEmpty) {
      _showMessage("Lütfen tüm alanları doldurun.");
      return;
    }

    if (password != confirmPassword) {
      _showMessage("Şifreler uyuşmuyor!");
      return;
    }

    try {
      // Firebase'e kullanıcıyı kaydediyoruz
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Kullanıcının adını profiline ekliyoruz
      await userCredential.user?.updateDisplayName(_nameController.text);

      _showMessage("Hesap başarıyla oluşturuldu!");

      // Başarılıysa giriş sayfasına veya ana sayfaya yönlendirebilirsin
    } on FirebaseAuthException catch (e) {
      // Firebase'den gelen spesifik hataları yakalıyoruz
      if (e.code == 'weak-password') {
        _showMessage("Şifre çok zayıf.");
      } else if (e.code == 'email-already-in-use') {
        _showMessage("Bu e-posta zaten kullanımda.");
      } else {
        _showMessage(
          "Bir hata oluştu: E-posta adresi hatalı formatta olabilir.",
        );
      }
    } catch (e) {
      _showMessage("Beklenmedik bir hata oluştu.");
    }
  }

  // Hata mesajlarını göstermek için yardımcı fonksiyon
  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1F5FE),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          width: double.infinity,
          height: MediaQuery.of(context).size.height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
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

              // Form Alanları - Controllerlar eklendi
              FadeInUp(
                child: Column(
                  children: [
                    _buildTextField("Adınız ve Soyadınız", _nameController),
                    const SizedBox(height: 15),
                    _buildTextField("E-posta", _emailController),
                    const SizedBox(height: 15),
                    _buildTextField(
                      "Şifre",
                      _passwordController,
                      isPassword: true,
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      "Şifre Tekrarı",
                      _confirmPasswordController,
                      isPassword: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: _buildGradientButton(
                  "Hesap Oluştur",
                  _registerUser,
                ), // Fonksiyon bağlandı
              ),
              const SizedBox(height: 20),

              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    const Text(
                      "Zaten Hesabınız Var Mı?",
                      style: TextStyle(color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller, // Kontrolcü buraya bağlandı
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
          colors: [Color(0xFF039BE5), Color(0xFFBA68C8)],
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
    return Image.network(
      "https://pngimg.com/uploads/google/google_PNG19635.png",
      height: 30,
    );
  }
}
