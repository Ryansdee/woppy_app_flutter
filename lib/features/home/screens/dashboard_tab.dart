import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  String _firstName = '';
  String _role = '';
  String _greeting = '';
  bool _isLoading = true;

  int _students = 0;
  int _annonces = 0;
  int _jobsDone = 0;
  int _users = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setGreeting();
  }

  void _setGreeting() {
    final h = DateTime.now().hour;
    setState(() {
      _greeting = h < 13 ? 'Bonjour !' : h < 18 ? 'Bon après-midi !' : 'Bonsoir !';
    });
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Infos user
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      setState(() {
        _firstName = data?['firstName'] ?? user.email?.split('@')[0] ?? '';
        _role = data?['role'] ?? '';
      });

      // Stats
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .where('hasStudentProfile', isEqualTo: true)
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('annonces')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('annonces')
            .where('statut', isEqualTo: 'fini')
            .count()
            .get(),
      ]);

      setState(() {
        _students = results[0].count ?? 0;
        _users = results[1].count ?? 0;
        _annonces = results[2].count ?? 0;
        _jobsDone = results[3].count ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = _role == 'admin';
    final bool isCollaborator = _role == 'collaborator' || isAdmin;

    final primaryActions = [
      _ActionItem(
        icon: Icons.campaign_outlined,
        label: 'Publier une annonce',
        sub: 'Créer et diffuser',
        onTap: () => context.push('/annonce/create'),
      ),
      _ActionItem(
        icon: Icons.list_alt_outlined,
        label: 'Annonces',
        sub: 'Parcourir les offres',
        onTap: () {},
      ),
      _ActionItem(
        icon: Icons.people_outline,
        label: 'Étudiants',
        sub: 'Trouver des talents',
        onTap: () {},
      ),
      _ActionItem(
        icon: Icons.message_outlined,
        label: 'Messagerie',
        sub: 'Conversations',
        onTap: () {},
      ),
    ];

    final accountLinks = [
      _ActionItem(
        icon: Icons.manage_accounts_outlined,
        label: 'Mon profil',
        sub: 'Informations personnelles',
        onTap: () => context.push('/profile/edit'),
      ),
      _ActionItem(
        icon: Icons.history_outlined,
        label: 'Activité',
        sub: 'Historique et missions',
        onTap: () {},
      ),
      if (isCollaborator)
        _ActionItem(
          icon: Icons.verified_user_outlined,
          label: 'Espace collaborateur',
          sub: 'Gestion des profils',
          onTap: () {},
        ),
      if (isAdmin) ...[
        _ActionItem(
          icon: Icons.work_outline,
          label: 'Postes internes',
          sub: 'Créer des offres',
          onTap: () {},
        ),
        _ActionItem(
          icon: Icons.assignment_outlined,
          label: 'Candidatures',
          sub: 'Gérer les demandes',
          onTap: () {},
        ),
        _ActionItem(
          icon: Icons.support_agent_outlined,
          label: 'Support',
          sub: 'Gérer les tickets',
          onTap: () {},
        ),
        _ActionItem(
          icon: Icons.trending_up_outlined,
          label: 'Récapitulatif',
          sub: 'Statistiques détaillées',
          onTap: () {},
        ),
      ],
    ];

    return SafeArea(
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8A6BFE)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  Text(
                    _greeting,
                    style: GoogleFonts.sora(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9CA3AF),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _firstName.isNotEmpty ? _firstName : '…',
                          style: GoogleFonts.sora(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1F2937),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      if (_role == 'admin' || _role == 'collaborator')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF8A6BFE).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF8A6BFE)
                                  .withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            _role == 'admin' ? 'Admin' : 'Collaborateur',
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8A6BFE),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aperçu de la plateforme Woppy',
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // KPIs
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _KpiCard(label: 'Étudiants', value: _students, icon: Icons.people_outline),
                      _KpiCard(label: 'Annonces', value: _annonces, icon: Icons.campaign_outlined),
                      _KpiCard(label: 'Missions terminées', value: _jobsDone, icon: Icons.emoji_events_outlined),
                      _KpiCard(label: 'Utilisateurs', value: _users, icon: Icons.person_outline),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Actions rapides
                  _buildSectionLabel('Actions'),
                  const SizedBox(height: 12),
                  _buildActionGroup(primaryActions),

                  const SizedBox(height: 24),

                  // Mon espace
                  _buildSectionLabel('Mon espace'),
                  const SizedBox(height: 12),
                  _buildActionGroup(accountLinks),

                  const SizedBox(height: 24),

                  // Statut plateforme
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8A6BFE).withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF8A6BFE).withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 16, color: Color(0xFF8A6BFE)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Plateforme sécurisée',
                                style: GoogleFonts.sora(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF8A6BFE),
                                ),
                              ),
                              Text(
                                'Stripe · vérification manuelle · anti-spam',
                                style: GoogleFonts.sora(
                                  fontSize: 11,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Opérationnel',
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10B981),
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
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.sora(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF9CA3AF),
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildActionGroup(List<_ActionItem> items) {
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
                  top: index == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8A6BFE).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF8A6BFE).withOpacity(0.15),
                          ),
                        ),
                        child: Icon(
                          item.icon,
                          size: 16,
                          color: const Color(0xFF8A6BFE),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: GoogleFonts.sora(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              item.sub,
                              style: GoogleFonts.sora(
                                fontSize: 12,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Color(0xFFD1D5DB),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  indent: 66,
                  color: Color(0xFFE5E7EB),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 11,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
            ],
          ),
          Text(
            value.toString(),
            style: GoogleFonts.sora(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });
}