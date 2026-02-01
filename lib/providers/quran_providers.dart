import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/quran_api_service.dart';
import '../models/quran_models.dart';
import '../data/repositories/quran_local_repository.dart';
import 'settings_providers.dart';

/// API utilisée uniquement pour l'audio (AlQuran Cloud). Jamais pour le texte.
final quranApiServiceProvider = Provider((ref) => QuranApiService());

/// Repository local (Tanzil). Texte 100 % offline.
final quranLocalRepositoryProvider = Provider<QuranLocalRepository>((ref) {
  return QuranLocalRepositoryImpl();
});

/// Toutes les sourates — UNIQUEMENT depuis le stockage local (aucun réseau).
final surahsProvider = FutureProvider<List<SurahModel>>((ref) async {
  final repo = ref.watch(quranLocalRepositoryProvider);
  return (await repo.getSurahs()) ?? [];
});

/// Détail d'une sourate : texte arabe depuis le local (Tanzil), traductions
/// optionnellement depuis l'API (AlQuran Cloud) pour le tooltip au survol.
final surahDetailProvider = FutureProvider.family<SurahDetailModel?, int>((
  ref,
  surahNumber,
) async {
  final repo = ref.watch(quranLocalRepositoryProvider);
  final local = await repo.getSurahDetail(surahNumber);
  if (local == null) return null;

  final translationEdition = ref.watch(translationEditionProvider);
  final api = ref.watch(quranApiServiceProvider);
  try {
    final withTranslation = await api.getSurahDetail(
      surahNumber,
      translationEdition: translationEdition,
    );
    final mergedAyahs = <AyahModel>[];
    for (int i = 0; i < local.ayahs.length; i++) {
      final ayah = local.ayahs[i];
      final text = i < withTranslation.ayahs.length
          ? withTranslation.ayahs[i].translation
          : null;
      mergedAyahs.add(AyahModel(
        number: ayah.number,
        numberInSurah: ayah.numberInSurah,
        juz: ayah.juz,
        text: ayah.text,
        translation: text,
        audioUrl: ayah.audioUrl,
      ));
    }
    return SurahDetailModel(
      number: local.number,
      name: local.name,
      englishName: local.englishName,
      englishNameTranslation: local.englishNameTranslation,
      revelationType: local.revelationType,
      numberOfAyahs: local.numberOfAyahs,
      ayahs: mergedAyahs,
    );
  } catch (e) {
    debugPrint('surahDetailProvider: translation fetch failed ($e), using local only');
    return local;
  }
});

/// Recherche locale par numéro ou nom de sourate.
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<SurahModel>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  final repo = ref.watch(quranLocalRepositoryProvider);
  if (query.isEmpty) return (await repo.getSurahs()) ?? [];
  return (await repo.searchSurahsByNameOrNumber(query)) ?? [];
});

/// Éditions traduction (liste statique, compatible Tanzil). Aucun appel api.alquran.cloud.
final editionsProvider = FutureProvider<List<EditionModel>>((ref) async {
  return ref.watch(quranApiServiceProvider).getEditions();
});

/// Éditions de script arabe (Tanzil uniquement). Aucun appel api.alquran.cloud.
final arabicScriptEditionsProvider =
    FutureProvider.autoDispose<List<EditionModel>>((ref) async {
      ref.keepAlive();
      return ref.watch(quranApiServiceProvider).getEditions(type: 'quran');
    });

/// Provider pour l'édition sélectionnée (français par défaut)
final selectedEditionProvider = StateProvider<String>((ref) => 'quran-madinah');
// final selectedEditionProvider = StateProvider<String>((ref) => 'fr.hamidullah');

// Les providers de connectivité sont maintenant dans network_providers.dart
// Utiliser isOnlineProvider et networkStatusProvider depuis network_providers.dart

/// Dernière sourate lue — persistance via SettingsService (continuité hors ligne).
final lastReadSurahProvider = StateProvider<int>((ref) => 2);

/// Dernier verset lu — persistance via SettingsService (continuité hors ligne).
final lastReadAyahProvider = StateProvider<int>((ref) => 1);

/// Marque-pages (offline).
final bookmarksProvider = FutureProvider<List<QuranBookmark>>((ref) async {
  final repo = ref.watch(quranLocalRepositoryProvider);
  return repo.getBookmarks();
});

/// Indique si un verset est marqué.
final isBookmarkedProvider = FutureProvider.family<bool, ({int surahNumber, int numberInSurah})>((ref, key) async {
  final repo = ref.watch(quranLocalRepositoryProvider);
  return repo.isBookmarked(key.surahNumber, key.numberInSurah);
});

/// Ayahs d'un Juz (1–30) — offline.
final ayahsByJuzProvider = FutureProvider.family<List<AyahModel>, int>((ref, juzNumber) async {
  final repo = ref.watch(quranLocalRepositoryProvider);
  return (await repo.getAyahsByJuz(juzNumber)) ?? [];
});

/// Ayahs d'une page mushaf (1–604) — offline.
final ayahsByPageProvider = FutureProvider.family<List<AyahModel>, int>((ref, pageNumber) async {
  final repo = ref.watch(quranLocalRepositoryProvider);
  return (await repo.getAyahsByPage(pageNumber)) ?? [];
});
