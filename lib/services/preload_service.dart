import 'package:flutter/foundation.dart';
import 'quran_api_service.dart';
import 'audio_service.dart';
import 'settings_service.dart';

/// Service de préchargement des données importantes
/// Charge les données au démarrage pour une expérience fluide
class PreloadService {
  final QuranApiService _quranApiService;
  final AudioService _audioService;
  final SettingsService _settingsService;

  PreloadService({
    required QuranApiService quranApiService,
    required AudioService audioService,
    required SettingsService settingsService,
  })  : _quranApiService = quranApiService,
        _audioService = audioService,
        _settingsService = settingsService;

  /// Précharge les données essentielles
  /// Retourne le nombre d'éléments préchargés
  Future<PreloadResult> preloadEssentialData({
    int preloadSurahsCount = 5,
  }) async {
    final startTime = DateTime.now();
    int loadedCount = 0;
    int errorCount = 0;

    try {
      debugPrint('🚀 Starting preload...');

      // 1. Initialiser les paramètres
      await _settingsService.init();
      loadedCount++;

      // 2. Charger la liste des sourates (essentiel)
      try {
        await _quranApiService.getAllSurahs();
        loadedCount++;
        debugPrint('✅ Preloaded: All surahs list');
      } catch (e) {
        errorCount++;
        debugPrint('❌ Failed to preload surahs list: $e');
      }

      // 3. Récupérer le récitateur sélectionné
      String selectedReciter = AudioService.defaultReciter;
      try {
        selectedReciter = await _settingsService.getSelectedReciter();
      } catch (e) {
        debugPrint('⚠️ Could not get selected reciter, using default');
      }

      // 4. Précharger les premières sourates (1 à preloadSurahsCount)
      // Faire cela en parallèle pour plus de rapidité
      final preloadFutures = <Future<void>>[];

      for (int i = 1; i <= preloadSurahsCount && i <= 114; i++) {
        // Précharger le détail de la sourate
        preloadFutures.add(
          _quranApiService
              .getSurahDetail(
                i,
                translationEdition: 'fr.hamidullah',
              )
              .then((_) {
                loadedCount++;
                debugPrint('✅ Preloaded: Surah $i detail');
              }).catchError((e) {
                errorCount++;
                debugPrint('❌ Failed to preload surah $i detail: $e');
              }),
        );

        // Précharger les URLs audio
        preloadFutures.add(
          _audioService
              .getSurahAudioUrls(i, reciter: selectedReciter)
              .then((_) {
                loadedCount++;
                debugPrint('✅ Preloaded: Surah $i audio URLs');
              }).catchError((e) {
                errorCount++;
                debugPrint('❌ Failed to preload surah $i audio: $e');
              }),
        );
      }

      // Attendre que tous les préchargements soient terminés
      await Future.wait(preloadFutures, eagerError: false);

      final duration = DateTime.now().difference(startTime);
      debugPrint(
        '🎉 Preload completed: $loadedCount loaded, $errorCount errors in ${duration.inMilliseconds}ms',
      );

      return PreloadResult(
        loadedCount: loadedCount,
        errorCount: errorCount,
        duration: duration,
      );
    } catch (e) {
      debugPrint('❌ Preload error: $e');
      final duration = DateTime.now().difference(startTime);
      return PreloadResult(
        loadedCount: loadedCount,
        errorCount: errorCount + 1,
        duration: duration,
      );
    }
  }

  /// Précharge une sourate spécifique (pour préchargement intelligent)
  Future<void> preloadSurah(int surahNumber, {String? reciter}) async {
    try {
      // Récupérer le récitateur si non fourni
      if (reciter == null) {
        try {
          reciter = await _settingsService.getSelectedReciter();
        } catch (e) {
          reciter = AudioService.defaultReciter;
        }
      }

      // Précharger en parallèle
      await Future.wait([
        _quranApiService.getSurahDetail(
          surahNumber,
          translationEdition: 'fr.hamidullah',
        ),
        _audioService.getSurahAudioUrls(surahNumber, reciter: reciter),
      ], eagerError: false);

      debugPrint('✅ Preloaded surah $surahNumber');
    } catch (e) {
      debugPrint('⚠️ Failed to preload surah $surahNumber: $e');
    }
  }

  /// Précharge les sourates adjacentes (pour navigation fluide)
  Future<void> preloadAdjacentSurahs(
    int currentSurahNumber, {
    String? reciter,
  }) async {
    final futures = <Future<void>>[];

    // Précharger la sourate précédente
    if (currentSurahNumber > 1) {
      futures.add(preloadSurah(currentSurahNumber - 1, reciter: reciter));
    }

    // Précharger la sourate suivante
    if (currentSurahNumber < 114) {
      futures.add(preloadSurah(currentSurahNumber + 1, reciter: reciter));
    }

    await Future.wait(futures, eagerError: false);
  }
}

/// Résultat du préchargement
class PreloadResult {
  final int loadedCount;
  final int errorCount;
  final Duration duration;

  PreloadResult({
    required this.loadedCount,
    required this.errorCount,
    required this.duration,
  });

  bool get isSuccess => errorCount == 0;
  double get successRate => loadedCount / (loadedCount + errorCount);
}

