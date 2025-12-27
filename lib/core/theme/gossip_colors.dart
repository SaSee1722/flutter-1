import 'package:flutter/material.dart';

class GossipColors {
  // Primary Palette
  static const Color background = Color(0xFF000000); // Pure Black
  static const Color cardBackground =
      Color(0xFF0D0D0D); // Slightly lighter than black for cards
  static const Color primary = Color(0xFF2FB5E8); // Sky Blue from screenshot
  static const Color secondary = Color(0xFFFF7EB2); // Baby Pink from screenshot

  // Text Colors
  static const Color textMain = Color(0xFFFFFFFF);
  static const Color textDim = Color(0xFF6E6E6E);
  static const Color textMuted = Color(0xFF333333);

  // Accents
  static const Color searchBar = Color(0xFF151515);
  static const Color border = Color(0xFF1A1A1A);
  static const Color navigationBg =
      Color(0xCC000000); // Translucent black for floating nav

  static const Gradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient blueGradient = LinearGradient(
    colors: [primary, Color(0xFF1A8CB8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Gradient secondaryGradient = LinearGradient(
    colors: [secondary, Color(0xFFD63E7B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
