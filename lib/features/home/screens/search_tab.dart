import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchTab extends StatelessWidget {
  const SearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Recherche — à venir',
          style: GoogleFonts.sora(color: const Color(0xFF6B7280))),
    );
  }
}