import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:humea/features/auth/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:humea/services/notification_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // 1. Verileri almak için Controller'ları tanımlıyoruz
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  DateTime? _pickedDate;
  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(
        2000,
      ), // Kullanıcı takvimi açtığında varsayılan tarih
      firstDate: DateTime(1950), // Seçilebilecek en eski tarih
      lastDate: DateTime.now(), // Seçilebilecek en son tarih
    );
    if (picked != null && picked != _pickedDate) {
      setState(() {
        _pickedDate = picked;
      });
    }
  }

  // 2. Firebase Kayıt Fonksiyonu
  Future<void> _registerUser() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    // Basit kontroller: _pickedDate değişkenini kontrol ediyoruz
    if (email.isEmpty ||
        password.isEmpty ||
        _nameController.text.isEmpty ||
        _pickedDate == null) {
      _showMessage("Lütfen tüm alanları doldurun ", Colors.redAccent);
      return;
    }

    if (password != confirmPassword) {
      _showMessage("Şifreler uyuşmuyor!", Colors.redAccent);
      return;
    }

    try {
      // Firebase'e kullanıcıyı kaydediyoruz
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Kullanıcının adını profiline ekliyoruz
      await userCredential.user?.updateDisplayName(_nameController.text);

      // Firestore'a verileri kaydediyoruz
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'name': _nameController.text,
            'searchName': _nameController.text.trim().toLowerCase(),
            'email': email,
            'birthDate': _pickedDate!.toIso8601String(),
            'birthMonthDay':
                "${_pickedDate!.month.toString().padLeft(2, '0')}-${_pickedDate!.day.toString().padLeft(2, '0')}", // YENİ
            'createdAt': FieldValue.serverTimestamp(),
          });

      await NotificationService.syncFcmTokenToFirestore(
        userId: userCredential.user!.uid,
      );

      if (mounted) {
        _showMessage("Hesap başarıyla oluşturuldu! ✨", Colors.green);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LoginPage(initialEmail: email, initialPassword: password),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        _showMessage(
          "Hey, bu şifre güvenli değil, daha güçlü bir şey seç!",
          Colors.orange,
        );
      } else if (e.code == 'email-already-in-use') {
        _showMessage("Bu e-posta zaten kullanımda.", Colors.orange);
      } else {
        _showMessage(
          "Bir hata oluştu: E-posta adresi hatalı formatta olabilir.",
          Colors.redAccent,
        );
      }
    } catch (e) {
      _showMessage("Beklenmedik bir hata oluştu.", Colors.redAccent);
    }
  }

  // Renkli destek sunan güncel yardımcı mesaj fonksiyonu
  void _showMessage(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/arka_plan_.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            width: double.infinity,
            height: MediaQuery.of(context).size.height,

            // ... build metodu içerisindeki Column yapısını şu şekilde güncelleyin:
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                // Humea yazısı dışarıda kalıyor
                FadeInDown(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Humea",
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(
                            255,
                            10,
                            10,
                            10,
                          ), // Arka planınıza göre beyaz daha iyi görünebilir
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.favorite, color: Colors.red, size: 30),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // TÜM İÇERİĞİ KUTU İÇİNE ALAN YAPI
                FadeInUp(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                        0.6,
                      ), // Hafif şeffaf modern kutu
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Kayıt Ol",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildTextField("Adınız ve Soyadınız", _nameController),
                        const SizedBox(height: 15),
                        InkWell(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime(
                                2011,
                              ), // Kullanıcı kolaylığı için varsayılan yıl
                              firstDate: DateTime(1950),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                _pickedDate =
                                    picked; // Değişken adını _pickedDate olarak güncelledik
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                // Diğer alanlarla uyumlu olması için shadow eklendi
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _pickedDate == null
                                      ? "Doğum Tarihi Seçin"
                                      : "${_pickedDate!.day}.${_pickedDate!.month}.${_pickedDate!.year}",
                                  style: TextStyle(
                                    color: _pickedDate == null
                                        ? Colors.grey
                                        : Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
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
                        const SizedBox(height: 30),

                        // Hesap Oluştur Butonu
                        _buildGradientButton("Hesap Oluştur", _registerUser),

                        const SizedBox(height: 3),

                        // Zaten Hesabınız Var mı?
                        Column(
                          children: [
                            const Text(
                              "Zaten Bir Hesabınız Var Mı?",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 8, 8, 8),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LoginPage(
                                      initialEmail: _emailController.text
                                          .trim(),
                                      initialPassword: _passwordController.text
                                          .trim(),
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                "Giriş Yap",
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
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
    // Şifre tekrarı mı kontrol ediyoruz
    bool isConfirmField = hint == "Şifre Tekrarı";

    // Hangi durum değişkenini kullanacağımızı seçiyoruz
    bool isVisible = isConfirmField
        ? _isConfirmPasswordVisible
        : _isPasswordVisible;

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
        controller: controller,
        // Eğer şifre alanıysa ve görünür değilse gizle
        obscureText: isPassword && !isVisible,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isConfirmField) {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      } else {
                        _isPasswordVisible = !_isPasswordVisible;
                      }
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
