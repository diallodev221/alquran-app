import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/quran_models.dart';
import '../core/exceptions/api_exceptions.dart';
import 'memory_cache_service.dart';

/// Service pour gérer l'audio du Quran
class AudioService {
  static const String baseUrl = 'https://api.alquran.cloud/v1';
  final Dio _dio;
  final MemoryCacheService _memoryCache = MemoryCacheService();

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
          );

  /// Récupère une sourate avec les URLs audio
  Future<List<String>> getSurahAudioUrls(
    int surahNumber, {
    String reciter = defaultReciter,
  }) async {
    final cacheKey = 'audio_urls_${surahNumber}_$reciter';

    // 1. Vérifier cache mémoire d'abord (le plus rapide)
    final memoryCached = _memoryCache.getList<List<String>>(cacheKey);
    if (memoryCached != null) {
      debugPrint('⚡ Returning memory-cached audio URLs for surah $surahNumber');
      return memoryCached;
    }

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

        // Mettre en cache mémoire pour les prochaines fois
        _memoryCache.putList(cacheKey, audioUrls);

        return audioUrls;
      }
      throw ServerException('Failed to fetch audio URLs');
    } on DioException catch (e) {
      debugPrint('Error fetching audio: ${e.message}');
      // En cas d'erreur, vérifier si on a un cache (même expiré)
      final cached = _memoryCache.getList<List<String>>(cacheKey);
      if (cached != null) {
        debugPrint('⚠️ Using cached audio URLs despite error');
        return cached;
      }
      throw NetworkException('Impossible de charger l\'audio: ${e.message}');
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
