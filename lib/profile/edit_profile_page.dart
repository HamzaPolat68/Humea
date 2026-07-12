import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController(); // E-posta için eklendi
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  DateTime? _selectedDate;
  bool _isLoading = false;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;
    _nameController.text = _user.displayName ?? "";
    _emailController.text = _user.email ?? "";

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .get();
    if (doc.exists &&
        doc.data()!.containsKey('birthDate') &&
        doc['birthDate'] != null) {
      try {
        // Veriyi güvenli şekilde çek
        setState(() {
          _selectedDate = DateTime.parse(doc['birthDate']);
        });
      } catch (e) {
        debugPrint("Tarih formatı hatalı: $e");
        setState(() => _selectedDate = null); // Hata varsa null bırak
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      // 1. Şifre Değiştirme
      if (_newPasswordController.text.isNotEmpty) {
        if (_oldPasswordController.text.isEmpty) {
          throw "Şifre değiştirmek için eski şifrenizi girmelisiniz.";
        }
        AuthCredential credential = EmailAuthProvider.credential(
          email: _user!.email!,
          password: _oldPasswordController.text,
        );
        await _user.reauthenticateWithCredential(credential);
        await _user.updatePassword(_newPasswordController.text);
      }

      // 2. E-posta Değiştirme (Firebase süreci)
      if (_emailController.text != _user!.email) {
        await _user.verifyBeforeUpdateEmail(_emailController.text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Yeni e-posta adresinize doğrulama gönderildi!"),
          ),
        );
      }

      // 3. Profil ve Firestore Güncelleme
      await _user.updateDisplayName(_nameController.text);
      await FirebaseFirestore.instance.collection('users').doc(_user.uid).update({
        'name': _nameController.text,
        'birthDate': _selectedDate?.toIso8601String(),
        'birthMonthDay': _selectedDate != null
            ? "${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
            : null, // YENİ
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Profil güncellendi! 🚀")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Kullanıcı Bilgileri",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profil Başlığı
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade100, Colors.purple.shade100],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    child: Icon(Icons.person, size: 40),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    _user?.displayName ?? "Kullanıcı",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _buildTextField("Ad Soyad", _nameController, Icons.person),
            const SizedBox(height: 15),
            _buildTextField(
              "E-posta",
              _emailController,
              Icons.email,
            ), // E-posta kutusu
            const SizedBox(height: 15),

            // Doğum Tarihi Alanı
            ListTile(
              onTap: () => _selectDate(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              leading: const Icon(Icons.cake, color: Colors.blueAccent),
              title: const Text("Doğum Tarihi"),
              subtitle: Text(
                _selectedDate == null
                    ? "Tarih seçilmedi"
                    : DateFormat(
                        'dd MMMM yyyy',
                        'tr_TR',
                      ).format(_selectedDate!),
              ),
              trailing: const Icon(Icons.edit),
            ),

            const SizedBox(height: 15),
            ExpansionTile(
              title: const Text(
                "Şifreyi Değiştir",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.lock_reset),
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      _buildTextField(
                        "Yeni Şifre",
                        _newPasswordController,
                        Icons.vpn_key,
                        obscure: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                fixedSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Değişiklikleri Kaydet"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
