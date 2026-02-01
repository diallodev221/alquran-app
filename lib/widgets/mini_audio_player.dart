import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/audio_providers.dart';
import '../providers/quran_providers.dart';
import '../providers/settings_providers.dart';
import '../utils/surah_adapter.dart';
import '../utils/responsive_utils.dart';
import '../screens/surah_detail_screen.dart';

/// Vitesses de lecture disponibles pour le mini player
const List<double> _playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// Mini lecteur audio affiché en bas de l'écran d'accueil ou de l'écran détail sourate
class MiniAudioPlayer extends ConsumerStatefulWidget {
  /// Si fourni, appelé au tap au lieu de naviguer vers la sourate en cours
  /// (utile quand le player est déjà affiché sur l'écran détail de la sourate)
  final VoidCallback? onTap;

  /// Contexte "sourate en cours d'affichage" (écran détail). Si fourni, le play
  /// démarre cette sourate quand aucune n'est en lecture ou qu'une autre est en lecture.
  final int? currentSurahNumber;
  final String? currentSurahName;
  final int? currentSurahTotalAyahs;
  /// Appelé pour charger et lancer la lecture de la sourate courante (currentSurah*).
  final Future<void> Function()? onPlayCurrentSurah;

  const MiniAudioPlayer({
    super.key,
    this.onTap,
    this.currentSurahNumber,
    this.currentSurahName,
    this.currentSurahTotalAyahs,
    this.onPlayCurrentSurah,
  });

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
    final playingSurahNumber = ref.watch(currentPlayingSurahProvider);
    final surahNameFromProvider = ref.watch(currentPlayingSurahNameProvider);
    final totalAyahsFromProvider = ref.watch(currentSurahTotalAyahsProvider);
    final playlistService = ref.watch(globalAudioPlaylistServiceProvider);

    // Sur l'écran détail: afficher la sourate en cours d'affichage si aucune en lecture
    final bool hasContextSurah = widget.currentSurahNumber != null &&
        widget.currentSurahName != null &&
        widget.currentSurahTotalAyahs != null &&
        widget.currentSurahTotalAyahs! > 0;
    final bool isThisSurahPlaying = playingSurahNumber == widget.currentSurahNumber;
    final String displayName = playingSurahNumber != null
        ? (surahNameFromProvider ?? '')
        : (hasContextSurah ? (widget.currentSurahName ?? 'Aucune sourate') : 'Aucune sourate');
    final int displayTotalAyahs = playingSurahNumber != null
        ? totalAyahsFromProvider
        : (hasContextSurah ? (widget.currentSurahTotalAyahs ?? 0) : 0);
    final int displayAyahIndex = playingSurahNumber != null ? currentAyahIndex : 0;
    final bool canStartThisSurah = hasContextSurah &&
        widget.onPlayCurrentSurah != null &&
        (playingSurahNumber == null || !isThisSurahPlaying);

    final playbackSpeed = ref.watch(playbackSpeedProvider);

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: EdgeInsets.all(
          ResponsiveUtils.adaptivePadding(context, mobile: 12.0, tablet: 14.0, desktop: 16.0),
        ),
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
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 16.0),
          ),
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
              if (widget.onTap != null) {
                widget.onTap!();
                return;
              }
              // Retourner à la sourate en cours de lecture
              final surahNumber = ref.read(currentPlayingSurahProvider);
              if (surahNumber != null) {
                final surahsAsync = ref.read(surahsProvider);
                await surahsAsync.when(
                  data: (apiSurahs) async {
                    if (apiSurahs.isEmpty) return;
                    final allSurahs = SurahAdapter.fromApiModelList(apiSurahs);
                    final matches =
                        allSurahs.where((s) => s.number == surahNumber).toList();
                    if (matches.isEmpty) return;
                    final surah = matches.first;
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
                            var tween = Tween(begin: begin, end: end)
                                .chain(CurveTween(curve: curve));
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
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.adaptiveBorderRadius(context, base: 16.0),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 12.0,
                  tablet: 14.0,
                  desktop: 16.0,
                ),
                vertical: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 10.0,
                  tablet: 12.0,
                  desktop: 14.0,
                ),
              ),
              child: Row(
                children: [
                  // Icône audio
                  Container(
                    padding: EdgeInsets.all(
                      ResponsiveUtils.adaptivePadding(context, mobile: 6.0, tablet: 8.0),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.luxuryGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPlaying ? Icons.graphic_eq : Icons.music_note,
                      color: AppColors.luxuryGold,
                      size: ResponsiveUtils.adaptiveIconSize(context, base: 20.0),
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.adaptivePadding(context, mobile: 10.0, tablet: 12.0),
                  ),

                  // Info sourate
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            color: AppColors.pureWhite,
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 14,
                              tablet: 15,
                              desktop: 16,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayTotalAyahs > 0
                              ? 'Ayah ${displayAyahIndex + 1} / $displayTotalAyahs'
                              : (canStartThisSurah
                                  ? 'Appuyez pour écouter'
                                  : 'Aucune sourate'),
                          style: TextStyle(
                            color: AppColors.pureWhite.withOpacity(0.75),
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 11,
                              tablet: 12,
                              desktop: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contrôles : Précédent | Play/Pause | Suivant | Vitesse
                  // Bouton précédent
                  IconButton(
                    onPressed: playingSurahNumber != null && currentAyahIndex > 0
                        ? () {
                            HapticFeedback.lightImpact();
                            playlistService.skipToPrevious();
                          }
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                    color: AppColors.pureWhite,
                    disabledColor: AppColors.pureWhite.withOpacity(0.35),
                    iconSize: ResponsiveUtils.adaptiveIconSize(context, base: 24.0),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: ResponsiveUtils.responsive(context, mobile: 36.0, tablet: 40.0, desktop: 44.0),
                      minHeight: ResponsiveUtils.responsive(context, mobile: 36.0, tablet: 40.0, desktop: 44.0),
                    ),
                  ),

                  // Bouton Play/Pause
                  Container(
                    width: ResponsiveUtils.responsive(context, mobile: 44.0, tablet: 48.0, desktop: 52.0),
                    height: ResponsiveUtils.responsive(context, mobile: 44.0, tablet: 48.0, desktop: 52.0),
                    margin: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.adaptivePadding(context, mobile: 4.0, tablet: 6.0),
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.luxuryGold.withOpacity(0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        if (canStartThisSurah && widget.onPlayCurrentSurah != null) {
                          await widget.onPlayCurrentSurah!();
                        } else {
                          playlistService.togglePlayPause();
                        }
                      },
                      icon: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: ResponsiveUtils.adaptiveIconSize(context, base: 24.0),
                      ),
                      color: isDark
                          ? AppColors.darkBackground
                          : AppColors.deepBlue,
                      padding: EdgeInsets.zero,
                    ),
                  ),

                  // Bouton suivant
                  IconButton(
                    onPressed: playingSurahNumber != null &&
                            currentAyahIndex < totalAyahsFromProvider - 1
                        ? () {
                            HapticFeedback.lightImpact();
                            playlistService.skipToNext();
                          }
                        : null,
                    icon: const Icon(Icons.skip_next_rounded),
                    color: AppColors.pureWhite,
                    disabledColor: AppColors.pureWhite.withOpacity(0.35),
                    iconSize: ResponsiveUtils.adaptiveIconSize(context, base: 24.0),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: ResponsiveUtils.responsive(context, mobile: 36.0, tablet: 40.0, desktop: 44.0),
                      minHeight: ResponsiveUtils.responsive(context, mobile: 36.0, tablet: 40.0, desktop: 44.0),
                    ),
                  ),

                  // Vitesse de lecture (après Suivant)
                  SizedBox(
                    width: ResponsiveUtils.adaptivePadding(context, mobile: 6.0, tablet: 8.0),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        final idx = _playbackSpeeds.indexOf(playbackSpeed);
                        final nextIdx = (idx + 1) % _playbackSpeeds.length;
                        final newSpeed = _playbackSpeeds[nextIdx];
                        await ref.read(playbackSpeedProvider.notifier).updateSpeed(newSpeed);
                        await playlistService.setSpeed(newSpeed);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Tooltip(
                        message: 'Vitesse: ${playbackSpeed}x — appuyez pour changer',
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.adaptivePadding(context, mobile: 8.0, tablet: 10.0),
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: playbackSpeed != 1.0
                                ? AppColors.luxuryGold.withOpacity(0.25)
                                : AppColors.pureWhite.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.pureWhite.withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.speed_rounded,
                                color: AppColors.pureWhite,
                                size: ResponsiveUtils.adaptiveIconSize(context, base: 16.0),
                              ),
                              SizedBox(
                                width: ResponsiveUtils.adaptivePadding(context, mobile: 4.0, tablet: 5.0),
                              ),
                              Text(
                                '${playbackSpeed == playbackSpeed.roundToDouble() ? playbackSpeed.toInt() : playbackSpeed}x',
                                style: TextStyle(
                                  color: AppColors.pureWhite,
                                  fontSize: ResponsiveUtils.adaptiveFontSize(
                                    context,
                                    mobile: 12,
                                    tablet: 13,
                                    desktop: 14,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
