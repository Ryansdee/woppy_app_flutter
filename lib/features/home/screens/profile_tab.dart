import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .get(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final String firstName = data?['firstName'] ?? '';
          final String lastName = data?['lastName'] ?? '';
          final String fullName = '$firstName $lastName'.trim();
          final String? photoURL = data?['photoURL'];
          final String city = data?['city'] ?? '';
          final String bio = data?['bio'] ?? '';
          final String email = data?['email'] ?? user?.email ?? '';
          final bool isAvailable = data?['isAvailable'] ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre
                Text(
                  'Mon profil',
                  style: GoogleFonts.sora(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2937),
                  ),
                ),

                const SizedBox(height: 24),

                // Card profil
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      // Photo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFF8A6BFE).withOpacity(0.12),
                          border: Border.all(
                            color: const Color(0xFF8A6BFE).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: photoURL != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.network(
                                  photoURL,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    color: Color(0xFF8A6BFE),
                                    size: 36,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Color(0xFF8A6BFE),
                                size: 36,
                              ),
                      ),

                      const SizedBox(height: 14),

                      // Nom
                      Text(
                        fullName.isNotEmpty ? fullName : 'Mon profil',
                        style: GoogleFonts.sora(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Email
                      Text(
                        email,
                        style: GoogleFonts.sora(
                          fontSize: 13,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Ville + dispo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (city.isNotEmpty) ...[
                            const Icon(Icons.location_on_outlined,
                                size: 13, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 4),
                            Text(
                              city,
                              style: GoogleFonts.sora(
                                fontSize: 12,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? const Color(0xFF10B981).withOpacity(0.1)
                                  : const Color(0xFF9CA3AF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAvailable ? '✅ Disponible' : '🔒 Indisponible',
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isAvailable
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          bio,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            color: const Color(0xFF6B7280),
                            height: 1.5,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Bouton modifier profil
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/profile/edit'),
                          icon: const Icon(Icons.edit_outlined,
                              size: 16, color: Color(0xFF8A6BFE)),
                          label: Text(
                            'Modifier mon profil',
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8A6BFE),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFF8A6BFE)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Section paramètres
                _buildSectionTitle('Paramètres'),

                _buildSettingsGroup([
                  _SettingsItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: Icons.language_outlined,
                    label: 'Langue',
                    trailing: Text(
                      'Français',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: Icons.lock_outline,
                    label: 'Changer le mot de passe',
                    onTap: () => context.push('/profile/change-password'),
                  ),
                ]),

                const SizedBox(height: 16),

                _buildSectionTitle('Compte'),
                const SizedBox(height: 12),

                _buildSettingsGroup([
                  _SettingsItem(
                    icon: Icons.help_outline,
                    label: 'Aide & Support',
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: Icons.shield_outlined,
                    label: 'Politique de confidentialité',
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: Icons.logout,
                    label: 'Se déconnecter',
                    color: const Color(0xFFEF4444),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Text(
                            'Déconnexion',
                            style: GoogleFonts.sora(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          content: Text(
                            'Tu veux vraiment te déconnecter ?',
                            style: GoogleFonts.sora(fontSize: 14),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, false),
                              child: Text(
                                'Annuler',
                                style: GoogleFonts.sora(
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, true),
                              child: Text(
                                'Se déconnecter',
                                style: GoogleFonts.sora(
                                  color: const Color(0xFFEF4444),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) context.go('/login');
                      }
                    },
                  ),
                ]),

                const SizedBox(height: 24),

                // Version
                Center(
                  child: Text(
                    'Woppy v1.0.0',
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      color: const Color(0xFFD1D5DB),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.sora(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF9CA3AF),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSettingsGroup(List<_SettingsItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.vertical(
                  top: index == 0
                      ? const Radius.circular(16)
                      : Radius.zero,
                  bottom: isLast
                      ? const Radius.circular(16)
                      : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 20,
                        color: item.color ?? const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.label,
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: item.color ?? const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      item.trailing ??
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: item.color ?? const Color(0xFFD1D5DB),
                          ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  indent: 50,
                  color: Color(0xFFE5E7EB),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  final Color? color;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.trailing,
  });
}