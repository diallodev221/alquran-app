import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_providers.dart';
import '../providers/quran_providers.dart';
import '../providers/settings_providers.dart';
import '../utils/surah_adapter.dart';

/// Widget qui écoute le provider shouldPlayNextSurah et charge automatiquement la sourate suivante
class AutoPlayListener extends ConsumerStatefulWidget {
  final Widget child;

  const AutoPlayListener({super.key, required this.child});

  @override
  ConsumerState<AutoPlayListener> createState() => _AutoPlayListenerState();
}

class _AutoPlayListenerState extends ConsumerState<AutoPlayListener> {
  int? _lastProcessedSurah;

  @override
  Widget build(BuildContext context) {
    // Écouter le provider pour la prochaine sourate
    final nextSurahNumber = ref.watch(shouldPlayNextSurahProvider);

    // Si une nouvelle sourate doit être jouée et qu'on ne l'a pas déjà traitée
    if (nextSurahNumber != null && nextSurahNumber != _lastProcessedSurah) {
      _lastProcessedSurah = nextSurahNumber;

      // Charger et jouer la sourate suivante après le build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playNextSurah(nextSurahNumber);
      });
    }

    return widget.child;
  }

  Future<void> _playNextSurah(int surahNumber) async {
    try {
      // Récupérer les informations de la sourate
      final surahsAsync = ref.read(surahsProvider);

      await surahsAsync.when(
        data: (apiSurahs) async {
          if (apiSurahs.isEmpty) return;
          final allSurahs = SurahAdapter.fromApiModelList(apiSurahs);
          final matches =
              allSurahs.where((s) => s.number == surahNumber).toList();
          if (matches.isEmpty) return;
          final nextSurah = matches.first;

          // Récupérer les URLs audio
          final audioService = ref.read(audioServiceProvider);
          final selectedReciter = ref.read(selectedReciterPersistentProvider);

          final audioUrls = await audioService.getSurahAudioUrls(
            surahNumber,
            reciter: selectedReciter,
          );

          if (audioUrls.isNotEmpty) {
            // Charger et jouer la nouvelle sourate
            final playlistService = ref.read(
              globalAudioPlaylistServiceProvider,
            );
            await playlistService.loadSurahPlaylist(audioUrls);
            await playlistService.play();

            // Mettre à jour les providers
            ref.read(currentPlayingSurahProvider.notifier).state =
                nextSurah.number;
            ref.read(currentPlayingSurahNameProvider.notifier).state =
                nextSurah.name;
            ref.read(currentSurahTotalAyahsProvider.notifier).state =
                nextSurah.numberOfAyahs;
            ref.read(currentAyahIndexProvider.notifier).state = 0;

            debugPrint(
              '🎵 Auto-playing: ${nextSurah.name} (${nextSurah.number})',
            );

            // Afficher une notification
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Lecture: ${nextSurah.name}'),
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }

          // Réinitialiser le provider
          ref.read(shouldPlayNextSurahProvider.notifier).state = null;
        },
        loading: () {
          debugPrint('⏳ Waiting for surahs to load...');
        },
        error: (error, stack) {
          debugPrint('❌ Error loading next surah: $error');
          ref.read(shouldPlayNextSurahProvider.notifier).state = null;
        },
      );
    } catch (e) {
      debugPrint('❌ Error in _playNextSurah: $e');
      ref.read(shouldPlayNextSurahProvider.notifier).state = null;
    }
  }
}
