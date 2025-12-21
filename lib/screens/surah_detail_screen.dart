import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/surah.dart';
import '../models/quran_models.dart';
import '../providers/quran_providers.dart';
import '../providers/audio_providers.dart';
import '../providers/favorites_providers.dart';
import '../utils/responsive_utils.dart';
import '../utils/surah_adapter.dart';

class SurahDetailScreen extends ConsumerStatefulWidget {
  final Surah surah;
  final int? initialAyahNumber; // Ayah initial à afficher
  final bool autoPlay; // Démarrer automatiquement la lecture

  const SurahDetailScreen({
    super.key,
    required this.surah,
    this.initialAyahNumber,
    this.autoPlay = false,
  });

  @override
  ConsumerState<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends ConsumerState<SurahDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false; // Afficher le bouton scroll to top
  int _currentAyahIndex =
      -1; // Index de l'ayah en cours de lecture (-1 = aucun)
  bool _showTranslation = false; // Toggle pour afficher/masquer la traduction
  bool _isAutoScrolling = false; // Prevent scroll conflicts
  bool _isAudioAutoScroll =
      false; // Flag pour distinguer les scrolls audio automatiques
  final Map<int, GlobalKey> _ayahKeys = {}; // Keys pour chaque ayah
  int? _highlightedAyahIndex; // Ayah temporairement mis en surbrillance
  bool _hasScrolledToInitialAyah =
      false; // Flag pour éviter les scrolls multiples
  DateTime? _lastManualScroll; // Dernier scroll manuel
  bool _shouldAutoScroll = true; // Autoriser l'auto-scroll
  bool _hasAutoPlayed = false; // Flag pour éviter les auto-plays multiples
  int? _lastHandledNextSurah; // Dernière sourate suivante traitée

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: AppTheme.animationDuration,
      vsync: this,
    );

    _scrollController.addListener(_onScroll);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Afficher le bouton scroll to top après 500px de scroll
    final shouldShow = _scrollController.offset > 500;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }

    // Détecter le scroll manuel (pas d'auto-scroll en cours)
    if (!_isAutoScrolling) {
      _lastManualScroll = DateTime.now();
      // Désactiver l'auto-scroll temporairement après un scroll manuel
      _shouldAutoScroll = false;
      // Réactiver après 3 secondes
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _shouldAutoScroll = true;
        }
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Obtenir ou créer une GlobalKey pour un ayah
  GlobalKey _getAyahKey(int index) {
    if (!_ayahKeys.containsKey(index)) {
      _ayahKeys[index] = GlobalKey();
    }
    return _ayahKeys[index]!;
  }

  /// Scroll vers un ayah avec précision maximale et feedback utilisateur amélioré
  void _scrollToAyah(int ayahIndex, {bool isAudioAutoScroll = false}) async {
    if (_isAutoScrolling || ayahIndex < 0) return;

    // Empêcher les scrolls multiples simultanés
    _isAutoScrolling = true;
    _isAudioAutoScroll = isAudioAutoScroll;

    try {
      // Haptic feedback doux pour indiquer le début du scroll (seulement pour scrolls manuels)
      if (!isAudioAutoScroll) {
        HapticFeedback.lightImpact();
      }

      // Mettre en surbrillance temporaire l'ayah cible immédiatement (seulement pour scrolls manuels)
      if (mounted && !isAudioAutoScroll) {
        setState(() => _highlightedAyahIndex = ayahIndex);
      }

      // Attendre que le widget soit construit avec sa key
      await Future.delayed(const Duration(milliseconds: 100));

      final ayahKey = _getAyahKey(ayahIndex);
      final ayahContext = ayahKey.currentContext;

      if (ayahContext != null && _scrollController.hasClients) {
        final RenderBox? renderBox =
            ayahContext.findRenderObject() as RenderBox?;

        if (renderBox != null) {
          final screenHeight = MediaQuery.of(context).size.height;
          final position = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;

          // Prendre en compte la barre audio minimisée
          final minimizedPlayerHeight = ResponsiveUtils.responsive(
            context,
            mobile: 70.0,
            tablet: 80.0,
            desktop: 90.0,
          );
          final appBarHeight = kToolbarHeight;
          final topOffset = appBarHeight + 50; // App bar + sub-app bar
          final bottomOffset = minimizedPlayerHeight + 20; // Player + marge

          // Zone visible optimale (en tenant compte des barres)
          final visibleTop = topOffset;
          final visibleBottom = screenHeight - bottomOffset;
          final visibleHeight = visibleBottom - visibleTop;
          // Position optimale centrée pour "step into" l'ayah (40% depuis le haut pour meilleur focus)
          final optimalCenter =
              visibleTop +
              (visibleHeight * 0.4); // 40% depuis le haut pour centrage optimal

          // Calculer la position de l'ayah
          final ayahTop = position.dy;
          final ayahBottom = position.dy + size.height;
          final ayahCenter = position.dy + (size.height / 2);
          final ayahHeight = size.height;

          // Vérifier si l'ayah est déjà dans la zone optimale avec tolérance réduite pour meilleur centrage
          final isInOptimalZone =
              ayahTop >= visibleTop &&
              ayahBottom <= visibleBottom &&
              (ayahCenter - optimalCenter).abs() <
                  visibleHeight * 0.1; // Tolérance réduite à 10%

          // Vérifier si l'ayah est partiellement visible
          final isPartiallyVisible =
              (ayahTop < visibleBottom && ayahBottom > visibleTop);

          // Calculer la distance de scroll nécessaire
          final scrollDistance = (ayahCenter - optimalCenter).abs();

          // Déterminer si l'ayah est au-dessus ou en dessous de la zone visible
          final isAbove = ayahBottom < visibleTop;
          final isBelow = ayahTop > visibleBottom;

          // Si déjà dans la zone optimale, pas besoin de scroller
          if (isInOptimalZone) {
            if (mounted) {
              await Future.delayed(const Duration(milliseconds: 200));
              if (!_isAudioAutoScroll) {
                HapticFeedback.selectionClick();
                await Future.delayed(const Duration(milliseconds: 2800));
              }
              setState(() {
                _highlightedAyahIndex = null;
                _isAutoScrolling = false;
                _isAudioAutoScroll = false;
              });
            }
            return;
          }

          // Calculer la durée du scroll basée sur la distance et la position
          int baseDuration;
          double alignment;

          // Calculer l'alignement optimal pour centrer l'ayah (0.4 = 40% depuis le haut)
          // Ajuster selon la hauteur de l'ayah pour un meilleur centrage
          final ayahHeightRatio = ayahHeight / visibleHeight;
          final baseAlignment =
              0.4; // Position de base à 40% pour centrage optimal

          // Ajuster l'alignement pour tenir compte de la hauteur de l'ayah
          if (ayahHeightRatio > 0.3) {
            // Ayah très grand, centrer légèrement plus haut
            alignment = baseAlignment - 0.05;
          } else if (ayahHeightRatio > 0.15) {
            // Ayah moyen, centrer normalement
            alignment = baseAlignment;
          } else {
            // Ayah petit, centrer légèrement plus bas pour meilleure visibilité
            alignment = baseAlignment + 0.05;
          }

          // Ajuster selon la direction pour un scroll plus naturel
          if (isPartiallyVisible) {
            // Si partiellement visible, scroll court et précis
            baseDuration = 400;
            // Ajustement fin selon la position
            if (isAbove) {
              alignment = (alignment - 0.05).clamp(0.0, 1.0);
            } else if (isBelow) {
              alignment = (alignment + 0.05).clamp(0.0, 1.0);
            }
          } else if (scrollDistance < screenHeight * 0.5) {
            // Distance courte
            baseDuration = 500;
          } else if (scrollDistance < screenHeight * 1.5) {
            // Distance moyenne
            baseDuration = 700;
          } else {
            // Distance longue
            baseDuration = 900;
          }

          // Ajustement final selon la direction pour "step into" l'ayah
          if (isAbove) {
            // Ayah au-dessus : aligner légèrement plus haut pour un effet de "descente" vers l'ayah
            alignment = (alignment - 0.03).clamp(0.15, 0.45);
          } else if (isBelow) {
            // Ayah en dessous : aligner légèrement plus bas pour un effet de "montée" vers l'ayah
            alignment = (alignment + 0.03).clamp(0.35, 0.5);
          }

          // Clamp final pour s'assurer que l'alignement reste dans des limites raisonnables
          alignment = alignment.clamp(0.15, 0.5);

          // Utiliser Scrollable.ensureVisible pour un scroll précis et fluide
          // Courbe plus douce pour un effet de "step into" plus naturel
          await Scrollable.ensureVisible(
            ayahContext,
            duration: Duration(milliseconds: baseDuration),
            curve: Curves
                .easeInOutCubic, // Courbe plus douce pour un effet plus naturel
            alignment: alignment,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          );

          // Vérifier que le scroll a réussi en vérifiant la position finale
          await Future.delayed(const Duration(milliseconds: 200));

          if (mounted) {
            // Recalculer la position après le scroll
            final finalRenderBox = ayahContext.findRenderObject() as RenderBox?;
            if (finalRenderBox != null) {
              final finalPosition = finalRenderBox.localToGlobal(Offset.zero);
              final finalCenter =
                  finalPosition.dy + (finalRenderBox.size.height / 2);
              final finalDistance = (finalCenter - optimalCenter).abs();

              // Si toujours pas bien positionné, faire un ajustement fin pour "step into"
              if (finalDistance > visibleHeight * 0.15) {
                // Ajustement fin avec courbe plus douce
                await Scrollable.ensureVisible(
                  ayahContext,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut, // Courbe douce pour l'ajustement fin
                  alignment: alignment,
                  alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
                );

                // Vérification finale après ajustement
                await Future.delayed(const Duration(milliseconds: 150));
                final finalRenderBox2 =
                    ayahContext.findRenderObject() as RenderBox?;
                if (finalRenderBox2 != null) {
                  final finalPosition2 = finalRenderBox2.localToGlobal(
                    Offset.zero,
                  );
                  final finalCenter2 =
                      finalPosition2.dy + (finalRenderBox2.size.height / 2);
                  final finalDistance2 = (finalCenter2 - optimalCenter).abs();

                  // Si encore besoin d'ajustement, micro-scroll final
                  if (finalDistance2 > visibleHeight * 0.1) {
                    await Scrollable.ensureVisible(
                      ayahContext,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      alignment: alignment,
                      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
                    );
                  }
                }
              }
            }
          }

          // Feedback haptic léger à la fin du scroll pour confirmer (seulement pour scrolls manuels)
          if (mounted && !_isAudioAutoScroll) {
            await Future.delayed(const Duration(milliseconds: 100));
            HapticFeedback.selectionClick();
          }
        } else {
          // Fallback si le renderBox n'est pas disponible
          await _scrollToAyahEstimated(ayahIndex);
        }
      } else {
        // Fallback: utiliser l'estimation si la clé n'est pas disponible
        await _scrollToAyahEstimated(ayahIndex);
      }

      // Maintenir le highlight pendant 3 secondes pour une meilleure visibilité (seulement pour scrolls manuels)
      if (!_isAudioAutoScroll) {
        await Future.delayed(const Duration(milliseconds: 3000));
      }

      if (mounted) {
        setState(() {
          _highlightedAyahIndex = null;
          _isAutoScrolling = false;
          _isAudioAutoScroll = false;
        });
      }
    } catch (e) {
      debugPrint('Scroll error: $e');
      // Fallback en cas d'erreur avec feedback visuel
      if (mounted) {
        try {
          await _scrollToAyahEstimated(ayahIndex);
          // Maintenir le highlight même en cas d'erreur
          await Future.delayed(const Duration(milliseconds: 2000));
        } catch (fallbackError) {
          debugPrint('Fallback scroll error: $fallbackError');
        }

        setState(() {
          _highlightedAyahIndex = null;
          _isAutoScrolling = false;
          _isAudioAutoScroll = false;
        });
      }
    } finally {
      // S'assurer que le flag est réinitialisé même en cas d'erreur
      if (mounted && _isAutoScrolling) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _isAutoScrolling = false;
              _isAudioAutoScroll = false;
            });
          }
        });
      }
    }
  }

  /// Fallback: scroll basé sur estimation avec calcul amélioré
  Future<void> _scrollToAyahEstimated(int ayahIndex) async {
    if (!_scrollController.hasClients) return;

    try {
      final screenHeight = MediaQuery.of(context).size.height;

      // Prendre en compte toutes les hauteurs de manière précise
      final appBarHeight = kToolbarHeight;
      final subAppBarHeight = ResponsiveUtils.responsive(
        context,
        mobile: 40.0,
        tablet: 45.0,
        desktop: 50.0,
      );
      final headerHeight = ResponsiveUtils.responsive(
        context,
        mobile: 280.0,
        tablet: 320.0,
        desktop: 360.0,
      );
      final bismillahHeight = widget.surah.number != 9
          ? ResponsiveUtils.responsive(
              context,
              mobile: 120.0,
              tablet: 140.0,
              desktop: 160.0,
            )
          : 0.0;
      final audioPlayerButtonHeight = ResponsiveUtils.responsive(
        context,
        mobile: 80.0,
        tablet: 90.0,
        desktop: 100.0,
      );
      final minimizedPlayerHeight = ResponsiveUtils.responsive(
        context,
        mobile: 70.0,
        tablet: 80.0,
        desktop: 90.0,
      );

      // Estimation plus précise de la hauteur des ayahs
      final averageAyahHeight = _showTranslation
          ? ResponsiveUtils.responsive(
              context,
              mobile: 280.0,
              tablet: 320.0,
              desktop: 360.0,
            )
          : ResponsiveUtils.responsive(
              context,
              mobile: 200.0,
              tablet: 240.0,
              desktop: 280.0,
            );

      // Calculer l'offset cible avec centrage vertical optimisé
      final baseOffset =
          appBarHeight +
          subAppBarHeight +
          headerHeight +
          audioPlayerButtonHeight +
          bismillahHeight;
      final ayahOffset = ayahIndex * averageAyahHeight;

      // Zone visible optimale (en tenant compte de la barre audio)
      final visibleTop = appBarHeight + subAppBarHeight;
      final visibleBottom = screenHeight - minimizedPlayerHeight;
      final visibleHeight = visibleBottom - visibleTop;
      final optimalCenter =
          visibleTop +
          (visibleHeight * 0.4); // 40% depuis le haut pour meilleur centrage

      // Position cible de l'ayah
      final ayahTargetTop = baseOffset + ayahOffset;
      final ayahTargetCenter = ayahTargetTop + (averageAyahHeight / 2);

      // Calculer l'offset pour centrer l'ayah
      final targetOffset = ayahTargetCenter - optimalCenter;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final minScroll = _scrollController.position.minScrollExtent;
      final safeOffset = targetOffset.clamp(minScroll, maxScroll);

      // Calculer la distance pour déterminer la durée
      final currentOffset = _scrollController.offset;
      final distance = (safeOffset - currentOffset).abs();

      // Durée adaptative basée sur la distance
      final duration = distance < screenHeight * 0.5
          ? 500
          : distance < screenHeight * 1.5
          ? 700
          : distance < screenHeight * 2.5
          ? 900
          : 1100;

      // Vérifier si le scroll est nécessaire
      if (distance < 50) {
        // Déjà très proche, pas besoin de scroller
        return;
      }

      await _scrollController.animateTo(
        safeOffset,
        duration: Duration(milliseconds: duration),
        curve: Curves.easeOutCubic,
      );

      // Ajustement fin après le scroll principal
      await Future.delayed(Duration(milliseconds: duration + 100));

      if (_scrollController.hasClients) {
        final finalOffset = _scrollController.offset;
        final finalDistance = (safeOffset - finalOffset).abs();

        // Si l'ajustement est nécessaire, faire un micro-scroll
        if (finalDistance > 100) {
          await _scrollController.animateTo(
            safeOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (e) {
      debugPrint('Estimated scroll error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surahDetailAsync = ref.watch(
      surahDetailProvider(widget.surah.number),
    );

    // Observer l'état des favoris pour cette sourate
    final isSurahFavorite = ref.watch(
      isSurahFavoriteProvider(widget.surah.number),
    );

    // Observer l'ayah en cours de lecture et la sourate
    final currentPlayingSurah = ref.watch(currentPlayingSurahProvider);
    final currentAyahIndexFromProvider = ref.watch(currentAyahIndexProvider);
    final isAudioPlaying = ref.watch(isAudioPlayingProvider);
    final isThisSurahPlaying = currentPlayingSurah == widget.surah.number;

    // Observer la demande de lecture de la sourate suivante (auto-play)
    final shouldPlayNextSurah = ref.watch(shouldPlayNextSurahProvider);

    // Mettre à jour l'index de l'ayah en cours si cette sourate est en lecture
    if (isThisSurahPlaying) {
      // Convertir l'index du provider en index local (0-based)
      final newAyahIndex = widget.surah.number == 9
          ? currentAyahIndexFromProvider
          : (currentAyahIndexFromProvider > 0
                ? currentAyahIndexFromProvider - 1
                : 0);

      if (_currentAyahIndex != newAyahIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _currentAyahIndex = newAyahIndex;
            });

            // Auto-scroll vers l'ayah en cours si l'audio est en lecture
            // Seulement si l'auto-scroll est autorisé et pas de scroll manuel récent
            if (isAudioPlaying &&
                !_isAutoScrolling &&
                _shouldAutoScroll &&
                (_lastManualScroll == null ||
                    DateTime.now().difference(_lastManualScroll!).inSeconds >
                        2)) {
              surahDetailAsync.whenData((surahDetail) {
                if (newAyahIndex >= 0 &&
                    newAyahIndex < surahDetail.numberOfAyahs) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted && !_isAutoScrolling && _shouldAutoScroll) {
                      _scrollToAyah(newAyahIndex, isAudioAutoScroll: true);
                    }
                  });
                }
              });
            }
          }
        });
      }
    } else if (!isThisSurahPlaying && _currentAyahIndex != -1) {
      // Réinitialiser si cette sourate n'est plus en lecture
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentAyahIndex = -1;
          });
        }
      });
    }

    // Si autoPlay est activé, démarrer automatiquement la lecture
    if (widget.autoPlay && !_hasAutoPlayed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hasAutoPlayed && mounted) {
          _hasAutoPlayed = true;

          // Attendre que les données de la sourate soient chargées
          surahDetailAsync.whenData((surahDetail) async {
            if (!mounted) return;

            // Attendre un court délai pour s'assurer que les données sont prêtes
            await Future.delayed(const Duration(milliseconds: 400));
            if (!mounted) return;

            // Attendre que les URLs audio soient chargées
            final audioUrlsAsync = ref.read(
              surahAudioUrlsProvider(widget.surah.number),
            );

            audioUrlsAsync.whenData((audioUrls) async {
              if (!mounted || audioUrls.isEmpty) return;

              try {
                final playlistService = ref.read(
                  globalAudioPlaylistServiceProvider,
                );

                // Attendre un court délai supplémentaire pour s'assurer que tout est prêt
                await Future.delayed(const Duration(milliseconds: 200));
                if (!mounted) return;

                // Charger la nouvelle playlist
                await playlistService.loadSurahPlaylist(audioUrls);

                // Mettre à jour les providers
                ref.read(currentPlayingSurahProvider.notifier).state =
                    widget.surah.number;
                ref.read(currentPlayingSurahNameProvider.notifier).state =
                    widget.surah.name;
                ref.read(currentSurahTotalAyahsProvider.notifier).state =
                    surahDetail.numberOfAyahs;

                // Démarrer automatiquement la lecture
                await playlistService.play();
              } catch (e) {
                debugPrint('Error auto-playing surah: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur de démarrage automatique: $e'),
                      backgroundColor: AppColors.error,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            });
          });
        }
      });
    }

    // Si un ayah initial est spécifié et les données sont chargées, scroller vers lui
    surahDetailAsync.whenData((surahDetail) {
      if (!_hasScrolledToInitialAyah &&
          widget.initialAyahNumber != null &&
          widget.initialAyahNumber! > 0 &&
          widget.initialAyahNumber! <= surahDetail.numberOfAyahs) {
        _hasScrolledToInitialAyah = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted && !_isAutoScrolling) {
              _scrollToAyah(widget.initialAyahNumber! - 1);
            }
          });
        });
      }
    });

    // Gérer la navigation automatique vers la sourate suivante quand la sourate actuelle se termine
    // Vérifier que la sourate suivante à jouer est bien celle qui suit la sourate actuelle de l'écran
    if (shouldPlayNextSurah != null &&
        shouldPlayNextSurah != _lastHandledNextSurah &&
        shouldPlayNextSurah == widget.surah.number + 1) {
      // La sourate suivante doit être jouée et c'est la sourate qui suit celle actuelle
      // Cela signifie que la sourate actuelle vient de se terminer
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _lastHandledNextSurah == shouldPlayNextSurah) return;

        _lastHandledNextSurah = shouldPlayNextSurah;

        // Récupérer la liste des sourates pour trouver la suivante
        final surahsAsync = ref.read(surahsProvider);
        await surahsAsync.whenData((surahs) async {
          if (!mounted) return;

          final nextSurahIndex = surahs.indexWhere(
            (s) => s.number == shouldPlayNextSurah,
          );

          if (nextSurahIndex >= 0 && nextSurahIndex < surahs.length) {
            final nextSurahModel = surahs[nextSurahIndex];
            final nextSurah = SurahAdapter.fromApiModel(nextSurahModel);

            // Réinitialiser le provider pour éviter les déclenchements multiples
            ref.read(shouldPlayNextSurahProvider.notifier).state = null;

            // Naviguer vers la sourate suivante avec auto-play activé
            if (mounted) {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      SurahDetailScreen(surah: nextSurah, autoPlay: true),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;
                        var tween = Tween(
                          begin: begin,
                          end: end,
                        ).chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);
                        return SlideTransition(
                          position: offsetAnimation,
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
          }
        });
      });
    }

    return Scaffold(
      body: surahDetailAsync.when(
        data: (surahDetail) =>
            _buildContent(surahDetail, isDark, isSurahFavorite),
        loading: () => _buildLoadingState(isDark),
        error: (error, stack) => _buildErrorState(error, isDark),
      ),
    );
  }

  Widget _buildContent(
    SurahDetailModel surahDetail,
    bool isDark,
    bool isSurahFavorite,
  ) {
    // Récupérer les URLs audio depuis l'API audio
    final audioUrlsAsync = ref.watch(
      surahAudioUrlsProvider(widget.surah.number),
    );

    return Stack(
      children: [
        // Contenu principal
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            // App Bar amélioré - Responsive
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.deepBlue,
              leading: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    margin: EdgeInsets.all(
                      ResponsiveUtils.adaptivePadding(context, mobile: 8.0),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.pureWhite.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: AppColors.pureWhite,
                      size: ResponsiveUtils.adaptiveIconSize(
                        context,
                        base: 20.0,
                      ),
                    ),
                  ),
                ),
              ),
              title: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showSurahSelector(context, isDark);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.surah.number}. ${widget.surah.name}',
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 17,
                          tablet: 19,
                          desktop: 21,
                        ),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(
                      width: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 6.0,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(
                        ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pureWhite.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.pureWhite,
                        size: ResponsiveUtils.adaptiveIconSize(
                          context,
                          base: 18.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              centerTitle: true,
              actions: [
                // Translation toggle - Responsive
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _showTranslation = !_showTranslation;
                      });
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      margin: EdgeInsets.all(
                        ResponsiveUtils.adaptivePadding(context, mobile: 8.0),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.adaptivePadding(
                          context,
                          mobile: 12.0,
                          tablet: 14.0,
                          desktop: 16.0,
                        ),
                        vertical: ResponsiveUtils.adaptivePadding(
                          context,
                          mobile: 8.0,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: _showTranslation
                            ? AppColors.luxuryGold.withOpacity(0.25)
                            : AppColors.pureWhite.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _showTranslation
                              ? AppColors.luxuryGold.withOpacity(0.5)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showTranslation
                                ? Icons.translate
                                : Icons.translate_outlined,
                            color: _showTranslation
                                ? AppColors.luxuryGold
                                : AppColors.pureWhite,
                            size: ResponsiveUtils.adaptiveIconSize(
                              context,
                              base: 18.0,
                            ),
                          ),
                          if (_showTranslation) ...[
                            SizedBox(
                              width: ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 4.0,
                              ),
                            ),
                            Text(
                              'FR',
                              style: TextStyle(
                                color: AppColors.luxuryGold,
                                fontSize: ResponsiveUtils.adaptiveFontSize(
                                  context,
                                  mobile: 11,
                                  tablet: 12,
                                  desktop: 13,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Settings icon - Responsive
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.adaptiveBorderRadius(
                                context,
                                base: 20.0,
                              ),
                            ),
                          ),
                          title: const Text('Settings'),
                          content: const Text(
                            'Settings options will be available here.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      margin: EdgeInsets.all(
                        ResponsiveUtils.adaptivePadding(context, mobile: 8.0),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pureWhite.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.tune,
                        color: AppColors.pureWhite,
                        size: ResponsiveUtils.adaptiveIconSize(
                          context,
                          base: 20.0,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
                ),
              ],
            ),

            // Sub-app bar avec info contextuelle améliorée - Responsive
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.deepBlue,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.pureWhite.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 20.0,
                    tablet: 32.0,
                    desktop: 48.0,
                  ),
                  vertical: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 10.0,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveUtils.maxContentWidth(context),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: ResponsiveUtils.adaptiveIconSize(
                            context,
                            base: 14.0,
                          ),
                          color: AppColors.pureWhite.withOpacity(0.7),
                        ),
                        SizedBox(
                          width: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 8.0,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _getContextualInfo(widget.surah.number),
                            style: TextStyle(
                              color: AppColors.pureWhite.withOpacity(0.85),
                              fontSize: ResponsiveUtils.adaptiveFontSize(
                                context,
                                mobile: 12,
                                tablet: 13,
                                desktop: 14,
                              ),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Header amélioré avec cercle et titre - Responsive
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBackground
                      : AppColors.pureWhite,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.pureWhite.withOpacity(0.05)
                          : AppColors.deepBlue.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 40.0,
                    tablet: 48.0,
                    desktop: 56.0,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveUtils.maxContentWidth(context),
                    ),
                    child: Column(
                      children: [
                        // Cercle avec numéro de surah amélioré - Responsive
                        Container(
                          width: ResponsiveUtils.responsive(
                            context,
                            mobile: 90.0,
                            tablet: 110.0,
                            desktop: 130.0,
                          ),
                          height: ResponsiveUtils.responsive(
                            context,
                            mobile: 90.0,
                            tablet: 110.0,
                            desktop: 130.0,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.deepBlue,
                                AppColors.deepBlue.withOpacity(0.8),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.deepBlue.withOpacity(0.3),
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
                          child: Center(
                            child: Text(
                              '${widget.surah.number}',
                              style: TextStyle(
                                color: AppColors.pureWhite,
                                fontSize: ResponsiveUtils.adaptiveFontSize(
                                  context,
                                  mobile: 36,
                                  tablet: 44,
                                  desktop: 52,
                                ),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 20.0,
                            tablet: 24.0,
                            desktop: 28.0,
                          ),
                        ),
                        // Titre arabe
                        Text(
                          widget.surah.arabicName,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 32,
                              tablet: 38,
                              desktop: 44,
                            ),
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.luxuryGold
                                : AppColors.deepBlue,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                        ),
                        SizedBox(
                          height: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 12.0,
                          ),
                        ),
                        // Titre français
                        Text(
                          widget.surah.name,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 22,
                              tablet: 26,
                              desktop: 30,
                            ),
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.pureWhite
                                : AppColors.deepBlue,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(
                          height: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 6.0,
                          ),
                        ),
                        // Traduction
                        Text(
                          widget.surah.meaning,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 15,
                              tablet: 17,
                              desktop: 19,
                            ),
                            color: isDark
                                ? AppColors.pureWhite.withOpacity(0.7)
                                : AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bouton pour ouvrir le lecteur audio (remplace le player inline)
            SliverToBoxAdapter(
              child: Container(
                color: isDark ? AppColors.darkBackground : AppColors.pureWhite,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingMedium,
                    tablet: 32.0,
                    desktop: 48.0,
                  ),
                  vertical: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingMedium,
                    tablet: 24.0,
                    desktop: 32.0,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveUtils.maxContentWidth(context),
                    ),
                    child: audioUrlsAsync.when(
                      data: (audioUrls) {
                        if (audioUrls.isEmpty) {
                          return _buildNoAudioCard(isDark);
                        }
                        return _buildAudioPlayerButton(
                          isDark,
                          audioUrls,
                          surahDetail.numberOfAyahs,
                        );
                      },
                      loading: () => _buildAudioLoadingCard(isDark),
                      error: (error, stack) => _buildAudioErrorCard(isDark),
                    ),
                  ),
                ),
              ),
            ),

            // Contenu principal - Texte continu avec ayahs intégrés - Responsive
            SliverToBoxAdapter(
              child: Container(
                color: isDark ? AppColors.darkBackground : AppColors.pureWhite,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingLarge,
                    tablet: 32.0,
                    desktop: 48.0,
                  ),
                  vertical: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingXLarge,
                    tablet: 40.0,
                    desktop: 56.0,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveUtils.maxContentWidth(context),
                    ),
                    child: _buildContinuousAyahsText(surahDetail, isDark),
                  ),
                ),
              ),
            ),

            // Espacement en bas - Ajusté pour la barre audio fixe
            SliverToBoxAdapter(
              child: SizedBox(
                height: ResponsiveUtils.responsive(
                  context,
                  mobile: 90.0,
                  tablet: 100.0,
                  desktop: 110.0,
                ),
              ),
            ),
          ],
        ),

        // Indicateur de scroll vers ayah amélioré (seulement pour scrolls manuels, pas pour audio)
        if (_isAutoScrolling &&
            _highlightedAyahIndex != null &&
            !_isAudioAutoScroll)
          Positioned(
            top: ResponsiveUtils.responsive(
              context,
              mobile: 100.0,
              tablet: 120.0,
              desktop: 140.0,
            ),
            left: 0,
            right: 0,
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final clampedValue = value.clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, -30 * (1 - clampedValue)),
                    child: Opacity(
                      opacity: clampedValue,
                      child: Transform.scale(
                        scale: 0.9 + (0.1 * clampedValue),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 24.0,
                              tablet: 28.0,
                              desktop: 32.0,
                            ),
                            vertical: ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 16.0,
                              tablet: 18.0,
                              desktop: 20.0,
                            ),
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
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.adaptiveBorderRadius(
                                context,
                                base: 32.0,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.luxuryGold.withOpacity(0.7),
                                blurRadius: ResponsiveUtils.responsive(
                                  context,
                                  mobile: 24.0,
                                  tablet: 28.0,
                                  desktop: 32.0,
                                ),
                                spreadRadius: 3,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icône animée avec pulse
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 1.0, end: 1.2),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeInOut,
                                builder: (context, scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.pureWhite.withOpacity(
                                          0.25,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.my_location,
                                        color: AppColors.pureWhite,
                                        size: 20,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(
                                width: ResponsiveUtils.adaptivePadding(
                                  context,
                                  mobile: 14.0,
                                  tablet: 16.0,
                                  desktop: 18.0,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Ayah ${(_highlightedAyahIndex ?? 0) + 1}',
                                    style: TextStyle(
                                      color: AppColors.pureWhite,
                                      fontSize:
                                          ResponsiveUtils.adaptiveFontSize(
                                            context,
                                            mobile: 17,
                                            tablet: 19,
                                            desktop: 21,
                                          ),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: ResponsiveUtils.adaptivePadding(
                                      context,
                                      mobile: 2.0,
                                    ),
                                  ),
                                  Text(
                                    'Navigation en cours...',
                                    style: TextStyle(
                                      color: AppColors.pureWhite.withOpacity(
                                        0.95,
                                      ),
                                      fontSize:
                                          ResponsiveUtils.adaptiveFontSize(
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // Fixed Audio Player en bas - Responsive
        _buildFixedBottomAudioPlayer(
          isDark,
          audioUrlsAsync,
          surahDetail.numberOfAyahs,
        ),

        // Bouton Scroll to Top amélioré - Responsive
        // Ajuster la position selon la barre audio fixe
        if (_showScrollToTop)
          Positioned(
            bottom: ResponsiveUtils.responsive(
              context,
              mobile: 90.0, // Ajusté pour la barre audio fixe
              tablet: 100.0,
              desktop: 110.0,
            ),
            right: ResponsiveUtils.adaptivePadding(
              context,
              mobile: 20.0,
              tablet: 32.0,
              desktop: 48.0,
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: _showScrollToTop ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                // Clamp values to prevent opacity assertion errors
                final clampedOpacity = value.clamp(0.0, 1.0);
                final clampedScale = value.clamp(0.0, 1.0);
                return Transform.scale(
                  scale: clampedScale,
                  child: Opacity(
                    opacity: clampedOpacity,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _scrollToTop();
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: ResponsiveUtils.responsive(
                            context,
                            mobile: 56.0,
                            tablet: 64.0,
                            desktop: 72.0,
                          ),
                          height: ResponsiveUtils.responsive(
                            context,
                            mobile: 56.0,
                            tablet: 64.0,
                            desktop: 72.0,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.luxuryGold,
                                AppColors.luxuryGold.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
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
                            Icons.keyboard_arrow_up_rounded,
                            color: AppColors.pureWhite,
                            size: ResponsiveUtils.adaptiveIconSize(
                              context,
                              base: 28.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDark ? AppColors.luxuryGold : AppColors.deepBlue,
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement de ${widget.surah.name}...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingXLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(surahDetailProvider(widget.surah.number));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }

  String _getContextualInfo(int surahNumber) {
    // Simple calculation for Juz/Hizb/Page/Ruku
    // This is a simplified version - in a real app, you'd have a proper mapping
    int juz = 1;
    int hizb = 1;
    int page = 1;
    int ruku = 1;

    // Rough calculation (this should be replaced with proper data)
    if (surahNumber <= 2) {
      juz = 1;
      hizb = 1;
      page = 1;
      ruku = 1;
    } else if (surahNumber <= 5) {
      juz = 1;
      hizb = 1;
      page = 2;
      ruku = 2;
    }

    return 'Juz $juz, Hizb $hizb : Page $page : Ruku $ruku';
  }

  Widget _buildContinuousAyahsText(SurahDetailModel surahDetail, bool isDark) {
    // Bismillah pour toutes les sourates sauf At-Tawbah
    final bismillah = widget.surah.number != 9
        ? 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bismillah si applicable - Design amélioré - Responsive
        if (bismillah.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveUtils.adaptivePadding(
                context,
                mobile: 24.0,
                tablet: 28.0,
                desktop: 32.0,
              ),
              horizontal: ResponsiveUtils.adaptivePadding(
                context,
                mobile: 16.0,
                tablet: 24.0,
                desktop: 32.0,
              ),
            ),
            margin: EdgeInsets.only(
              bottom: ResponsiveUtils.adaptivePadding(
                context,
                mobile: 32.0,
                tablet: 40.0,
                desktop: 48.0,
              ),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppColors.luxuryGold.withOpacity(0.15),
                        AppColors.luxuryGold.withOpacity(0.05),
                      ]
                    : [
                        AppColors.luxuryGold.withOpacity(0.1),
                        AppColors.luxuryGold.withOpacity(0.03),
                      ],
              ),
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.adaptiveBorderRadius(context, base: 20.0),
              ),
              border: Border.all(
                color: AppColors.luxuryGold.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Text(
              bismillah,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: ResponsiveUtils.adaptiveFontSize(
                  context,
                  mobile: 30,
                  tablet: 36,
                  desktop: 42,
                ),
                height: 2.2,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.luxuryGold : AppColors.deepBlue,
                letterSpacing: ResponsiveUtils.responsive(
                  context,
                  mobile: 2.0,
                  tablet: 3.0,
                  desktop: 4.0,
                ),
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
          ),
        ],

        // Texte continu avec ayahs intégrés
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text.rich(
            TextSpan(children: _buildAyahSpans(surahDetail, isDark)),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
          ),
        ),

        // Traductions si activées - Design amélioré - Responsive
        if (_showTranslation) ...[
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(
              context,
              mobile: 40.0,
              tablet: 48.0,
              desktop: 56.0,
            ),
          ),
          Container(
            padding: EdgeInsets.all(
              ResponsiveUtils.adaptivePadding(
                context,
                mobile: 20.0,
                tablet: 24.0,
                desktop: 32.0,
              ),
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkCard.withOpacity(0.5)
                  : AppColors.ivory.withOpacity(0.6),
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.adaptiveBorderRadius(context, base: 16.0),
              ),
              border: Border.all(
                color: isDark
                    ? AppColors.luxuryGold.withOpacity(0.2)
                    : AppColors.luxuryGold.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.adaptivePadding(
                          context,
                          mobile: 12.0,
                          tablet: 14.0,
                          desktop: 16.0,
                        ),
                        vertical: ResponsiveUtils.adaptivePadding(
                          context,
                          mobile: 6.0,
                        ),
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.luxuryGold.withOpacity(0.2),
                            AppColors.luxuryGold.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.adaptiveBorderRadius(
                            context,
                            base: 12.0,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate,
                            size: ResponsiveUtils.adaptiveIconSize(
                              context,
                              base: 16.0,
                            ),
                            color: AppColors.luxuryGold,
                          ),
                          SizedBox(
                            width: ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 6.0,
                            ),
                          ),
                          Text(
                            'Traduction',
                            style: TextStyle(
                              color: AppColors.luxuryGold,
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
                  ],
                ),
                SizedBox(
                  height: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 20.0,
                    tablet: 24.0,
                    desktop: 28.0,
                  ),
                ),
                ...surahDetail.ayahs.map((ayah) {
                  final ayahIndex = ayah.numberInSurah - 1;
                  final currentPlayingSurah = ref.read(
                    currentPlayingSurahProvider,
                  );
                  final isAudioPlaying = ref.read(isAudioPlayingProvider);
                  final isThisSurahPlaying =
                      currentPlayingSurah == widget.surah.number;
                  final isHighlighted = _highlightedAyahIndex == ayahIndex;
                  final isPlaying =
                      isThisSurahPlaying &&
                      _currentAyahIndex == ayahIndex &&
                      isAudioPlaying;
                  final isActive = isHighlighted || isPlaying;

                  return Padding(
                    key: _getAyahKey(ayah.numberInSurah - 1),
                    padding: EdgeInsets.only(
                      bottom: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 20.0,
                        tablet: 24.0,
                        desktop: 28.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
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
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.deepBlue,
                                    AppColors.deepBlue.withOpacity(0.8),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.deepBlue.withOpacity(0.3),
                                    blurRadius: ResponsiveUtils.responsive(
                                      context,
                                      mobile: 6.0,
                                      tablet: 8.0,
                                      desktop: 10.0,
                                    ),
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${ayah.numberInSurah}',
                                  style: TextStyle(
                                    color: AppColors.pureWhite,
                                    fontSize: ResponsiveUtils.adaptiveFontSize(
                                      context,
                                      mobile: 13,
                                      tablet: 14,
                                      desktop: 15,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 12.0,
                                tablet: 16.0,
                                desktop: 20.0,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                ayah.translation ?? 'Traduction non disponible',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      height: 1.7,
                                      fontSize:
                                          ResponsiveUtils.adaptiveFontSize(
                                            context,
                                            mobile: 15,
                                            tablet: 17,
                                            desktop: 19,
                                          ),
                                      color: isDark
                                          ? AppColors.pureWhite.withOpacity(0.9)
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        if (isActive)
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeInOut,
                            builder: (context, value, child) {
                              return Container(
                                margin: EdgeInsets.only(
                                  top: ResponsiveUtils.adaptivePadding(
                                    context,
                                    mobile: 8.0,
                                  ),
                                ),
                                height: isPlaying ? 3 : 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.luxuryGold.withOpacity(
                                        0.3 * value,
                                      ),
                                      AppColors.luxuryGold.withOpacity(
                                        0.8 + (0.2 * value),
                                      ),
                                      AppColors.luxuryGold.withOpacity(
                                        0.3 * value,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(1),
                                  boxShadow: isPlaying
                                      ? [
                                          BoxShadow(
                                            color: AppColors.luxuryGold
                                                .withOpacity(0.5 * value),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<InlineSpan> _buildAyahSpans(SurahDetailModel surahDetail, bool isDark) {
    final List<InlineSpan> spans = [];
    final currentPlayingSurah = ref.read(currentPlayingSurahProvider);
    final isAudioPlaying = ref.read(isAudioPlayingProvider);
    final isThisSurahPlaying = currentPlayingSurah == widget.surah.number;

    for (int i = 0; i < surahDetail.ayahs.length; i++) {
      final ayah = surahDetail.ayahs[i];
      final isHighlighted = _highlightedAyahIndex == i;
      final isPlaying =
          isThisSurahPlaying && _currentAyahIndex == i && isAudioPlaying;
      final isActive = isHighlighted || isPlaying;

      // Texte arabe de l'ayah - Responsive avec animation améliorée
      spans.add(
        TextSpan(
          text: '${ayah.text} ',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: ResponsiveUtils.adaptiveFontSize(
              context,
              mobile: 28,
              tablet: 34,
              desktop: 40,
            ),
            height: ResponsiveUtils.responsive(
              context,
              mobile: 2.0,
              tablet: 2.2,
              desktop: 2.4,
            ),
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive
                ? AppColors.luxuryGold
                : (isDark ? AppColors.pureWhite : AppColors.textPrimary),
            backgroundColor: isPlaying
                ? AppColors.luxuryGold.withOpacity(0.2)
                : isHighlighted
                ? AppColors.luxuryGold.withOpacity(0.25)
                : null,
            shadows: isActive
                ? [
                    Shadow(
                      color: AppColors.luxuryGold.withOpacity(0.6),
                      blurRadius: isPlaying ? 12 : 8,
                      offset: const Offset(0, 0),
                    ),
                    Shadow(
                      color: AppColors.luxuryGold.withOpacity(0.3),
                      blurRadius: isPlaying ? 20 : 12,
                      offset: const Offset(0, 0),
                    ),
                  ]
                : null,
          ),
        ),
      );

      // Badge avec numéro d'ayah intégré amélioré - Responsive avec animation
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _buildAyahBadge(
            ayahNumber: ayah.numberInSurah,
            isHighlighted: isHighlighted,
            isPlaying: isPlaying,
          ),
        ),
      );

      // Espace après l'ayah (sauf le dernier)
      if (i < surahDetail.ayahs.length - 1) {
        spans.add(const TextSpan(text: '  '));
      }
    }

    return spans;
  }

  /// Widget pour badge d'ayah avec animation
  Widget _buildAyahBadge({
    required int ayahNumber,
    required bool isHighlighted,
    required bool isPlaying,
  }) {
    final isActive = isHighlighted || isPlaying;

    // Animation de pulsation pour l'ayah en cours de lecture
    if (isPlaying) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
        onEnd: () {
          // Répéter l'animation
          if (mounted && isPlaying) {
            setState(() {});
          }
        },
        builder: (context, pulseValue, child) {
          final pulseScale =
              1.0 + (0.08 * (0.5 + 0.5 * (pulseValue * 2 - 1).abs()));
          return Transform.scale(
            scale: 1.15 * pulseScale,
            child: Container(
              width: ResponsiveUtils.responsive(
                context,
                mobile: 36.0,
                tablet: 40.0,
                desktop: 44.0,
              ),
              height: ResponsiveUtils.responsive(
                context,
                mobile: 36.0,
                tablet: 40.0,
                desktop: 44.0,
              ),
              margin: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 6.0,
                ),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPlaying
                      ? [
                          AppColors.luxuryGold,
                          AppColors.luxuryGold.withOpacity(0.9),
                          AppColors.luxuryGold.withOpacity(0.85),
                        ]
                      : isActive
                      ? [
                          AppColors.luxuryGold,
                          AppColors.luxuryGold.withOpacity(0.85),
                        ]
                      : [
                          AppColors.deepBlue,
                          AppColors.deepBlue.withOpacity(0.8),
                        ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        (isPlaying
                                ? AppColors.luxuryGold
                                : isActive
                                ? AppColors.luxuryGold
                                : AppColors.deepBlue)
                            .withOpacity(
                              isPlaying
                                  ? 0.7
                                  : isActive
                                  ? 0.5
                                  : 0.3,
                            ),
                    blurRadius: ResponsiveUtils.responsive(
                      context,
                      mobile: isPlaying
                          ? 16.0
                          : isActive
                          ? 12.0
                          : 8.0,
                      tablet: isPlaying
                          ? 18.0
                          : isActive
                          ? 14.0
                          : 10.0,
                      desktop: isPlaying
                          ? 20.0
                          : isActive
                          ? 16.0
                          : 12.0,
                    ),
                    spreadRadius: isPlaying
                        ? 3
                        : isActive
                        ? 2
                        : 1,
                    offset: const Offset(0, 2),
                  ),
                  if (isPlaying)
                    BoxShadow(
                      color: AppColors.luxuryGold.withOpacity(0.4),
                      blurRadius: ResponsiveUtils.responsive(
                        context,
                        mobile: 24.0,
                        tablet: 28.0,
                        desktop: 32.0,
                      ),
                      spreadRadius: 2,
                      offset: const Offset(0, 0),
                    ),
                ],
              ),
              child: Center(
                child: Text(
                  '$ayahNumber',
                  style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 13,
                      tablet: 14,
                      desktop: 15,
                    ),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // Animation normale pour les autres cas
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: isActive ? 0.0 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, scaleValue, child) {
        final clampedValue = scaleValue.clamp(0.0, 1.0);
        final scale = isActive ? 1.0 + (0.2 * (1 - clampedValue)) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: ResponsiveUtils.responsive(
              context,
              mobile: 36.0,
              tablet: 40.0,
              desktop: 44.0,
            ),
            height: ResponsiveUtils.responsive(
              context,
              mobile: 36.0,
              tablet: 40.0,
              desktop: 44.0,
            ),
            margin: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.adaptivePadding(context, mobile: 6.0),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isActive
                    ? [
                        AppColors.luxuryGold,
                        AppColors.luxuryGold.withOpacity(0.85),
                      ]
                    : [AppColors.deepBlue, AppColors.deepBlue.withOpacity(0.8)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isActive ? AppColors.luxuryGold : AppColors.deepBlue)
                      .withOpacity(isActive ? 0.5 : 0.3),
                  blurRadius: ResponsiveUtils.responsive(
                    context,
                    mobile: isActive ? 12.0 : 8.0,
                    tablet: isActive ? 14.0 : 10.0,
                    desktop: isActive ? 16.0 : 12.0,
                  ),
                  spreadRadius: isActive ? 2 : 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$ayahNumber',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 13,
                    tablet: 14,
                    desktop: 15,
                  ),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoAudioCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingLarge),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_off, color: AppColors.warning, size: 32),
          const SizedBox(width: AppTheme.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio non disponible',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'L\'audio pour cette sourate n\'est pas disponible',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioLoadingCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingLarge),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                colors: [
                  AppColors.darkCard,
                  AppColors.darkCard.withOpacity(0.95),
                ],
              )
            : AppColors.headerGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.luxuryGold),
            ),
          ),
          const SizedBox(width: AppTheme.paddingMedium),
          Text(
            'Chargement de l\'audio...',
            style: TextStyle(
              color: AppColors.pureWhite.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioErrorCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 24),
          const SizedBox(width: AppTheme.paddingMedium),
          Expanded(
            child: Text(
              'Erreur de chargement audio',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () {
              ref.invalidate(surahAudioUrlsProvider(widget.surah.number));
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  /// Bouton pour ouvrir le lecteur audio
  Widget _buildAudioPlayerButton(
    bool isDark,
    List<String> audioUrls,
    int totalAyahs,
  ) {
    final isAudioPlaying = ref.watch(isAudioPlayingProvider);
    final currentSurah = ref.watch(currentPlayingSurahProvider);
    final isThisSurahPlaying = currentSurah == widget.surah.number;
    final playlistService = ref.read(globalAudioPlaylistServiceProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();

          // Si cette sourate n'est pas en cours de lecture, charger et démarrer
          if (!isThisSurahPlaying) {
            try {
              await playlistService.loadSurahPlaylist(audioUrls);
              // Mettre à jour les providers
              ref.read(currentPlayingSurahProvider.notifier).state =
                  widget.surah.number;
              ref.read(currentPlayingSurahNameProvider.notifier).state =
                  widget.surah.name;
              ref.read(currentSurahTotalAyahsProvider.notifier).state =
                  totalAyahs;
              // Démarrer la lecture
              await playlistService.play();
            } catch (e) {
              debugPrint('Error starting playback: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur de démarrage: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          } else {
            // Si déjà en cours, toggle play/pause
            if (isAudioPlaying) {
              playlistService.pause();
            } else {
              playlistService.play();
            }
          }
        },
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context, base: 16.0),
        ),
        child: Container(
          padding: EdgeInsets.all(
            ResponsiveUtils.adaptivePadding(
              context,
              mobile: 16.0,
              tablet: 20.0,
              desktop: 24.0,
            ),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isThisSurahPlaying && isAudioPlaying
                  ? [
                      AppColors.luxuryGold,
                      AppColors.luxuryGold.withOpacity(0.8),
                    ]
                  : [AppColors.deepBlue, AppColors.deepBlue.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.adaptiveBorderRadius(context, base: 16.0),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (isThisSurahPlaying && isAudioPlaying
                            ? AppColors.luxuryGold
                            : AppColors.deepBlue)
                        .withOpacity(0.3),
                blurRadius: ResponsiveUtils.responsive(
                  context,
                  mobile: 12.0,
                  tablet: 16.0,
                  desktop: 20.0,
                ),
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isThisSurahPlaying && isAudioPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: AppColors.pureWhite,
                size: ResponsiveUtils.adaptiveIconSize(context, base: 32.0),
              ),
              SizedBox(
                width: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 12.0,
                  tablet: 16.0,
                  desktop: 20.0,
                ),
              ),
              Text(
                isThisSurahPlaying && isAudioPlaying
                    ? 'Lecture en cours'
                    : 'Écouter la sourate',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fixed Bottom Audio Player avec contrôles pour jouer et changer de sourate
  Widget _buildFixedBottomAudioPlayer(
    bool isDark,
    AsyncValue<List<String>> audioUrlsAsync,
    int totalAyahs,
  ) {
    final currentSurah = ref.watch(currentPlayingSurahProvider);
    final isAudioPlaying = ref.watch(isAudioPlayingProvider);
    final currentAyahIndex = ref.watch(currentAyahIndexProvider);
    final isThisSurahPlaying = currentSurah == widget.surah.number;
    final surahsAsync = ref.watch(surahsProvider);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: audioUrlsAsync.when(
        data: (audioUrls) {
          return surahsAsync.when(
            data: (surahs) {
              // Trouver les sourates précédente et suivante
              final currentIndex = surahs.indexWhere(
                (s) => s.number == widget.surah.number,
              );
              final hasPrevious = currentIndex > 0;
              final hasNext = currentIndex < surahs.length - 1;
              final previousSurah = hasPrevious
                  ? SurahAdapter.fromApiModel(surahs[currentIndex - 1])
                  : null;
              final nextSurah = hasNext
                  ? SurahAdapter.fromApiModel(surahs[currentIndex + 1])
                  : null;

              return _buildFixedPlayerBar(
                isDark,
                isThisSurahPlaying,
                isAudioPlaying,
                currentAyahIndex,
                totalAyahs,
                audioUrls,
                audioUrlsAsync,
                previousSurah,
                nextSurah,
              );
            },
            loading: () => _buildFixedPlayerBar(
              isDark,
              isThisSurahPlaying,
              isAudioPlaying,
              currentAyahIndex,
              totalAyahs,
              audioUrls,
              audioUrlsAsync,
              null,
              null,
            ),
            error: (_, __) => _buildFixedPlayerBar(
              isDark,
              isThisSurahPlaying,
              isAudioPlaying,
              currentAyahIndex,
              totalAyahs,
              audioUrls,
              audioUrlsAsync,
              null,
              null,
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  /// Barre audio fixe en bas avec contrôles
  Widget _buildFixedPlayerBar(
    bool isDark,
    bool isThisSurahPlaying,
    bool isAudioPlaying,
    int? currentAyahIndex,
    int totalAyahs,
    List<String> audioUrls,
    AsyncValue<List<String>> audioUrlsAsync,
    Surah? previousSurah,
    Surah? nextSurah,
  ) {
    final playlistService = ref.read(globalAudioPlaylistServiceProvider);
    final currentAyah = currentAyahIndex != null && currentAyahIndex > 0
        ? (widget.surah.number == 9 ? currentAyahIndex : currentAyahIndex - 1)
        : 0;

    // Calculer le pourcentage de progression
    final progress = totalAyahs > 0
        ? (currentAyah / totalAyahs).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isThisSurahPlaying && isAudioPlaying
              ? [AppColors.luxuryGold, AppColors.luxuryGold.withOpacity(0.9)]
              : [AppColors.deepBlue, AppColors.deepBlue.withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isThisSurahPlaying && isAudioPlaying
                        ? AppColors.luxuryGold
                        : AppColors.deepBlue)
                    .withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barre de progression en haut
            Container(
              height: 3,
              child: Stack(
                children: [
                  // Fond de la barre
                  Container(color: AppColors.pureWhite.withOpacity(0.2)),
                  // Barre de progression animée
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: MediaQuery.of(context).size.width * progress,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.pureWhite,
                          AppColors.pureWhite.withOpacity(0.8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pureWhite.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Contenu principal
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 16.0,
                  tablet: 20.0,
                  desktop: 24.0,
                ),
                vertical: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 12.0,
                  tablet: 14.0,
                  desktop: 16.0,
                ),
              ),
              child: Row(
                children: [
                  // Bouton sourate précédente
                  if (previousSurah != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          // Sauvegarder l'état de lecture avant navigation
                          final wasPlaying =
                              isThisSurahPlaying && isAudioPlaying;
                          // Naviguer vers la sourate précédente
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      SurahDetailScreen(
                                        surah: previousSurah,
                                        autoPlay: wasPlaying,
                                      ),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(-1.0, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    return SlideTransition(
                                      position: offsetAnimation,
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration: const Duration(
                                milliseconds: 300,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.adaptiveBorderRadius(
                            context,
                            base: 12.0,
                          ),
                        ),
                        child: Container(
                          padding: EdgeInsets.all(
                            ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 10.0,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.pureWhite.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.adaptiveBorderRadius(
                                context,
                                base: 12.0,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.skip_previous_rounded,
                            color: AppColors.pureWhite,
                            size: ResponsiveUtils.adaptiveIconSize(
                              context,
                              base: 24.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (previousSurah != null)
                    SizedBox(
                      width: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 8.0,
                      ),
                    ),
                  // Bouton play/pause
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        HapticFeedback.mediumImpact();

                        if (!isThisSurahPlaying) {
                          // Charger et démarrer cette sourate
                          try {
                            await playlistService.loadSurahPlaylist(audioUrls);
                            ref
                                    .read(currentPlayingSurahProvider.notifier)
                                    .state =
                                widget.surah.number;
                            ref
                                .read(currentPlayingSurahNameProvider.notifier)
                                .state = widget
                                .surah
                                .name;
                            ref
                                    .read(
                                      currentSurahTotalAyahsProvider.notifier,
                                    )
                                    .state =
                                totalAyahs;
                            await playlistService.play();
                          } catch (e) {
                            debugPrint('Error starting playback: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur de démarrage: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        } else {
                          // Toggle play/pause
                          if (isAudioPlaying) {
                            playlistService.pause();
                          } else {
                            playlistService.play();
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.adaptiveBorderRadius(
                          context,
                          base: 16.0,
                        ),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: ResponsiveUtils.responsive(
                          context,
                          mobile: 56.0,
                          tablet: 60.0,
                          desktop: 64.0,
                        ),
                        height: ResponsiveUtils.responsive(
                          context,
                          mobile: 56.0,
                          tablet: 60.0,
                          desktop: 64.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pureWhite.withOpacity(
                            isThisSurahPlaying && isAudioPlaying ? 0.3 : 0.2,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.pureWhite.withOpacity(0.3),
                              blurRadius: isThisSurahPlaying && isAudioPlaying
                                  ? 12
                                  : 6,
                              spreadRadius: isThisSurahPlaying && isAudioPlaying
                                  ? 2
                                  : 1,
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isThisSurahPlaying && isAudioPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            key: ValueKey(
                              '${isThisSurahPlaying}_$isAudioPlaying',
                            ),
                            color: AppColors.pureWhite,
                            size: ResponsiveUtils.adaptiveIconSize(
                              context,
                              base: 28.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 12.0,
                      tablet: 14.0,
                      desktop: 16.0,
                    ),
                  ),
                  // Info de la sourate
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.surah.name,
                                style: TextStyle(
                                  color: AppColors.pureWhite,
                                  fontSize: ResponsiveUtils.adaptiveFontSize(
                                    context,
                                    mobile: 16,
                                    tablet: 17,
                                    desktop: 18,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Indicateur de lecture animé
                            if (isThisSurahPlaying && isAudioPlaying)
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.easeInOut,
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: 0.5 + (0.5 * (value % 1)),
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: AppColors.pureWhite,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.pureWhite
                                                .withOpacity(0.8),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        SizedBox(
                          height: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 4.0,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.adaptivePadding(
                                  context,
                                  mobile: 6.0,
                                  tablet: 8.0,
                                  desktop: 10.0,
                                ),
                                vertical: ResponsiveUtils.adaptivePadding(
                                  context,
                                  mobile: 2.0,
                                  tablet: 3.0,
                                  desktop: 4.0,
                                ),
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.pureWhite.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(
                                  ResponsiveUtils.adaptiveBorderRadius(
                                    context,
                                    base: 8.0,
                                  ),
                                ),
                              ),
                              child: Text(
                                currentAyah > 0
                                    ? 'Ayah $currentAyah'
                                    : isThisSurahPlaying
                                    ? 'Bismillah'
                                    : 'Prêt',
                                style: TextStyle(
                                  color: AppColors.pureWhite,
                                  fontSize: ResponsiveUtils.adaptiveFontSize(
                                    context,
                                    mobile: 10,
                                    tablet: 11,
                                    desktop: 12,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 6.0,
                              ),
                            ),
                            Text(
                              '• $totalAyahs',
                              style: TextStyle(
                                color: AppColors.pureWhite.withOpacity(0.8),
                                fontSize: ResponsiveUtils.adaptiveFontSize(
                                  context,
                                  mobile: 10,
                                  tablet: 11,
                                  desktop: 12,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 8.0,
                    ),
                  ),
                  // Bouton sourate suivante
                  if (nextSurah != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          // Sauvegarder l'état de lecture avant navigation
                          final wasPlaying =
                              isThisSurahPlaying && isAudioPlaying;
                          // Naviguer vers la sourate suivante
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      SurahDetailScreen(
                                        surah: nextSurah,
                                        autoPlay: wasPlaying,
                                      ),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(1.0, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    return SlideTransition(
                                      position: offsetAnimation,
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration: const Duration(
                                milliseconds: 300,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.adaptiveBorderRadius(
                            context,
                            base: 12.0,
                          ),
                        ),
                        child: Container(
                          padding: EdgeInsets.all(
                            ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 10.0,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.pureWhite.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.adaptiveBorderRadius(
                                context,
                                base: 12.0,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.skip_next_rounded,
                            color: AppColors.pureWhite,
                            size: ResponsiveUtils.adaptiveIconSize(
                              context,
                              base: 24.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Afficher le sélecteur de sourate avec recherche et navigation
  void _showSurahSelector(BuildContext context, bool isDark) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SurahSelectorBottomSheet(
        currentSurahNumber: widget.surah.number,
        isDark: isDark,
        onSurahSelected: (surah, ayahNumber) {
          Navigator.pop(context); // Fermer le bottom sheet

          // Si c'est la même sourate, scroller vers l'ayah si spécifié
          if (surah.number == widget.surah.number) {
            if (ayahNumber != null && ayahNumber > 0) {
              // Scroller vers l'ayah spécifié
              Future.delayed(const Duration(milliseconds: 300), () {
                _scrollToAyah(ayahNumber - 1);
              });
            }
          } else {
            // Naviguer vers une nouvelle sourate
            HapticFeedback.mediumImpact();
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    SurahDetailScreen(
                      surah: surah,
                      initialAyahNumber: ayahNumber,
                    ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;

                      var tween = Tween(
                        begin: begin,
                        end: end,
                      ).chain(CurveTween(curve: curve));
                      var offsetAnimation = animation.drive(tween);

                      return SlideTransition(
                        position: offsetAnimation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          }
        },
      ),
    );
  }
}

/// Bottom Sheet pour sélectionner une sourate
class _SurahSelectorBottomSheet extends ConsumerStatefulWidget {
  final int currentSurahNumber;
  final bool isDark;
  final Function(Surah surah, int? ayahNumber) onSurahSelected;

  const _SurahSelectorBottomSheet({
    required this.currentSurahNumber,
    required this.isDark,
    required this.onSurahSelected,
  });

  @override
  ConsumerState<_SurahSelectorBottomSheet> createState() =>
      _SurahSelectorBottomSheetState();
}

class _SurahSelectorBottomSheetState
    extends ConsumerState<_SurahSelectorBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedAyahNumber;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surahsAsync = ref.watch(surahsProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 24.0),
          ),
          topRight: Radius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 24.0),
          ),
        ),
      ),
      child: Column(
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
              color: widget.isDark
                  ? AppColors.pureWhite.withOpacity(0.2)
                  : AppColors.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header avec titre et bouton fermer
          Padding(
            padding: EdgeInsets.all(
              ResponsiveUtils.adaptivePadding(context, mobile: 20.0),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Sélectionner une sourate',
                    style: TextStyle(
                      color: widget.isDark
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
                ),
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: widget.isDark
                        ? AppColors.pureWhite
                        : AppColors.textPrimary,
                    size: ResponsiveUtils.adaptiveIconSize(context, base: 24.0),
                  ),
                ),
              ],
            ),
          ),

          // Barre de recherche
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.adaptivePadding(
                context,
                mobile: 20.0,
                tablet: 24.0,
                desktop: 32.0,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDark
                    ? AppColors.darkCard
                    : AppColors.ivory.withOpacity(0.5),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.adaptiveBorderRadius(context, base: 16.0),
                ),
                border: Border.all(
                  color: widget.isDark
                      ? AppColors.pureWhite.withOpacity(0.1)
                      : AppColors.deepBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
                style: TextStyle(
                  color: widget.isDark
                      ? AppColors.pureWhite
                      : AppColors.textPrimary,
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 16,
                    tablet: 17,
                    desktop: 18,
                  ),
                ),
                decoration: InputDecoration(
                  hintText: 'Rechercher une sourate...',
                  hintStyle: TextStyle(
                    color: widget.isDark
                        ? AppColors.pureWhite.withOpacity(0.5)
                        : AppColors.textSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: widget.isDark
                        ? AppColors.pureWhite.withOpacity(0.7)
                        : AppColors.textSecondary,
                    size: ResponsiveUtils.adaptiveIconSize(context, base: 22.0),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: Icon(
                            Icons.clear,
                            color: widget.isDark
                                ? AppColors.pureWhite.withOpacity(0.7)
                                : AppColors.textSecondary,
                            size: ResponsiveUtils.adaptiveIconSize(
                              context,
                              base: 20.0,
                            ),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 16.0,
                    ),
                    vertical: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 14.0,
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
          ),

          // Liste des sourates
          Expanded(
            child: surahsAsync.when(
              data: (surahs) {
                // Filtrer les sourates selon la recherche
                final filteredSurahs = _searchQuery.isEmpty
                    ? surahs
                    : surahs.where((surah) {
                        final query = _searchQuery;
                        return surah.number.toString().contains(query) ||
                            surah.name.toLowerCase().contains(query) ||
                            surah.englishName.toLowerCase().contains(query) ||
                            surah.englishNameTranslation.toLowerCase().contains(
                              query,
                            );
                      }).toList();

                if (filteredSurahs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: widget.isDark
                              ? AppColors.pureWhite.withOpacity(0.5)
                              : AppColors.textSecondary,
                        ),
                        SizedBox(
                          height: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 16.0,
                          ),
                        ),
                        Text(
                          'Aucune sourate trouvée',
                          style: TextStyle(
                            color: widget.isDark
                                ? AppColors.pureWhite.withOpacity(0.7)
                                : AppColors.textSecondary,
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 16,
                              tablet: 17,
                              desktop: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 20.0,
                      tablet: 24.0,
                      desktop: 32.0,
                    ),
                  ),
                  itemCount: filteredSurahs.length,
                  itemBuilder: (context, index) {
                    final surahModel = filteredSurahs[index];
                    final surah = SurahAdapter.fromApiModel(surahModel);
                    final isCurrentSurah =
                        surah.number == widget.currentSurahNumber;

                    return _buildSurahItem(surah, isCurrentSurah);
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: widget.isDark
                      ? AppColors.luxuryGold
                      : AppColors.deepBlue,
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 16.0,
                      ),
                    ),
                    Text(
                      'Erreur de chargement',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 16,
                          tablet: 17,
                          desktop: 18,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 12.0,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.invalidate(surahsProvider);
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahItem(Surah surah, bool isCurrentSurah) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          // Proposer de sélectionner un ayah ou naviguer directement
          _showSurahOptions(surah, isCurrentSurah);
        },
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context, base: 16.0),
        ),
        child: Container(
          margin: EdgeInsets.only(
            bottom: ResponsiveUtils.adaptivePadding(context, mobile: 8.0),
          ),
          padding: EdgeInsets.all(
            ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
          ),
          decoration: BoxDecoration(
            color: isCurrentSurah
                ? (widget.isDark
                      ? AppColors.luxuryGold.withOpacity(0.2)
                      : AppColors.luxuryGold.withOpacity(0.1))
                : (widget.isDark ? AppColors.darkCard : AppColors.pureWhite),
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.adaptiveBorderRadius(context, base: 16.0),
            ),
            border: Border.all(
              color: isCurrentSurah
                  ? AppColors.luxuryGold.withOpacity(0.5)
                  : (widget.isDark
                        ? AppColors.pureWhite.withOpacity(0.1)
                        : AppColors.deepBlue.withOpacity(0.1)),
              width: isCurrentSurah ? 2 : 1,
            ),
            boxShadow: isCurrentSurah
                ? [
                    BoxShadow(
                      color: AppColors.luxuryGold.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Numéro de sourate
              Container(
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
                  gradient: LinearGradient(
                    colors: isCurrentSurah
                        ? [
                            AppColors.luxuryGold,
                            AppColors.luxuryGold.withOpacity(0.8),
                          ]
                        : [
                            AppColors.deepBlue,
                            AppColors.deepBlue.withOpacity(0.8),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isCurrentSurah
                                  ? AppColors.luxuryGold
                                  : AppColors.deepBlue)
                              .withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${surah.number}',
                    style: TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 18,
                        tablet: 20,
                        desktop: 22,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
              ),
              // Informations de la sourate
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            surah.name,
                            style: TextStyle(
                              color: widget.isDark
                                  ? AppColors.pureWhite
                                  : AppColors.textPrimary,
                              fontSize: ResponsiveUtils.adaptiveFontSize(
                                context,
                                mobile: 17,
                                tablet: 18,
                                desktop: 19,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isCurrentSurah)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 8.0,
                              ),
                              vertical: ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 4.0,
                              ),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.luxuryGold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.adaptiveBorderRadius(
                                  context,
                                  base: 8.0,
                                ),
                              ),
                            ),
                            child: Text(
                              'Actuelle',
                              style: TextStyle(
                                color: AppColors.luxuryGold,
                                fontSize: ResponsiveUtils.adaptiveFontSize(
                                  context,
                                  mobile: 10,
                                  tablet: 11,
                                  desktop: 12,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 4.0,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          surah.arabicName,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: widget.isDark
                                ? AppColors.pureWhite.withOpacity(0.8)
                                : AppColors.textSecondary,
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 14,
                              tablet: 15,
                              desktop: 16,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        SizedBox(
                          width: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 8.0,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 6.0,
                            ),
                            vertical: ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 2.0,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? AppColors.pureWhite.withOpacity(0.1)
                                : AppColors.deepBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${surah.numberOfAyahs} ayahs',
                            style: TextStyle(
                              color: widget.isDark
                                  ? AppColors.pureWhite.withOpacity(0.7)
                                  : AppColors.textSecondary,
                              fontSize: ResponsiveUtils.adaptiveFontSize(
                                context,
                                mobile: 11,
                                tablet: 12,
                                desktop: 13,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: widget.isDark
                    ? AppColors.pureWhite.withOpacity(0.5)
                    : AppColors.textSecondary,
                size: ResponsiveUtils.adaptiveIconSize(context, base: 18.0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Afficher les options pour une sourate (naviguer ou sélectionner un ayah)
  void _showSurahOptions(Surah surah, bool isCurrentSurah) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkSurface : AppColors.pureWhite,
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
                  color: widget.isDark
                      ? AppColors.pureWhite.withOpacity(0.2)
                      : AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(
                  ResponsiveUtils.adaptivePadding(context, mobile: 20.0),
                ),
                child: Column(
                  children: [
                    Text(
                      surah.name,
                      style: TextStyle(
                        color: widget.isDark
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
                        mobile: 8.0,
                      ),
                    ),
                    Text(
                      surah.arabicName,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: widget.isDark
                            ? AppColors.pureWhite.withOpacity(0.8)
                            : AppColors.textSecondary,
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 16,
                          tablet: 18,
                          desktop: 20,
                        ),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 24.0,
                      ),
                    ),
                    // Option 1: Aller au début de la sourate
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                          widget.onSurahSelected(surah, null);
                        },
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.adaptiveBorderRadius(
                            context,
                            base: 16.0,
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(
                            ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 16.0,
                            ),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.deepBlue,
                                AppColors.deepBlue.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.adaptiveBorderRadius(
                                context,
                                base: 16.0,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                color: AppColors.pureWhite,
                                size: ResponsiveUtils.adaptiveIconSize(
                                  context,
                                  base: 24.0,
                                ),
                              ),
                              SizedBox(
                                width: ResponsiveUtils.adaptivePadding(
                                  context,
                                  mobile: 12.0,
                                ),
                              ),
                              Text(
                                isCurrentSurah
                                    ? 'Aller au début'
                                    : 'Ouvrir la sourate',
                                style: TextStyle(
                                  color: AppColors.pureWhite,
                                  fontSize: ResponsiveUtils.adaptiveFontSize(
                                    context,
                                    mobile: 16,
                                    tablet: 17,
                                    desktop: 18,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 12.0,
                      ),
                    ),
                    // Option 2: Aller à un ayah spécifique
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                          _showAyahSelector(surah);
                        },
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.adaptiveBorderRadius(
                            context,
                            base: 16.0,
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(
                            ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 16.0,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? AppColors.darkCard
                                : AppColors.ivory.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.adaptiveBorderRadius(
                                context,
                                base: 16.0,
                              ),
                            ),
                            border: Border.all(
                              color: AppColors.luxuryGold.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.numbers,
                                color: AppColors.luxuryGold,
                                size: ResponsiveUtils.adaptiveIconSize(
                                  context,
                                  base: 24.0,
                                ),
                              ),
                              SizedBox(
                                width: ResponsiveUtils.adaptivePadding(
                                  context,
                                  mobile: 12.0,
                                ),
                              ),
                              Text(
                                'Aller à un ayah spécifique',
                                style: TextStyle(
                                  color: widget.isDark
                                      ? AppColors.pureWhite
                                      : AppColors.textPrimary,
                                  fontSize: ResponsiveUtils.adaptiveFontSize(
                                    context,
                                    mobile: 16,
                                    tablet: 17,
                                    desktop: 18,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 12.0,
                      ),
                    ),
                    // Bouton annuler
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Annuler',
                        style: TextStyle(
                          color: widget.isDark
                              ? AppColors.pureWhite.withOpacity(0.7)
                              : AppColors.textSecondary,
                          fontSize: ResponsiveUtils.adaptiveFontSize(
                            context,
                            mobile: 15,
                            tablet: 16,
                            desktop: 17,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Afficher le sélecteur d'ayah pour une sourate
  void _showAyahSelector(Surah surah) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 20.0),
          ),
        ),
        backgroundColor: widget.isDark
            ? AppColors.darkSurface
            : AppColors.pureWhite,
        title: Text(
          'Aller à un ayah',
          style: TextStyle(
            color: widget.isDark ? AppColors.pureWhite : AppColors.textPrimary,
            fontSize: ResponsiveUtils.adaptiveFontSize(
              context,
              mobile: 18,
              tablet: 20,
              desktop: 22,
            ),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sourate ${surah.number}: ${surah.name}',
              style: TextStyle(
                color: widget.isDark
                    ? AppColors.pureWhite.withOpacity(0.8)
                    : AppColors.textSecondary,
                fontSize: ResponsiveUtils.adaptiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
            SizedBox(
              height: ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
            ),
            TextField(
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: widget.isDark
                    ? AppColors.pureWhite
                    : AppColors.textPrimary,
                fontSize: ResponsiveUtils.adaptiveFontSize(
                  context,
                  mobile: 16,
                  tablet: 17,
                  desktop: 18,
                ),
              ),
              decoration: InputDecoration(
                labelText: 'Numéro d\'ayah (1-${surah.numberOfAyahs})',
                labelStyle: TextStyle(
                  color: widget.isDark
                      ? AppColors.pureWhite.withOpacity(0.7)
                      : AppColors.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.adaptiveBorderRadius(context, base: 12.0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.adaptiveBorderRadius(context, base: 12.0),
                  ),
                  borderSide: BorderSide(color: AppColors.luxuryGold, width: 2),
                ),
              ),
              onChanged: (value) {
                final ayahNum = int.tryParse(value);
                if (ayahNum != null &&
                    ayahNum >= 1 &&
                    ayahNum <= surah.numberOfAyahs) {
                  setState(() => _selectedAyahNumber = ayahNum);
                } else {
                  setState(() => _selectedAyahNumber = null);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Text(
              'Annuler',
              style: TextStyle(
                color: widget.isDark
                    ? AppColors.pureWhite.withOpacity(0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _selectedAyahNumber != null
                ? () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context); // Fermer le dialog
                    widget.onSurahSelected(surah, _selectedAyahNumber);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.luxuryGold,
              foregroundColor: AppColors.pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.adaptiveBorderRadius(context, base: 12.0),
                ),
              ),
            ),
            child: const Text('Aller'),
          ),
        ],
      ),
    );
  }
}
