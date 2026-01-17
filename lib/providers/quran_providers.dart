import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/quran_api_service.dart';
import '../models/quran_models.dart';
import 'settings_providers.dart';

/// Provider pour le service API
final quranApiServiceProvider = Provider((ref) => QuranApiService());

/// Provider pour toutes les sourates
final surahsProvider = FutureProvider<List<SurahModel>>((ref) async {
  final apiService = ref.watch(quranApiServiceProvider);
  return apiService.getAllSurahs();
});

/// Provider pour le détail d'une sourate avec traduction française
final surahDetailProvider = FutureProvider.family<SurahDetailModel, int>((
  ref,
  surahNumber,
) async {
  final apiService = ref.watch(quranApiServiceProvider);
  final arabicScript = ref.watch(arabicScriptProvider);
  final translationEdition = ref.watch(translationEditionProvider);
  return apiService.getSurahDetail(
    surahNumber,
    edition: arabicScript, // Utiliser le script sélectionné
    translationEdition: translationEdition, // Utiliser la traduction sélectionnée
  );
});

/// Provider pour la recherche
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<AyahModel>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];

  final apiService = ref.watch(quranApiServiceProvider);
  return apiService.searchAyahs(query);
});

/// Provider pour les éditions/traductions disponibles
final editionsProvider = FutureProvider<List<EditionModel>>((ref) async {
  final apiService = ref.watch(quranApiServiceProvider);
  return apiService.getEditions();
});

/// Provider pour les éditions de script arabe disponibles (cached in memory)
final arabicScriptEditionsProvider =
    FutureProvider.autoDispose<List<EditionModel>>((ref) async {
  final apiService = ref.watch(quranApiServiceProvider);
  // Keep provider alive to cache data in memory
  ref.keepAlive();
  return apiService.getEditions(type: 'quran');
});

/// Provider pour l'édition sélectionnée (français par défaut)
final selectedEditionProvider = StateProvider<String>((ref) => 'quran-madinah');
// final selectedEditionProvider = StateProvider<String>((ref) => 'fr.hamidullah');

// Les providers de connectivité sont maintenant dans network_providers.dart
// Utiliser isOnlineProvider et networkStatusProvider depuis network_providers.dart

/// Provider pour la dernière sourate lue (numéro)
final lastReadSurahProvider = StateProvider<int>((ref) => 2);

/// Provider pour le dernier verset lu
final lastReadAyahProvider = StateProvider<int>((ref) => 1);
