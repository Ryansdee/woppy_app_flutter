import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentDetailScreen extends StatelessWidget {
  final String studentId;

  const StudentDetailScreen({super.key, required this.studentId});

  Future<void> _openOrCreateChat(BuildContext context, String otherUid) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  final db = FirebaseFirestore.instance;

  try {
    // Cherche si un chat existe déjà entre les deux users
    final existing = await db
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    String? existingChatId;
    for (final doc in existing.docs) {
      final participants = List.from(doc.data()['participants'] ?? []);
      if (participants.contains(otherUid)) {
        existingChatId = doc.id;
        break;
      }
    }

    if (existingChatId != null) {
      // Chat existant → ouvre directement
      if (context.mounted) context.push('/chat/$existingChatId');
      return;
    }

    // Crée un nouveau chat
    final newChat = await db.collection('chats').add({
      'participants': [currentUser.uid, otherUid],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) context.push('/chat/${newChat.id}');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de l\'ouverture du chat',
            style: GoogleFonts.sora(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF8A6BFE),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F5),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () async => await _openOrCreateChat(context, studentId),
            icon: const Icon(Icons.message_outlined, size: 18, color: Colors.white),
            label: Text(
              'Envoyer un message',
              style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A6BFE),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
      // ... reste pareil
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8A6BFE)),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Profil introuvable'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String firstName = data['firstName'] ?? '';
          final String lastName = data['lastName'] ?? '';
          final String fullName = '$firstName $lastName'.trim();
          final String? photoURL = data['photoURL'];
          final String bio = data['bio'] ?? '';
          final String city = data['city'] ?? '';
          final bool isAvailable = data['isAvailable'] ?? false;
          final List experiences =
              data['experiences'] is List ? data['experiences'] : [];
          final Map availabilitySchedule =
              data['availabilitySchedule'] is Map
                  ? data['availabilitySchedule']
                  : {};

          return CustomScrollView(
            slivers: [
              // AppBar
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFFF9F8F5),
                elevation: 0,
                leading: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header profil
                      Center(
                        child: Column(
                          children: [
                            // Photo
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: const Color(0xFF8A6BFE)
                                    .withOpacity(0.12),
                                border: Border.all(
                                  color: const Color(0xFF8A6BFE)
                                      .withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: photoURL != null
                                  ? ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(22),
                                      child: Image.network(
                                        photoURL,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.person,
                                                color: Color(0xFF8A6BFE),
                                                size: 40),
                                      ),
                                    )
                                  : const Icon(Icons.person,
                                      color: Color(0xFF8A6BFE), size: 40),
                            ),

                            const SizedBox(height: 16),

                            // Nom
                            Text(
                              fullName.isNotEmpty ? fullName : 'Étudiant',
                              style: GoogleFonts.sora(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1F2937),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Ville + disponibilité
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (city.isNotEmpty) ...[
                                  const Icon(Icons.location_on_outlined,
                                      size: 14,
                                      color: Color(0xFF9CA3AF)),
                                  const SizedBox(width: 4),
                                  Text(
                                    city,
                                    style: GoogleFonts.sora(
                                      fontSize: 13,
                                      color: const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Bio
                      if (bio.isNotEmpty) ...[
                        _buildSectionTitle('À propos'),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            bio,
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              color: const Color(0xFF4B5563),
                              height: 1.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Expériences
                      if (experiences.isNotEmpty) ...[
                        _buildSectionTitle('Expériences'),
                        const SizedBox(height: 12),
                        ...experiences.map((exp) {
                          final e = exp as Map<String, dynamic>;
                          final bool isCurrent =
                              e['endDate'] == null || e['endDate'] == '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8A6BFE)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.work_outline,
                                      color: Color(0xFF8A6BFE), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              e['title'] ?? '',
                                              style: GoogleFonts.sora(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    const Color(0xFF1F2937),
                                              ),
                                            ),
                                          ),
                                          if (isCurrent)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF8A6BFE)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'En cours',
                                                style: GoogleFonts.sora(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xFF8A6BFE),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        e['company'] ?? '',
                                        style: GoogleFonts.sora(
                                          fontSize: 13,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                      if (e['startDate'] != null &&
                                          e['startDate'] != '') ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '${e['startDate']} → ${isCurrent ? "Aujourd'hui" : e['endDate']}',
                                          style: GoogleFonts.sora(
                                            fontSize: 11,
                                            color: const Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ],
                                      if (e['description'] != null &&
                                          e['description'] != '') ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          e['description'],
                                          style: GoogleFonts.sora(
                                            fontSize: 13,
                                            color: const Color(0xFF4B5563),
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 28),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.sora(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1F2937),
      ),
    );
  }
}