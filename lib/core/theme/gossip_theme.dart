import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'gossip_colors.dart';

class GossipTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: GossipColors.background,
      colorScheme: ColorScheme.dark(
        primary: GossipColors.primary,
        secondary: GossipColors.secondary,
        surface: GossipColors.cardBackground,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
              color: GossipColors.textMain, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(
              color: GossipColors.textMain, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: GossipColors.textMain),
          bodyMedium: TextStyle(color: GossipColors.textDim),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: GossipColors.textMain,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GossipColors.searchBar,
        hintStyle: const TextStyle(color: GossipColors.textDim),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: GossipColors.primary.withValues(alpha: 0.3)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: GossipColors.primary,
        unselectedItemColor: GossipColors.textDim,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }
}
