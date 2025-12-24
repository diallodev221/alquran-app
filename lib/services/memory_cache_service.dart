import 'package:flutter/foundation.dart';
import 'dart:collection';

/// Service de cache en mémoire pour des accès ultra-rapides
/// Utilise un système LRU (Least Recently Used) pour gérer la mémoire
class MemoryCacheService {
  static final MemoryCacheService _instance = MemoryCacheService._internal();
  factory MemoryCacheService() => _instance;
  MemoryCacheService._internal();

  // Cache avec limite de taille (LRU)
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();

  // Taille maximale du cache (nombre d'entrées)
  static const int maxCacheSize = 50;

  // Cache pour les listes (surahs, etc.) - pas de limite car c'est petit
  final Map<String, dynamic> _listCache = {};

  /// Récupère une valeur du cache
  T? get<T>(String key) {
    final entry = _cache[key];

    if (entry == null) return null;

    // Vérifier l'expiration
    if (entry.expiresAt != null && DateTime.now().isAfter(entry.expiresAt!)) {
      _cache.remove(key);
      return null;
    }

    // Déplacer en fin (LRU - most recently used)
    _cache.remove(key);
    _cache[key] = entry;

    return entry.value as T?;
  }

  /// Récupère une liste du cache
  T? getList<T>(String key) {
    return _listCache[key] as T?;
  }

  /// Met une valeur en cache
  void put<T>(String key, T value, {Duration? expiry}) {
    // Si le cache est plein, supprimer le moins récemment utilisé
    if (_cache.length >= maxCacheSize && !_cache.containsKey(key)) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
      debugPrint('🗑️ Memory cache: Removed LRU entry: $firstKey');
    }

    final expiresAt = expiry != null ? DateTime.now().add(expiry) : null;

    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: expiresAt,
      timestamp: DateTime.now(),
    );

    debugPrint('💾 Memory cache: Cached $key (${_cache.length}/$maxCacheSize)');
  }

  /// Met une liste en cache (sans expiration)
  void putList<T>(String key, T value) {
    _listCache[key] = value;
    debugPrint('💾 Memory cache: Cached list $key');
  }

  /// Vérifie si une clé existe
  bool has(String key) {
    final entry = _cache[key];
    if (entry == null) return false;

    if (entry.expiresAt != null && DateTime.now().isAfter(entry.expiresAt!)) {
      _cache.remove(key);
      return false;
    }

    return true;
  }

  /// Vérifie si une liste existe
  bool hasList(String key) {
    return _listCache.containsKey(key);
  }

  /// Supprime une entrée
  void remove(String key) {
    _cache.remove(key);
  }

  /// Supprime une liste
  void removeList(String key) {
    _listCache.remove(key);
  }

  /// Vide tout le cache
  void clear() {
    _cache.clear();
    _listCache.clear();
    debugPrint('🗑️ Memory cache: Cleared all');
  }

  /// Vide uniquement les entrées expirées
  void clearExpired() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.expiresAt != null &&
          now.isAfter(entry.value.expiresAt!)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      debugPrint(
        '🗑️ Memory cache: Removed ${keysToRemove.length} expired entries',
      );
    }
  }

  /// Obtient la taille actuelle du cache
  int get size => _cache.length;

  /// Obtient la taille des listes
  int get listSize => _listCache.length;

  /// Obtient des statistiques du cache
  Map<String, dynamic> getStats() {
    return {
      'cacheSize': _cache.length,
      'listCacheSize': _listCache.length,
      'maxSize': maxCacheSize,
      'keys': _cache.keys.toList(),
      'listKeys': _listCache.keys.toList(),
    };
  }
}

/// Entrée du cache avec métadonnées
class _CacheEntry {
  final dynamic value;
  final DateTime? expiresAt;
  final DateTime timestamp;

  _CacheEntry({required this.value, this.expiresAt, required this.timestamp});
}
