import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_service.dart';
import '../services/audio_playlist_service.dart';
import '../services/settings_service.dart';
import '../models/quran_models.dart';
import 'settings_providers.dart';

/// Provider pour le service audio
final audioServiceProvider = Provider((ref) => AudioService());

/// Provider pour le récitateur sélectionné (maintenant avec persistance)
final selectedReciterProvider =
    StateNotifierProvider<SelectedReciterNotifier, String>((ref) {
      // Utiliser le provider persistent de settings_providers
      return ref.watch(selectedReciterPersistentProvider.notifier);
    });

// Garder l'ancien comme alias pour compatibilité
final selectedReciterStateProvider = Provider<String>((ref) {
  return ref.watch(selectedReciterPersistentProvider);
});

/// Provider pour les URLs audio d'une sourate
final surahAudioUrlsProvider = FutureProvider.family<List<String>, int>((
  ref,
  surahNumber,
) async {
  final audioService = ref.watch(audioServiceProvider);
  final selectedReciter = ref.watch(selectedReciterPersistentProvider);

  return audioService.getSurahAudioUrls(surahNumber, reciter: selectedReciter);
});

/// Provider pour les récitateurs disponibles
final recitersProvider = FutureProvider<List<RecitationModel>>((ref) async {
  final audioService = ref.watch(audioServiceProvider);
  return audioService.getReciters();
});

/// Provider global pour le service de playlist audio
/// Ce provider persiste à travers la navigation
final globalAudioPlaylistServiceProvider = Provider<AudioPlaylistService>((
  ref,
) {
  final service = AudioPlaylistService(
    onAyahChanged: (index) {
      ref.read(currentAyahIndexProvider.notifier).state = index;
    },
    onSurahCompleted: () async {
      // Quand une sourate se termine, passer à la suivante si autoplay activé
      final settingsService = SettingsService();
      await settingsService.init();
      final autoPlay = await settingsService.getAutoPlayNext();

      if (autoPlay) {
        final currentSurah = ref.read(currentPlayingSurahProvider);
        if (currentSurah != null && currentSurah < 114) {
          // Passer à la sourate suivante
          final nextSurahNumber = currentSurah + 1;
          debugPrint('🎵 Auto-playing next surah: $nextSurahNumber');

          // Déclencher le chargement de la sourate suivante
          ref.read(shouldPlayNextSurahProvider.notifier).state =
              nextSurahNumber;
        } else {
          debugPrint('✅ Completed all surahs (reached 114)');
        }
      }
    },
  );

  // Écouter les changements d'état de lecture
  service.playerStateStream.listen((state) {
    ref.read(isAudioPlayingProvider.notifier).state = state.playing;
  });

  // Charger et appliquer le paramètre de lecture automatique
  _initializeAudioSettings(service);

  // Ne pas disposer automatiquement le service
  ref.onDispose(() {
    // On garde le service actif même si le provider est disposé
  });

  return service;
});

/// Initialiser les paramètres audio
Future<void> _initializeAudioSettings(AudioPlaylistService service) async {
  final settingsService = SettingsService();
  await settingsService.init();
  // Note: Le loop mode est géré par le callback onSurahCompleted
  // qui déclenche la sourate suivante si autoPlay est activé
  await service.setLoopMode(LoopMode.off);
}

/// Provider pour l'état de lecture actuel
final isAudioPlayingProvider = StateProvider<bool>((ref) => false);

/// Provider pour l'index du verset actuel
final currentAyahIndexProvider = StateProvider<int>((ref) => 0);

/// Provider pour le numéro de sourate en cours de lecture
final currentPlayingSurahProvider = StateProvider<int?>((ref) => null);

/// Provider pour le nom de la sourate en cours de lecture
final currentPlayingSurahNameProvider = StateProvider<String?>((ref) => null);

/// Provider pour le nombre total de versets
final currentSurahTotalAyahsProvider = StateProvider<int>((ref) => 0);

/// Provider pour déclencher la lecture de la sourate suivante
final shouldPlayNextSurahProvider = StateProvider<int?>((ref) => null);
