import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Widget de lecteur audio fonctionnel avec just_audio
class AudioPlayerController extends StatefulWidget {
  final String surahName;
  final List<String> audioUrls;
  final int currentAyahIndex;
  final Function(int)? onAyahChanged;

  const AudioPlayerController({
    super.key,
    required this.surahName,
    required this.audioUrls,
    this.currentAyahIndex = 0,
    this.onAyahChanged,
  });

  @override
  State<AudioPlayerController> createState() => _AudioPlayerControllerState();
}

class _AudioPlayerControllerState extends State<AudioPlayerController>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _audioPlayer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  int _currentIndex = 0;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentAyahIndex;
    _audioPlayer = AudioPlayer();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    // Écouter la durée
    _audioPlayer.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      }
    });

    // Écouter la position
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    // Écouter l'état de lecture
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isLoading =
              state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
        });

        if (_isPlaying) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }

        // Si terminé, passer au suivant
        if (state.processingState == ProcessingState.completed) {
          _playNext();
        }
      }
    });
  }

  Future<void> _loadAndPlay(int index) async {
    if (index < 0 || index >= widget.audioUrls.length) return;

    setState(() {
      _currentIndex = index;
      _isLoading = true;
    });

    try {
      await _audioPlayer.setUrl(widget.audioUrls[index]);
      await _audioPlayer.play();
      widget.onAyahChanged?.call(index);
    } catch (e) {
      debugPrint('Erreur chargement audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur de chargement audio'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_audioPlayer.duration == null) {
        // Première lecture
        await _loadAndPlay(_currentIndex);
      } else {
        await _audioPlayer.play();
      }
    }
  }

  Future<void> _playNext() async {
    if (_currentIndex < widget.audioUrls.length - 1) {
      await _loadAndPlay(_currentIndex + 1);
    } else {
      // Fin de la sourate
      await _audioPlayer.stop();
    }
  }

  Future<void> _playPrevious() async {
    if (_currentIndex > 0) {
      await _loadAndPlay(_currentIndex - 1);
    }
  }

  Future<void> _seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> _seekRelative(Duration offset) async {
    final newPosition = _position + offset;
    if (newPosition >= Duration.zero && newPosition <= _duration) {
      await _audioPlayer.seek(newPosition);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      'Ayah ${_currentIndex + 1} / ${widget.audioUrls.length}',
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
                    _seek(Duration(milliseconds: value.toInt()));
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
                onPressed: _currentIndex > 0 ? _playPrevious : null,
                size: 32,
              ),
              _buildControlButton(
                icon: Icons.replay_10,
                onPressed: () => _seekRelative(const Duration(seconds: -10)),
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
                          ? Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDark
                                        ? AppColors.darkBackground
                                        : AppColors.deepBlue,
                                  ),
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: _togglePlayPause,
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
                onPressed: () => _seekRelative(const Duration(seconds: 10)),
                size: 28,
              ),
              _buildControlButton(
                icon: Icons.skip_next,
                onPressed: _currentIndex < widget.audioUrls.length - 1
                    ? _playNext
                    : null,
                size: 32,
              ),
            ],
          ),
        ],
      ),
    );
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
}
