import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/favorites_service.dart';

/// Provider pour le service de favoris (singleton)
final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  final service = FavoritesService();
  service.init(); // Initialiser automatiquement
  return service;
});

/// Provider pour la liste des sourates favorites
final favoriteSurahsProvider = StreamProvider<List<int>>((ref) async* {
  final service = ref.watch(favoritesServiceProvider);

  // Émettre la liste initiale
  yield await service.getFavoriteSurahs();

  // Dans une vraie application, on pourrait écouter les changements
  // Pour l'instant, on émet périodiquement ou on utilise un StateNotifier
});

/// Provider pour la liste des versets favoris
final favoriteAyahsProvider = StreamProvider<List<String>>((ref) async* {
  final service = ref.watch(favoritesServiceProvider);
  yield await service.getFavoriteAyahs();
});

/// StateNotifier pour gérer l'état des favoris de manière réactive
class FavoritesNotifier extends StateNotifier<AsyncValue<FavoritesState>> {
  final FavoritesService _service;

  FavoritesNotifier(this._service) : super(const AsyncValue.loading()) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    state = const AsyncValue.loading();
    try {
      final surahs = await _service.getFavoriteSurahs();
      final ayahs = await _service.getFavoriteAyahs();
      state = AsyncValue.data(
        FavoritesState(favoriteSurahs: surahs, favoriteAyahs: ayahs),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Basculer l'état favori d'une sourate
  Future<bool> toggleSurahFavorite(int surahNumber) async {
    final result = await _service.toggleSurahFavorite(surahNumber);
    await _loadFavorites(); // Recharger l'état
    return result;
  }

  /// Basculer l'état favori d'un verset
  Future<bool> toggleAyahFavorite(int surahNumber, int ayahNumber) async {
    final result = await _service.toggleAyahFavorite(surahNumber, ayahNumber);
    await _loadFavorites(); // Recharger l'état
    return result;
  }

  /// Vérifier si une sourate est en favori
  bool isSurahFavorite(int surahNumber) {
    return state.maybeWhen(
      data: (favoritesState) =>
          favoritesState.favoriteSurahs.contains(surahNumber),
      orElse: () => false,
    );
  }

  /// Vérifier si un verset est en favori
  bool isAyahFavorite(int surahNumber, int ayahNumber) {
    final key = '$surahNumber:$ayahNumber';
    return state.maybeWhen(
      data: (favoritesState) => favoritesState.favoriteAyahs.contains(key),
      orElse: () => false,
    );
  }

  /// Obtenir le nombre total de favoris
  int getTotalFavoritesCount() {
    return state.maybeWhen(
      data: (favoritesState) =>
          favoritesState.favoriteSurahs.length +
          favoritesState.favoriteAyahs.length,
      orElse: () => 0,
    );
  }

  /// Effacer tous les favoris
  Future<void> clearAllFavorites() async {
    await _service.clearAllFavorites();
    await _loadFavorites();
  }
}

/// État des favoris
class FavoritesState {
  final List<int> favoriteSurahs;
  final List<String> favoriteAyahs;

  const FavoritesState({
    required this.favoriteSurahs,
    required this.favoriteAyahs,
  });

  FavoritesState copyWith({
    List<int>? favoriteSurahs,
    List<String>? favoriteAyahs,
  }) {
    return FavoritesState(
      favoriteSurahs: favoriteSurahs ?? this.favoriteSurahs,
      favoriteAyahs: favoriteAyahs ?? this.favoriteAyahs,
    );
  }
}

/// Provider pour le StateNotifier des favoris
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, AsyncValue<FavoritesState>>((ref) {
      final service = ref.watch(favoritesServiceProvider);
      return FavoritesNotifier(service);
    });

/// Provider pour vérifier si une sourate est en favori
final isSurahFavoriteProvider = Provider.family<bool, int>((ref, surahNumber) {
  final favoritesNotifier = ref.watch(favoritesProvider.notifier);
  return favoritesNotifier.isSurahFavorite(surahNumber);
});

/// Provider pour vérifier si un verset est en favori
final isAyahFavoriteProvider = Provider.family<bool, ({int surah, int ayah})>((
  ref,
  params,
) {
  final favoritesNotifier = ref.watch(favoritesProvider.notifier);
  return favoritesNotifier.isAyahFavorite(params.surah, params.ayah);
});

/// Provider pour obtenir le nombre total de favoris
final totalFavoritesCountProvider = Provider<int>((ref) {
  final favoritesNotifier = ref.watch(favoritesProvider.notifier);
  return favoritesNotifier.getTotalFavoritesCount();
});
