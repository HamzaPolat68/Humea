import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:humea/services/mention_service.dart';
import 'package:humea/search/other_user_profile_page.dart';
import '../models/post_model.dart';
import 'package:humea/feed/feed.dart';

class NotePage extends StatefulWidget {
  final String selectedEmoji;
  final Color selectedColor;

  const NotePage({
    super.key,
    required this.selectedEmoji,
    required this.selectedColor,
  });

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  File? _selectedImage;
  File? _selectedVideo;
  VideoPlayerController? _videoController;

  bool _isUploading = false;
  bool _isLoadingMentionSuggestions = false;
  List<Map<String, dynamic>> _mentionSuggestions = [];
  Map<String, dynamic>? _selectedMentionUser;
  String? _lastMentionQuery;

  final List<String> _suggestions = [
    "Bugün harika bir gün geçirdim! 🌟",
    "Biraz yorgunum ama huzurluyum. 😌",
    "Yeni şeyler öğrendiğim için heyecanlıyım! 🚀",
    "Bugün biraz dinlenmeye ihtiyacım var. ☕",
    "Çok verimli bir gün oldu! 💪",
  ];

  String _getMoodTitle(String emoji) {
    switch (emoji) {
      case "😍":
        return "Harika!";
      case "🤩":
        return "Heyecanlı";
      case "🙂":
        return "İyi";
      case "😊":
        return "Huzurlu";
      case "😞":
        return "Hüzünlü";
      case "🤔":
        return "Düşünceli";
      case "😡":
        return "Öfkeli";
      case "😟":
        return "Endişeli";
      case "💤":
        return "Yorgun";
      case "😰":
        return "Çok Kaygılı";
      default:
        return "Normal";
    }
  }

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_onNoteTextChanged);
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteTextChanged);
    _noteController.dispose();
    _commentController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _onNoteTextChanged() async {
    final text = _noteController.text;
    final cursor = _noteController.selection.baseOffset;

    if (cursor < 0 || cursor > text.length) {
      if (mounted) {
        setState(() => _mentionSuggestions = []);
      }
      return;
    }

    final beforeCursor = text.substring(0, cursor);
    final lastAtIndex = beforeCursor.lastIndexOf('@');

    if (lastAtIndex == -1) {
      if (mounted) {
        setState(() => _mentionSuggestions = []);
      }
      return;
    }

    final queryPart = beforeCursor.substring(lastAtIndex + 1);
    if (queryPart.contains(' ') || queryPart.contains('\n')) {
      if (mounted) {
        setState(() => _mentionSuggestions = []);
      }
      return;
    }

    final query = queryPart.trim().toLowerCase();
    if (query == _lastMentionQuery) {
      return;
    }

    _lastMentionQuery = query;

    if (!mounted) return;

    setState(() => _isLoadingMentionSuggestions = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final filteredUsers =
          snapshot.docs
              .map((doc) {
                final data = doc.data();
                final searchName = (data['searchName'] ?? '')
                    .toString()
                    .toLowerCase();
                final displayName =
                    (data['name'] ??
                            data['displayName'] ??
                            data['userName'] ??
                            searchName)
                        .toString();
                // DÜZELTME: photoUrl alanı eksikti, bu yüzden seçim yapıldığında
                // _selectedMentionUser!['photoUrl'] null dönüyor ve
                // "as String" cast'i "Null is not a subtype of String" hatası
                // fırlatıyordu. Alan burada eklendi (yoksa boş string).
                final photoUrl = (data['photoUrl'] ?? data['photoURL'] ?? '')
                    .toString();
                return {
                  'uid': doc.id,
                  'searchName': searchName,
                  'displayName': displayName,
                  'photoUrl': photoUrl,
                };
              })
              .where((entry) {
                final searchName = (entry['searchName'] as String)
                    .toLowerCase();
                final displayName = (entry['displayName'] as String)
                    .toLowerCase();

                if (searchName.isEmpty) return false;
                if (query.isEmpty) return true;

                return searchName.contains(query) ||
                    displayName.contains(query);
              })
              .toList()
            ..sort((a, b) {
              final aName = (a['displayName'] as String).toLowerCase();
              final bName = (b['displayName'] as String).toLowerCase();
              return aName.compareTo(bName);
            });

      if (!mounted) return;

      setState(() => _mentionSuggestions = filteredUsers);
    } catch (e) {
      debugPrint('Mention öneri çekme hatası: $e');
      if (!mounted) {
        setState(() => _mentionSuggestions = []);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMentionSuggestions = false);
      }
    }
  }

  void _applyMentionSuggestion(String username) {
    final text = _noteController.text;
    final cursor = _noteController.selection.baseOffset;
    final beforeCursor = text.substring(0, cursor);
    final lastAtIndex = beforeCursor.lastIndexOf('@');

    if (lastAtIndex == -1) return;

    Map<String, dynamic> suggestion = {
      'uid': '',
      'searchName': username,
      'displayName': username,
      'photoUrl': '',
    };

    for (final entry in _mentionSuggestions) {
      if ((entry['searchName'] as String) == username) {
        suggestion = entry;
        break;
      }
    }

    final newText =
        '${beforeCursor.substring(0, lastAtIndex)}@$username ${text.substring(cursor)}';

    _noteController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: lastAtIndex + username.length + 2,
      ),
    );

    if (mounted) {
      setState(() {
        _mentionSuggestions = [];
        _lastMentionQuery = null;
        _selectedMentionUser = suggestion;
      });
    }
  }

  // GALERİDEN VEYA KAMERADAN FOTOĞRAF SEÇME VE KIRPMA
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1400,
    );

    if (pickedFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Fotoğrafı Kırp / Genişlet',
          toolbarColor: Colors.blue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Fotoğrafı Kırp / Genişlet',
          aspectRatioLockEnabled: false,
        ),
      ],
    );

    if (croppedFile == null) return;

    _clearVideo();
    if (mounted) {
      setState(() {
        _selectedImage = File(croppedFile.path);
      });
    }
  }

  // GALERİDEN VEYA KAMERADAN VİDEO SEÇME
  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 60), // isteğe bağlı sınır
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = null; // fotoğrafı temizle, ikisi birden olmasın
      });

      final controller = VideoPlayerController.file(File(pickedFile.path));
      await controller.initialize();
      controller.setLooping(true);

      _videoController?.dispose();

      setState(() {
        _selectedVideo = File(pickedFile.path);
        _videoController = controller;
      });
    }
  }

  void _clearVideo() {
    _videoController?.dispose();
    _videoController = null;
    _selectedVideo = null;
  }

  void _showMediaSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Fotoğraf Çek"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Galeriden Fotoğraf Seç"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text("Video Çek"),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text("Galeriden Video Seç"),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // FIREBASE STORAGE'A FOTOĞRAF YÜKLEME
  Future<String?> _uploadImage(File imageFile, String postId) async {
    try {
      final extension = imageFile.path.split('.').last.toLowerCase();
      final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

      final ref = FirebaseStorage.instance
          .ref()
          .child('post_images')
          .child('$postId.$extension');

      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Fotoğraf yükleme hatası: $e");
      return null;
    }
  }

  // FIREBASE STORAGE'A VİDEO YÜKLEME
  Future<String?> _uploadVideo(File videoFile, String postId) async {
    try {
      final extension = videoFile.path.split('.').last.toLowerCase();
      final contentType = extension == 'mov' ? 'video/quicktime' : 'video/mp4';

      final ref = FirebaseStorage.instance
          .ref()
          .child('post_videos')
          .child('$postId.$extension');

      final uploadTask = await ref.putFile(
        videoFile,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Video yükleme hatası: $e");
      return null;
    }
  }

  Future<void> _addComment(String postId, String commentText) async {
    if (commentText.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add({
          'text': commentText,
          'userName': user?.displayName ?? "Anonim",
          'userImage': user?.photoURL ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          'userId': user?.uid,
          'likesCount': 0,
        });
  }

  Future<void> _notifyMentionedUsers(
    String postId,
    String postText,
    String? senderUserId,
  ) async {
    if (senderUserId == null || senderUserId.isEmpty) return;

    final senderName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Anonim';
    final mentionedUsers = extractMentions(postText);

    if (mentionedUsers.isEmpty) return;

    final usersCollection = FirebaseFirestore.instance.collection('users');

    for (final username in mentionedUsers) {
      final querySnapshot = await usersCollection
          .where('searchName', isEqualTo: username)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) continue;

      final targetedUser = querySnapshot.docs.first;
      final recipientId = targetedUser.id;

      if (recipientId == senderUserId) continue;

      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': recipientId,
        'senderId': senderUserId,
        'senderName': senderName,
        'type': 'mention',
        'postId': postId,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Widget _buildMediaPreview() {
    if (_selectedImage != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.file(
              _selectedImage!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, color: Colors.white),
            ),
            onPressed: () {
              setState(() {
                _selectedImage = null;
              });
            },
          ),
        ],
      );
    }

    if (_selectedVideo != null && _videoController != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              width: double.infinity,
              height: 200,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: IconButton(
                iconSize: 50,
                color: Colors.white,
                icon: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
                onPressed: () {
                  setState(() {
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play();
                  });
                },
              ),
            ),
          ),
          IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, color: Colors.white),
            ),
            onPressed: () {
              setState(() {
                _clearVideo();
              });
            },
          ),
        ],
      );
    }

    return const SizedBox(height: 30);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Günün Notu"),
        backgroundColor: widget.selectedColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(widget.selectedEmoji, style: const TextStyle(fontSize: 60)),
              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _suggestions
                    .map(
                      (suggestion) => ActionChip(
                        label: Text(
                          suggestion,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: widget.selectedColor.withOpacity(0.5),
                        ),
                        onPressed: () {
                          _noteController.text = suggestion;
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _showMediaSourceSheet,
                icon: const Icon(Icons.perm_media),
                label: const Text("Fotoğraf / Video Ekle"),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: widget.selectedColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _noteController,
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText: "Duygularını buraya dök (Opsiyonel)...",
                        helperText:
                            "Etiketlemek için metne @kullaniciadi yazın",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  if (_selectedMentionUser != null) ...[
                    const SizedBox(width: 8),
                    Builder(
                      builder: (context) {
                        // DÜZELTME: Bu alanlar Firestore'dan gelmeyebilir
                        // (örn. kullanıcı fallback suggestion'dan geldiyse
                        // veya alan hiç set edilmediyse). "as String" yerine
                        // null-safe cast + varsayılan değer kullanılıyor,
                        // böylece "Null is not a subtype of String" hatası
                        // bir daha oluşmuyor.
                        final targetUserId =
                            (_selectedMentionUser!['uid'] as String? ?? '')
                                .trim();
                        final targetUserName =
                            (_selectedMentionUser!['displayName'] as String? ??
                                    '')
                                .trim();
                        final targetPhotoUrl =
                            (_selectedMentionUser!['photoUrl'] as String? ?? '')
                                .trim();

                        return GestureDetector(
                          onTap: () {
                            if (targetUserId.isEmpty) return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OtherUserProfilePage(
                                  targetUserId: targetUserId,
                                  targetUserName: targetUserName,
                                  targetPhotoUrl: targetPhotoUrl,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 150,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (targetPhotoUrl.isNotEmpty)
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundImage: NetworkImage(
                                      targetPhotoUrl,
                                    ),
                                  )
                                else
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(
                                      // DÜZELTME: displayName boşsa
                                      // substring(0,1) RangeError fırlatırdı.
                                      targetUserName.isNotEmpty
                                          ? targetUserName
                                                .substring(0, 1)
                                                .toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  targetUserName.isNotEmpty
                                      ? targetUserName
                                      : '@${_selectedMentionUser!['searchName'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '@${_selectedMentionUser!['searchName'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
              if (_isLoadingMentionSuggestions && _mentionSuggestions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 20,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                )
              else if (_mentionSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _mentionSuggestions.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final suggestion = _mentionSuggestions[index];
                      final name = suggestion['displayName'] as String;
                      final username = suggestion['searchName'] as String;

                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.alternate_email, size: 18),
                        title: Text(name),
                        subtitle: Text('@$username'),
                        onTap: () => _applyMentionSuggestion(username),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),

              // FOTOĞRAF/VİDEO ÖNİZLEME
              _buildMediaPreview(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.selectedColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _isUploading
                      ? null
                      : () async {
                          final User? user = FirebaseAuth.instance.currentUser;
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          final navigator = Navigator.of(context);

                          if (user == null || user.uid.isEmpty) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Oturum bulunamadı. Lütfen tekrar giriş yapın.',
                                ),
                              ),
                            );
                            return;
                          }

                          final String finalNote = _noteController.text.trim();
                          final String generatedId = FirebaseFirestore.instance
                              .collection('posts')
                              .doc()
                              .id;

                          setState(() => _isUploading = true);

                          try {
                            String? uploadedImageUrl;
                            String? uploadedVideoUrl;

                            if (_selectedImage != null) {
                              uploadedImageUrl = await _uploadImage(
                                _selectedImage!,
                                generatedId,
                              );

                              if (uploadedImageUrl == null ||
                                  uploadedImageUrl.isEmpty) {
                                throw Exception('Fotoğraf yüklenemedi.');
                              }
                            } else if (_selectedVideo != null) {
                              uploadedVideoUrl = await _uploadVideo(
                                _selectedVideo!,
                                generatedId,
                              );

                              if (uploadedVideoUrl == null ||
                                  uploadedVideoUrl.isEmpty) {
                                throw Exception('Video yüklenemedi.');
                              }
                            }

                            final List<String> mentionedUsers = extractMentions(
                              finalNote,
                            );

                            final Post newPost = Post(
                              id: generatedId,
                              userName: user.displayName ?? "Anonim",
                              userImage:
                                  user.photoURL ??
                                  "https://via.placeholder.com/150",
                              moodEmoji: widget.selectedEmoji,
                              moodTitle: _getMoodTitle(widget.selectedEmoji),
                              note: finalNote,
                              mentions: mentionedUsers,
                              timestamp: DateTime.now(),
                              likes: 0,
                              commentsCount: 0,
                              userId: user.uid,
                              likesList: [],
                              imageUrl: uploadedImageUrl,
                              videoUrl: uploadedVideoUrl,
                            );

                            await FirebaseFirestore.instance
                                .collection('posts')
                                .doc(generatedId)
                                .set(newPost.toFirestore());

                            await _notifyMentionedUsers(
                              generatedId,
                              finalNote,
                              user.uid,
                            );

                            // ... paylaşım ve bildirim işlemleri bittikten sonra ...

                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text("Duygun paylaşıldı! ✨"),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // Geri gitmek yerine doğrudan FeedPage'e yönlendirir ve önceki ara sayfaları yığından temizler
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FeedPage(
                                    onPostDeleted: () async {
                                      // Gerekirse yenileme işlemi, gerekmiyorsa boş bırakabilirsiniz
                                    },
                                  ),
                                ),
                                (route) => route.isFirst,
                              );
                            }
                          } catch (e) {
                            debugPrint("Hata: $e");
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Paylaşım sırasında bağlantı veya veri hatası oluştu. Lütfen tekrar deneyin.\n$e',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isUploading = false);
                          }
                        },
                  child: _isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Paylaş",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
