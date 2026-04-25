import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:woppy_app/shared/services/notification_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0;
  bool? _wantsStudentProfile;
  bool _isLoading = false;
  String? _error;

  // Step 1 — infos générales
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  File? _photoFile;

  // Step 2 — profil étudiant
  final _studiesController = TextEditingController();
  final _ageController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _bioStudentController = TextEditingController();

  // Step 3 — disponibilités
  final List<String> _days = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];
  late Map<String, Map<String, dynamic>> _availability;

  // Step 4 — expériences
  List<Map<String, String>> _experiences = [];
  final _expTitleController = TextEditingController();
  final _expDescController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _availability = {
      for (final day in _days)
        day: {'enabled': false, 'slots': <Map<String, String>>[]}
    };
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _studiesController.dispose();
    _ageController.dispose();
    _hourlyRateController.dispose();
    _descriptionController.dispose();
    _bioStudentController.dispose();
    _expTitleController.dispose();
    _expDescController.dispose();
    super.dispose();
  }

  List<String> get _stepTitles => _wantsStudentProfile == true
      ? ['Profil', 'Infos', 'Étudiant', 'Dispos', 'Expériences', 'Bio']
      : ['Profil', 'Infos', 'Finalisation'];

  bool _validateStep1() {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty) {
      setState(() => _error = 'Remplis tous les champs obligatoires.');
      return false;
    }
    if (!_emailController.text.contains('@')) {
      setState(() => _error = 'Adresse email invalide.');
      return false;
    }
    if (_passwordController.text.length < 8) {
      setState(
          () => _error = 'Le mot de passe doit contenir au moins 8 caractères.');
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return false;
    }
    return true;
  }

  void _goNext() {
    if (_step == 1 && !_validateStep1()) return;
    setState(() {
      _error = null;
      _step++;
    });
  }

  void _goBack() {
    if (_step == 0) return;
    setState(() {
      _error = null;
      _step--;
    });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile != null) setState(() => _photoFile = File(xfile.path));
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = cred.user!;

      // Upload photo
      String photoURL = '';
      if (_photoFile != null) {
        final ref = FirebaseStorage.instance
            .ref('profilePhotos/${user.uid}/profile.jpg');
        await ref.putFile(_photoFile!);
        photoURL = await ref.getDownloadURL();
        await user.updateDisplayName(
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}');
        await user.updatePhotoURL(photoURL);
      }

      final base = {
        'uid': user.uid,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'city': _cityController.text.trim(),
        'bio': _bioController.text.trim(),
        'photoURL': photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'isAvailable': false,
      };

      Map<String, dynamic> finalDoc;

      if (_wantsStudentProfile == true) {
        finalDoc = {
          ...base,
          'hasStudentProfile': true,
          'studentProfile': {
            'studies': _studiesController.text.trim(),
            'age': _ageController.text.trim(),
            'hourlyRate': _hourlyRateController.text.trim(),
            'description': _descriptionController.text.trim(),
            'availability': _availability,
            'experiences': _experiences,
            'bio': _bioStudentController.text.trim(),
            'isComplete': true,
          },
          'experiences': _experiences,
          'availabilitySchedule': _availability,
        };
      } else {
        finalDoc = {
          ...base,
          'hasStudentProfile': false,
        };
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(finalDoc);

      await NotificationService.init();
      if (mounted) context.go('/home');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'email-already-in-use' => 'Cette adresse email est déjà utilisée.',
          'weak-password' => 'Mot de passe trop faible.',
          _ => 'Une erreur est survenue.',
        };
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F5),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar + steps
            if (_step > 0) _buildProgressBar(),

            // Error
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFEF4444), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: _buildCurrentStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final titles = _stepTitles;
    final progress = titles.length > 1 ? _step / (titles.length - 1) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          // Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF8A6BFE)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          // Step indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: titles.asMap().entries.map((entry) {
              final i = entry.key;
              final title = entry.value;
              final isDone = _step > i;
              final isCurrent = _step == i;

              return Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDone || isCurrent
                            ? const Color(0xFF8A6BFE)
                            : const Color(0xFFE5E7EB),
                        shape: BoxShape.circle,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF8A6BFE)
                                      .withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: GoogleFonts.sora(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrent
                                      ? Colors.white
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: GoogleFonts.sora(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: _step >= i
                            ? const Color(0xFF1F2937)
                            : const Color(0xFF9CA3AF),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      case 2:
        if (_wantsStudentProfile != true) return _buildStepFinal();
        return _buildStep2();
      case 3:
        return _buildStep3();
      case 4:
        return _buildStep4();
      case 5:
        return _buildStep5();
      default:
        return const SizedBox();
    }
  }

  // ── Step 0 — Choix du profil ──
  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => context.go('/login'),
          child: const Icon(Icons.arrow_back_ios,
              size: 20, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 32),
        Text(
          'Quel est ton profil ?',
          style: GoogleFonts.sora(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choisis comment tu veux utiliser Woppy.',
          style: GoogleFonts.sora(
              fontSize: 14, color: const Color(0xFF6B7280)),
        ),
        const SizedBox(height: 32),

        // Étudiant
        _buildProfileCard(
          icon: Icons.school_outlined,
          title: 'Étudiant',
          desc: "Postule aux missions, gagne jusqu'à 18€/h et développe ton réseau.",
          isStudent: true,
        ),

        const SizedBox(height: 16),

        // Particulier
        _buildProfileCard(
          icon: Icons.business_outlined,
          title: 'Particulier',
          desc: "Publie des annonces et trouve de l'aide pour tes missions.",
          isStudent: false,
        ),

        const SizedBox(height: 32),

        Center(
          child: GestureDetector(
            onTap: () => context.go('/login'),
            child: RichText(
              text: TextSpan(
                text: 'Tu as déjà un compte ? ',
                style: GoogleFonts.sora(
                    fontSize: 14, color: const Color(0xFF6B7280)),
                children: [
                  TextSpan(
                    text: 'Se connecter',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      color: const Color(0xFF8A6BFE),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard({
    required IconData icon,
    required String title,
    required String desc,
    required bool isStudent,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _wantsStudentProfile = isStudent;
          _step = 1;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF8A6BFE).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF8A6BFE), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }

  // ── Step 1 — Infos générales ──
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          'Informations générales',
          'Ces informations sont nécessaires pour créer ton compte.',
        ),

        // Photo
        _buildLabel('Photo de profil'),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF8A6BFE).withOpacity(0.08),
                border: Border.all(
                  color: const Color(0xFF8A6BFE).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: _photoFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.file(_photoFile!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_outlined,
                            color: Color(0xFF8A6BFE), size: 28),
                        const SizedBox(height: 4),
                        Text(
                          'Ajouter',
                          style: GoogleFonts.sora(
                            fontSize: 11,
                            color: const Color(0xFF8A6BFE),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Prénom + Nom
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Prénom *'),
                  const SizedBox(height: 8),
                  _buildTextField(
                      controller: _firstNameController, hint: 'Jean'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Nom *'),
                  const SizedBox(height: 8),
                  _buildTextField(
                      controller: _lastNameController, hint: 'Dupont'),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildLabel('Email *'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _emailController,
          hint: 'jean@example.com',
          keyboardType: TextInputType.emailAddress,
          prefix: const Icon(Icons.mail_outline,
              size: 18, color: Color(0xFF9CA3AF)),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Mot de passe *'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _passwordController,
                    hint: '••••••••',
                    obscure: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18,
                        color: const Color(0xFF9CA3AF),
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Confirmer *'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    hint: '••••••••',
                    obscure: _obscureConfirm,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18,
                        color: const Color(0xFF9CA3AF),
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildLabel('Ville *'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _cityController,
          hint: 'Bruxelles',
          prefix: const Icon(Icons.location_on_outlined,
              size: 18, color: Color(0xFF9CA3AF)),
        ),

        const SizedBox(height: 16),

        _buildLabel('Bio courte'),
        const SizedBox(height: 8),
        TextField(
          controller: _bioController,
          maxLines: 3,
          maxLength: 300,
          style: GoogleFonts.sora(
              fontSize: 14, color: const Color(0xFF1F2937)),
          decoration: _inputDecoration('Parle de toi en quelques mots…'),
        ),

        const SizedBox(height: 8),
        _buildNavButtons(),
      ],
    );
  }

  // ── Step 2 — Profil étudiant ──
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          'Profil étudiant',
          'Ces informations aident les particuliers à mieux te connaître.',
        ),

        _buildLabel('Études *'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _studiesController,
          hint: 'Ex : Bachelier en communication',
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Âge *'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _ageController,
                    hint: '20',
                    keyboardType: TextInputType.number,
                    prefix: const Icon(Icons.cake_outlined,
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
                  _buildLabel('Tarif (€/h)'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _hourlyRateController,
                    hint: '15.00',
                    keyboardType: TextInputType.number,
                    prefix: const Icon(Icons.euro_outlined,
                        size: 18, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildLabel('Description du profil'),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          style: GoogleFonts.sora(
              fontSize: 14, color: const Color(0xFF1F2937)),
          decoration: _inputDecoration(
              'Parle de tes compétences, tes études, ton expérience…'),
        ),

        const SizedBox(height: 24),
        _buildNavButtons(),
      ],
    );
  }

  // ── Step 3 — Disponibilités ──
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          'Disponibilités',
          'Active les jours où tu es disponible.',
        ),

        ..._days.map((day) {
          final dayData = _availability[day]!;
          final enabled = dayData['enabled'] as bool;
          final slots =
              dayData['slots'] as List<Map<String, String>>;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                // Header jour
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        day,
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      Switch(
                        value: enabled,
                        onChanged: (val) {
                          setState(() {
                            _availability[day]!['enabled'] = val;
                          });
                        },
                        activeColor: const Color(0xFF8A6BFE),
                      ),
                    ],
                  ),
                ),

                // Slots
                if (enabled) ...[
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ...slots.asMap().entries.map((entry) {
                          final i = entry.key;
                          final slot = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildTimeField(
                                    value: slot['start'] ?? '',
                                    hint: '08:00',
                                    onChanged: (val) => setState(() {
                                      (_availability[day]!['slots']
                                              as List<Map<String, String>>)[i]
                                          ['start'] = val;
                                    }),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Text('→',
                                      style: GoogleFonts.sora(
                                          color:
                                              const Color(0xFF9CA3AF))),
                                ),
                                Expanded(
                                  child: _buildTimeField(
                                    value: slot['end'] ?? '',
                                    hint: '17:00',
                                    onChanged: (val) => setState(() {
                                      (_availability[day]!['slots']
                                              as List<Map<String, String>>)[i]
                                          ['end'] = val;
                                    }),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 16,
                                      color: Color(0xFF9CA3AF)),
                                  onPressed: () => setState(() {
                                    (_availability[day]!['slots']
                                            as List<Map<String, String>>)
                                        .removeAt(i);
                                  }),
                                ),
                              ],
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: () => setState(() {
                            (_availability[day]!['slots']
                                    as List<Map<String, String>>)
                                .add({'start': '', 'end': ''});
                          }),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle_outline,
                                  size: 16, color: Color(0xFF8A6BFE)),
                              const SizedBox(width: 6),
                              Text(
                                'Ajouter un créneau',
                                style: GoogleFonts.sora(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF8A6BFE),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        _buildNavButtons(),
      ],
    );
  }

  // ── Step 4 — Expériences ──
  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          'Expériences',
          'Ajoute tes expériences pertinentes (optionnel).',
        ),

        // Liste des expériences
        if (_experiences.isNotEmpty)
          ..._experiences.map((exp) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF8A6BFE).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF8A6BFE).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exp['title'] ?? '',
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          if ((exp['description'] ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                exp['description'] ?? '',
                                style: GoogleFonts.sora(
                                  fontSize: 12,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(
                          () => _experiences.remove(exp)),
                      child: const Icon(Icons.close,
                          size: 16, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              )),

        // Formulaire ajout
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              _buildTextField(
                controller: _expTitleController,
                hint: "Titre de l'expérience",
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _expDescController,
                maxLines: 2,
                style: GoogleFonts.sora(
                    fontSize: 14, color: const Color(0xFF1F2937)),
                decoration: _inputDecoration('Description (optionnel)'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_expTitleController.text.trim().isEmpty)
                      return;
                    setState(() {
                      _experiences.add({
                        'title': _expTitleController.text.trim(),
                        'description': _expDescController.text.trim(),
                      });
                      _expTitleController.clear();
                      _expDescController.clear();
                    });
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    'Ajouter',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A6BFE),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildNavButtons(),
      ],
    );
  }

  // ── Step 5 — Bio étudiante ──
  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          'Dernière étape',
          'Un mot pour te présenter aux particuliers.',
        ),

        _buildLabel('Bio étudiante'),
        const SizedBox(height: 8),
        TextField(
          controller: _bioStudentController,
          maxLines: 5,
          style: GoogleFonts.sora(
              fontSize: 14, color: const Color(0xFF1F2937)),
          decoration: _inputDecoration(
              'Explique ce que tu recherches, tes atouts, ta motivation…'),
        ),

        const SizedBox(height: 24),
        _buildNavButtons(isSubmit: true),
      ],
    );
  }

  // ── Step final (non-étudiant) ──
  Widget _buildStepFinal() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tout est prêt !',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tes informations sont complètes. Tu pourras ajouter un profil étudiant à tout moment.',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildNavButtons(isSubmit: true),
      ],
    );
  }

  // ── Nav buttons ──
  Widget _buildNavButtons({bool isSubmit = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_step > 0)
            OutlinedButton(
              onPressed: _goBack,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Retour',
                style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
            )
          else
            const SizedBox(),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : isSubmit
                    ? _submit
                    : _goNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A6BFE),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isSubmit ? 'Créer mon compte' : 'Continuer',
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (isSubmit) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check,
                            size: 16, color: Colors.white),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──
  Widget _buildStepHeader(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.sora(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          desc,
          style: GoogleFonts.sora(
              fontSize: 13, color: const Color(0xFF6B7280)),
        ),
        const SizedBox(height: 24),
      ],
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
    bool obscure = false,
    Widget? prefix,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: GoogleFonts.sora(
          fontSize: 14, color: const Color(0xFF1F2937)),
      decoration: _inputDecoration(hint).copyWith(
        prefixIcon: prefix,
        suffixIcon: suffix,
      ),
    );
  }

  Widget _buildTimeField({
    required String value,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      onChanged: onChanged,
      keyboardType: TextInputType.datetime,
      style: GoogleFonts.sora(
          fontSize: 13, color: const Color(0xFF1F2937)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.sora(
            fontSize: 13, color: const Color(0xFFD1D5DB)),
        filled: true,
        fillColor: const Color(0xFFF9F8F5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF8A6BFE), width: 2),
        ),
      ),
    );
  }
}