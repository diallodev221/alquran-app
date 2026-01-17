import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'user_behavior_service.dart';

/// Priorités de sections pour la personnalisation
enum SectionPriority {
  high, // Toujours afficher en haut
  medium, // Affichage normal
  low, // Réduire ou masquer
}

/// Configuration de personnalisation
class PersonalizationConfig {
  final SectionPriority spiritualContentPriority;
  final SectionPriority quickActionsPriority;
  final SectionPriority momentOfDayPriority;
  final bool showContextualSuggestions;
  final String? preferredAudioType; // 'quran', 'xassida', null
  final String? preferredQuranTime; // 'fajr', 'dhuhr', etc.
  final double reminderFrequencyMultiplier; // 0.0 - 1.0, réduit la fréquence si < 1.0

  PersonalizationConfig({
    this.spiritualContentPriority = SectionPriority.medium,
    this.quickActionsPriority = SectionPriority.medium,
    this.momentOfDayPriority = SectionPriority.medium,
    this.showContextualSuggestions = true,
    this.preferredAudioType,
    this.preferredQuranTime,
    this.reminderFrequencyMultiplier = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'spiritualContentPriority': spiritualContentPriority.index,
      'quickActionsPriority': quickActionsPriority.index,
      'momentOfDayPriority': momentOfDayPriority.index,
      'showContextualSuggestions': showContextualSuggestions,
      'preferredAudioType': preferredAudioType,
      'preferredQuranTime': preferredQuranTime,
      'reminderFrequencyMultiplier': reminderFrequencyMultiplier,
    };
  }

  factory PersonalizationConfig.fromJson(Map<String, dynamic> json) {
    return PersonalizationConfig(
      spiritualContentPriority: SectionPriority.values[
        json['spiritualContentPriority'] ?? SectionPriority.medium.index
      ],
      quickActionsPriority: SectionPriority.values[
        json['quickActionsPriority'] ?? SectionPriority.medium.index
      ],
      momentOfDayPriority: SectionPriority.values[
        json['momentOfDayPriority'] ?? SectionPriority.medium.index
      ],
      showContextualSuggestions: json['showContextualSuggestions'] ?? true,
      preferredAudioType: json['preferredAudioType'],
      preferredQuranTime: json['preferredQuranTime'],
      reminderFrequencyMultiplier: (json['reminderFrequencyMultiplier'] ?? 1.0).toDouble(),
    );
  }
}

/// Service pour gérer la personnalisation basée sur le comportement
class PersonalizationService {
  static final PersonalizationService _instance = PersonalizationService._internal();
  factory PersonalizationService() => _instance;
  PersonalizationService._internal();

  static const String _configKey = 'personalization_config';
  Box<dynamic>? _box;
  final UserBehaviorService _behaviorService = UserBehaviorService();

  /// Initialiser le service
  Future<void> init() async {
    try {
      _box = await Hive.openBox('personalization');
    } catch (e) {
      debugPrint('⚠️ Error initializing PersonalizationService: $e');
    }
  }

  /// Analyser le comportement et mettre à jour la configuration
  Future<PersonalizationConfig> analyzeAndUpdate() async {
    final currentConfig = await getConfig();

    // Analyser les préférences audio
    final mostPlayedAudio = await _behaviorService.getMostPlayedAudioType(days: 7);
    
    // Analyser le moment préféré pour le Quran
    final preferredQuranTime = await _behaviorService.getPreferredQuranTime(days: 14);
    
    // Analyser le taux de rejet des rappels
    final dismissalRate = await _behaviorService.getReminderDismissalRate(days: 7);

    // Calculer les priorités
    final spiritualContentPriority = _calculateSpiritualContentPriority(mostPlayedAudio);
    final quickActionsPriority = _calculateQuickActionsPriority();
    final reminderMultiplier = _calculateReminderMultiplier(dismissalRate);

    final newConfig = PersonalizationConfig(
      spiritualContentPriority: spiritualContentPriority,
      quickActionsPriority: quickActionsPriority,
      momentOfDayPriority: SectionPriority.high, // Toujours important
      showContextualSuggestions: currentConfig.showContextualSuggestions,
      preferredAudioType: mostPlayedAudio ?? currentConfig.preferredAudioType,
      preferredQuranTime: preferredQuranTime ?? currentConfig.preferredQuranTime,
      reminderFrequencyMultiplier: reminderMultiplier,
    );

    await saveConfig(newConfig);
    return newConfig;
  }

  SectionPriority _calculateSpiritualContentPriority(String? audioType) {
    if (audioType == 'xassida' || audioType == 'khutba') {
      return SectionPriority.high;
    }
    if (audioType == 'quran') {
      return SectionPriority.medium;
    }
    return SectionPriority.medium;
  }

  SectionPriority _calculateQuickActionsPriority() {
    // Toujours moyenne pour les actions rapides
    return SectionPriority.medium;
  }

  double _calculateReminderMultiplier(double dismissalRate) {
    // Si l'utilisateur ignore > 50% des rappels, réduire la fréquence
    if (dismissalRate > 0.5) {
      return 0.5; // 50% moins fréquent
    }
    if (dismissalRate > 0.3) {
      return 0.7; // 30% moins fréquent
    }
    return 1.0; // Fréquence normale
  }

  /// Sauvegarder la configuration
  Future<void> saveConfig(PersonalizationConfig config) async {
    if (_box == null) return;

    try {
      await _box!.put(_configKey, config.toJson());
    } catch (e) {
      debugPrint('⚠️ Error saving personalization config: $e');
    }
  }

  /// Obtenir la configuration actuelle
  Future<PersonalizationConfig> getConfig() async {
    if (_box == null) {
      return PersonalizationConfig();
    }

    try {
      final data = _box!.get(_configKey) as Map<dynamic, dynamic>?;
      if (data != null) {
        return PersonalizationConfig.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      debugPrint('⚠️ Error getting personalization config: $e');
    }

    return PersonalizationConfig();
  }

  /// Vérifier si une suggestion contextuelle doit être affichée
  Future<bool> shouldShowContextualSuggestion(String suggestionType, DateTime now) async {
    final config = await getConfig();
    if (!config.showContextualSuggestions) return false;

    // Vérifier le moment préféré pour le Quran
    if (suggestionType == 'quran' && config.preferredQuranTime != null) {
      // Logique pour vérifier si on est proche de l'heure préférée
      final hour = now.hour;
      final preferredTime = config.preferredQuranTime!;
      
      switch (preferredTime) {
        case 'fajr':
          return hour >= 4 && hour < 7;
        case 'dhuhr':
          return hour >= 12 && hour < 15;
        case 'asr':
          return hour >= 15 && hour < 18;
        case 'maghrib':
          return hour >= 18 && hour < 20;
        case 'isha':
          return hour >= 20 || hour < 4;
        default:
          return false;
      }
    }

    return false;
  }

  /// Obtenir l'ordre des sections selon les priorités
  List<String> getSectionOrder(PersonalizationConfig config) {
    final sections = <String>[
      'countdown',
      'prayerTimeline',
      'ramadanProgress',
      'momentOfDay',
      'quickActions',
      'spiritualContent',
    ];

    // Réorganiser selon les priorités
    final orderedSections = <String>[];
    
    // Toujours en premier
    orderedSections.addAll(['countdown', 'prayerTimeline', 'ramadanProgress']);

    // Ajouter selon les priorités
    if (config.momentOfDayPriority == SectionPriority.high) {
      orderedSections.add('momentOfDay');
    }
    
    if (config.quickActionsPriority == SectionPriority.high) {
      orderedSections.add('quickActions');
    }
    
    if (config.spiritualContentPriority == SectionPriority.high) {
      orderedSections.add('spiritualContent');
    }

    // Ajouter les sections restantes
    for (final section in sections) {
      if (!orderedSections.contains(section)) {
        orderedSections.add(section);
      }
    }

    return orderedSections;
  }
}
