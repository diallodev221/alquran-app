import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';

/// Mode de répétition
enum RepeatMode {
  none, // Pas de répétition
  one, // Répéter un seul ayah
  all, // Répéter toute la sourate
}

/// Widget audio player moderne et user-friendly
class AudioPlayerWidget extends StatefulWidget {
  final String surahName;
  final int currentAyah;
  final int totalAyahs;
  final Duration? currentPosition;
  final Duration? totalDuration;
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  final Function(double)? onSeek;
  final Function(double)? onSpeedChanged;
  final Function(RepeatMode)? onRepeatModeChanged;
  final VoidCallback? onBookmark;
  final bool isBookmarked;

  const AudioPlayerWidget({
    super.key,
    required this.surahName,
    required this.currentAyah,
    required this.totalAyahs,
    this.currentPosition,
    this.totalDuration,
    this.isPlaying = false,
    this.onPlayPause,
    this.onPrevious,
    this.onNext,
    this.onRewind,
    this.onForward,
    this.onSeek,
    this.onSpeedChanged,
    this.onRepeatModeChanged,
    this.onBookmark,
    this.isBookmarked = false,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;
  RepeatMode _repeatMode = RepeatMode.none;
  double _playbackSpeed = 1.0;
  bool _isDragging = false;
  double _dragProgress = 0.0;

  // Vitesses de lecture disponibles
  final List<double> _availableSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();

    // Animation de pulse pour le bouton play
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animation de vague pour l'indicateur de lecture
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Démarrer le pulse si en lecture
    if (widget.isPlaying) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mettre à jour l'animation selon l'état de lecture
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _pulseController.repeat(reverse: true);
        _waveController.repeat();
      } else {
        _pulseController.stop();
        _pulseController.reset();
        _waveController.stop();
        _waveController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  double get _progress {
    if (_isDragging) return _dragProgress;
    if (widget.currentPosition == null || widget.totalDuration == null) {
      return 0.0;
    }
    if (widget.totalDuration!.inMilliseconds == 0) return 0.0;
    return widget.currentPosition!.inMilliseconds /
        widget.totalDuration!.inMilliseconds;
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _toggleRepeatMode() {
    setState(() {
      switch (_repeatMode) {
        case RepeatMode.none:
          _repeatMode = RepeatMode.one;
          break;
        case RepeatMode.one:
          _repeatMode = RepeatMode.all;
          break;
        case RepeatMode.all:
          _repeatMode = RepeatMode.none;
          break;
      }
    });
    HapticFeedback.selectionClick();
    widget.onRepeatModeChanged?.call(_repeatMode);
  }

  void _showSpeedSelectorDialog() {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SpeedSelectorBottomSheet(
        currentSpeed: _playbackSpeed,
        availableSpeeds: _availableSpeeds,
        isDark: Theme.of(context).brightness == Brightness.dark,
        onSpeedSelected: (speed) {
          setState(() {
            _playbackSpeed = speed;
          });
          HapticFeedback.mediumImpact();
          widget.onSpeedChanged?.call(speed);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(
        ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingLarge,
          tablet: 24.0,
          desktop: 32.0,
        ),
      ),
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
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context, base: 24.0),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.luxuryGold.withOpacity(0.3),
            blurRadius: ResponsiveUtils.responsive(
              context,
              mobile: 20.0,
              tablet: 24.0,
              desktop: 28.0,
            ),
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header avec informations
          _buildHeader(isDark),

          SizedBox(
            height: ResponsiveUtils.adaptivePadding(
              context,
              mobile: 24.0,
              tablet: 28.0,
              desktop: 32.0,
            ),
          ),

          // Barre de progression améliorée
          _buildProgressBar(isDark),

          SizedBox(
            height: ResponsiveUtils.adaptivePadding(
              context,
              mobile: 24.0,
              tablet: 28.0,
              desktop: 32.0,
            ),
          ),

          // Contrôles principaux
          _buildMainControls(isDark),

          SizedBox(
            height: ResponsiveUtils.adaptivePadding(
              context,
              mobile: 20.0,
              tablet: 24.0,
              desktop: 28.0,
            ),
          ),

          // Options et contrôles secondaires
          _buildSecondaryControls(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        // Icône avec animation de vague si en lecture
        AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            if (!widget.isPlaying) return child!;
            return Container(
              padding: EdgeInsets.all(
                ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
              ),
              decoration: BoxDecoration(
                color: AppColors.luxuryGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.adaptiveBorderRadius(context, base: 12.0),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Onde animée
                  Opacity(
                    opacity: 0.3 + (0.2 * (_waveController.value % 1)),
                    child: Container(
                      width: ResponsiveUtils.responsive(
                        context,
                        mobile: 32.0,
                        tablet: 36.0,
                        desktop: 40.0,
                      ),
                      height: ResponsiveUtils.responsive(
                        context,
                        mobile: 32.0,
                        tablet: 36.0,
                        desktop: 40.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.luxuryGold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Icône
                  Icon(
                    Icons.headphones_rounded,
                    color: AppColors.luxuryGold,
                    size: ResponsiveUtils.adaptiveIconSize(context, base: 20.0),
                  ),
                ],
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(
              ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
            ),
            decoration: BoxDecoration(
              color: AppColors.luxuryGold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.adaptiveBorderRadius(context, base: 12.0),
              ),
            ),
            child: Icon(
              Icons.headphones_rounded,
              color: AppColors.luxuryGold,
              size: ResponsiveUtils.adaptiveIconSize(context, base: 20.0),
            ),
          ),
        ),
        SizedBox(width: ResponsiveUtils.adaptivePadding(context, mobile: 16.0)),
        // Informations de la sourate
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.surahName,
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(
                height: ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
              ),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 8.0,
                      ),
                      vertical: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 3.0,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.pureWhite.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.adaptiveBorderRadius(
                          context,
                          base: 8.0,
                        ),
                      ),
                    ),
                    child: Text(
                      'Ayah ${widget.currentAyah}',
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 11,
                          tablet: 12,
                          desktop: 13,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 8.0,
                    ),
                  ),
                  Text(
                    '• ${widget.totalAyahs} total',
                    style: TextStyle(
                      color: AppColors.pureWhite.withOpacity(0.7),
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Bouton bookmark
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onBookmark?.call();
            },
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.adaptiveBorderRadius(context, base: 12.0),
            ),
            child: Container(
              padding: EdgeInsets.all(
                ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
              ),
              decoration: BoxDecoration(
                color: widget.isBookmarked
                    ? AppColors.luxuryGold.withOpacity(0.3)
                    : AppColors.pureWhite.withOpacity(0.1),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.adaptiveBorderRadius(context, base: 12.0),
                ),
              ),
              child: Icon(
                widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: widget.isBookmarked
                    ? AppColors.luxuryGold
                    : AppColors.pureWhite,
                size: ResponsiveUtils.adaptiveIconSize(context, base: 22.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(bool isDark) {
    return Column(
      children: [
        // Slider personnalisé
        GestureDetector(
          onHorizontalDragStart: (details) {
            setState(() {
              _isDragging = true;
            });
          },
          onHorizontalDragUpdate: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final double width = box.size.width;
            final double dx = details.localPosition.dx;
            final double progress = (dx / width).clamp(0.0, 1.0);
            setState(() {
              _dragProgress = progress;
            });
          },
          onHorizontalDragEnd: (details) {
            setState(() {
              _isDragging = false;
            });
            widget.onSeek?.call(_dragProgress);
            HapticFeedback.selectionClick();
          },
          child: Container(
            height: ResponsiveUtils.responsive(
              context,
              mobile: 6.0,
              tablet: 7.0,
              desktop: 8.0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.adaptiveBorderRadius(context, base: 4.0),
              ),
              color: AppColors.pureWhite.withOpacity(0.2),
            ),
            child: Stack(
              children: [
                // Barre de progression
                FractionallySizedBox(
                  widthFactor: _progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.luxuryGold,
                          AppColors.luxuryGold.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.adaptiveBorderRadius(
                          context,
                          base: 4.0,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.luxuryGold.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                // Indicateur de position
                Positioned(
                  left: (_progress * 100).clamp(0.0, 100.0) - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: ResponsiveUtils.responsive(
                      context,
                      mobile: 12.0,
                      tablet: 14.0,
                      desktop: 16.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.pureWhite,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.luxuryGold.withOpacity(0.8),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: ResponsiveUtils.adaptivePadding(context, mobile: 8.0)),
        // Temps actuel et total
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(widget.currentPosition),
                style: TextStyle(
                  color: AppColors.pureWhite.withOpacity(0.8),
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 12,
                    tablet: 13,
                    desktop: 14,
                  ),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(widget.totalDuration),
                style: TextStyle(
                  color: AppColors.pureWhite.withOpacity(0.8),
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 12,
                    tablet: 13,
                    desktop: 14,
                  ),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainControls(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Previous
        _buildControlButton(
          icon: Icons.skip_previous_rounded,
          onPressed: widget.onPrevious,
          size: ResponsiveUtils.adaptiveIconSize(context, base: 28.0),
        ),
        // Rewind 10s
        _buildControlButton(
          icon: Icons.replay_10_rounded,
          onPressed: widget.onRewind,
          size: ResponsiveUtils.adaptiveIconSize(context, base: 24.0),
          label: '10',
        ),
        // Play/Pause principal
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isPlaying ? _pulseAnimation.value : 1.0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onPlayPause?.call();
                  },
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    width: ResponsiveUtils.responsive(
                      context,
                      mobile: 72.0,
                      tablet: 80.0,
                      desktop: 88.0,
                    ),
                    height: ResponsiveUtils.responsive(
                      context,
                      mobile: 72.0,
                      tablet: 80.0,
                      desktop: 88.0,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.luxuryGold,
                          AppColors.luxuryGold.withOpacity(0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.luxuryGold.withOpacity(0.5),
                          blurRadius: ResponsiveUtils.responsive(
                            context,
                            mobile: 16.0,
                            tablet: 20.0,
                            desktop: 24.0,
                          ),
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.pureWhite,
                      size: ResponsiveUtils.adaptiveIconSize(
                        context,
                        base: 36.0,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Forward 10s
        _buildControlButton(
          icon: Icons.forward_10_rounded,
          onPressed: widget.onForward,
          size: ResponsiveUtils.adaptiveIconSize(context, base: 24.0),
          label: '10',
        ),
        // Next
        _buildControlButton(
          icon: Icons.skip_next_rounded,
          onPressed: widget.onNext,
          size: ResponsiveUtils.adaptiveIconSize(context, base: 28.0),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required double size,
    String? label,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed != null
            ? () {
                HapticFeedback.lightImpact();
                onPressed();
              }
            : null,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context, base: 16.0),
        ),
        child: Container(
          width: ResponsiveUtils.responsive(
            context,
            mobile: 48.0,
            tablet: 52.0,
            desktop: 56.0,
          ),
          height: ResponsiveUtils.responsive(
            context,
            mobile: 48.0,
            tablet: 52.0,
            desktop: 56.0,
          ),
          decoration: BoxDecoration(
            color: AppColors.pureWhite.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.pureWhite.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: label != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppColors.pureWhite, size: size * 0.7),
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.pureWhite.withOpacity(0.8),
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 9,
                          tablet: 10,
                          desktop: 11,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Icon(icon, color: AppColors.pureWhite, size: size),
        ),
      ),
    );
  }

  Widget _buildSecondaryControls(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Repeat mode
        _buildSecondaryButton(
          icon: _getRepeatIcon(),
          label: _getRepeatLabel(),
          onPressed: _toggleRepeatMode,
          isActive: _repeatMode != RepeatMode.none,
        ),
        // Playback speed
        _buildSecondaryButton(
          icon: Icons.speed_rounded,
          label: '${_playbackSpeed}x',
          onPressed: _showSpeedSelectorDialog,
          isActive: _playbackSpeed != 1.0,
        ),
        // Share (placeholder)
        _buildSecondaryButton(
          icon: Icons.share_rounded,
          label: 'Partager',
          onPressed: () {
            HapticFeedback.lightImpact();
            // TODO: Implement share functionality
          },
        ),
      ],
    );
  }

  IconData _getRepeatIcon() {
    switch (_repeatMode) {
      case RepeatMode.none:
        return Icons.repeat_rounded;
      case RepeatMode.one:
        return Icons.repeat_one_rounded;
      case RepeatMode.all:
        return Icons.repeat_rounded;
    }
  }

  String _getRepeatLabel() {
    switch (_repeatMode) {
      case RepeatMode.none:
        return 'Répéter';
      case RepeatMode.one:
        return 'Un seul';
      case RepeatMode.all:
        return 'Tous';
    }
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context, base: 12.0),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.adaptivePadding(
              context,
              mobile: 16.0,
              tablet: 20.0,
              desktop: 24.0,
            ),
            vertical: ResponsiveUtils.adaptivePadding(
              context,
              mobile: 10.0,
              tablet: 12.0,
              desktop: 14.0,
            ),
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.luxuryGold.withOpacity(0.2)
                : AppColors.pureWhite.withOpacity(0.1),
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.adaptiveBorderRadius(context, base: 12.0),
            ),
            border: Border.all(
              color: isActive
                  ? AppColors.luxuryGold.withOpacity(0.5)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive
                    ? AppColors.luxuryGold
                    : AppColors.pureWhite.withOpacity(0.8),
                size: ResponsiveUtils.adaptiveIconSize(context, base: 20.0),
              ),
              SizedBox(
                height: ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
              ),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? AppColors.luxuryGold
                      : AppColors.pureWhite.withOpacity(0.8),
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 10,
                    tablet: 11,
                    desktop: 12,
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet pour sélectionner la vitesse de lecture
class _SpeedSelectorBottomSheet extends StatelessWidget {
  final double currentSpeed;
  final List<double> availableSpeeds;
  final bool isDark;
  final Function(double) onSpeedSelected;

  const _SpeedSelectorBottomSheet({
    required this.currentSpeed,
    required this.availableSpeeds,
    required this.isDark,
    required this.onSpeedSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 24.0),
          ),
          topRight: Radius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 24.0),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(
                top: ResponsiveUtils.adaptivePadding(context, mobile: 12.0),
              ),
              width: ResponsiveUtils.responsive(
                context,
                mobile: 40.0,
                tablet: 50.0,
                desktop: 60.0,
              ),
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.pureWhite.withOpacity(0.2)
                    : AppColors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(
                ResponsiveUtils.adaptivePadding(context, mobile: 24.0),
              ),
              child: Column(
                children: [
                  Text(
                    'Vitesse de lecture',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.pureWhite
                          : AppColors.textPrimary,
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 20,
                        tablet: 22,
                        desktop: 24,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    height: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 24.0,
                    ),
                  ),
                  // Liste des vitesses
                  Wrap(
                    spacing: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 12.0,
                    ),
                    runSpacing: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 12.0,
                    ),
                    alignment: WrapAlignment.center,
                    children: availableSpeeds.map((speed) {
                      final isSelected = speed == currentSpeed;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onSpeedSelected(speed),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.adaptiveBorderRadius(
                              context,
                              base: 16.0,
                            ),
                          ),
                          child: Container(
                            width: ResponsiveUtils.responsive(
                              context,
                              mobile: 80.0,
                              tablet: 90.0,
                              desktop: 100.0,
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 16.0,
                              ),
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: [
                                        AppColors.luxuryGold,
                                        AppColors.luxuryGold.withOpacity(0.8),
                                      ],
                                    )
                                  : null,
                              color: isSelected
                                  ? null
                                  : (isDark
                                        ? AppColors.darkCard
                                        : AppColors.ivory.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.adaptiveBorderRadius(
                                  context,
                                  base: 16.0,
                                ),
                              ),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.luxuryGold.withOpacity(0.5)
                                    : (isDark
                                          ? AppColors.pureWhite.withOpacity(0.1)
                                          : AppColors.deepBlue.withOpacity(
                                              0.2,
                                            )),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              '${speed}x',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.pureWhite
                                    : (isDark
                                          ? AppColors.pureWhite
                                          : AppColors.textPrimary),
                                fontSize: ResponsiveUtils.adaptiveFontSize(
                                  context,
                                  mobile: 16,
                                  tablet: 18,
                                  desktop: 20,
                                ),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
