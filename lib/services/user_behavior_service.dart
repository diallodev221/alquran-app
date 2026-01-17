import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

/// Service pour tracker le comportement utilisateur de manière anonyme
class UserBehaviorService {
  static final UserBehaviorService _instance = UserBehaviorService._internal();
  factory UserBehaviorService() => _instance;
  UserBehaviorService._internal();

  static const String _behaviorBoxName = 'user_behavior';
  Box<dynamic>? _box;

  // Clés de tracking
  static const String _audioPlaysKey = 'audio_plays';
  static const String _quranOpensKey = 'quran_opens';
  static const String _reminderInteractionsKey = 'reminder_interactions';
  static const String _momentOfDayViewsKey = 'moment_of_day_views';
  static const String _spiritualContentPlaysKey = 'spiritual_content_plays';

  /// Initialiser le service
  Future<void> init() async {
    try {
      _box = await Hive.openBox(_behaviorBoxName);
    } catch (e) {
      debugPrint('⚠️ Error initializing UserBehaviorService: $e');
    }
  }

  // ==================== TRACKING AUDIO ====================

  /// Enregistrer une session d'écoute audio
  Future<void> trackAudioPlay({
    required String type, // 'quran', 'xassida', 'hadith'
    required DateTime timestamp,
    int duration = 0,
  }) async {
    if (_box == null) return;

    try {
      final key = '$_audioPlaysKey:${DateTime.now().toIso8601String().split('T')[0]}';
      final existing = _box!.get(key, defaultValue: <String, dynamic>{}) as Map;
      
      final plays = (existing[type] as List?) ?? [];
      plays.add({
        'timestamp': timestamp.toIso8601String(),
        'duration': duration,
      });

      existing[type] = plays;
      await _box!.put(key, existing);
      _cleanOldEntries(_audioPlaysKey, daysToKeep: 30);
    } catch (e) {
      debugPrint('⚠️ Error tracking audio play: $e');
    }
  }

  /// Obtenir le type d'audio le plus écouté
  Future<String?> getMostPlayedAudioType({int days = 7}) async {
    if (_box == null) return null;

    try {
      final now = DateTime.now();
      final stats = <String, int>{};

      for (int i = 0; i < days; i++) {
        final date = now.subtract(Duration(days: i));
        final key = '$_audioPlaysKey:${date.toIso8601String().split('T')[0]}';
        final data = _box!.get(key) as Map<dynamic, dynamic>?;
        
        if (data != null) {
          data.forEach((type, plays) {
            if (plays is List) {
              stats[type as String] = (stats[type] ?? 0) + plays.length;
            }
          });
        }
      }

      if (stats.isEmpty) return null;

      final sorted = stats.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return sorted.first.key;
    } catch (e) {
      debugPrint('⚠️ Error getting most played audio type: $e');
      return null;
    }
  }

  // ==================== TRACKING QURAN ====================

  /// Enregistrer une ouverture du Quran
  Future<void> trackQuranOpen({
    required DateTime timestamp,
    String? prayerTime, // 'fajr', 'dhuhr', etc.
  }) async {
    if (_box == null) return;

    try {
      final key = '$_quranOpensKey:${DateTime.now().toIso8601String().split('T')[0]}';
      final existing = _box!.get(key, defaultValue: <String, dynamic>{}) as Map;
      
      final opens = (existing['opens'] as List?) ?? [];
      opens.add({
        'timestamp': timestamp.toIso8601String(),
        'prayerTime': prayerTime,
        'hour': timestamp.hour,
      });

      existing['opens'] = opens;
      await _box!.put(key, existing);
      _cleanOldEntries(_quranOpensKey, daysToKeep: 30);
    } catch (e) {
      debugPrint('⚠️ Error tracking Quran open: $e');
    }
  }

  /// Obtenir l'heure de prière la plus commune pour ouvrir le Quran
  Future<String?> getPreferredQuranTime({int days = 14}) async {
    if (_box == null) return null;

    try {
      final now = DateTime.now();
      final prayerStats = <String, int>{};

      for (int i = 0; i < days; i++) {
        final date = now.subtract(Duration(days: i));
        final key = '$_quranOpensKey:${date.toIso8601String().split('T')[0]}';
        final data = _box!.get(key) as Map<dynamic, dynamic>?;
        
        if (data != null) {
          final opens = data['opens'] as List?;
          if (opens != null) {
            for (final open in opens) {
              if (open is Map) {
                final prayerTime = open['prayerTime'] as String?;
                final hour = open['hour'] as int?;
                
                if (prayerTime != null) {
                  prayerStats[prayerTime] = (prayerStats[prayerTime] ?? 0) + 1;
                } else if (hour != null) {
                  // Déduire l'heure de prière basée sur l'heure
                  String? inferredPrayer;
                  if (hour >= 4 && hour < 7) {
                    inferredPrayer = 'fajr';
                  } else if (hour >= 12 && hour < 15) {
                    inferredPrayer = 'dhuhr';
                  } else if (hour >= 15 && hour < 18) {
                    inferredPrayer = 'asr';
                  } else if (hour >= 18 && hour < 20) {
                    inferredPrayer = 'maghrib';
                  } else if (hour >= 20 || hour < 4) {
                    inferredPrayer = 'isha';
                  }
                  
                  if (inferredPrayer != null) {
                    prayerStats[inferredPrayer] = (prayerStats[inferredPrayer] ?? 0) + 1;
                  }
                }
              }
            }
          }
        }
      }

      if (prayerStats.isEmpty) return null;

      final sorted = prayerStats.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return sorted.first.key;
    } catch (e) {
      debugPrint('⚠️ Error getting preferred Quran time: $e');
      return null;
    }
  }

  // ==================== TRACKING RAPPELS ====================

  /// Enregistrer une interaction avec un rappel
  Future<void> trackReminderInteraction({
    required String reminderType,
    required bool dismissed,
    required bool actedUpon,
  }) async {
    if (_box == null) return;

    try {
      final key = '$_reminderInteractionsKey:${DateTime.now().toIso8601String().split('T')[0]}';
      final existing = _box!.get(key, defaultValue: <String, dynamic>{}) as Map;
      
      final interactions = (existing[reminderType] as List?) ?? [];
      interactions.add({
        'timestamp': DateTime.now().toIso8601String(),
        'dismissed': dismissed,
        'actedUpon': actedUpon,
      });

      existing[reminderType] = interactions;
      await _box!.put(key, existing);
      _cleanOldEntries(_reminderInteractionsKey, daysToKeep: 30);
    } catch (e) {
      debugPrint('⚠️ Error tracking reminder interaction: $e');
    }
  }

  /// Obtenir le taux de rejet des rappels
  Future<double> getReminderDismissalRate({int days = 7}) async {
    if (_box == null) return 0.0;

    try {
      final now = DateTime.now();
      int totalInteractions = 0;
      int dismissedCount = 0;

      for (int i = 0; i < days; i++) {
        final date = now.subtract(Duration(days: i));
        final key = '$_reminderInteractionsKey:${date.toIso8601String().split('T')[0]}';
        final data = _box!.get(key) as Map<dynamic, dynamic>?;
        
        if (data != null) {
          data.forEach((type, interactions) {
            if (interactions is List) {
              for (final interaction in interactions) {
                if (interaction is Map) {
                  totalInteractions++;
                  if (interaction['dismissed'] == true) {
                    dismissedCount++;
                  }
                }
              }
            }
          });
        }
      }

      if (totalInteractions == 0) return 0.0;
      return dismissedCount / totalInteractions;
    } catch (e) {
      debugPrint('⚠️ Error getting reminder dismissal rate: $e');
      return 0.0;
    }
  }

  // ==================== TRACKING MOMENT OF DAY ====================

  /// Enregistrer une vue du Moment of the Day
  Future<void> trackMomentOfDayView({
    required String momentType,
    required bool interacted, // tapped to see details
  }) async {
    if (_box == null) return;

    try {
      final key = '$_momentOfDayViewsKey:${DateTime.now().toIso8601String().split('T')[0]}';
      final existing = _box!.get(key, defaultValue: <String, dynamic>{}) as Map;
      
      final views = (existing[momentType] as List?) ?? [];
      views.add({
        'timestamp': DateTime.now().toIso8601String(),
        'interacted': interacted,
      });

      existing[momentType] = views;
      await _box!.put(key, existing);
    } catch (e) {
      debugPrint('⚠️ Error tracking moment of day view: $e');
    }
  }

  /// Enregistrer une lecture de contenu spirituel
  Future<void> trackSpiritualContentPlay({
    required String contentType, // 'xassida', 'khutba', etc.
  }) async {
    if (_box == null) return;

    try {
      final key = '$_spiritualContentPlaysKey:${DateTime.now().toIso8601String().split('T')[0]}';
      final existing = _box!.get(key, defaultValue: <String, dynamic>{}) as Map;
      
      final plays = (existing[contentType] as List?) ?? [];
      plays.add({
        'timestamp': DateTime.now().toIso8601String(),
      });

      existing[contentType] = plays;
      await _box!.put(key, existing);
      _cleanOldEntries(_spiritualContentPlaysKey, daysToKeep: 30);
    } catch (e) {
      debugPrint('⚠️ Error tracking spiritual content play: $e');
    }
  }

  // ==================== NETTOYAGE ====================

  void _cleanOldEntries(String prefix, {int daysToKeep = 30}) {
    if (_box == null) return;

    try {
      final now = DateTime.now();
      final keysToDelete = <String>[];

      for (final key in _box!.keys) {
        if (key is String && key.startsWith('$prefix:')) {
          final dateStr = key.split(':').last;
          try {
            final date = DateTime.parse(dateStr);
            if (now.difference(date).inDays > daysToKeep) {
              keysToDelete.add(key);
            }
          } catch (e) {
            // Invalid date format, skip
          }
        }
      }

      for (final key in keysToDelete) {
        _box!.delete(key);
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning old entries: $e');
    }
  }

  /// Réinitialiser toutes les données de comportement (pour debug)
  Future<void> reset() async {
    if (_box == null) return;
    await _box!.clear();
  }
}
