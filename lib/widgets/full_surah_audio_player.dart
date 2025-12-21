import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/audio_providers.dart';

/// Lecteur audio pour récitation complète d'une sourate
class FullSurahAudioPlayer extends ConsumerStatefulWidget {
  final String surahName;
  final int surahNumber;
  final List<String> audioUrls;
  final int totalAyahs;
  final Function(int)? onAyahChanged;

  const FullSurahAudioPlayer({
    super.key,
    required this.surahName,
    required this.surahNumber,
    required this.audioUrls,
    required this.totalAyahs,
    this.onAyahChanged,
  });

  /// Vérifie si cette sourate a le Bismillah (toutes sauf At-Tawbah)
  bool get hasBismillah => surahNumber != 9;

  @override
  ConsumerState<FullSurahAudioPlayer> createState() =>
      _FullSurahAudioPlayerState();
}

class _FullSurahAudioPlayerState extends ConsumerState<FullSurahAudioPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _currentAyahIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = false;
  double _speed = 1.0;
  LoopMode _loopMode = LoopMode.off;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final playlistService = ref.read(globalAudioPlaylistServiceProvider);

    // Vérifier si cette sourate est déjà en cours de lecture
    final currentPlayingSurah = ref.read(currentPlayingSurahProvider);
    final isAlreadyPlaying = currentPlayingSurah == widget.surahNumber;

    // Mettre à jour les informations de la sourate en cours (après le build)
    Future.microtask(() {
      ref.read(currentPlayingSurahProvider.notifier).state = widget.surahNumber;
      ref.read(currentPlayingSurahNameProvider.notifier).state =
          widget.surahName;
      ref.read(currentSurahTotalAyahsProvider.notifier).state =
          widget.totalAyahs;
    });

    // Écouter les streams
    playlistService.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    playlistService.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration ?? Duration.zero);
      }
    });

    playlistService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isLoading =
              state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
        });

        // Mettre à jour le provider global (après le build)
        Future.microtask(() {
          ref.read(isAudioPlayingProvider.notifier).state = state.playing;
        });

        if (_isPlaying) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }
      }
    });

    playlistService.currentIndexStream.listen((index) {
      if (mounted && index != null) {
        setState(() => _currentAyahIndex = index);

        // Pour onAyahChanged, on passe l'index de l'ayah réel (sans compter le Bismillah)
        // Si on a le Bismillah et qu'on est à l'index 0, on passe -1
        // Sinon on ajuste l'index pour exclure le Bismillah
        if (widget.hasBismillah) {
          if (index == 0) {
            // C'est le Bismillah, ne pas scroller aux ayahs
            widget.onAyahChanged?.call(-1);
          } else {
            // C'est un ayah, on ajuste l'index (index - 1)
            widget.onAyahChanged?.call(index - 1);
          }
        } else {
          // Pas de Bismillah, index normal
          widget.onAyahChanged?.call(index);
        }

        // Mettre à jour le provider (après le build)
        Future.microtask(() {
          ref.read(currentAyahIndexProvider.notifier).state = index;
        });
      }
    });

    // Charger la playlist SEULEMENT si c'est une nouvelle sourate
    if (!isAlreadyPlaying && widget.audioUrls.isNotEmpty) {
      try {
        setState(() => _isLoading = true);
        await playlistService.loadSurahPlaylist(widget.audioUrls);
      } catch (e) {
        debugPrint('Error loading playlist: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de chargement: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else if (isAlreadyPlaying) {
      // Si déjà en lecture, juste récupérer l'état actuel
      setState(() {
        _currentAyahIndex = playlistService.currentIndex;
        _isPlaying = playlistService.isPlaying;
        _position = playlistService.position;
        _duration = playlistService.duration ?? Duration.zero;
        _speed = playlistService.speed;
        _loopMode = playlistService.loopMode;
      });

      if (_isPlaying) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    // Ne pas disposer le service global, juste l'animation
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Retourne le texte de position actuelle (Bismillah ou Ayah X/Y)
  String _getCurrentPositionText() {
    if (widget.hasBismillah && _currentAyahIndex == 0) {
      return 'Bismillah - بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
    } else if (widget.hasBismillah) {
      // Ajuster l'index pour les sourates avec Bismillah
      return 'Ayah $_currentAyahIndex / ${widget.totalAyahs}';
    } else {
      // Pas de Bismillah (sourate 9)
      return 'Ayah ${_currentAyahIndex + 1} / ${widget.totalAyahs}';
    }
  }

  /// Vérifie si on peut passer au suivant
  bool _canSkipNext() {
    final totalItems = widget.hasBismillah
        ? widget.totalAyahs +
              1 // +1 pour le Bismillah
        : widget.totalAyahs;
    return _currentAyahIndex < totalItems - 1;
  }

  void _showSpeedMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSpeedSheet(),
    );
  }

  void _cycleLoopMode() {
    setState(() {
      if (_loopMode == LoopMode.off) {
        _loopMode = LoopMode.one; // Répéter verset actuel
      } else if (_loopMode == LoopMode.one) {
        _loopMode = LoopMode.all; // Répéter toute la sourate
      } else {
        _loopMode = LoopMode.off; // Désactiver
      }
    });
    final playlistService = ref.read(globalAudioPlaylistServiceProvider);
    playlistService.setLoopMode(_loopMode);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playlistService = ref.watch(globalAudioPlaylistServiceProvider);

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingLarge),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                colors: [
                  AppColors.darkCard,
                  AppColors.darkCard.withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppColors.headerGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppColors.goldGlow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre et info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.luxuryGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.headphones,
                  color: AppColors.luxuryGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.paddingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.surahName,
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getCurrentPositionText(),
                      style: TextStyle(
                        color: AppColors.pureWhite.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.paddingLarge),

          // Barre de progression
          Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  activeTrackColor: AppColors.luxuryGold,
                  inactiveTrackColor: AppColors.pureWhite.withOpacity(0.2),
                  thumbColor: AppColors.luxuryGold,
                  overlayColor: AppColors.luxuryGold.withOpacity(0.3),
                ),
                child: Slider(
                  value: _duration.inMilliseconds > 0
                      ? _position.inMilliseconds.toDouble()
                      : 0.0,
                  min: 0.0,
                  max: _duration.inMilliseconds > 0
                      ? _duration.inMilliseconds.toDouble()
                      : 1.0,
                  onChanged: (value) {
                    final service = ref.read(
                      globalAudioPlaylistServiceProvider,
                    );
                    service.seekBackward(
                      _position - Duration(milliseconds: value.toInt()),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.paddingMedium,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        color: AppColors.pureWhite.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        color: AppColors.pureWhite.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.paddingLarge),

          // Contrôles de lecture
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.skip_previous,
                onPressed: _currentAyahIndex > 0
                    ? () => playlistService.skipToPrevious()
                    : null,
                size: 32,
              ),
              _buildControlButton(
                icon: Icons.replay_10,
                onPressed: () =>
                    playlistService.seekBackward(const Duration(seconds: 10)),
                size: 28,
              ),
              // Bouton Play/Pause principal
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isPlaying ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldAccent,
                        shape: BoxShape.circle,
                        boxShadow: AppColors.goldGlow,
                      ),
                      child: _isLoading
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.deepBlue,
                                  ),
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: playlistService.togglePlayPause,
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 32,
                              ),
                              color: isDark
                                  ? AppColors.darkBackground
                                  : AppColors.deepBlue,
                              padding: EdgeInsets.zero,
                            ),
                    ),
                  );
                },
              ),
              _buildControlButton(
                icon: Icons.forward_10,
                onPressed: () =>
                    playlistService.seekForward(const Duration(seconds: 10)),
                size: 28,
              ),
              _buildControlButton(
                icon: Icons.skip_next,
                onPressed: _canSkipNext()
                    ? () => playlistService.skipToNext()
                    : null,
                size: 32,
              ),
            ],
          ),

          const SizedBox(height: AppTheme.paddingMedium),

          // Options supplémentaires
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOptionButton(
                icon: _getLoopIcon(),
                label: _getLoopLabel(),
                onPressed: _cycleLoopMode,
                isActive: _loopMode != LoopMode.off,
              ),
              _buildOptionButton(
                icon: Icons.speed,
                label: '${_speed}x',
                onPressed: _showSpeedMenu,
                isActive: _speed != 1.0,
              ),
              _buildOptionButton(
                icon: Icons.list,
                label: 'Versets',
                onPressed: () => _showAyahsList(),
                isActive: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getLoopIcon() {
    switch (_loopMode) {
      case LoopMode.off:
        return Icons.repeat;
      case LoopMode.one:
        return Icons.repeat_one;
      case LoopMode.all:
        return Icons.repeat_on;
    }
  }

  String _getLoopLabel() {
    switch (_loopMode) {
      case LoopMode.off:
        return 'Répéter';
      case LoopMode.one:
        return '1 verset';
      case LoopMode.all:
        return 'Tout';
    }
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required double size,
  }) {
    return Container(
      width: AppTheme.minTouchTarget,
      height: AppTheme.minTouchTarget,
      decoration: BoxDecoration(
        color: AppColors.pureWhite.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: size),
        color: onPressed != null
            ? AppColors.pureWhite
            : AppColors.pureWhite.withOpacity(0.3),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.paddingSmall),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.luxuryGold.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? AppColors.luxuryGold
                  : AppColors.pureWhite.withOpacity(0.8),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? AppColors.luxuryGold
                    : AppColors.pureWhite.withOpacity(0.8),
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedSheet() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.pureWhite,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Column(
              children: [
                Text(
                  'Vitesse de Lecture',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppTheme.paddingMedium),
                ...speeds.map((speed) {
                  final isSelected = _speed == speed;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.speed,
                      color: isSelected
                          ? AppColors.luxuryGold
                          : AppColors.textSecondary,
                    ),
                    title: Text('${speed}x'),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.luxuryGold)
                        : null,
                    selected: isSelected,
                    onTap: () {
                      setState(() => _speed = speed);
                      final playlistService = ref.read(
                        globalAudioPlaylistServiceProvider,
                      );
                      playlistService.setSpeed(speed);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAyahsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildAyahsListSheet(),
    );
  }

  Widget _buildAyahsListSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.pureWhite,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Row(
              children: [
                const Icon(Icons.list, color: AppColors.luxuryGold),
                const SizedBox(width: 8),
                Text(
                  'Liste des Versets',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.hasBismillah
                  ? widget.totalAyahs + 1
                  : widget.totalAyahs,
              itemBuilder: (context, index) {
                final isCurrentlyPlaying = index == _currentAyahIndex;

                // Afficher le Bismillah comme premier élément si nécessaire
                if (widget.hasBismillah && index == 0) {
                  return ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: isCurrentlyPlaying
                            ? AppColors.goldAccent
                            : null,
                        color: isCurrentlyPlaying
                            ? null
                            : AppColors.luxuryGold.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.book,
                          size: 16,
                          color: isCurrentlyPlaying
                              ? AppColors.deepBlue
                              : AppColors.luxuryGold,
                        ),
                      ),
                    ),
                    title: const Text('بِسْمِ اللَّهِ'),
                    subtitle: const Text(
                      'Bismillah',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: isCurrentlyPlaying && _isPlaying
                        ? const Icon(
                            Icons.volume_up,
                            color: AppColors.luxuryGold,
                          )
                        : null,
                    selected: isCurrentlyPlaying,
                    onTap: () {
                      final playlistService = ref.read(
                        globalAudioPlaylistServiceProvider,
                      );
                      playlistService.seekToAyah(0);
                      Navigator.pop(context);
                    },
                  );
                }

                // Calculer le numéro d'ayah réel
                final ayahNumber = widget.hasBismillah ? index : index + 1;

                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: isCurrentlyPlaying
                          ? AppColors.goldAccent
                          : null,
                      color: isCurrentlyPlaying
                          ? null
                          : AppColors.textTertiary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$ayahNumber',
                        style: TextStyle(
                          color: isCurrentlyPlaying
                              ? AppColors.deepBlue
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  title: Text('Ayah $ayahNumber'),
                  trailing: isCurrentlyPlaying && _isPlaying
                      ? const Icon(Icons.volume_up, color: AppColors.luxuryGold)
                      : null,
                  selected: isCurrentlyPlaying,
                  onTap: () {
                    final playlistService = ref.read(
                      globalAudioPlaylistServiceProvider,
                    );
                    playlistService.seekToAyah(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
