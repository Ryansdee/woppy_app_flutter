import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import 'package:go_router/go_router.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  User? _user;
  Map<String, dynamic>? _otherProfile;
  bool _showEmoji = false;
  bool _isSending = false;
  bool _otherTyping = false;
  DateTime? _typingTimer;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _loadOtherProfile();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _clearTyping();
    super.dispose();
  }

  Future<void> _loadOtherProfile() async {
    final chat = await _db.collection('chats').doc(widget.chatId).get();
    final List participants = chat.data()?['participants'] ?? [];
    final otherUid =
        participants.firstWhere((p) => p != _user?.uid, orElse: () => null);
    if (otherUid == null) return;

    final doc = await _db.collection('users').doc(otherUid).get();
    final data = doc.data() ?? {};
    setState(() {
      _otherProfile = {
        'uid': otherUid,
        'displayName':
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
        'photoURL': data['photoURL'],
        'isOnline': data['isOnline'] ?? false,
      };
    });
  }

  Future<void> _markAsRead() async {
    await _db.collection('chats').doc(widget.chatId).update({
      'unreadCount': 0,
    }).catchError((_) {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? text, String? fileUrl, String? fileName, String type = 'text'}) async {
    if (_user == null) return;

    final messageData = {
      'senderId': _user!.uid,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      if (text != null) 'text': text,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
    };

    await _db
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData);

    await _db.collection('chats').doc(widget.chatId).update({
      'lastMessage': type == 'text' ? text : '📎 $fileName',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'typing.${_user!.uid}': false,
    });

    // Notification
    if (_otherProfile != null) {
      await _db.collection('notifications').add({
        'toUser': _otherProfile!['uid'],
        'fromUser': _user!.uid,
        'type': 'message',
        'message': 'Nouveau message',
        'messagePreview': (text ?? fileName ?? '').substring(
            0, (text ?? fileName ?? '').length.clamp(0, 100)),
        'chatId': widget.chatId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    _scrollToBottom();
  }

  Future<void> _onSendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    _messageController.clear();
    setState(() => _isSending = true);
    await _sendMessage(text: text);
    setState(() => _isSending = false);
  }

  Future<void> _onSendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _isSending = true);
    try {
      final ref = _storage.ref(
          'attachments/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
      await ref.putFile(File(file.path!));
      final url = await ref.getDownloadURL();
      await _sendMessage(fileUrl: url, fileName: file.name, type: 'file');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload', style: GoogleFonts.sora())),
        );
      }
    }
    setState(() => _isSending = false);
  }

  Future<void> _onSendImage() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    setState(() => _isSending = true);
    try {
      final ref = _storage.ref(
          'attachments/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}_${xfile.name}');
      await ref.putFile(File(xfile.path));
      final url = await ref.getDownloadURL();
      await _sendMessage(fileUrl: url, fileName: xfile.name, type: 'file');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload', style: GoogleFonts.sora())),
        );
      }
    }
    setState(() => _isSending = false);
  }

  void _onTyping(String val) {
    _db.collection('chats').doc(widget.chatId).update({
      'typing.${_user!.uid}': true,
    }).catchError((_) {});

    _typingTimer = DateTime.now();
    Future.delayed(const Duration(seconds: 3), () {
      if (_typingTimer != null &&
          DateTime.now().difference(_typingTimer!).inSeconds >= 3) {
        _clearTyping();
      }
    });
  }

  void _clearTyping() {
    if (_user == null) return;
    _db.collection('chats').doc(widget.chatId).update({
      'typing.${_user!.uid}': false,
    }).catchError((_) {});
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachOption(
                  icon: Icons.photo_outlined,
                  label: 'Photo',
                  color: const Color(0xFF8A6BFE),
                  onTap: () {
                    Navigator.pop(ctx);
                    _onSendImage();
                  },
                ),
                _AttachOption(
                  icon: Icons.attach_file_outlined,
                  label: 'Fichier',
                  color: const Color(0xFF3B82F6),
                  onTap: () {
                    Navigator.pop(ctx);
                    _onSendFile();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Hier';
    if (diff < 7) {
      const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
      return days[date.weekday - 1];
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isImage(String? name) {
    if (name == null) return false;
    return RegExp(r'\.(jpg|jpeg|png|gif|webp)$', caseSensitive: false)
        .hasMatch(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F8F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 14, color: Color(0xFF1F2937)),
          ),
        ),
        title: _otherProfile == null
            ? const SizedBox()
            : Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFF8A6BFE).withOpacity(0.12),
                        ),
                        child: _otherProfile!['photoURL'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _otherProfile!['photoURL'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    color: Color(0xFF8A6BFE),
                                    size: 20,
                                  ),
                                ),
                              )
                            : const Icon(Icons.person,
                                color: Color(0xFF8A6BFE), size: 20),
                      ),
                      if (_otherProfile!['isOnline'] == true)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _otherProfile!['displayName'] ?? 'Utilisateur',
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      StreamBuilder<DocumentSnapshot>(
                        stream: _db
                            .collection('chats')
                            .doc(widget.chatId)
                            .snapshots(),
                        builder: (context, snap) {
                          final data =
                              snap.data?.data() as Map<String, dynamic>?;
                          final typing = data?['typing'] as Map?;
                          final otherTyping = typing?[_otherProfile!['uid']] == true;
                          return Text(
                            otherTyping
                                ? 'est en train d\'écrire…'
                                : _otherProfile!['isOnline'] == true
                                    ? 'En ligne'
                                    : 'Hors ligne',
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              color: otherTyping
                                  ? const Color(0xFF8A6BFE)
                                  : _otherProfile!['isOnline'] == true
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF9CA3AF),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E7EB)),
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF8A6BFE)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.waving_hand_outlined,
                            size: 40, color: Color(0xFFD1D5DB)),
                        const SizedBox(height: 12),
                        Text(
                          'Commence la conversation !',
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                _scrollToBottom();

                // Grouper par date
                final Map<String, List<QueryDocumentSnapshot>> grouped = {};
                for (final msg in messages) {
                  final data = msg.data() as Map<String, dynamic>;
                  if (data['createdAt'] == null) continue;
                  final date =
                      (data['createdAt'] as Timestamp).toDate();
                  final key = date.toLocal().toString().split(' ')[0];
                  grouped.putIfAbsent(key, () => []).add(msg);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  itemCount: grouped.length,
                  itemBuilder: (context, groupIndex) {
                    final dateKey =
                        grouped.keys.elementAt(groupIndex);
                    final dayMessages = grouped[dateKey]!;
                    final date = DateTime.parse(dateKey);

                    return Column(
                      children: [
                        // Date divider
                        Center(
                          child: Container(
                            margin:
                                const EdgeInsets.symmetric(vertical: 16),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFFE5E7EB)),
                            ),
                            child: Text(
                              _formatDateLabel(date),
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                color: const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        // Messages du jour
                        ...dayMessages.map((msgDoc) {
                          final data =
                              msgDoc.data() as Map<String, dynamic>;
                          final isOwn =
                              data['senderId'] == _user?.uid;
                          final type = data['type'] ?? 'text';
                          final createdAt = data['createdAt'] != null
                              ? (data['createdAt'] as Timestamp)
                                  .toDate()
                              : null;

                          return _MessageBubble(
                            isOwn: isOwn,
                            type: type,
                            text: data['text'],
                            fileUrl: data['fileUrl'],
                            fileName: data['fileName'],
                            time: createdAt != null
                                ? _formatTime(createdAt)
                                : '',
                            isImage: _isImage(data['fileName']),
                            otherPhotoURL: _otherProfile?['photoURL'],
                          );
                        }),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Emoji picker
          if (_showEmoji)
            SizedBox(
              height: 280,
              child: ep.EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _messageController.text += emoji.emoji;
                  _messageController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _messageController.text.length),
                  );
                },
                config: ep.Config(
                  height: 280,
                  emojiViewConfig: ep.EmojiViewConfig(
                    columns: 8,
                  ),
                  categoryViewConfig: ep.CategoryViewConfig(
                    iconColor: Color(0xFF9CA3AF),
                    iconColorSelected: Color(0xFF8A6BFE),
                    indicatorColor: Color(0xFF8A6BFE),
                  ),
                ),
              ),
            ),

          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment
                GestureDetector(
                  onTap: _showAttachmentOptions,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F8F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(Icons.attach_file_outlined,
                        size: 18, color: Color(0xFF6B7280)),
                  ),
                ),

                const SizedBox(width: 8),

                // Text field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F8F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            maxLines: null,
                            onChanged: _onTyping,
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              color: const Color(0xFF1F2937),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Écrire un message…',
                              hintStyle: GoogleFonts.sora(
                                fontSize: 14,
                                color: const Color(0xFFD1D5DB),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                        // Emoji
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showEmoji = !_showEmoji),
                          child: Padding(
                            padding: const EdgeInsets.only(
                                right: 10, bottom: 10),
                            child: Icon(
                              Icons.emoji_emotions_outlined,
                              size: 20,
                              color: _showEmoji
                                  ? const Color(0xFF8A6BFE)
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                GestureDetector(
                  onTap: _isSending ? null : _onSendText,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8A6BFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message Bubble ──
class _MessageBubble extends StatelessWidget {
  final bool isOwn;
  final String type;
  final String? text;
  final String? fileUrl;
  final String? fileName;
  final String time;
  final bool isImage;
  final String? otherPhotoURL;

  const _MessageBubble({
    required this.isOwn,
    required this.type,
    required this.time,
    required this.isImage,
    this.text,
    this.fileUrl,
    this.fileName,
    this.otherPhotoURL,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar other
          if (!isOwn) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF8A6BFE).withOpacity(0.12),
              ),
              child: otherPhotoURL != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        otherPhotoURL!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          size: 14,
                          color: Color(0xFF8A6BFE),
                        ),
                      ),
                    )
                  : const Icon(Icons.person,
                      size: 14, color: Color(0xFF8A6BFE)),
            ),
          ],

          // Bubble
          Column(
            crossAxisAlignment:
                isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (type == 'file' && isImage && fileUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    fileUrl!,
                    width: 200,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image),
                  ),
                )
              else
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isOwn
                        ? const Color(0xFF8A6BFE)
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isOwn ? 18 : 4),
                      bottomRight: Radius.circular(isOwn ? 4 : 18),
                    ),
                    border: isOwn
                        ? null
                        : Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: type == 'file'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_file_outlined,
                              size: 14,
                              color: isOwn
                                  ? Colors.white
                                  : const Color(0xFF8A6BFE),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                fileName ?? 'Fichier',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sora(
                                  fontSize: 13,
                                  color: isOwn
                                      ? Colors.white
                                      : const Color(0xFF8A6BFE),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          text ?? '',
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            color: isOwn
                                ? Colors.white
                                : const Color(0xFF1F2937),
                            height: 1.4,
                          ),
                        ),
                ),

              const SizedBox(height: 3),
              Text(
                time,
                style: GoogleFonts.sora(
                  fontSize: 10,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),

          if (isOwn) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── Attach Option ──
class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.sora(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}