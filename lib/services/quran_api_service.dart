import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import '../core/exceptions/api_exceptions.dart';
import '../models/quran_models.dart';
import 'cache_service.dart';
import 'package:hive/hive.dart';

/// Service API pour Al-Quran Cloud
class QuranApiService {
  static const String baseUrl = 'https://api.alquran.cloud/v1';
  static const Duration timeout = Duration(seconds: 30);

  final Dio _dio;
  late final CacheService _cacheService;

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

    // Vérifier cache d'abord
    final cached = _cacheService.getIfValid<List>(
      cacheKey,
      (data) => (data as List).map((e) => SurahModel.fromJson(e)).toList(),
    );

    if (cached != null) {
      debugPrint('📦 Returning cached surahs');
      return cached as List<SurahModel>;
    }

    try {
      final response = await _dio.get('/surah');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final surahs = (data['data'] as List)
            .map((e) => SurahModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // Sauvegarder en cache
        await _cacheService.saveWithExpiry(
          cacheKey,
          surahs.map((e) => e.toJson()).toList(),
          duration: CacheService.staticContentDuration,
        );

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

    // Vérifier cache
    final cached = _cacheService.getIfValid<SurahDetailModel>(
      cacheKey,
      (data) => SurahDetailModel.fromJson(data),
    );

    if (cached != null) {
      debugPrint('📦 Returning cached surah $surahNumber');
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

      // Cache
      await _cacheService.saveWithExpiry(
        cacheKey,
        surahDetail.toJson(),
        duration: CacheService.staticContentDuration,
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

  /// GET /edition/type/translation - Récupère les traductions disponibles
  Future<List<EditionModel>> getEditions({String type = 'translation'}) async {
    final cacheKey = 'editions_$type';

    // Cache
    final cached = _cacheService.getIfValid<List>(
      cacheKey,
      (data) => (data as List).map((e) => EditionModel.fromJson(e)).toList(),
    );

    if (cached != null) {
      return cached as List<EditionModel>;
    }

    try {
      final response = await _dio.get('/edition/type/$type');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final editions = (data['data'] as List)
            .map((e) => EditionModel.fromJson(e as Map<String, dynamic>))
            .toList();

        await _cacheService.saveWithExpiry(
          cacheKey,
          editions.map((e) => e.toJson()).toList(),
          duration: CacheService.staticContentDuration,
        );

        return editions;
      }
      throw ServerException('Failed to fetch editions');
    } on DioException catch (e) {
      final staleCache = _cacheService.getStale<List>(
        cacheKey,
        (data) => (data as List).map((e) => EditionModel.fromJson(e)).toList(),
      );

      if (staleCache != null) {
        return staleCache as List<EditionModel>;
      }

      throw _handleDioError(e);
    }
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
