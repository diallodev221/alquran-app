import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/cache_service.dart';
import 'data/local/quran_database.dart';
import 'services/favorites_service.dart';
import 'services/settings_service.dart';
import 'services/user_behavior_service.dart';
import 'services/personalization_service.dart';
import 'services/content_rotation_service.dart';
import 'services/ramadan_content_service.dart';
import 'providers/settings_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await CacheService.init();

  // Texte Qur'an 100 % offline (Tanzil) : copie assets puis init SQLite
  await QuranDatabase.copyFromAssetsIfNeeded(rootBundle.load);
  await QuranDatabase.initialize();

  // Initialiser le service de favoris
  final favoritesService = FavoritesService();
  await favoritesService.init();

  // Initialiser le service de paramètres
  final settingsService = SettingsService();
  await settingsService.init();

  // Initialiser les services de personnalisation
  final userBehaviorService = UserBehaviorService();
  await userBehaviorService.init();

  final personalizationService = PersonalizationService();
  await personalizationService.init();

  // Initialiser le service de rotation de contenu
  final contentRotationService = ContentRotationService();
  await contentRotationService.init();

  // Initialiser le service de contenu Ramadan
  final ramadanContentService = RamadanContentService();
  await ramadanContentService.init();

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
    final themeMode = ref.watch(themeModeProvider);

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

      // Mode de thème depuis les paramètres
      themeMode: themeMode,

      // Démarrer avec le splash screen
      home: const SplashScreen(),
    );
  }
}
