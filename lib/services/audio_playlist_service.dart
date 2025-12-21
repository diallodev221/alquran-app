import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// Callback appelé quand une sourate se termine
typedef OnSurahCompletedCallback = void Function();

/// Service pour gérer la playlist audio d'une sourate complète
class AudioPlaylistService {
  final AudioPlayer _audioPlayer;
  ConcatenatingAudioSource? _playlist;

  int _currentIndex = 0;
  final Function(int)? onAyahChanged;
  final OnSurahCompletedCallback? onSurahCompleted;

  AudioPlaylistService({
    AudioPlayer? audioPlayer,
    this.onAyahChanged,
    this.onSurahCompleted,
  }) : _audioPlayer = audioPlayer ?? AudioPlayer() {
    _setupListeners();
  }

  void _setupListeners() {
    // Écouter le changement d'index dans la playlist
    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && index != _currentIndex) {
        _currentIndex = index;
        onAyahChanged?.call(index);
        debugPrint('🎵 Playing ayah ${index + 1}');
      }
    });

    // Écouter la fin de la lecture
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        debugPrint('✅ Surah recitation completed');
        onSurahCompleted?.call();
      }
    });
  }

  /// Charge une playlist complète pour une sourate
  Future<void> loadSurahPlaylist(
    List<String> audioUrls, {
    int startIndex = 0,
  }) async {
    try {
      // Créer une playlist de tous les versets
      _playlist = ConcatenatingAudioSource(
        useLazyPreparation: true, // Charge les URLs progressivement
        shuffleOrder: DefaultShuffleOrder(),
        children: audioUrls.map((url) {
          return AudioSource.uri(
            Uri.parse(url),
            tag: url, // Tag pour identifier l'URL
          );
        }).toList(),
      );

      // Charger la playlist
      await _audioPlayer.setAudioSource(
        _playlist!,
        initialIndex: startIndex,
        initialPosition: Duration.zero,
      );

      _currentIndex = startIndex;
      debugPrint('📻 Loaded playlist with ${audioUrls.length} ayahs');
    } catch (e) {
      debugPrint('Error loading playlist: $e');
      rethrow;
    }
  }

  /// Démarrer la lecture
  Future<void> play() async {
    await _audioPlayer.play();
  }

  /// Mettre en pause
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// Lecture / Pause
  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  /// Jouer un verset spécifique
  Future<void> seekToAyah(int ayahIndex) async {
    try {
      await _audioPlayer.seek(Duration.zero, index: ayahIndex);
      _currentIndex = ayahIndex;
    } catch (e) {
      debugPrint('Error seeking to ayah: $e');
    }
  }

  /// Verset suivant
  Future<void> skipToNext() async {
    if (_audioPlayer.hasNext) {
      await _audioPlayer.seekToNext();
    }
  }

  /// Verset précédent
  Future<void> skipToPrevious() async {
    if (_audioPlayer.hasPrevious) {
      await _audioPlayer.seekToPrevious();
    }
  }

  /// Avancer de N secondes
  Future<void> seekForward(Duration duration) async {
    final newPosition = (_audioPlayer.position) + duration;
    final maxDuration = _audioPlayer.duration ?? Duration.zero;

    if (newPosition <= maxDuration) {
      await _audioPlayer.seek(newPosition);
    }
  }

  /// Reculer de N secondes
  Future<void> seekBackward(Duration duration) async {
    final newPosition = _audioPlayer.position - duration;

    if (newPosition >= Duration.zero) {
      await _audioPlayer.seek(newPosition);
    } else {
      await _audioPlayer.seek(Duration.zero);
    }
  }

  /// Changer la vitesse de lecture
  Future<void> setSpeed(double speed) async {
    await _audioPlayer.setSpeed(speed);
  }

  /// Activer/désactiver le mode repeat
  Future<void> setLoopMode(LoopMode mode) async {
    await _audioPlayer.setLoopMode(mode);
  }

  /// Arrêter complètement la lecture
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// Getters pour les streams
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<int?> get currentIndexStream => _audioPlayer.currentIndexStream;

  /// Getters pour l'état actuel
  bool get isPlaying => _audioPlayer.playing;
  Duration get position => _audioPlayer.position;
  Duration? get duration => _audioPlayer.duration;
  int get currentIndex => _currentIndex;
  double get speed => _audioPlayer.speed;
  LoopMode get loopMode => _audioPlayer.loopMode;

  /// Nettoyer les ressources
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
