import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/audio_providers.dart';
import '../providers/quran_providers.dart';
import '../utils/surah_adapter.dart';
import '../screens/surah_detail_screen.dart';

/// Mini lecteur audio affiché en bas de l'écran d'accueil
class MiniAudioPlayer extends ConsumerStatefulWidget {
  const MiniAudioPlayer({super.key});

  @override
  ConsumerState<MiniAudioPlayer> createState() => _MiniAudioPlayerState();
}

class _MiniAudioPlayerState extends ConsumerState<MiniAudioPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: AppTheme.animationDuration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _slideController,
            curve: AppTheme.animationCurve,
          ),
        );

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPlaying = ref.watch(isAudioPlayingProvider);
    final currentAyahIndex = ref.watch(currentAyahIndexProvider);
    final surahName = ref.watch(currentPlayingSurahNameProvider);
    final totalAyahs = ref.watch(currentSurahTotalAyahsProvider);
    final playlistService = ref.watch(globalAudioPlaylistServiceProvider);

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(AppTheme.paddingMedium),
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  colors: [
                    AppColors.darkCard,
                    AppColors.darkCard.withOpacity(0.98),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : AppColors.headerGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: AppColors.luxuryGold.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              HapticFeedback.lightImpact();

              // Retourner à la sourate en cours de lecture
              final surahNumber = ref.read(currentPlayingSurahProvider);
              if (surahNumber != null) {
                // Récupérer les données de la sourate
                final surahsAsync = ref.read(surahsProvider);

                await surahsAsync.when(
                  data: (apiSurahs) async {
                    final allSurahs = SurahAdapter.fromApiModelList(apiSurahs);
                    final surah = allSurahs.firstWhere(
                      (s) => s.number == surahNumber,
                      orElse: () => allSurahs.first,
                    );

                    // Naviguer vers l'écran de détail
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  SurahDetailScreen(surah: surah),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                const begin = Offset(0.0, 1.0);
                                const end = Offset.zero;
                                const curve = Curves.easeInOut;

                                var tween = Tween(
                                  begin: begin,
                                  end: end,
                                ).chain(CurveTween(curve: curve));

                                return SlideTransition(
                                  position: animation.drive(tween),
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
                    }
                  },
                  loading: () {},
                  error: (error, stack) {},
                );
              }
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.paddingMedium,
                vertical: AppTheme.paddingSmall,
              ),
              child: Row(
                children: [
                  // Icône audio animée
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.luxuryGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPlaying ? Icons.graphic_eq : Icons.music_note,
                      color: AppColors.luxuryGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingMedium),

                  // Info sourate
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          surahName ?? 'Aucune sourate',
                          style: const TextStyle(
                            color: AppColors.pureWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ayah ${currentAyahIndex + 1} / $totalAyahs',
                          style: TextStyle(
                            color: AppColors.pureWhite.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bouton précédent
                  IconButton(
                    onPressed: currentAyahIndex > 0
                        ? () {
                            HapticFeedback.lightImpact();
                            playlistService.skipToPrevious();
                          }
                        : null,
                    icon: const Icon(Icons.skip_previous),
                    color: AppColors.pureWhite,
                    disabledColor: AppColors.pureWhite.withOpacity(0.3),
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),

                  // Bouton Play/Pause
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.luxuryGold.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        playlistService.togglePlayPause();
                      },
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 20,
                      ),
                      color: isDark
                          ? AppColors.darkBackground
                          : AppColors.deepBlue,
                      padding: EdgeInsets.zero,
                    ),
                  ),

                  // Bouton suivant
                  IconButton(
                    onPressed: currentAyahIndex < totalAyahs - 1
                        ? () {
                            HapticFeedback.lightImpact();
                            playlistService.skipToNext();
                          }
                        : null,
                    icon: const Icon(Icons.skip_next),
                    color: AppColors.pureWhite,
                    disabledColor: AppColors.pureWhite.withOpacity(0.3),
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),

                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
