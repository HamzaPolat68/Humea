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
  bool _termsAccepted = false;
  bool _isLoading = false;

  // EULA metnini güncellediğinizde bu sayıyı artırın.
  // Login tarafındaki gate bu versiyonla karşılaştırma yapacak.
  static const int currentTermsVersion = 1;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  DateTime? _pickedDate;

  Future<void> _registerUser() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

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

    if (!_termsAccepted) {
      _showMessage(
        "Devam etmek için Kullanım Şartları'nı kabul etmelisiniz.",
        Colors.orangeAccent,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await userCredential.user?.updateDisplayName(_nameController.text);

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
                "${_pickedDate!.month.toString().padLeft(2, '0')}-${_pickedDate!.day.toString().padLeft(2, '0')}",
            'createdAt': FieldValue.serverTimestamp(),
            'acceptedTermsVersion': currentTermsVersion,
            'acceptedTermsAt': FieldValue.serverTimestamp(),
          });

      try {
        await NotificationService.syncFcmTokenToFirestore(
          userId: userCredential.user!.uid,
        );
      } catch (e) {
        print("FCM Token senkronizasyon hatası es geçildi: $e");
      }

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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  void _showTermsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Kullanım Şartları",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: const Text(
                        "Humea'yı kullanarak aşağıdaki kuralları kabul etmiş sayılırsınız:\n\n"
                        "• Nefret söylemi, ayrımcı içerik, taciz, zorbalık ve tehdit kesinlikle "
                        "yasaktır. Bu tür davranışlarda bulunan hesaplar uyarı yapılmaksızın "
                        "kapatılabilir.\n\n"
                        "• Uygunsuz, müstehcen veya yasa dışı içerik paylaşımı sıfır toleransla "
                        "karşılanır ve ilgili içerik/hesap derhal kaldırılır.\n\n"
                        "• Diğer kullanıcıları rahatsız eden, taklit eden veya yanıltan davranışlar "
                        "yasaktır.\n\n"
                        "• Bildirilen veya tespit edilen ihlaller ekibimiz tarafından incelenir; "
                        "gerekli durumlarda hesabınız uyarılmadan askıya alınabilir veya "
                        "kapatılabilir.\n\n"
                        "• Kişisel verileriniz Gizlilik Politikamız kapsamında işlenir; "
                        "üçüncü taraflarla izniniz olmadan paylaşılmaz.\n\n"
                        "• Humea ekibi, platformu güvenli ve keyifli tutmak için "
                        "kuralları güncelleme hakkını saklı tutar. Kuralların ihlali durumunda kullanıcılar bilgilendirilmeden hesapları askıya alınabilir veya kapatılabilir.\n\n",
                        style: TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF039BE5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () {
                        setState(() => _termsAccepted = true);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Kabul Ediyorum",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
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
                                  color: Color.fromARGB(255, 10, 10, 10),
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.favorite,
                                color: Colors.red,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        FadeInUp(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
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
                                _buildTextField(
                                  "Adınız ve Soyadınız",
                                  _nameController,
                                ),
                                const SizedBox(height: 15),
                                InkWell(
                                  onTap: () async {
                                    DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime(2011),
                                      firstDate: DateTime(1950),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _pickedDate = picked;
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
                                const SizedBox(height: 15),

                                // EULA / Kullanım Şartları onayı
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: _termsAccepted,
                                      activeColor: const Color(0xFF039BE5),
                                      onChanged: (v) => setState(
                                        () => _termsAccepted = v ?? false,
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: _showTermsSheet,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 12,
                                          ),
                                          child: RichText(
                                            text: const TextSpan(
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontSize: 13,
                                              ),
                                              children: [
                                                TextSpan(
                                                  text:
                                                      "Okudum, kabul ediyorum: ",
                                                ),
                                                TextSpan(
                                                  text:
                                                      "Kullanım Şartları ve Gizlilik Politikası",
                                                  style: TextStyle(
                                                    color: Colors.blueAccent,
                                                    fontWeight: FontWeight.bold,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),

                                _buildGradientButton(
                                  _isLoading
                                      ? "Lütfen bekleyin..."
                                      : "Hesap Oluştur",
                                  _isLoading ? () {} : _registerUser,
                                ),

                                const SizedBox(height: 3),

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
                                              initialEmail: _emailController
                                                  .text
                                                  .trim(),
                                              initialPassword:
                                                  _passwordController.text
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
              );
            },
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
    bool isConfirmField = hint == "Şifre Tekrarı";

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
