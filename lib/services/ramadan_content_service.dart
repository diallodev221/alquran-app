import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:hijri_date_time/hijri_date_time.dart';

/// Service pour gérer le contenu Ramadan (facts, citations, etc.)
class RamadanContentService {
  static final RamadanContentService _instance = RamadanContentService._internal();
  factory RamadanContentService() => _instance;
  RamadanContentService._internal();

  static const String _contentBoxName = 'ramadan_content';
  Box<dynamic>? _box;

  /// Initialiser le service
  Future<void> init() async {
    try {
      _box = await Hive.openBox(_contentBoxName);
    } catch (e) {
      debugPrint('⚠️ Error initializing RamadanContentService: $e');
    }
  }

  /// Obtenir un fait Ramadan du jour (déterministe)
  Future<Map<String, dynamic>> getRamadanFactOfTheDay() async {
    if (_box == null) await init();

    final hijriDate = HijriDateTime.now();
    final ramadanDay = hijriDate.month == 9 ? hijriDate.day : 1;
    
    final cacheKey = 'ramadan_fact:$ramadanDay';
    
    // Vérifier le cache
    final cached = _box?.get(cacheKey) as Map<dynamic, dynamic>?;
    if (cached != null) {
      return Map<String, dynamic>.from(cached);
    }

    // Sélectionner un fait basé sur le jour (déterministe)
    final fact = _getRamadanFactByDay(ramadanDay);
    
    // Sauvegarder en cache
    await _box?.put(cacheKey, fact);
    
    return fact;
  }

  /// Obtenir une citation de cheikh du jour (déterministe)
  Future<Map<String, dynamic>> getScholarQuoteOfTheDay() async {
    if (_box == null) await init();

    final today = DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;
    
    final cacheKey = 'scholar_quote:${today.toIso8601String().split('T')[0]}';
    
    // Vérifier le cache
    final cached = _box?.get(cacheKey) as Map<dynamic, dynamic>?;
    if (cached != null) {
      return Map<String, dynamic>.from(cached);
    }

    // Sélectionner une citation basée sur le jour (déterministe)
    final quote = _getScholarQuoteByDay(dayOfYear);
    
    // Sauvegarder en cache
    await _box?.put(cacheKey, quote);
    
    return quote;
  }

  /// Obtenir un fait Ramadan par jour
  Map<String, dynamic> _getRamadanFactByDay(int day) {
    final facts = [
      {
        'title': 'Le mois béni',
        'content': 'Ramadan est le 9ème mois du calendrier lunaire islamique. C\'est le mois où le Coran a été révélé au Prophète Muhammad (PSL).',
        'source': 'Sourate Al-Baqarah, verset 185',
      },
      {
        'title': 'Les trois Ashras',
        'content': 'Ramadan est divisé en trois périodes de 10 jours : Rahma (Miséricorde), Maghfira (Pardon), et Itq min an-Nar (Salut du Feu).',
        'source': 'Hadith',
      },
      {
        'title': 'Laylat al-Qadr',
        'content': 'La Nuit du Destin (Laylat al-Qadr) est meilleure que 1000 mois. Elle se trouve dans les 10 derniers jours impairs de Ramadan.',
        'source': 'Sourate Al-Qadr',
      },
      {
        'title': 'Le jeûne',
        'content': 'Le jeûne (Sawm) est l\'un des cinq piliers de l\'Islam. Il consiste à s\'abstenir de manger, boire et relations intimes de l\'aube au coucher du soleil.',
        'source': 'Sourate Al-Baqarah, verset 183',
      },
      {
        'title': 'Zakat al-Fitr',
        'content': 'Zakat al-Fitr est une aumône obligatoire à la fin du Ramadan, avant la prière de l\'Aïd. Elle purifie le jeûne et aide les nécessiteux.',
        'source': 'Hadith',
      },
      {
        'title': 'Iftar et Suhoor',
        'content': 'Le Suhoor (repas avant l\'aube) et l\'Iftar (rupture du jeûne) sont des moments bénis. Le Prophète (PSL) recommandait de retarder le Suhoor et hâter l\'Iftar.',
        'source': 'Hadith',
      },
      {
        'title': 'Le Coran en Ramadan',
        'content': 'Le Prophète (PSL) récitait le Coran plus fréquemment pendant Ramadan. L\'ange Jibril le révisait avec lui chaque année ce mois-là.',
        'source': 'Sahih Al-Bukhari',
      },
      {
        'title': 'Les portes du Paradis',
        'content': 'Pendant Ramadan, les portes du Paradis sont ouvertes, les portes de l\'Enfer sont fermées, et les démons sont enchaînés.',
        'source': 'Sahih Al-Bukhari',
      },
      {
        'title': 'La récompense',
        'content': 'Chaque bonne action en Ramadan est multipliée. Le jeûne est une protection et une expiation des péchés.',
        'source': 'Sahih Muslim',
      },
      {
        'title': 'La patience',
        'content': 'Le jeûne enseigne la patience, la discipline et la gratitude. C\'est un mois de purification spirituelle et de rapprochement d\'Allah.',
        'source': 'Hadith',
      },
    ];

    return facts[(day - 1) % facts.length];
  }

  /// Obtenir une citation de cheikh par jour
  Map<String, dynamic> _getScholarQuoteByDay(int dayOfYear) {
    final quotes = [
      {
        'content': 'Le jeûne n\'est pas seulement s\'abstenir de manger et de boire. C\'est surtout s\'abstenir de tout ce qui peut souiller l\'âme.',
        'author': 'Cheikh Ahmadou Bamba',
        'source': 'Muridiyya',
      },
      {
        'content': 'Ramadan est une école de discipline. Il nous apprend à maîtriser nos désirs et à nous rapprocher de notre Créateur.',
        'author': 'Cheikh Al-Ghazali',
        'source': 'Ihya Ulum al-Din',
      },
      {
        'content': 'Le vrai jeûne est celui du cœur, pas seulement celui de l\'estomac. Jeûnez des péchés comme vous jeûnez de la nourriture.',
        'author': 'Imam Al-Nawawi',
        'source': 'Riyad as-Salihin',
      },
      {
        'content': 'Ramadan est le mois de la générosité. Donnez plus, priez plus, lisez plus le Coran. C\'est votre chance de transformation.',
        'author': 'Cheikh Ibn Taymiyyah',
        'source': 'Majmu\' al-Fatawa',
      },
      {
        'content': 'Le jeûne est un bouclier. Protégez votre jeûne en évitant les disputes, les mensonges et les mauvaises paroles.',
        'author': 'Imam Malik',
        'source': 'Muwatta',
      },
      {
        'content': 'Pendant Ramadan, multipliez vos invocations. C\'est le moment où Allah répond le plus aux supplications de Ses serviteurs.',
        'author': 'Cheikh Ibn Qayyim',
        'source': 'Zad al-Ma\'ad',
      },
      {
        'content': 'Le jeûne purifie le corps et l\'âme. Il nous rappelle notre dépendance envers Allah et notre gratitude pour Ses bienfaits.',
        'author': 'Cheikh Al-Suyuti',
        'source': 'Tafsir al-Jalalayn',
      },
      {
        'content': 'Ramadan est un mois de miséricorde. Soyez miséricordieux envers les autres, et Allah sera miséricordieux envers vous.',
        'author': 'Imam Al-Shafi\'i',
        'source': 'Al-Umm',
      },
    ];

    return quotes[dayOfYear % quotes.length];
  }
}
