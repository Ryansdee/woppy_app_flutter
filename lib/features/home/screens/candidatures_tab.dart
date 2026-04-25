import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CandidaturesTab extends StatelessWidget {
  const CandidaturesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Candidatures — à venir',
          style: GoogleFonts.sora(color: const Color(0xFF6B7280))),
    );
  }
}