import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../widgets/app_logo.dart';
import '../widgets/auto_play_listener.dart';
import '../services/preload_service.dart';
import '../services/settings_service.dart';
import '../providers/quran_providers.dart';
import '../providers/audio_providers.dart';
import 'main_navigation.dart';

/// Écran de démarrage avec le logo de l'application
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
    _startPreload();
  }

  /// Démarre le préchargement des données
  Future<void> _startPreload() async {
    try {
      // Créer le service de préchargement
      final quranApiService = ref.read(quranApiServiceProvider);
      final audioService = ref.read(audioServiceProvider);
      final settingsService = SettingsService();
      await settingsService.init();

      // Restaurer la dernière lecture (clé du produit : continuité)
      final lastSurah = await settingsService.getLastReadSurah();
      final lastAyah = await settingsService.getLastReadAyah();
      if (mounted) {
        ref.read(lastReadSurahProvider.notifier).state = lastSurah;
        ref.read(lastReadAyahProvider.notifier).state = lastAyah;
      }

      final preloadService = PreloadService(
        quranApiService: quranApiService,
        audioService: audioService,
        settingsService: settingsService,
      );

      // Lancer le préchargement (en arrière-plan)
      final preloadFuture = preloadService.preloadEssentialData(
        preloadSurahsCount: 5, // Précharger les 5 premières sourates
      );

      // Attendre au minimum 1.5 secondes pour l'animation
      // et au maximum 3 secondes pour le préchargement
      await Future.wait([
        Future.delayed(const Duration(milliseconds: 1500)),
        preloadFuture,
      ], eagerError: false).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⏱️ Preload timeout, continuing anyway');
          return <void>[];
        },
      );

      if (mounted) {
        _navigateToHome();
      }
    } catch (e) {
      debugPrint('❌ Preload error: $e');
      // Naviguer quand même après un délai minimum
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            _navigateToHome();
          }
        });
      }
    }
  }

  /// Navigue vers l'écran principal
  void _navigateToHome() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AutoPlayListener(child: MainNavigation()),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  colors: [AppColors.darkBackground, AppColors.darkSurface],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : LinearGradient(
                  colors: [AppColors.deepBlue, AppColors.lightBlue],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: const AppLogo(size: 150, showText: true),
            ),
          ),
        ),
      ),
    );
  }
}
