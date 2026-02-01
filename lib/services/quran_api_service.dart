import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import '../core/exceptions/api_exceptions.dart';
import '../models/quran_models.dart';
import '../utils/available_translations.dart';
import 'cache_service.dart';
import 'memory_cache_service.dart';
import 'package:hive/hive.dart';

/// Service API pour Al-Quran Cloud
class QuranApiService {
  static const String baseUrl = 'https://api.alquran.cloud/v1';
  static const Duration timeout = Duration(seconds: 30);

  final Dio _dio;
  late final CacheService _cacheService;
  final MemoryCacheService _memoryCache = MemoryCacheService();

  QuranApiService({Dio? dio}) : _dio = dio ?? _initDio() {
    _initCache();
  }

  void _initCache() async {
    final box = Hive.box(CacheService.surahsBox);
    _cacheService = CacheService(box);
  }

  static Dio _initDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );

    // Interceptors pour logging
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint('🌐 API Request: ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('✅ API Response: ${response.statusCode}');
          return handler.next(response);
        },
        onError: (error, handler) {
          debugPrint('❌ API Error: ${error.message}');
          return handler.next(error);
        },
      ),
    );

    // Retry interceptor pour connexions instables
    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        retries: 3,
        retryDelays: const [
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 3),
        ],
      ),
    );

    return dio;
  }

  /// GET /surah - Récupère toutes les sourates (114)
  Future<List<SurahModel>> getAllSurahs() async {
    const cacheKey = 'all_surahs';

    // 1. Vérifier cache mémoire d'abord (le plus rapide)
    final memoryCached = _memoryCache.getList<List<SurahModel>>(cacheKey);
    if (memoryCached != null) {
      debugPrint('⚡ Returning memory-cached surahs');
      return memoryCached;
    }

    // 2. Vérifier cache Hive (persistant)
    final cached = _cacheService.getIfValid<List>(
      cacheKey,
      (data) => (data as List).map((e) => SurahModel.fromJson(e)).toList(),
    );

    if (cached != null) {
      debugPrint('📦 Returning Hive-cached surahs');
      // Mettre aussi en cache mémoire pour les prochaines fois
      _memoryCache.putList(cacheKey, cached);
      return cached as List<SurahModel>;
    }

    try {
      final response = await _dio.get('/surah');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final surahs = (data['data'] as List)
            .map((e) => SurahModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // Sauvegarder en cache Hive (persistant)
        await _cacheService.saveWithExpiry(
          cacheKey,
          surahs.map((e) => e.toJson()).toList(),
          duration: CacheService.staticContentDuration,
        );

        // Sauvegarder aussi en cache mémoire (ultra-rapide)
        _memoryCache.putList(cacheKey, surahs);

        return surahs;
      }
      throw ServerException('Failed to fetch surahs');
    } on DioException catch (e) {
      // Fallback sur cache expiré si erreur
      final staleCache = _cacheService.getStale<List>(
        cacheKey,
        (data) => (data as List).map((e) => SurahModel.fromJson(e)).toList(),
      );

      if (staleCache != null) {
        debugPrint('⚠️ Using stale cache for surahs');
        // Mettre en cache mémoire aussi
        _memoryCache.putList(cacheKey, staleCache);
        return staleCache as List<SurahModel>;
      }

      throw _handleDioError(e);
    }
  }

  /// GET /surah/{number}/{edition} - Détail d'une sourate avec traduction
  Future<SurahDetailModel> getSurahDetail(
    int surahNumber, {
    String edition = 'quran-madinah',
    String? translationEdition,
  }) async {
    final cacheKey = translationEdition != null
        ? 'surah_${surahNumber}_${edition}_$translationEdition'
        : 'surah_${surahNumber}_$edition';

    // 1. Vérifier cache mémoire d'abord (le plus rapide)
    final memoryCached = _memoryCache.get<SurahDetailModel>(cacheKey);
    if (memoryCached != null) {
      debugPrint('⚡ Returning memory-cached surah $surahNumber');
      return memoryCached;
    }

    // 2. Vérifier cache Hive (persistant)
    final cached = _cacheService.getIfValid<SurahDetailModel>(
      cacheKey,
      (data) => SurahDetailModel.fromJson(data),
    );

    if (cached != null) {
      debugPrint('📦 Returning Hive-cached surah $surahNumber');
      // Mettre aussi en cache mémoire pour les prochaines fois
      _memoryCache.put(
        cacheKey,
        cached,
        expiry: CacheService.staticContentDuration,
      );
      return cached;
    }

    try {
      // Récupérer le texte arabe
      final arabicResponse = await _dio.get('/surah/$surahNumber/$edition');

      if (arabicResponse.statusCode != 200) {
        throw ServerException('Failed to fetch surah detail');
      }

      final arabicData = arabicResponse.data as Map<String, dynamic>;
      final surahData = arabicData['data'] as Map<String, dynamic>;

      // Si une traduction est demandée, la récupérer
      if (translationEdition != null) {
        try {
          final translationResponse = await _dio.get(
            '/surah/$surahNumber/$translationEdition',
          );

          if (translationResponse.statusCode == 200) {
            final translationData =
                translationResponse.data as Map<String, dynamic>;
            final translationAyahs = (translationData['data']['ayahs'] as List);

            // Fusionner les traductions avec le texte arabe
            final arabicAyahs = surahData['ayahs'] as List;
            for (int i = 0; i < arabicAyahs.length; i++) {
              if (i < translationAyahs.length) {
                arabicAyahs[i]['translation'] = translationAyahs[i]['text'];
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to fetch translation: $e');
          // Continue sans traduction si erreur
        }
      }

      final surahDetail = SurahDetailModel.fromJson(surahData);

      // Cache Hive (persistant)
      await _cacheService.saveWithExpiry(
        cacheKey,
        surahDetail.toJson(),
        duration: CacheService.staticContentDuration,
      );

      // Cache mémoire (ultra-rapide)
      _memoryCache.put(
        cacheKey,
        surahDetail,
        expiry: CacheService.staticContentDuration,
      );

      return surahDetail;
    } on DioException catch (e) {
      // Fallback
      final staleCache = _cacheService.getStale<SurahDetailModel>(
        cacheKey,
        (data) => SurahDetailModel.fromJson(data),
      );

      if (staleCache != null) {
        debugPrint('⚠️ Using stale cache for surah $surahNumber');
        // Mettre en cache mémoire aussi
        _memoryCache.put(
          cacheKey,
          staleCache,
          expiry: CacheService.staticContentDuration,
        );
        return staleCache;
      }

      throw _handleDioError(e);
    }
  }

  /// GET /search/{query}/{surah}/{edition} - Recherche dans le Quran
  Future<List<AyahModel>> searchAyahs(
    String query, {
    String edition = 'quran-simple',
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _dio.get('/search/$query/all/$edition');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final matches = data['data']?['matches'] as List?;

        if (matches == null) return [];

        return matches
            .map((e) => AyahModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Search error: ${e.message}');
      return [];
    }
  }

  /// Éditions script (Tanzil uniquement) — plus d'appel api.alquran.cloud.
  static List<EditionModel> get defaultQuranEditions => [
        EditionModel(
          identifier: 'quran-uthmani',
          language: 'ar',
          name: 'Uthmani',
          englishName: 'Uthmani (Tanzil)',
          format: 'text',
          type: 'quran',
        ),
        EditionModel(
          identifier: 'quran-madinah',
          language: 'ar',
          name: 'Madinah',
          englishName: 'Madinah (Tanzil)',
          format: 'text',
          type: 'quran',
        ),
      ];

  /// Éditions traduction (liste statique, compatible Tanzil) — plus d'appel api.alquran.cloud.
  static List<EditionModel> get defaultTranslationEditions {
    final list = <EditionModel>[];
    for (final category in AvailableTranslations.all.values) {
      for (final t in category) {
        final lang = t['language'] ?? 'en';
        final name = t['name'] ?? t['id'] ?? '';
        list.add(EditionModel(
          identifier: t['id'] ?? '',
          language: lang,
          name: name,
          englishName: name,
          format: 'text',
          type: 'translation',
        ));
      }
    }
    return list;
  }

  /// Éditions (Tanzil / liste statique uniquement). Aucun appel à api.alquran.cloud.
  Future<List<EditionModel>> getEditions({String type = 'translation'}) async {
    if (type == 'quran') {
      return defaultQuranEditions;
    }
    return defaultTranslationEditions;
  }

  /// Gestion centralisée des erreurs Dio
  Exception _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return TimeoutException();

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 404) {
          return NotFoundException('Ressource non trouvée');
        } else if (statusCode == 500) {
          return ServerException('Erreur serveur', statusCode: statusCode);
        }
        return ServerException(
          'Mauvaise réponse: ${error.response?.data}',
          statusCode: statusCode,
        );

      case DioExceptionType.connectionError:
        return NetworkException(
          'Impossible de se connecter. Vérifiez votre connexion internet.',
        );

      case DioExceptionType.cancel:
        return NetworkException('Requête annulée');

      case DioExceptionType.unknown:
        return NetworkException('Erreur inconnue: ${error.message}');

      default:
        return NetworkException('Erreur inattendue: ${error.message}');
    }
  }
}
