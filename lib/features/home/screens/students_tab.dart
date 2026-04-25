import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class StudentsTab extends StatelessWidget {
  const StudentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Étudiants',
                    style: GoogleFonts.sora(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Trouve le profil idéal pour ton entreprise',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('hasStudentProfile', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: Color(0xFF8A6BFE),
                      ),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          const Icon(Icons.people_outline,
                              size: 48, color: Color(0xFFD1D5DB)),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun étudiant inscrit',
                            style: GoogleFonts.sora(
                              fontSize: 15,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final students = snapshot.data!.docs;

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _StudentCard(student: students[index]),
                    childCount: students.length,
                  ),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final QueryDocumentSnapshot student;

  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final data = student.data() as Map<String, dynamic>;

    final String firstName = data['firstName'] ?? '';
    final String lastName = data['lastName'] ?? '';
    final String fullName = '$firstName $lastName'.trim();
    final String city = data['city'] ?? '';
    final String bio = data['bio'] ?? '';
    final String? photoURL = data['photoURL'];
    final bool isAvailable = data['isAvailable'] ?? false;
    final List experiences =
        data['experiences'] is List ? data['experiences'] : [];

    return GestureDetector(
      onTap: () => context.push('/student/${student.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF8A6BFE).withOpacity(0.12),
              ),
              child: photoURL != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        photoURL,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          color: Color(0xFF8A6BFE),
                          size: 28,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: Color(0xFF8A6BFE),
                      size: 28,
                    ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom + badge disponibilité
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fullName.isNotEmpty ? fullName : 'Étudiant',
                          style: GoogleFonts.sora(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Ville
                  if (city.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(
                          city,
                          style: GoogleFonts.sora(
                            fontSize: 12,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),

                  // Bio
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                  ],

                  // Expériences
                  if (experiences.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.work_outline,
                            size: 12, color: Color(0xFF8A6BFE)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            (experiences.first as Map)['title'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8A6BFE),
                            ),
                          ),
                        ),
                        if (experiences.length > 1)
                          Text(
                            '+${experiences.length - 1}',
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String label;

  const _SkillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF8A6BFE).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.sora(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF8A6BFE),
        ),
      ),
    );
  }
}