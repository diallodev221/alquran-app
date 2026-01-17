import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:hijri_date_time/hijri_date_time.dart';

/// Phases du Ramadan
enum RamadanPhase {
  early, // jours 1-10
  middle, // jours 11-20
  last10, // jours 21-30
}

/// Fenêtres temporelles
enum TimeWindow {
  night, // 00:00-04:00
  morning, // 04:00-12:00
  afternoon, // 12:00-17:00
  iftarWindow, // 17:00-20:00
  evening, // 20:00-00:00
}

/// Types de contenu pour la Daily Highlight Zone
enum DailyHighlightType {
  dua,
  ayah,
  xassida,
  khutba,
  ramadanFact,
  scholarQuote,
}

/// Types de bannières contextuelles
enum BannerType {
  iftarCountdown, // Critique
  suhoorReminder, // Critique
  prayerReminder, // Critique
  offlineSuggestion, // Suggestion
  zakatReminder, // Spirituel
  laylatAlQadr, // Spirituel
}

/// Priorité des bannières
enum BannerPriority {
  critical, // Iftar/Suhoor/Prayer
  spiritual, // Zakat/Laylat al-Qadr
  suggestion, // Offline download
}

/// Résultat de sélection de contenu
class ContentRotationResult {
  final DailyHighlightType highlightType;
  final String? bannerType;
  final BannerPriority? bannerPriority;
  final Map<String, dynamic>? metadata;

  ContentRotationResult({
    required this.highlightType,
    this.bannerType,
    this.bannerPriority,
    this.metadata,
  });
}

/// Service de rotation de contenu déterministe
class ContentRotationService {
  static final ContentRotationService _instance = ContentRotationService._internal();
  factory ContentRotationService() => _instance;
  ContentRotationService._internal();

  static const String _rotationBoxName = 'content_rotation';
  Box<dynamic>? _box;

  /// Initialiser le service
  Future<void> init() async {
    try {
      _box = await Hive.openBox(_rotationBoxName);
    } catch (e) {
      debugPrint('⚠️ Error initializing ContentRotationService: $e');
    }
  }

  /// Obtenir la phase du Ramadan
  RamadanPhase getRamadanPhase(HijriDateTime hijriDate) {
    if (hijriDate.month != 9) {
      // Si ce n'est pas Ramadan, utiliser une phase par défaut
      return RamadanPhase.middle;
    }

    final day = hijriDate.day;
    if (day <= 10) {
      return RamadanPhase.early;
    } else if (day <= 20) {
      return RamadanPhase.middle;
    } else {
      return RamadanPhase.last10;
    }
  }

  /// Obtenir la fenêtre temporelle actuelle
  TimeWindow getTimeWindow(DateTime now) {
    final hour = now.hour;
    if (hour >= 0 && hour < 4) {
      return TimeWindow.night;
    } else if (hour >= 4 && hour < 12) {
      return TimeWindow.morning;
    } else if (hour >= 12 && hour < 17) {
      return TimeWindow.afternoon;
    } else if (hour >= 17 && hour < 20) {
      return TimeWindow.iftarWindow;
    } else {
      return TimeWindow.evening;
    }
  }

  /// Obtenir le type de contenu pour aujourd'hui (déterministe)
  Future<DailyHighlightType> getTodayHighlight({
    required RamadanPhase phase,
    required TimeWindow window,
    String? userAffinity, // 'audio' ou 'text'
  }) async {
    if (_box == null) await init();

    final today = DateTime.now();
    final cacheKey = 'highlight:${today.toIso8601String().split('T')[0]}';

    // Vérifier si on a déjà sélectionné pour aujourd'hui
    final cached = _box?.get(cacheKey);
    if (cached != null) {
      return DailyHighlightType.values[cached as int];
    }

    // Sélectionner selon la matrice de règles
    final selectedType = _selectHighlightByMatrix(
      phase: phase,
      window: window,
      userAffinity: userAffinity,
      today: today,
    );

    // Vérifier la répétition (pas le même type qu'hier)
    final yesterdayType = await _getYesterdayHighlight();
    if (yesterdayType != null && selectedType == yesterdayType) {
      // Choisir une alternative dans le même groupe logique
      final alternative = _getAlternativeType(selectedType, phase, window);
      await _saveHighlight(cacheKey, alternative);
      return alternative;
    }

    await _saveHighlight(cacheKey, selectedType);
    return selectedType;
  }

  /// Matrice de sélection basée sur les règles
  DailyHighlightType _selectHighlightByMatrix({
    required RamadanPhase phase,
    required TimeWindow window,
    String? userAffinity,
    required DateTime today,
  }) {
    // Matrice de règles déterministe
    if (phase == RamadanPhase.early) {
      if (window == TimeWindow.morning) {
        return (today.day % 2 == 0) ? DailyHighlightType.dua : DailyHighlightType.ayah;
      } else if (window == TimeWindow.afternoon) {
        return DailyHighlightType.ramadanFact;
      } else if (window == TimeWindow.evening) {
        if (userAffinity == 'audio') {
          return DailyHighlightType.xassida;
        }
        return DailyHighlightType.dua;
      }
    } else if (phase == RamadanPhase.middle) {
      if (window == TimeWindow.morning) {
        return (today.day % 2 == 0) ? DailyHighlightType.ayah : DailyHighlightType.dua;
      } else if (window == TimeWindow.afternoon) {
        return DailyHighlightType.ramadanFact;
      } else if (window == TimeWindow.evening || window == TimeWindow.iftarWindow) {
        if (userAffinity == 'audio') {
          return DailyHighlightType.khutba;
        }
        return DailyHighlightType.scholarQuote;
      }
    } else if (phase == RamadanPhase.last10) {
      if (window == TimeWindow.night || window == TimeWindow.morning) {
        return DailyHighlightType.dua;
      } else if (window == TimeWindow.afternoon) {
        return DailyHighlightType.ayah;
      } else if (window == TimeWindow.evening) {
        if (userAffinity == 'audio') {
          return DailyHighlightType.xassida;
        }
        return DailyHighlightType.scholarQuote;
      }
    }

    // Par défaut
    return DailyHighlightType.dua;
  }

  /// Obtenir un type alternatif si répétition
  DailyHighlightType _getAlternativeType(
    DailyHighlightType type,
    RamadanPhase phase,
    TimeWindow window,
  ) {
    // Groupes logiques
    final spiritual = [DailyHighlightType.dua, DailyHighlightType.ayah];
    final audio = [DailyHighlightType.xassida, DailyHighlightType.khutba];
    final educational = [DailyHighlightType.ramadanFact, DailyHighlightType.scholarQuote];

    if (spiritual.contains(type)) {
      return spiritual.firstWhere((t) => t != type);
    } else if (audio.contains(type)) {
      return audio.firstWhere((t) => t != type);
    } else if (educational.contains(type)) {
      return educational.firstWhere((t) => t != type);
    }

    // Par défaut, retourner dua
    return DailyHighlightType.dua;
  }

  /// Obtenir le highlight d'hier
  Future<DailyHighlightType?> _getYesterdayHighlight() async {
    if (_box == null) return null;

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final cacheKey = 'highlight:${yesterday.toIso8601String().split('T')[0]}';
    final cached = _box?.get(cacheKey) as int?;

    if (cached != null) {
      return DailyHighlightType.values[cached];
    }
    return null;
  }

  /// Sauvegarder le highlight sélectionné
  Future<void> _saveHighlight(String key, DailyHighlightType type) async {
    if (_box == null) return;
    await _box!.put(key, type.index);
  }

  /// Obtenir la bannière contextuelle (priorité basée)
  Future<String?> getContextualBanner({
    required DateTime now,
    required bool hasPrayerTimes,
    DateTime? nextIftar,
    DateTime? nextSuhoor,
    DateTime? nextPrayer,
    bool? hasOfflineContent,
    int? ramadanDay,
    bool? reminderEnabled,
  }) async {
    if (_box == null) await init();

    // Vérifier les cooldowns et historique de rejet
    final dismissedBanners = await _getDismissedBanners();

    // 1. Vérifier les événements critiques
    if (nextIftar != null) {
      final minutesUntilIftar = nextIftar.difference(now).inMinutes;
      if (minutesUntilIftar <= 30 && minutesUntilIftar >= 0) {
        final bannerKey = 'iftar_countdown';
        if (!dismissedBanners.contains(bannerKey)) {
          return bannerKey;
        }
      }
    }

    if (nextSuhoor != null) {
      final minutesUntilSuhoor = nextSuhoor.difference(now).inMinutes;
      if (minutesUntilSuhoor <= 30 && minutesUntilSuhoor >= 15) {
        final bannerKey = 'suhoor_reminder';
        if (!dismissedBanners.contains(bannerKey) && !(reminderEnabled ?? false)) {
          return bannerKey;
        }
      }
    }

    if (nextPrayer != null) {
      final minutesUntilPrayer = nextPrayer.difference(now).inMinutes;
      if (minutesUntilPrayer <= 10 && minutesUntilPrayer >= 0) {
        final bannerKey = 'prayer_reminder';
        if (!dismissedBanners.contains(bannerKey)) {
          return bannerKey;
        }
      }
    }

    // 2. Vérifier Laylat al-Qadr (nuits impaires des 10 derniers jours)
    if (ramadanDay != null && ramadanDay >= 21) {
      if (now.hour >= 20 || now.hour < 4) {
        // Nuit impaire
        if (ramadanDay % 2 == 1) {
          final bannerKey = 'laylat_al_qadr';
          if (!dismissedBanners.contains(bannerKey)) {
            return bannerKey;
          }
        }
      }
    }

    // 3. Suggestions (seulement si pas d'événements critiques)
    if (hasOfflineContent == false) {
      final bannerKey = 'offline_suggestion';
      if (!dismissedBanners.contains(bannerKey)) {
        return bannerKey;
      }
    }

    // 4. Rappel Zakat (vers la fin du Ramadan)
    if (ramadanDay != null && ramadanDay >= 25) {
      final bannerKey = 'zakat_reminder';
      if (!dismissedBanners.contains(bannerKey)) {
        return bannerKey;
      }
    }

    return null;
  }

  /// Marquer une bannière comme rejetée
  Future<void> dismissBanner(String bannerKey) async {
    if (_box == null) await init();

    final today = DateTime.now();
    final dismissedKey = 'dismissed:$bannerKey:${today.toIso8601String().split('T')[0]}';
    await _box?.put(dismissedKey, true);

    // Nettoyer les rejets anciens (> 7 jours)
    _cleanOldDismissals();
  }

  /// Obtenir les bannières rejetées aujourd'hui
  Future<Set<String>> _getDismissedBanners() async {
    if (_box == null) return {};

    final today = DateTime.now();
    final dismissedPrefix = 'dismissed:';
    final todayStr = today.toIso8601String().split('T')[0];
    final dismissed = <String>{};

    for (final key in _box!.keys) {
      if (key is String && key.startsWith(dismissedPrefix) && key.contains(todayStr)) {
        final bannerKey = key.split(':')[1];
        dismissed.add(bannerKey);
      }
    }

    return dismissed;
  }

  /// Nettoyer les rejets anciens
  void _cleanOldDismissals() {
    if (_box == null) return;

    final today = DateTime.now();
    final keysToDelete = <String>[];

    for (final key in _box!.keys) {
      if (key is String && key.startsWith('dismissed:')) {
        try {
          final parts = key.split(':');
          if (parts.length >= 3) {
            final dateStr = parts[2];
            final date = DateTime.parse(dateStr);
            if (today.difference(date).inDays > 7) {
              keysToDelete.add(key);
            }
          }
        } catch (e) {
          // Invalid date format, skip
        }
      }
    }

    for (final key in keysToDelete) {
      _box!.delete(key);
    }
  }

  /// Obtenir la priorité d'une bannière
  BannerPriority getBannerPriority(String bannerKey) {
    if (['iftar_countdown', 'suhoor_reminder', 'prayer_reminder'].contains(bannerKey)) {
      return BannerPriority.critical;
    } else if (['zakat_reminder', 'laylat_al_qadr'].contains(bannerKey)) {
      return BannerPriority.spiritual;
    } else {
      return BannerPriority.suggestion;
    }
  }

  /// Obtenir le nom d'affichage d'un type de highlight
  String getHighlightDisplayName(DailyHighlightType type) {
    switch (type) {
      case DailyHighlightType.dua:
        return 'Du\'a du jour';
      case DailyHighlightType.ayah:
        return 'Ayah du jour';
      case DailyHighlightType.xassida:
        return 'Xassida du jour';
      case DailyHighlightType.khutba:
        return 'Khutba du jour';
      case DailyHighlightType.ramadanFact:
        return 'Ramadan fact';
      case DailyHighlightType.scholarQuote:
        return 'Citation du jour';
    }
  }

  /// Obtenir l'icône d'un type de highlight
  String getHighlightIcon(DailyHighlightType type) {
    switch (type) {
      case DailyHighlightType.dua:
        return 'favorite';
      case DailyHighlightType.ayah:
        return 'menu_book';
      case DailyHighlightType.xassida:
        return 'music_note';
      case DailyHighlightType.khutba:
        return 'record_voice_over';
      case DailyHighlightType.ramadanFact:
        return 'lightbulb_outline';
      case DailyHighlightType.scholarQuote:
        return 'format_quote';
    }
  }

  /// Réinitialiser pour debug
  Future<void> reset() async {
    if (_box == null) return;
    await _box!.clear();
  }
}
