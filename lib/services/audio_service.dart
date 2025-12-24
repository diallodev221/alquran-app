import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/quran_models.dart';
import '../core/exceptions/api_exceptions.dart';
import 'memory_cache_service.dart';
import 'cache_service.dart';
import 'package:hive/hive.dart';

/// Service pour gérer l'audio du Quran
class AudioService {
  static const String baseUrl = 'https://api.alquran.cloud/v1';
  final Dio _dio;
  final MemoryCacheService _memoryCache = MemoryCacheService();
  late final CacheService _cacheService;

  // Récitateurs populaires
  static const String defaultReciter = 'ar.alafasy'; // Mishary Alafasy
  static const String alternateReciter = 'ar.abdulbasitmurattal'; // Abdul Basit
  static const String alternateReciter2 = 'ar.husary'; // alHussary

  AudioService({Dio? dio})
      : _dio =
            dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
              ),
            ) {
    _initCache();
  }

  void _initCache() {
    // Initialiser le cache de manière synchrone
    // La box Hive doit être ouverte avant (dans main.dart via CacheService.init())
    try {
      final box = Hive.box(CacheService.surahsBox);
      _cacheService = CacheService(box);
    } catch (e) {
      // Si la box n'est pas encore ouverte, utiliser une box temporaire
      // qui sera réinitialisée lors de l'accès
      debugPrint('⚠️ Cache box not ready: $e');
      // On initialisera lors du premier accès
    }
  }

  /// Récupère le cache service, en l'initialisant si nécessaire
  CacheService get _safeCacheService {
    try {
      final box = Hive.box(CacheService.surahsBox);
      return CacheService(box);
    } catch (e) {
      // Si la box n'est pas ouverte, retourner le cache existant ou créer un nouveau
      try {
        final box = Hive.box(CacheService.surahsBox);
        _cacheService = CacheService(box);
        return _cacheService;
      } catch (_) {
        // En dernier recours, retourner le cache existant (peut être null mais ne devrait pas arriver)
        return _cacheService;
      }
    }
  }

  /// Récupère une sourate avec les URLs audio
  /// Utilise le cache si offline, sinon fait une requête réseau
  Future<List<String>> getSurahAudioUrls(
    int surahNumber, {
    String reciter = defaultReciter,
    bool forceNetwork = false, // Pour forcer une requête réseau même si cache existe
  }) async {
    final cacheKey = 'audio_urls_${surahNumber}_$reciter';

    // 1. Vérifier cache mémoire d'abord (le plus rapide)
    final memoryCached = _memoryCache.getList<List<String>>(cacheKey);
    if (memoryCached != null && !forceNetwork) {
      debugPrint('⚡ Returning memory-cached audio URLs for surah $surahNumber');
      return memoryCached;
    }

    // 2. Vérifier cache Hive (persistant)
    if (!forceNetwork) {
      try {
        final cached = _safeCacheService.getIfValid<List>(
          cacheKey,
          (data) => (data as List).map((e) => e.toString()).toList(),
        );

        if (cached != null && cached.isNotEmpty) {
          final cachedUrls = cached.map((e) => e.toString()).toList();
          debugPrint('📦 Returning Hive-cached audio URLs for surah $surahNumber');
          // Mettre aussi en cache mémoire pour les prochaines fois
          _memoryCache.putList(cacheKey, cachedUrls);
          return cachedUrls;
        }
      } catch (e) {
        debugPrint('⚠️ Error accessing Hive cache: $e');
        // Continue avec la requête réseau
      }
    }

    // 3. Essayer de récupérer depuis le réseau
    try {
      final response = await _dio.get('/surah/$surahNumber/$reciter');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final surahData = data['data'] as Map<String, dynamic>;
        final ayahs = surahData['ayahs'] as List;

        final audioUrls = ayahs
            .map((ayah) {
              final audio = ayah['audio'] as String?;
              return audio ?? '';
            })
            .where((url) => url.isNotEmpty)
            .toList();

        // Ajouter le Bismillah au début pour toutes les sourates sauf At-Tawbah (9)
        if (surahNumber != 9 && audioUrls.isNotEmpty) {
          final bismillahUrl = _getBismillahUrl(reciter);
          audioUrls.insert(0, bismillahUrl);
          debugPrint(
            '🎵 Loaded ${audioUrls.length} audio URLs for surah $surahNumber (with Bismillah)',
          );
        } else {
          debugPrint(
            '🎵 Loaded ${audioUrls.length} audio URLs for surah $surahNumber',
          );
        }

        // Sauvegarder en cache Hive (persistant)
        try {
          await _safeCacheService.saveWithExpiry(
            cacheKey,
            audioUrls,
            duration: CacheService.staticContentDuration,
          );
        } catch (e) {
          debugPrint('⚠️ Error saving to Hive cache: $e');
          // Continue même si le cache échoue
        }

        // Mettre en cache mémoire pour les prochaines fois
        _memoryCache.putList(cacheKey, audioUrls);

        return audioUrls;
      }
      throw ServerException('Failed to fetch audio URLs');
    } on DioException catch (e) {
      // En cas d'erreur réseau, utiliser le cache si disponible
      debugPrint('⚠️ Network error fetching audio: ${e.message}');
      
      // Essayer cache mémoire d'abord
      final memoryCached = _memoryCache.getList<List<String>>(cacheKey);
      if (memoryCached != null && memoryCached.isNotEmpty) {
        debugPrint('📦 Using memory-cached audio URLs (offline mode)');
        return memoryCached;
      }

      // Essayer cache Hive (même expiré)
      try {
        final staleCache = _safeCacheService.getStale<List>(
          cacheKey,
          (data) => (data as List).map((e) => e.toString()).toList(),
        );

        if (staleCache != null && staleCache.isNotEmpty) {
          final staleUrls = staleCache.map((e) => e.toString()).toList();
          debugPrint('📦 Using stale Hive-cached audio URLs (offline mode)');
          // Mettre en cache mémoire aussi
          _memoryCache.putList(cacheKey, staleUrls);
          return staleUrls;
        }
      } catch (e) {
        debugPrint('⚠️ Error accessing stale Hive cache: $e');
        // Continue avec l'exception
      }

      // Pas de cache disponible, lancer l'exception
      throw NetworkException(
        'Impossible de charger l\'audio. Vérifiez votre connexion Internet.',
      );
    } catch (e) {
      // Pour toute autre erreur, essayer aussi le cache
      if (e is! NetworkException) {
        final memoryCached = _memoryCache.getList<List<String>>(cacheKey);
        if (memoryCached != null && memoryCached.isNotEmpty) {
          debugPrint('📦 Using cached audio URLs due to error: $e');
          return memoryCached;
        }
      }
      rethrow;
    }
  }

  /// Génère l'URL du Bismillah pour un récitateur donné
  /// Utilise l'ayah 1 de la sourate Al-Fatiha (1:1) qui est le Bismillah complet
  String _getBismillahUrl(String reciter) {
    // L'API utilise le numéro global de l'ayah (1 pour le premier ayah du Quran)
    return 'https://cdn.islamic.network/quran/audio/128/$reciter/1.mp3';
  }

  /// Récupère les récitateurs disponibles
  Future<List<RecitationModel>> getReciters() async {
    try {
      final response = await _dio.get('/edition/format/audio');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final editions = (data['data'] as List)
            .map((e) => RecitationModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // Filtrer pour ne garder que les récitations audio en arabe
        final arabicReciters = editions
            .where(
              (e) =>
                  e.language == 'ar' &&
                  e.format == 'audio' &&
                  e.type == 'versebyverse',
            )
            .toList();

        debugPrint('🎙️ Found ${arabicReciters.length} Arabic reciters');
        return arabicReciters;
      }
      throw ServerException('Failed to fetch reciters');
    } on DioException catch (e) {
      debugPrint('Error fetching reciters: ${e.message}');
      return [];
    }
  }

  /// Liste des récitateurs recommandés (hardcodés pour performance)
  static List<Map<String, String>> get popularReciters => [
    {
      'id': 'ar.alafasy',
      'name': 'Mishary Rashid Alafasy',
      'arabicName': 'مشاري راشد العفاسي',
    },
    {
      'id': 'ar.abdulbasitmurattal',
      'name': 'Abdul Basit (Murattal)',
      'arabicName': 'عبد الباسط عبد الصمد (مرتل)',
    },
    {
      'id': 'ar.abdurrahmaansudais',
      'name': 'Abdur-Rahman as-Sudais',
      'arabicName': 'عبد الرحمن السديس',
    },
    {
      'id': 'ar.minshawi',
      'name': 'Mohamed Siddiq al-Minshawi',
      'arabicName': 'محمد صديق المنشاوي',
    },
    {
      'id': 'ar.husary',
      'name': 'Mahmoud Khalil Al-Hussary',
      'arabicName': 'محمود خليل الحصري',
    },
    {
      'id': 'ar.shaatree',
      'name': 'Abu Bakr al-Shatri',
      'arabicName': 'أبو بكر الشاطري',
    },
  ];
}
