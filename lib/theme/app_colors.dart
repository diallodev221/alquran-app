import 'package:flutter/material.dart';

/// Charte graphique inspirée de l'esthétique islamique
class AppColors {
  // Couleurs principales - Light Mode
  static const Color deepBlue = Color(0xFF1F4788); // Bleu nuit profond
  static const Color luxuryGold = Color(0xFFD4AF37); // Or luxueux
  static const Color softBronze = Color(0xFFCD7F32); // Bronze doux
  static const Color ivory = Color(0xFFFFFFF0); // Ivoire pour le fond
  static const Color pureWhite = Color(0xFFFFFFFF);

  // Couleurs secondaires
  static const Color lightBlue = Color(0xFF4A7AB8);
  static const Color paleGold = Color(0xFFF5E6C3);
  static const Color darkGold = Color(0xFFB8941F);

  // Texte et contenu
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);

  // Dark Mode
  static const Color darkBackground = Color(0xFF0F1419);
  static const Color darkSurface = Color(0xFF1A2332);
  static const Color darkCard = Color(0xFF212B3D);
  static const Color darkTextPrimary = Color(0xFFE8E8E8);
  static const Color darkTextSecondary = Color(0xFFB8B8B8);

  // Statuts et feedback
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF29B6F6);

  // Dégradés
  static const LinearGradient headerGradient = LinearGradient(
    colors: [deepBlue, Color(0xFF2A5699)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldAccent = LinearGradient(
    colors: [luxuryGold, darkGold],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [Color(0xFFE8E8E8), Color(0xFFF5F5F5), Color(0xFFE8E8E8)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, 0.0),
    end: Alignment(1.0, 0.0),
  );

  // Ombres
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get cardShadowHover => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get goldGlow => [
    BoxShadow(
      color: luxuryGold.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
}
