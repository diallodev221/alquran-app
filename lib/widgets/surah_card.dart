import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/surah.dart';
import '../providers/favorites_providers.dart';

class SurahCard extends ConsumerStatefulWidget {
  final Surah surah;
  final VoidCallback onTap;
  final bool isLastRead;

  const SurahCard({
    super.key,
    required this.surah,
    required this.onTap,
    this.isLastRead = false,
  });

  @override
  ConsumerState<SurahCard> createState() => _SurahCardState();
}

class _SurahCardState extends ConsumerState<SurahCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.fastAnimation,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.animationCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Vérifier si cette sourate est en favori
    final isFavorite = ref.watch(isSurahFavoriteProvider(widget.surah.number));

    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        setState(() => _isHovered = true);
      },
      onTapUp: (_) {
        _controller.reverse();
        setState(() => _isHovered = false);
        widget.onTap();
      },
      onTapCancel: () {
        _controller.reverse();
        setState(() => _isHovered = false);
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: AppTheme.paddingMedium),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.pureWhite,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: _isHovered
                    ? AppColors.cardShadowHover
                    : AppColors.cardShadow,
                border: widget.isLastRead
                    ? Border.all(color: AppColors.luxuryGold, width: 2)
                    : null,
              ),
              child: Stack(
                children: [
                  // Badge "Dernière lecture" si applicable
                  if (widget.isLastRead)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.goldAccent,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(AppTheme.radiusMedium),
                            bottomLeft: Radius.circular(AppTheme.radiusMedium),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bookmark,
                              size: 14,
                              color: isDark
                                  ? AppColors.darkBackground
                                  : AppColors.deepBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'En cours',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkBackground
                                    : AppColors.deepBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Indicateur de favori (à gauche si pas "dernière lecture")
                  if (isFavorite && !widget.isLastRead)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.luxuryGold.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.luxuryGold.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.bookmark,
                          size: 16,
                          color: isDark
                              ? AppColors.darkBackground
                              : AppColors.pureWhite,
                        ),
                      ),
                    ),

                  // Contenu principal
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.paddingMedium),
                    child: Row(
                      children: [
                        // Numéro de la Surah avec style islamique
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: isDark
                                ? LinearGradient(
                                    colors: [
                                      AppColors.lightBlue,
                                      AppColors.lightBlue.withOpacity(0.7),
                                    ],
                                  )
                                : AppColors.headerGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '${widget.surah.number}',
                              style: const TextStyle(
                                color: AppColors.pureWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: AppTheme.paddingMedium),

                        // Informations de la Surah
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.surah.name,
                                style: Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.surah.revelationType} • ${widget.surah.numberOfAyahs} Ayahs',
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Nom arabe avec police Cairo
                        Flexible(
                          flex: 2,
                          child: Text(
                            widget.surah.arabicName,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.luxuryGold
                                  : AppColors.deepBlue,
                            ),
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            maxLines: 1,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
