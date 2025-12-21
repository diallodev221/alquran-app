import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/cache_service.dart';
import 'services/favorites_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Hive pour le cache local et les favoris
  await Hive.initFlutter();
  await CacheService.init();

  // Initialiser le service de favoris
  final favoritesService = FavoritesService();
  await favoritesService.init();

  // Initialiser le service de paramètres
  final settingsService = SettingsService();
  await settingsService.init();

  // Configuration du statut bar et navigation bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Mode edge-to-edge
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const ProviderScope(child: AlQuranApp()));
}

class AlQuranApp extends ConsumerWidget {
  const AlQuranApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'القرآن الكريم',
      debugShowCheckedModeBanner: false,

      // Theme Light avec Google Fonts
      theme: AppTheme.lightTheme().copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(
          AppTheme.lightTheme().textTheme,
        ),
      ),

      // Theme Dark avec Google Fonts
      darkTheme: AppTheme.darkTheme().copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(AppTheme.darkTheme().textTheme),
      ),

      // Mode automatique basé sur le système
      themeMode: ThemeMode.system,

      // Démarrer avec le splash screen
      home: const SplashScreen(),
    );
  }
}
