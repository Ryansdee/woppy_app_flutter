import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

class CreateAnnonceScreen extends StatefulWidget {
  const CreateAnnonceScreen({super.key});

  @override
  State<CreateAnnonceScreen> createState() => _CreateAnnonceScreenState();
}

class _CreateAnnonceScreenState extends State<CreateAnnonceScreen> {
  final _titreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _lieuController = TextEditingController();
  final _remunerationController = TextEditingController();
  final _dureeController = TextEditingController();
  final _maxApplicantsController = TextEditingController(text: '1');

  String _rateMode = 'hourly';
  DateTime? _selectedDate;
  bool _isSaving = false;
  String? _errorMessage;
  List<File> _photos = [];
  final _picker = ImagePicker();

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _lieuController.dispose();
    _remunerationController.dispose();
    _dureeController.dispose();
    _maxApplicantsController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final List<XFile> picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _photos.addAll(
          picked.map((x) => File(x.path)).take(5 - _photos.length),
        );
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF8A6BFE),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  bool _validate() {
    if (_titreController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Le titre est obligatoire.');
      return false;
    }
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'La description est obligatoire.');
      return false;
    }
    if (_lieuController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Le lieu est obligatoire.');
      return false;
    }
    if (_remunerationController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'La rémunération est obligatoire.');
      return false;
    }
    if (_selectedDate == null) {
      setState(() => _errorMessage = 'La date est obligatoire.');
      return false;
    }
    return true;
  }

  Future<List<String>> _uploadPhotos(String uid) async {
    final List<String> urls = [];
    for (int i = 0; i < _photos.length; i++) {
      final ref = FirebaseStorage.instance.ref(
        'annonceImages/$uid/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
      );
      await ref.putFile(_photos[i]);
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Upload photos
      final photoUrls = await _uploadPhotos(user.uid);

      await FirebaseFirestore.instance.collection('annonces').add({
        'titre': _titreController.text.trim(),
        'description': _descriptionController.text.trim(),
        'lieu': _lieuController.text.trim(),
        'remuneration': double.tryParse(
              _remunerationController.text.trim().replaceAll(',', '.'),
            ) ?? 0,
        'rateMode': _rateMode,
        'duree': int.tryParse(_dureeController.text.trim()) ?? 0,
        'maxApplicants': int.tryParse(_maxApplicantsController.text.trim()) ?? 1,
        'date':
            '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
        'userId': user.uid,
        'statut': 'ouverte',
        'currentApplicants': 0,
        'applicants': [],
        'photos': photoUrls,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Annonce publiée avec succès !',
                style: GoogleFonts.sora(fontSize: 13)),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Une erreur est survenue. Réessaie.');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F8F5),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
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
        title: Text(
          'Publier une annonce',
          style: GoogleFonts.sora(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photos ──
            _buildLabel('Photos'),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Bouton ajouter
                  if (_photos.length < 5)
                    GestureDetector(
                      onTap: _pickPhotos,
                      child: Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF8A6BFE).withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined,
                                color: Color(0xFF8A6BFE), size: 28),
                            const SizedBox(height: 4),
                            Text(
                              'Ajouter',
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                color: const Color(0xFF8A6BFE),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Photos sélectionnées
                  ..._photos.asMap().entries.map((entry) {
                    final i = entry.key;
                    final file = entry.value;
                    return Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: const Color(0xFFE5E7EB)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.file(file, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 14,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _photos.removeAt(i)),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            Text(
              'Maximum 5 photos',
              style: GoogleFonts.sora(
                  fontSize: 11, color: const Color(0xFF9CA3AF)),
            ),

            const SizedBox(height: 20),

            // ── Titre ──
            _buildLabel('Titre *'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titreController,
              hint: 'Ex: Aide déménagement, Cours de maths...',
              prefix: const Icon(Icons.title_outlined,
                  size: 18, color: Color(0xFF9CA3AF)),
            ),

            const SizedBox(height: 20),

            // ── Description ──
            _buildLabel('Description *'),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 1000,
              style: GoogleFonts.sora(
                  fontSize: 14, color: const Color(0xFF1F2937)),
              decoration: _inputDecoration(
                  'Décris la mission en détail...'),
            ),

            const SizedBox(height: 12),

            // ── Lieu ──
            _buildLabel('Lieu *'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _lieuController,
              hint: 'Ex: Rue de la Loi 1, Bruxelles',
              prefix: const Icon(Icons.location_on_outlined,
                  size: 18, color: Color(0xFF9CA3AF)),
            ),

            const SizedBox(height: 20),

            // ── Rémunération + mode ──
            _buildLabel('Rémunération *'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _remunerationController,
                    hint: '15.00',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    prefix: const Icon(Icons.euro_outlined,
                        size: 18, color: Color(0xFF9CA3AF)),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      _buildRateToggle('hourly', '/heure'),
                      _buildRateToggle('fixed', 'Fixe'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Durée + Max candidats ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Durée (heures)'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _dureeController,
                        hint: 'Ex: 3',
                        keyboardType: TextInputType.number,
                        prefix: const Icon(Icons.schedule_outlined,
                            size: 18, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Max candidats'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _maxApplicantsController,
                        hint: '1',
                        keyboardType: TextInputType.number,
                        prefix: const Icon(Icons.people_outline,
                            size: 18, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Date ──
            _buildLabel('Date *'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
                          : 'Choisir une date',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        color: _selectedDate != null
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFD1D5DB),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios,
                        size: 12, color: Color(0xFFD1D5DB)),
                  ],
                ),
              ),
            ),

            // ── Erreur ──
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.sora(
                          fontSize: 13,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── Bouton publier ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.campaign_outlined,
                        size: 20, color: Colors.white),
                label: Text(
                  _isSaving ? 'Publication...' : 'Publier l\'annonce',
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
          ],
        ),
      ),
    );
  }

  Widget _buildRateToggle(String value, String label) {
    final isSelected = _rateMode == value;
    return GestureDetector(
      onTap: () => setState(() => _rateMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8A6BFE)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.sora(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.sora(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF374151),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.sora(
          fontSize: 14, color: const Color(0xFFD1D5DB)),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFF8A6BFE), width: 2),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    Widget? prefix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.sora(
          fontSize: 14, color: const Color(0xFF1F2937)),
      decoration: _inputDecoration(hint).copyWith(prefixIcon: prefix),
    );
  }
}