import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import '../core/exceptions/api_exceptions.dart';
import 'cache_service.dart';
import 'memory_cache_service.dart';
import 'package:hive/hive.dart';

/// Modèle pour une Dua/Hadith du jour
class DuaModel {
  final String arabic;
  final String? transliteration;
  final String translation;
  final String? source; // e.g., "Sahih Al-Bukhari", "Sunan Abu Dawud"
  final String? reference; // e.g., "Book 2, Hadith 123"
  final String? category; // e.g., "supplication", "prayer", "remembrance"

  DuaModel({
    required this.arabic,
    this.transliteration,
    required this.translation,
    this.source,
    this.reference,
    this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'arabic': arabic,
      'transliteration': transliteration,
      'translation': translation,
      'source': source,
      'reference': reference,
      'category': category,
    };
  }

  factory DuaModel.fromJson(Map<String, dynamic> json) {
    return DuaModel(
      arabic: json['arabic'] as String? ?? '',
      transliteration: json['transliteration'] as String?,
      translation: json['translation'] as String? ?? '',
      source: json['source'] as String?,
      reference: json['reference'] as String?,
      category: json['category'] as String?,
    );
  }
}

/// Service API pour récupérer les Duas du jour
/// Utilise hadith-api (fawazahmed0) et fitrahive/dua-dhikr
class DuasApiService {
  // API principale: hadith-api (très fiable)
  static const String hadithApiBaseUrl = 'https://api.hadith.gading.dev';

  // API secondaire: fitrahive dua-dhikr (si self-hosted disponible)
  static const String duaApiBaseUrl = 'https://api.duadhikr.com';

  static const Duration timeout = Duration(seconds: 30);

  final Dio _dio;
  late final CacheService _cacheService;
  final MemoryCacheService _memoryCache = MemoryCacheService();

  DuasApiService({Dio? dio}) : _dio = dio ?? _initDio() {
    _initCache();
  }

  void _initCache() async {
    try {
      final box = Hive.box(CacheService.settingsBox);
      _cacheService = CacheService(box);
    } catch (e) {
      debugPrint('⚠️ Error initializing DuasApiService cache: $e');
    }
  }

  static Dio _initDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: hadithApiBaseUrl,
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
          debugPrint('🌐 Dua API Request: ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('✅ Dua API Response: ${response.statusCode}');
          return handler.next(response);
        },
        onError: (error, handler) {
          debugPrint('❌ Dua API Error: ${error.message}');
          return handler.next(error);
        },
      ),
    );

    // Retry interceptor
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

  /// Récupère une Dua/Hadith aléatoire depuis hadith-api
  /// Utilise un index basé sur la date pour garantir la même dua le même jour
  Future<DuaModel> getDuaOfTheDay({String? language}) async {
    final today = DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;
    final cacheKey =
        'dua_of_day:${today.toIso8601String().split('T')[0]}:${language ?? 'fr'}';

    // 1. Vérifier cache mémoire
    final memoryCached = _memoryCache.get<DuaModel>(cacheKey);
    if (memoryCached != null) {
      debugPrint('⚡ Returning memory-cached dua');
      return memoryCached;
    }

    // 2. Vérifier cache Hive (persistant pour la journée)
    final cached = _cacheService.getIfValid<DuaModel>(
      cacheKey,
      (data) => DuaModel.fromJson(data as Map<String, dynamic>),
    );

    if (cached != null) {
      debugPrint('📦 Returning Hive-cached dua');
      _memoryCache.put(cacheKey, cached);
      return cached;
    }

    try {
      // Essayer hadith-api en premier (plus fiable)
      final dua = await _getFromHadithApi(
        dayOfYear,
        language: language ?? 'fr',
      );

      // Sauvegarder en cache
      await _cacheService.saveWithExpiry(
        cacheKey,
        dua.toJson(),
        duration: const Duration(hours: 24), // Cache pour la journée
      );

      _memoryCache.put(cacheKey, dua);

      return dua;
    } catch (e) {
      debugPrint('⚠️ Error fetching dua from API: $e');
      // Fallback sur du'as locales en cas d'erreur
      return _getFallbackDua(dayOfYear);
    }
  }

  /// Récupère un hadith depuis hadith-api
  /// Utilise une collection et un index basé sur la date pour la cohérence
  Future<DuaModel> _getFromHadithApi(
    int dayIndex, {
    String language = 'fr',
  }) async {
    // Collections disponibles: 'bukhari', 'muslim', 'abudawud', 'tirmidhi', 'nasai', 'ibnmajah'
    final collections = ['bukhari', 'muslim', 'abudawud', 'tirmidhi'];
    final collection = collections[dayIndex % collections.length];

    // Utiliser un nombre aléatoire basé sur la date pour la cohérence
    final randomSeed = dayIndex * 37; // Multiplier pour avoir plus de variation

    try {
      // hadith-api endpoint: /books/{collection}?range=1-7000
      // Pour obtenir un hadith spécifique, on peut utiliser un index
      final response = await _dio.get(
        '/books/$collection',
        queryParameters: {'range': '1-7000'},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final hadiths = data['data'] as Map<String, dynamic>?;

        if (hadiths != null && hadiths.containsKey('hadiths')) {
          final hadithList = hadiths['hadiths'] as List;
          if (hadithList.isNotEmpty) {
            // Sélectionner un hadith basé sur l'index du jour
            final hadithIndex = randomSeed % hadithList.length;
            final hadith = hadithList[hadithIndex] as Map<String, dynamic>;

            final arabicText = hadith['arabic'] as String? ?? '';
            final number = hadith['number'] as int?;

            // Récupérer la traduction
            String translation = arabicText; // Fallback
            if (hadith.containsKey('id')) {
              // Essayer de récupérer la traduction depuis l'endpoint de traduction
              try {
                final transResponse = await _dio.get(
                  '/books/$collection/$number/id',
                  queryParameters: {'lang': language},
                );
                if (transResponse.statusCode == 200) {
                  final transData = transResponse.data as Map<String, dynamic>;
                  final transHadiths =
                      transData['data'] as Map<String, dynamic>?;
                  if (transHadiths != null &&
                      transHadiths.containsKey('contents')) {
                    final contents =
                        transHadiths['contents'] as Map<String, dynamic>?;
                    translation = contents?[language] as String? ?? arabicText;
                  }
                }
              } catch (e) {
                debugPrint('⚠️ Could not fetch translation: $e');
              }
            }

            return DuaModel(
              arabic: arabicText,
              translation: translation,
              source: _getCollectionName(collection),
              reference: 'Hadith ${number ?? 'N/A'}',
              category: 'hadith',
            );
          }
        }
      }

      throw ServerException('No hadith data found');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 500) {
        throw ServerException('Hadith API unavailable');
      }
      throw NetworkException('Failed to fetch hadith: ${e.message}');
    }
  }

  String _getCollectionName(String collection) {
    switch (collection) {
      case 'bukhari':
        return 'Sahih Al-Bukhari';
      case 'muslim':
        return 'Sahih Muslim';
      case 'abudawud':
        return 'Sunan Abu Dawud';
      case 'tirmidhi':
        return 'Sunan At-Tirmidhi';
      case 'nasai':
        return 'Sunan An-Nasai';
      case 'ibnmajah':
        return 'Sunan Ibn Majah';
      default:
        return 'Hadith';
    }
  }

  /// Fallback: Du'as locales en cas d'erreur réseau
  DuaModel _getFallbackDua(int dayIndex) {
    final duas = [
      DuaModel(
        arabic:
            'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
        transliteration:
            'Rabbanā ātinā fīd-dunyā ḥasanatan wa fīl-ākhirati ḥasanatan wa qinā \'adhāban-nār',
        translation:
            'Seigneur ! Accorde-nous le bien ici-bas et le bien dans l\'au-delà, et préserve-nous du châtiment du Feu.',
        source: 'Sourate Al-Baqarah',
        reference: 'Verset 201',
        category: 'quranic',
      ),
      DuaModel(
        arabic:
            'وَمَا تَوْفِيقِي إِلَّا بِاللَّهِ عَلَيْهِ تَوَكَّلْتُ وَإِلَيْهِ أُنِيبُ',
        transliteration:
            'Wa mā tawfīqī illā billāh, \'alayhi tawakkaltu wa ilayhi unīb',
        translation:
            'Ma réussite ne dépend que d\'Allah. C\'est en Lui que je place ma confiance et c\'est vers Lui que je reviens repentant.',
        source: 'Sourate Houd',
        reference: 'Verset 88',
        category: 'quranic',
      ),
      DuaModel(
        arabic: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ',
        transliteration: 'Allāhumma innī a\'ūdhu bika minal-hammi wal-ḥazan',
        translation:
            'Ô Allah, je cherche refuge auprès de Toi contre l\'anxiété et la tristesse.',
        source: 'Sahih Al-Bukhari',
        reference: 'Hadith 2893',
        category: 'supplication',
      ),
      DuaModel(
        arabic: 'مَنْ أَحَبَّ لِقَاءَ اللَّهِ أَحَبَّ اللَّهُ لِقَاءَهُ',
        transliteration: 'Man aḥabba liqā\'a Llāh, aḥabba Llāh liqā\'ahu',
        translation:
            'Celui qui aime rencontrer Allah, Allah aime le rencontrer.',
        source: 'Sahih Al-Bukhari',
        reference: 'Hadith 6507',
        category: 'hadith',
      ),
    ];

    return duas[dayIndex % duas.length];
  }

  /// Récupère une liste de du'as par catégorie
  Future<List<DuaModel>> getDuasByCategory(String category) async {
    // TODO: Implémenter si l'API le permet
    return [];
  }

  /// Recherche de du'as
  Future<List<DuaModel>> searchDuas(String query) async {
    // TODO: Implémenter si l'API le permet
    return [];
  }
}
