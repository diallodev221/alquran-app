import 'package:flutter/material.dart';

/// Utilitaires pour gérer la responsivité de l'application
class ResponsiveUtils {
  /// Breakpoints pour différentes tailles d'écran
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Obtenir la largeur de l'écran
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Obtenir la hauteur de l'écran
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Vérifier si c'est un petit écran (mobile)
  static bool isMobile(BuildContext context) {
    return screenWidth(context) < mobileBreakpoint;
  }

  /// Vérifier si c'est une tablette
  static bool isTablet(BuildContext context) {
    return screenWidth(context) >= mobileBreakpoint &&
        screenWidth(context) < tabletBreakpoint;
  }

  /// Vérifier si c'est un grand écran (desktop)
  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= desktopBreakpoint;
  }

  /// Obtenir le type d'appareil
  static DeviceType getDeviceType(BuildContext context) {
    final width = screenWidth(context);
    if (width < mobileBreakpoint) return DeviceType.mobile;
    if (width < tabletBreakpoint) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// Padding adaptatif basé sur la taille de l'écran
  static double adaptivePadding(
    BuildContext context, {
    double mobile = 16.0,
    double? tablet,
    double? desktop,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile * 1.5;
      case DeviceType.desktop:
        return desktop ?? mobile * 2;
    }
  }

  /// Taille de police adaptative
  static double adaptiveFontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile * 1.2;
      case DeviceType.desktop:
        return desktop ?? mobile * 1.3;
    }
  }

  /// Taille de police pour le texte Quran : 100 % partout (même font, même taille sur tous les appareils).
  static double quranFontSize(BuildContext context, double baseSize) =>
      baseSize;

  /// Largeur maximale pour le contenu (empêche les lignes trop longues)
  static double maxContentWidth(BuildContext context) {
    final width = screenWidth(context);
    if (width < tabletBreakpoint) return width;
    if (width < desktopBreakpoint) return 800;
    return 1000;
  }

  /// Nombre de colonnes pour une grille
  static int gridColumns(
    BuildContext context, {
    int mobile = 1,
    int? tablet,
    int? desktop,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? 2;
      case DeviceType.desktop:
        return desktop ?? 3;
    }
  }

  /// Aspect ratio adaptatif
  static double adaptiveAspectRatio(
    BuildContext context, {
    double mobile = 1.0,
    double? tablet,
    double? desktop,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? mobile;
    }
  }

  /// Obtenir une valeur responsive basée sur le type d'appareil
  static T responsive<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  /// Hauteur de l'AppBar expansible adaptative
  static double adaptiveAppBarHeight(BuildContext context) {
    final height = screenHeight(context);
    if (height < 600) return 150; // Petits écrans
    if (height < 800) return 200; // Écrans moyens
    return 250; // Grands écrans
  }

  /// Taille des icônes adaptative
  static double adaptiveIconSize(BuildContext context, {double base = 24.0}) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return base;
      case DeviceType.tablet:
        return base * 1.3;
      case DeviceType.desktop:
        return base * 1.5;
    }
  }

  /// Border radius adaptatif
  static double adaptiveBorderRadius(
    BuildContext context, {
    double base = 16.0,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return base;
      case DeviceType.tablet:
        return base * 1.2;
      case DeviceType.desktop:
        return base * 1.3;
    }
  }
}

/// Types d'appareils
enum DeviceType { mobile, tablet, desktop }

/// Extension sur BuildContext pour un accès facile
extension ResponsiveExtension on BuildContext {
  /// Est-ce un mobile ?
  bool get isMobile => ResponsiveUtils.isMobile(this);

  /// Est-ce une tablette ?
  bool get isTablet => ResponsiveUtils.isTablet(this);

  /// Est-ce un desktop ?
  bool get isDesktop => ResponsiveUtils.isDesktop(this);

  /// Type d'appareil
  DeviceType get deviceType => ResponsiveUtils.getDeviceType(this);

  /// Largeur de l'écran
  double get screenWidth => ResponsiveUtils.screenWidth(this);

  /// Hauteur de l'écran
  double get screenHeight => ResponsiveUtils.screenHeight(this);

  /// Largeur maximale du contenu
  double get maxContentWidth => ResponsiveUtils.maxContentWidth(this);
}
