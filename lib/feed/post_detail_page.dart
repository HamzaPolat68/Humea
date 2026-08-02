// post_detail_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:humea/models/post_model.dart';
import 'package:humea/feed/feed.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  final String? highlightCommentId;
  final String? highlightReplyId;

  const PostDetailPage({
    super.key,
    required this.postId,
    this.highlightCommentId,
    this.highlightReplyId,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Set<String> _likedCommentIds = {};
  Set<String> _likedReplyIds = {};
  bool _hasAutoScrolled = false;

  @override
  void initState() {
    super.initState();
    _loadLikedComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLikedComments() async {
    final prefs = await SharedPreferences.getInstance();
    final likedCommentIds = prefs
        .getKeys()
        .where((key) => key.startsWith('liked_comment_'))
        .map((key) => key.substring('liked_comment_'.length))
        .toSet();
    final likedReplyIds = prefs
        .getKeys()
        .where((key) => key.startsWith('liked_reply_'))
        .map((key) => key.substring('liked_reply_'.length))
        .toSet();

    if (mounted) {
      setState(() {
        _likedCommentIds = likedCommentIds;
        _likedReplyIds = likedReplyIds;
      });
    }
  }

  // Bildirimden gelindiğinde yorumlar bölümüne otomatik kaydırma yapar
  void _scrollToCommentsIfHighlighted() {
    if (_hasAutoScrolled) return;
    final hasHighlight =
        (widget.highlightCommentId != null &&
            widget.highlightCommentId!.isNotEmpty) ||
        (widget.highlightReplyId != null &&
            widget.highlightReplyId!.isNotEmpty);

    if (hasHighlight) {
      _hasAutoScrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            280.0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _formatDate(DateTime dateTime) {
    final List<String> months = [
      "Ocak",
      "Şubat",
      "Mart",
      "Nisan",
      "Mayıs",
      "Haziran",
      "Temmuz",
      "Ağustos",
      "Eylül",
      "Ekim",
      "Kasım",
      "Aralık",
    ];
    final day = dateTime.day.toString();
    final month = months[dateTime.month - 1];
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return "$day $month $year - $hour:$minute";
  }

  Future<void> _addComment(Post post) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final commentData = {
      'text': text,
      'userId': user.uid,
      'userName': user.displayName ?? 'Anonim',
      'userImage': user.photoURL ?? '',
      'timestamp': Timestamp.now(),
      'likesCount': 0,
    };

    final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
    await postRef.collection('comments').add(commentData);
    await postRef.update({'commentsCount': FieldValue.increment(1)});

    if (post.userId != user.uid) {
      await FirebaseFirestore.instance
          .collection('notifications')
          .add(
            buildNotificationPayload(
              recipientId: post.userId,
              senderId: user.uid,
              senderName: user.displayName ?? 'Anonim',
              type: 'comment',
              postId: post.id,
            ),
          );
    }
    _commentController.clear();
  }

  Future<void> _toggleCommentLike(String postId, String commentId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'liked_comment_$commentId';
    final isAlreadyLiked = _likedCommentIds.contains(commentId);

    setState(() {
      if (isAlreadyLiked) {
        _likedCommentIds.remove(commentId);
      } else {
        _likedCommentIds.add(commentId);
      }
    });

    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    try {
      await commentRef.update({
        'likesCount': FieldValue.increment(isAlreadyLiked ? -1 : 1),
      });

      if (!isAlreadyLiked) {
        final commentDoc = await commentRef.get();
        final ownerId = commentDoc.data()?['userId']?.toString() ?? '';
        final senderName =
            FirebaseAuth.instance.currentUser?.displayName ?? 'Anonim';
        if (ownerId.isNotEmpty &&
            ownerId != FirebaseAuth.instance.currentUser?.uid) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'recipientId': ownerId,
            'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
            'senderName': senderName,
            'type': 'comment_like',
            'postId': postId,
            'commentId': commentId,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
      await prefs.setBool(key, !isAlreadyLiked);
    } catch (e) {
      debugPrint('Yorum beğeni hatası: $e');
    }
  }

  Future<void> _toggleReplyLike(
    String postId,
    String commentId,
    String replyId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'liked_reply_$replyId';
    final isAlreadyLiked = _likedReplyIds.contains(replyId);

    setState(() {
      if (isAlreadyLiked) {
        _likedReplyIds.remove(replyId);
      } else {
        _likedReplyIds.add(replyId);
      }
    });

    final replyRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);

    try {
      await replyRef.update({
        'likesCount': FieldValue.increment(isAlreadyLiked ? -1 : 1),
      });
      await prefs.setBool(key, !isAlreadyLiked);
    } catch (e) {
      debugPrint('Yanıt beğeni hatası: $e');
    }
  }

  Future<void> _showReplyDialog(
    String postId,
    String commentId,
    String recipientId,
  ) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yanıtla', style: TextStyle(color: Colors.black87)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              final replyData = {
                'text': text,
                'userId': user.uid,
                'userName': user.displayName ?? 'Anonim',
                'userImage': user.photoURL ?? '',
                'timestamp': Timestamp.now(),
                'likesCount': 0,
                'parentReplyId': '',
              };

              final commentRef = FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .collection('comments')
                  .doc(commentId);
              final replyRef = await commentRef
                  .collection('replies')
                  .add(replyData);
              await commentRef.update({
                'repliesCount': FieldValue.increment(1),
              });

              if (recipientId != user.uid) {
                await FirebaseFirestore.instance
                    .collection('notifications')
                    .add(
                      buildNotificationPayload(
                        recipientId: recipientId,
                        senderId: user.uid,
                        senderName: user.displayName ?? 'Anonim',
                        type: 'reply',
                        postId: postId,
                        commentId: commentId,
                        replyId: replyRef.id,
                      ),
                    );
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Gönderi'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .snapshots(),
        builder: (context, postSnap) {
          if (postSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!postSnap.hasData || !postSnap.data!.exists) {
            return const Center(child: Text('Bu gönderi silinmiş olabilir.'));
          }

          final data = postSnap.data!.data() as Map<String, dynamic>;
          data['id'] = postSnap.data!.id;
          final post = Post.fromFirestore(data);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Gönderi kartı
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: post.userImage.isNotEmpty
                                    ? NetworkImage(post.userImage)
                                    : null,
                                child: post.userImage.isEmpty
                                    ? Text(
                                        post.userName.isNotEmpty
                                            ? post.userName[0].toUpperCase()
                                            : '?',
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(post.timestamp),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                post.moodEmoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                post.moodTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),

                          // Paylaşım metni (Siyah renk zorunlu kılındı)
                          if (post.note.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            buildLinkifiedText(
                              post.note,
                              context: context,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],

                          if (post.imageUrl != null &&
                              post.imageUrl!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                post.imageUrl!,
                                width: double.infinity,
                                height: 220,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Yorumlar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Yorumlar listesi
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(post.id)
                          .collection('comments')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, commentsSnap) {
                        if (!commentsSnap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final comments = commentsSnap.data!.docs;
                        if (comments.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Henüz yorum yok.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          );
                        }

                        // Otomatik kaydırma işlemini tetikle
                        _scrollToCommentsIfHighlighted();

                        return Column(
                          children: comments.map((doc) {
                            final c = doc.data() as Map<String, dynamic>;

                            final isHighlighted =
                                (widget.highlightCommentId != null &&
                                    widget.highlightCommentId!.isNotEmpty &&
                                    doc.id == widget.highlightCommentId) ||
                                (widget.highlightCommentId == null &&
                                    widget.highlightReplyId != null &&
                                    widget.highlightReplyId!.isNotEmpty);

                            final isLiked = _likedCommentIds.contains(doc.id);
                            final userName = readSafeStringField(
                              c,
                              'userName',
                              fallback: 'Anonim',
                            );
                            final text = readSafeStringField(c, 'text');
                            final likesCount = readSafeIntField(
                              c,
                              'likesCount',
                            );
                            final ts = c['timestamp'] as Timestamp?;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isHighlighted
                                    ? Colors.blue.withOpacity(0.08)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: isHighlighted
                                    ? Border.all(
                                        color: Colors.blueAccent,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          userName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        ts != null
                                            ? _formatDate(ts.toDate())
                                            : '',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Yorum Metni (Siyah Renk Zorunlu Yapıldı)
                                  buildLinkifiedText(
                                    text,
                                    context: context,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          isLiked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 18,
                                          color: isLiked
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                        onPressed: () =>
                                            _toggleCommentLike(post.id, doc.id),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$likesCount',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      InkWell(
                                        onTap: () => _showReplyDialog(
                                          post.id,
                                          doc.id,
                                          readSafeStringField(c, 'userId'),
                                        ),
                                        child: const Text(
                                          'Yanıtla',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Yanıtlar (Replies)
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('posts')
                                        .doc(post.id)
                                        .collection('comments')
                                        .doc(doc.id)
                                        .collection('replies')
                                        .orderBy('timestamp')
                                        .snapshots(),
                                    builder: (context, repliesSnap) {
                                      if (!repliesSnap.hasData ||
                                          repliesSnap.data!.docs.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8,
                                          left: 12,
                                        ),
                                        child: Column(
                                          children: repliesSnap.data!.docs.map((
                                            r,
                                          ) {
                                            final rd =
                                                r.data()
                                                    as Map<String, dynamic>;
                                            final rIsHighlighted =
                                                widget.highlightReplyId !=
                                                    null &&
                                                widget
                                                    .highlightReplyId!
                                                    .isNotEmpty &&
                                                r.id == widget.highlightReplyId;
                                            final rIsLiked = _likedReplyIds
                                                .contains(r.id);

                                            return Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: rIsHighlighted
                                                    ? Colors.blue.withOpacity(
                                                        0.15,
                                                      )
                                                    : Colors.grey[100],
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: rIsHighlighted
                                                    ? Border.all(
                                                        color:
                                                            Colors.blueAccent,
                                                        width: 1.5,
                                                      )
                                                    : null,
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          readSafeStringField(
                                                            rd,
                                                            'userName',
                                                            fallback: 'Anonim',
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        // Yanıt Metni (Siyah Renk Zorunlu Yapıldı)
                                                        Text(
                                                          readSafeStringField(
                                                            rd,
                                                            'text',
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    icon: Icon(
                                                      rIsLiked
                                                          ? Icons.favorite
                                                          : Icons
                                                                .favorite_border,
                                                      size: 16,
                                                      color: rIsLiked
                                                          ? Colors.red
                                                          : Colors.grey,
                                                    ),
                                                    onPressed: () =>
                                                        _toggleReplyLike(
                                                          post.id,
                                                          doc.id,
                                                          r.id,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Yorum yazma alanı
              Container(
                color: Colors.white,
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Yorum ekle...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: () => _addComment(post),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
