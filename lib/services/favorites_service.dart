import 'package:hive/hive.dart';

/// Service pour gérer les favoris (sourates et versets)
class FavoritesService {
  static const String _boxName = 'favorites';
  static const String _surahsKey = 'favorite_surahs';
  static const String _ayahsKey = 'favorite_ayahs';

  Box<dynamic>? _box;

  /// Initialiser le service
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Obtenir la box (avec initialisation automatique si nécessaire)
  Future<Box<dynamic>> _getBox() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    return _box!;
  }

  // ==================== GESTION DES SOURATES FAVORITES ====================

  /// Obtenir la liste des numéros de sourates en favori
  Future<List<int>> getFavoriteSurahs() async {
    final box = await _getBox();
    final List<dynamic>? favorites = box.get(_surahsKey);
    if (favorites == null) return [];
    return favorites.cast<int>();
  }

  /// Vérifier si une sourate est en favori
  Future<bool> isSurahFavorite(int surahNumber) async {
    final favorites = await getFavoriteSurahs();
    return favorites.contains(surahNumber);
  }

  /// Ajouter une sourate aux favoris
  Future<void> addSurahToFavorites(int surahNumber) async {
    final box = await _getBox();
    final favorites = await getFavoriteSurahs();

    if (!favorites.contains(surahNumber)) {
      favorites.add(surahNumber);
      await box.put(_surahsKey, favorites);
    }
  }

  /// Retirer une sourate des favoris
  Future<void> removeSurahFromFavorites(int surahNumber) async {
    final box = await _getBox();
    final favorites = await getFavoriteSurahs();

    if (favorites.contains(surahNumber)) {
      favorites.remove(surahNumber);
      await box.put(_surahsKey, favorites);
    }
  }

  /// Basculer l'état favori d'une sourate (toggle)
  Future<bool> toggleSurahFavorite(int surahNumber) async {
    final isFavorite = await isSurahFavorite(surahNumber);

    if (isFavorite) {
      await removeSurahFromFavorites(surahNumber);
      return false;
    } else {
      await addSurahToFavorites(surahNumber);
      return true;
    }
  }

  // ==================== GESTION DES VERSETS FAVORIS ====================

  /// Obtenir la liste des versets en favori
  /// Format: "surahNumber:ayahNumber" (ex: "2:255" pour Ayat al-Kursi)
  Future<List<String>> getFavoriteAyahs() async {
    final box = await _getBox();
    final List<dynamic>? favorites = box.get(_ayahsKey);
    if (favorites == null) return [];
    return favorites.cast<String>();
  }

  /// Vérifier si un verset est en favori
  Future<bool> isAyahFavorite(int surahNumber, int ayahNumber) async {
    final favorites = await getFavoriteAyahs();
    final key = '$surahNumber:$ayahNumber';
    return favorites.contains(key);
  }

  /// Ajouter un verset aux favoris
  Future<void> addAyahToFavorites(int surahNumber, int ayahNumber) async {
    final box = await _getBox();
    final favorites = await getFavoriteAyahs();
    final key = '$surahNumber:$ayahNumber';

    if (!favorites.contains(key)) {
      favorites.add(key);
      await box.put(_ayahsKey, favorites);
    }
  }

  /// Retirer un verset des favoris
  Future<void> removeAyahFromFavorites(int surahNumber, int ayahNumber) async {
    final box = await _getBox();
    final favorites = await getFavoriteAyahs();
    final key = '$surahNumber:$ayahNumber';

    if (favorites.contains(key)) {
      favorites.remove(key);
      await box.put(_ayahsKey, favorites);
    }
  }

  /// Basculer l'état favori d'un verset (toggle)
  Future<bool> toggleAyahFavorite(int surahNumber, int ayahNumber) async {
    final isFavorite = await isAyahFavorite(surahNumber, ayahNumber);

    if (isFavorite) {
      await removeAyahFromFavorites(surahNumber, ayahNumber);
      return false;
    } else {
      await addAyahToFavorites(surahNumber, ayahNumber);
      return true;
    }
  }

  /// Obtenir tous les versets favoris d'une sourate spécifique
  Future<List<int>> getFavoriteAyahsForSurah(int surahNumber) async {
    final favorites = await getFavoriteAyahs();
    final ayahNumbers = <int>[];

    for (final key in favorites) {
      final parts = key.split(':');
      if (parts.length == 2 && int.parse(parts[0]) == surahNumber) {
        ayahNumbers.add(int.parse(parts[1]));
      }
    }

    return ayahNumbers;
  }

  // ==================== GESTION GLOBALE ====================

  /// Effacer tous les favoris
  Future<void> clearAllFavorites() async {
    final box = await _getBox();
    await box.delete(_surahsKey);
    await box.delete(_ayahsKey);
  }

  /// Obtenir le nombre total de favoris (sourates + versets)
  Future<int> getTotalFavoritesCount() async {
    final surahs = await getFavoriteSurahs();
    final ayahs = await getFavoriteAyahs();
    return surahs.length + ayahs.length;
  }

  /// Fermer le service
  Future<void> close() async {
    await _box?.close();
  }
}
