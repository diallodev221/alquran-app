/// Traductions disponibles pour le Quran
class AvailableTranslations {
  /// Traductions françaises
  static const List<Map<String, String>> french = [
    {
      'id': 'fr.hamidullah',
      'name': 'Muhammad Hamidullah',
      'language': 'Français',
      'description': 'Traduction classique et respectée',
    },
    {
      'id': 'fr.montada',
      'name': 'IslamWeb Montada',
      'language': 'Français',
      'description': 'Traduction moderne',
    },
  ];

  /// Traductions anglaises
  static const List<Map<String, String>> english = [
    {
      'id': 'en.asad',
      'name': 'Muhammad Asad',
      'language': 'English',
      'description': 'The Message of The Quran',
    },
    {
      'id': 'en.sahih',
      'name': 'Saheeh International',
      'language': 'English',
      'description': 'Clear and modern',
    },
    {
      'id': 'en.yusufali',
      'name': 'Abdullah Yusuf Ali',
      'language': 'English',
      'description': 'Classical translation',
    },
    {
      'id': 'en.pickthall',
      'name': 'Mohammed Marmaduke Pickthall',
      'language': 'English',
      'description': 'The Meaning of the Glorious Quran',
    },
  ];

  /// Traductions arabes (texte simple)
  static const List<Map<String, String>> arabic = [
    {
      'id': 'quran-simple',
      'name': 'القرآن الكريم',
      'language': 'العربية',
      'description': 'Texte arabe simple',
    },
    {
      'id': 'ar.muyassar',
      'name': 'تفسير المیسر',
      'language': 'العربية',
      'description': 'Tafsir simplifié',
    },
  ];

  /// Autres langues
  static const List<Map<String, String>> other = [
    {
      'id': 'ur.jalandhry',
      'name': 'Fateh Muhammad Jalandhry',
      'language': 'Urdu',
      'description': 'اردو ترجمہ',
    },
    {
      'id': 'id.indonesian',
      'name': 'Indonesian Ministry of Religious Affairs',
      'language': 'Indonesian',
      'description': 'Kementerian Agama',
    },
    {
      'id': 'tr.diyanet',
      'name': 'Diyanet İşleri',
      'language': 'Turkish',
      'description': 'Türkçe',
    },
    {
      'id': 'es.cortes',
      'name': 'Julio Cortes',
      'language': 'Spanish',
      'description': 'Español',
    },
    {
      'id': 'de.bubenheim',
      'name': 'A. S. F. Bubenheim and N. Elyas',
      'language': 'German',
      'description': 'Deutsch',
    },
  ];

  /// Toutes les traductions par catégorie
  static Map<String, List<Map<String, String>>> get all => {
        'Français': french,
        'English': english,
        'العربية': arabic,
        'Autres': other,
      };

  /// Traduction par défaut
  static const String defaultTranslation = 'fr.hamidullah';

  /// Récupère le nom d'une traduction par son ID
  static String getName(String id) {
    for (final category in all.values) {
      for (final translation in category) {
        if (translation['id'] == id) {
          return translation['name']!;
        }
      }
    }
    return id;
  }
}

