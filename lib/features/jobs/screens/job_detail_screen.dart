import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _isApplying = false;

  String _formatCurrency(dynamic value) {
    try {
      final number = value is String
          ? double.parse(value)
          : (value as num?)?.toDouble() ?? 0;
      final formatter = NumberFormat.currency(locale: 'fr_BE', symbol: '€');
      return formatter.format(number);
    } catch (e) {
      return 'À définir';
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'À définir';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('d MMMM yyyy', 'fr_BE').format(parsed);
    } catch (e) {
      return date;
    }
  }

  Future<void> _postuler(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final List applicants = data['applicants'] is List ? data['applicants'] : [];
    final int currentApplicants = data['currentApplicants'] ?? 0;
    final int maxApplicants = data['maxApplicants'] ?? 1;
    final String statut = data['statut'] ?? 'ouverte';

    // Vérifications
    if (statut != 'ouverte') {
      _showSnackbar('Cette annonce est fermée.', isError: true);
      return;
    }
    if (applicants.contains(user.uid)) {
      _showSnackbar('Tu as déjà postulé à cette annonce.', isError: true);
      return;
    }
    if (currentApplicants >= maxApplicants) {
      _showSnackbar('Le nombre maximum de candidats est atteint.', isError: true);
      return;
    }
    if (data['userId'] == user.uid) {
      _showSnackbar('Tu ne peux pas postuler à ta propre annonce.', isError: true);
      return;
    }

    // Confirmation
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF8A6BFE).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.campaign_outlined,
                  color: Color(0xFF8A6BFE), size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'Postuler à cette annonce ?',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data['titre'] ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 14,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Annuler',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8A6BFE),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Text(
                      'Confirmer',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
    );

    if (confirm != true) return;

    setState(() => _isApplying = true);

    try {
      final db = FirebaseFirestore.instance;

      // Met à jour l'annonce
      await db.collection('annonces').doc(widget.jobId).update({
        'applicants': FieldValue.arrayUnion([user.uid]),
        'currentApplicants': FieldValue.increment(1),
      });

      // Crée une candidature
      await db.collection('candidatures').add({
        'annonceId': widget.jobId,
        'candidatId': user.uid,
        'userId': data['userId'],
        'titre': data['titre'],
        'statut': 'en_attente',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notification au créateur
      await db.collection('notifications').add({
        'toUser': data['userId'],
        'fromUser': user.uid,
        'type': 'candidature',
        'message': 'Nouvelle candidature sur ton annonce',
        'annonceId': widget.jobId,
        'annonceTitre': data['titre'],
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) _showSnackbar('Candidature envoyée avec succès ! 🎉');
    } catch (e) {
      if (mounted) {
        _showSnackbar('Une erreur est survenue. Réessaie.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.sora(fontSize: 13)),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F5),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('annonces')
            .doc(widget.jobId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8A6BFE)),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Offre introuvable'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List photos = data['photos'] is List ? data['photos'] : [];
          final String rateMode = data['rateMode'] ?? 'hourly';
          final String rateSuffix = rateMode == 'hourly' ? '/h' : ' fixe';
          final List applicants =
              data['applicants'] is List ? data['applicants'] : [];
          final bool alreadyApplied =
              user != null && applicants.contains(user.uid);
          final bool isOwner = user?.uid == data['userId'];
          final bool isFull =
              (data['currentApplicants'] ?? 0) >= (data['maxApplicants'] ?? 1);
          final bool isClosed = data['statut'] != 'ouverte';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: photos.isNotEmpty ? 260 : 0,
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
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 16, color: Color(0xFF1F2937)),
                  ),
                ),
                flexibleSpace: photos.isNotEmpty
                    ? FlexibleSpaceBar(
                        background: Image.network(
                          photos[0],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFE5E7EB),
                            child: const Icon(
                                Icons.image_not_supported_outlined,
                                size: 48,
                                color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      )
                    : null,
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Statut
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isClosed
                              ? const Color(0xFF9CA3AF).withOpacity(0.1)
                              : const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isClosed ? '🔒 Fermée' : '✅ Ouverte',
                          style: GoogleFonts.sora(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isClosed
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        data['titre'] ?? 'Sans titre',
                        style: GoogleFonts.sora(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F2937),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildBadge(Icons.location_on_outlined,
                              data['lieu'] ?? 'Belgique'),
                          _buildBadge(Icons.euro_outlined,
                              '${_formatCurrency(data['remuneration'])}$rateSuffix'),
                          _buildBadge(Icons.calendar_today_outlined,
                              _formatDate(data['date'])),
                          if (data['duree'] != null)
                            _buildBadge(Icons.schedule_outlined,
                                '${data['duree']}h'),
                          _buildBadge(
                            Icons.people_outline,
                            '${data['currentApplicants'] ?? 0}/${data['maxApplicants'] ?? '?'} candidats',
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      _buildSection('Description'),
                      const SizedBox(height: 12),
                      Text(
                        data['description'] ?? 'Aucune description.',
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          color: const Color(0xFF4B5563),
                          height: 1.7,
                        ),
                      ),

                      if (photos.length > 1) ...[
                        const SizedBox(height: 28),
                        _buildSection('Photos'),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            itemBuilder: (context, index) => Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFFE5E7EB),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  photos[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // Bouton bas
      bottomNavigationBar: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('annonces')
            .doc(widget.jobId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox(height: 80);

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List applicants =
              data['applicants'] is List ? data['applicants'] : [];
          final bool alreadyApplied =
              user != null && applicants.contains(user.uid);
          final bool isOwner = user?.uid == data['userId'];
          final bool isFull =
              (data['currentApplicants'] ?? 0) >= (data['maxApplicants'] ?? 1);
          final bool isClosed = data['statut'] != 'ouverte';

          String buttonLabel;
          bool buttonDisabled;
          Color buttonColor;

          if (isOwner) {
            buttonLabel = 'Votre annonce';
            buttonDisabled = true;
            buttonColor = const Color(0xFF9CA3AF);
          } else if (alreadyApplied) {
            buttonLabel = '✅ Candidature envoyée';
            buttonDisabled = true;
            buttonColor = const Color(0xFF10B981);
          } else if (isClosed || isFull) {
            buttonLabel = isClosed ? 'Annonce fermée' : 'Complet';
            buttonDisabled = true;
            buttonColor = const Color(0xFF9CA3AF);
          } else {
            buttonLabel = 'Postuler maintenant';
            buttonDisabled = false;
            buttonColor = const Color(0xFF8A6BFE);
          }

          return Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              border:
                  Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: buttonDisabled || _isApplying
                    ? null
                    : () => _postuler(data),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  disabledBackgroundColor: buttonColor.withOpacity(0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isApplying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        buttonLabel,
                        style: GoogleFonts.sora(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title) {
    return Text(
      title,
      style: GoogleFonts.sora(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF8A6BFE)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF4B5563),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}