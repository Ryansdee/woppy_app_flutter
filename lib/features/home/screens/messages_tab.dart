import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchProfile(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? {};
      final firstName = data['firstName'] ?? '';
      final lastName = data['lastName'] ?? '';
      return {
        'uid': uid,
        'displayName': '$firstName $lastName'.trim().isNotEmpty
            ? '$firstName $lastName'.trim()
            : 'Utilisateur',
        'photoURL': data['photoURL'],
        'isOnline': data['isOnline'] ?? false,
      };
    } catch (e) {
      return {'uid': uid, 'displayName': 'Utilisateur', 'isOnline': false};
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Hier';
    } else if (diff.inDays < 7) {
      const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return days[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Messages',
                  style: GoogleFonts.sora(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showSearch = !_showSearch),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _showSearch
                          ? const Color(0xFF8A6BFE).withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _showSearch
                            ? const Color(0xFF8A6BFE)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Icon(
                      Icons.search,
                      size: 18,
                      color: _showSearch
                          ? const Color(0xFF8A6BFE)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: GoogleFonts.sora(
                    fontSize: 14, color: const Color(0xFF1F2937)),
                decoration: InputDecoration(
                  hintText: 'Rechercher…',
                  hintStyle: GoogleFonts.sora(
                      fontSize: 14, color: const Color(0xFFD1D5DB)),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: Color(0xFF9CA3AF)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(Icons.close,
                              size: 16, color: Color(0xFF9CA3AF)),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF8A6BFE), width: 2),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Liste des chats
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants',
                      arrayContains: user.uid)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF8A6BFE)),
                  );
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.message_outlined,
                            size: 28,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune conversation',
                          style: GoogleFonts.sora(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tes messages apparaîtront ici',
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final chats = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: chats.length,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemBuilder: (context, index) {
                    final chat =
                        chats[index].data() as Map<String, dynamic>;
                    final chatId = chats[index].id;
                    final List participants =
                        chat['participants'] ?? [];
                    final otherUid = participants
                        .firstWhere((p) => p != user.uid,
                            orElse: () => null);

                    if (otherUid == null) return const SizedBox();

                    return FutureBuilder<Map<String, dynamic>>(
                      future: _fetchProfile(otherUid),
                      builder: (context, profileSnap) {
                        final profile = profileSnap.data;
                        final displayName =
                            profile?['displayName'] ?? '…';
                        final photoURL = profile?['photoURL'];
                        final isOnline =
                            profile?['isOnline'] ?? false;
                        final lastMessage =
                            chat['lastMessage'] ?? '';
                        final lastTime =
                            chat['lastMessageTime'] != null
                                ? _formatTime((chat['lastMessageTime']
                                        as Timestamp)
                                    .toDate())
                                : '';
                        final unreadCount =
                            chat['unreadCount'] ?? 0;

                        // Filtre recherche
                        if (_searchQuery.isNotEmpty &&
                            !displayName
                                .toLowerCase()
                                .contains(
                                    _searchQuery.toLowerCase()) &&
                            !lastMessage
                                .toLowerCase()
                                .contains(
                                    _searchQuery.toLowerCase())) {
                          return const SizedBox();
                        }

                        return GestureDetector(
                          onTap: () =>
                              context.push('/chat/$chatId'),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Stack(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        color: const Color(0xFF8A6BFE)
                                            .withOpacity(0.12),
                                      ),
                                      child: photoURL != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      14),
                                              child: Image.network(
                                                photoURL,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __,
                                                        ___) =>
                                                    const Icon(
                                                  Icons.person,
                                                  color:
                                                      Color(0xFF8A6BFE),
                                                  size: 24,
                                                ),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person,
                                              color: Color(0xFF8A6BFE),
                                              size: 24,
                                            ),
                                    ),
                                    if (isOnline)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color:
                                                const Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(width: 14),

                                // Infos
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              displayName,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: GoogleFonts.sora(
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.w700,
                                                color: const Color(
                                                    0xFF1F2937),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            lastTime,
                                            style: GoogleFonts.sora(
                                              fontSize: 11,
                                              color: const Color(
                                                  0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              lastMessage,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              maxLines: 1,
                                              style: GoogleFonts.sora(
                                                fontSize: 12,
                                                color: const Color(
                                                    0xFF9CA3AF),
                                              ),
                                            ),
                                          ),
                                          if (unreadCount > 0)
                                            Container(
                                              width: 18,
                                              height: 18,
                                              decoration:
                                                  const BoxDecoration(
                                                color:
                                                    Color(0xFF8A6BFE),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  unreadCount.toString(),
                                                  style:
                                                      GoogleFonts.sora(
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}