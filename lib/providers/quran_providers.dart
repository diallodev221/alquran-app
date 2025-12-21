import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/quran_api_service.dart';
import '../models/quran_models.dart';

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
  return apiService.getSurahDetail(
    surahNumber,
    translationEdition: 'fr.hamidullah', // Traduction française de Hamidullah
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

/// Provider pour l'édition sélectionnée (français par défaut)
final selectedEditionProvider = StateProvider<String>((ref) => 'quran-madinah');
// final selectedEditionProvider = StateProvider<String>((ref) => 'fr.hamidullah');

/// Provider pour vérifier la connectivité internet
final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Provider pour savoir si on est en ligne
final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (result) => result != ConnectivityResult.none,
    loading: () => true,
    error: (_, __) => false,
  );
});

/// Provider pour la dernière sourate lue (numéro)
final lastReadSurahProvider = StateProvider<int>((ref) => 2);

/// Provider pour le dernier verset lu
final lastReadAyahProvider = StateProvider<int>((ref) => 1);
