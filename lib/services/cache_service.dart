import 'package:hive/hive.dart';
import 'dart:convert';

/// Service de gestion du cache local avec Hive
class CacheService {
  static const String surahsBox = 'surahs';
  static const String surahDetailBox = 'surah_details';
  static const String recitationsBox = 'recitations';
  static const String editionsBox = 'editions';
  static const String settingsBox = 'settings';

  final Box<dynamic> _box;

  CacheService(this._box);

  /// Durées de cache
  static const Duration staticContentDuration = Duration(days: 30);
  static const Duration dynamicContentDuration = Duration(days: 1);

  /// Initialise tous les boxes Hive
  static Future<void> init() async {
    await Hive.openBox(surahsBox);
    await Hive.openBox(surahDetailBox);
    await Hive.openBox(recitationsBox);
    await Hive.openBox(editionsBox);
    await Hive.openBox(settingsBox);
  }

  /// Sauvegarde avec timestamp d'expiration
  Future<void> saveWithExpiry(
    String key,
    dynamic value, {
    Duration duration = staticContentDuration,
  }) async {
    final expiryTime = DateTime.now().add(duration).millisecondsSinceEpoch;

    await _box.put(key, {
      'data': jsonEncode(value),
      'expiry': expiryTime,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Récupère depuis cache si non expiré
  T? getIfValid<T>(String key, T Function(dynamic) fromJson) {
    final cached = _box.get(key) as Map<dynamic, dynamic>?;

    if (cached == null) return null;

    final expiryTime = cached['expiry'] as int;

    if (DateTime.now().millisecondsSinceEpoch > expiryTime) {
      _box.delete(key);
      return null;
    }

    try {
      final data = jsonDecode(cached['data'] as String);
      return fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Récupère même si expiré (fallback)
  T? getStale<T>(String key, T Function(dynamic) fromJson) {
    final cached = _box.get(key) as Map<dynamic, dynamic>?;

    if (cached == null) return null;

    try {
      final data = jsonDecode(cached['data'] as String);
      return fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Vérifie si une clé existe et est valide
  bool has(String key) {
    final cached = _box.get(key) as Map<dynamic, dynamic>?;
    if (cached == null) return false;

    final expiryTime = cached['expiry'] as int;
    return DateTime.now().millisecondsSinceEpoch <= expiryTime;
  }

  /// Supprime une entrée
  Future<void> delete(String key) => _box.delete(key);

  /// Vide tout le cache
  Future<void> clear() => _box.clear();

  /// Obtient la taille du cache
  int get size => _box.length;
}

