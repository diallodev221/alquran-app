import 'dart:async';
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
import '../providers/settings_providers.dart';
import '../services/audio_service.dart';
import '../utils/responsive_utils.dart';
import '../utils/surah_adapter.dart';
import '../services/preload_service.dart';
import '../services/settings_service.dart';
import '../utils/available_translations.dart';
import '../utils/juz_utils.dart';
import '../utils/tanzil_pause_marks.dart';
import '../widgets/mini_audio_player.dart';

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
  bool _isAutoScrollEnabled = true; // État du toggle auto-scroll dans l'UI
  Timer? _continuousScrollTimer; // Timer pour le scroll continu
  bool _isContinuousScrolling = false; // Flag pour le scroll continu
  bool _showBottomBar = true; // Afficher/masquer la barre audio en bas
  Timer? _hideBottomBarTimer; // Timer pour masquer la barre après 2s
  Timer? _scrollStopTimer; // Timer pour masquer la barre après arrêt du scroll
  Timer? _saveLastReadTimer; // Debounce pour sauvegarder la dernière lecture

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: AppTheme.animationDuration,
      vsync: this,
    );

    _scrollController.addListener(_onScroll);
    _animationController.forward();

    // Précharger la sourate courante (audio) et les adjacentes en arrière-plan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadCurrentSurahAudio();
      _preloadAdjacentSurahs();
    });
  }

  /// Précharge les URLs audio de la sourate affichée en arrière-plan pour une lecture immédiate
  void _preloadCurrentSurahAudio() {
    ref.read(surahAudioUrlsProvider(widget.surah.number));
  }

  /// Précharge les sourates adjacentes pour une navigation fluide
  Future<void> _preloadAdjacentSurahs() async {
    try {
      final quranApiService = ref.read(quranApiServiceProvider);
      final audioService = ref.read(audioServiceProvider);
      final settingsService = SettingsService();
      await settingsService.init();

      final preloadService = PreloadService(
        quranApiService: quranApiService,
        audioService: audioService,
        settingsService: settingsService,
      );

      // Précharger en arrière-plan (ne pas bloquer l'UI)
      preloadService.preloadAdjacentSurahs(widget.surah.number).catchError((e) {
        debugPrint('⚠️ Failed to preload adjacent surahs: $e');
      });
    } catch (e) {
      debugPrint('⚠️ Error setting up preload: $e');
    }
  }

  @override
  void dispose() {
    _saveLastReadTimer?.cancel();
    _persistLastRead();
    _animationController.dispose();
    _scrollController.dispose();
    _continuousScrollTimer?.cancel();
    super.dispose();
  }

  /// Sauvegarde la dernière lecture (sourate + verset) pour continuité. Debounced au scroll.
  void _persistLastRead() {
    if (!_scrollController.hasClients) return;
    final extent = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final n = widget.surah.numberOfAyahs;
    if (n <= 0 || extent <= 0) return;
    final ratio = (offset / extent).clamp(0.0, 1.0);
    final ayah1Based = (ratio * n).round().clamp(1, n);
    ref.read(lastReadSurahProvider.notifier).state = widget.surah.number;
    ref.read(lastReadAyahProvider.notifier).state = ayah1Based;
    SettingsService().setLastRead(
      surahNumber: widget.surah.number,
      ayahNumber: ayah1Based,
    );
  }

  void _onScroll() {
    // Afficher le bouton scroll to top après 500px de scroll
    final shouldShow = _scrollController.offset > 500;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }

    // Afficher la barre audio lors du scroll
    if (!_showBottomBar) {
      setState(() => _showBottomBar = true);
    }

    // Annuler le timer de masquage après arrêt du scroll
    _scrollStopTimer?.cancel();
    _hideBottomBarTimer?.cancel();

    // Programmer le masquage après arrêt du scroll (1 seconde d'inactivité)
    // Mais seulement si l'audio n'est pas en lecture
    _scrollStopTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && !_isContinuousScrolling) {
        final currentSurah = ref.read(currentPlayingSurahProvider);
        final isAudioPlaying = ref.read(isAudioPlayingProvider);
        final isThisSurahPlaying = currentSurah == widget.surah.number;

        // Ne masquer que si l'audio n'est pas en lecture
        // Sinon, le timer de 2 secondes après le démarrage de l'audio s'en chargera
        if (!isThisSurahPlaying || !isAudioPlaying) {
          setState(() => _showBottomBar = false);
        }
      }
    });

    // Détecter le scroll manuel (pas d'auto-scroll en cours)
    if (!_isAutoScrolling && !_isContinuousScrolling) {
      _lastManualScroll = DateTime.now();
      // Arrêter le scroll continu si l'utilisateur scroll manuellement
      _stopContinuousScroll();
      // Sauvegarder la dernière lecture (debounced) pour continuité
      _saveLastReadTimer?.cancel();
      _saveLastReadTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) _persistLastRead();
      });
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

  /// Démarrer le scroll continu et fluide
  void _startContinuousScroll() {
    if (_isContinuousScrolling || !_scrollController.hasClients) return;

    _isContinuousScrolling = true;

    // Vitesse de scroll : pixels par seconde (ajustable pour plus de lenteur)
    const double scrollSpeed = 15.0; // Pixels par seconde - très lent et fluide

    _continuousScrollTimer?.cancel();
    _continuousScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
      if (!mounted || !_scrollController.hasClients) {
        timer.cancel();
        return;
      }

      final currentPosition = _scrollController.offset;
      final maxPosition = _scrollController.position.maxScrollExtent;

      // Si on a atteint le bas, arrêter le scroll
      if (currentPosition >= maxPosition) {
        _stopContinuousScroll();
        return;
      }

      // Calculer le nouveau offset avec une vitesse constante
      final newOffset = (currentPosition + (scrollSpeed * 0.05)).clamp(
        0.0,
        maxPosition,
      );

      // Scroller de manière fluide
      _scrollController.jumpTo(newOffset);
    });
  }

  /// Arrêter le scroll continu
  void _stopContinuousScroll() {
    _isContinuousScrolling = false;
    _continuousScrollTimer?.cancel();
    _continuousScrollTimer = null;
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

    // Masquer la barre audio après 2 secondes si l'audio est en lecture
    // Mais garder la barre visible pendant le scroll continu
    if (isThisSurahPlaying && isAudioPlaying && !_isContinuousScrolling) {
      _hideBottomBarTimer?.cancel();
      _hideBottomBarTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && !_isContinuousScrolling) {
          setState(() => _showBottomBar = false);
        }
      });
    } else if (!isThisSurahPlaying || !isAudioPlaying) {
      // Afficher la barre si l'audio n'est pas en lecture
      _hideBottomBarTimer?.cancel();
      if (!_showBottomBar) {
        setState(() => _showBottomBar = true);
      }
    } else if (_isContinuousScrolling && !_showBottomBar) {
      // Afficher la barre pendant le scroll continu
      setState(() => _showBottomBar = true);
    }

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

            // Auto-scroll continu si l'audio est en lecture et auto-scroll activé
            if (isAudioPlaying &&
                _shouldAutoScroll &&
                _isAutoScrollEnabled &&
                (_lastManualScroll == null ||
                    DateTime.now().difference(_lastManualScroll!).inSeconds >
                        2)) {
              // Démarrer le scroll continu et fluide
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && _shouldAutoScroll && _isAutoScrollEnabled) {
                  _startContinuousScroll();
                }
              });
            } else if (!isAudioPlaying ||
                !_shouldAutoScroll ||
                !_isAutoScrollEnabled) {
              // Arrêter le scroll continu si l'audio s'arrête ou auto-scroll désactivé
              _stopContinuousScroll();
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
          // Arrêter le scroll continu quand on change de sourate
          _stopContinuousScroll();
        }
      });
    }

    // Gérer le scroll continu selon l'état de lecture
    if (isThisSurahPlaying &&
        isAudioPlaying &&
        _isAutoScrollEnabled &&
        _shouldAutoScroll) {
      // S'assurer que le scroll continu est actif
      if (!_isContinuousScrolling && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isAutoScrollEnabled && _shouldAutoScroll) {
            _startContinuousScroll();
          }
        });
      }
    } else {
      // Arrêter le scroll continu si l'audio s'arrête ou auto-scroll désactivé
      if (_isContinuousScrolling) {
        _stopContinuousScroll();
      }
    }

    // Si autoPlay est activé, démarrer automatiquement la lecture
    if (widget.autoPlay && !_hasAutoPlayed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hasAutoPlayed && mounted) {
          _hasAutoPlayed = true;

          // Attendre que les données de la sourate soient chargées
          surahDetailAsync.whenData((surahDetail) async {
            if (!mounted || surahDetail == null) return;

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
      if (surahDetail == null) return;
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
        surahsAsync.whenData((surahs) async {
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
        data: (surahDetail) => surahDetail == null
            ? _buildDataUnavailable(isDark)
            : _buildContent(surahDetail, isDark, isSurahFavorite),
        loading: () => _buildLoadingState(isDark),
        error: (error, stack) => _buildErrorState(error, isDark),
      ),
    );
  }

  /// Texte 100 % offline : base Tanzil absente ou vide.
  Widget _buildDataUnavailable(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Données non disponibles',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'La base Qur\'an (Tanzil) doit être fournie dans assets/db/quran.db pour la lecture offline.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    SurahDetailModel surahDetail,
    bool isDark,
    bool isSurahFavorite,
  ) {
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
                // Continuer la lecture : aller au dernier verset lu (si cette sourate est la dernière lue)
                Consumer(
                  builder: (context, ref, _) {
                    final lastSurah = ref.watch(lastReadSurahProvider);
                    final lastAyah = ref.watch(lastReadAyahProvider);
                    final isThisLastRead = lastSurah == widget.surah.number &&
                        lastAyah > 0 &&
                        lastAyah <= widget.surah.numberOfAyahs;
                    if (!isThisLastRead) return const SizedBox.shrink();
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _scrollToAyah(lastAyah - 1);
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Tooltip(
                          message: 'Reprendre ici (verset $lastAyah)',
                          child: Container(
                            margin: EdgeInsets.all(
                              ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 8.0,
                              ),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.pureWhite.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bookmark,
                              color: AppColors.luxuryGold,
                              size: ResponsiveUtils.adaptiveIconSize(
                                context,
                                base: 20.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(
                  width: ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
                ),
                // Settings icon - Responsive
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showSettingsPanel(isDark);
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
                        Icons.settings_rounded,
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

            // Nom arabe compact — transition entre app bar et contenu
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,
                  ),
                  horizontal: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 16.0,
                    tablet: 20.0,
                    desktop: 24.0,
                  ),
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.pureWhite,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.pureWhite.withOpacity(0.06)
                          : AppColors.deepBlue.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.surah.arabicName,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 22,
                        tablet: 26,
                        desktop: 28,
                      ),
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.luxuryGold.withOpacity(0.95)
                          : AppColors.deepBlue,
                      height: 1.3,
                      letterSpacing: ResponsiveUtils.responsive(
                        context,
                        mobile: 1.0,
                        tablet: 1.5,
                        desktop: 2.0,
                      ),
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
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

        // Mini lecteur audio en bas (même widget que l'accueil)
        _buildBottomMiniAudioPlayer(),

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

  /// Affiche la traduction du verset dans une bottom sheet (au tap).
  void _showTranslationForAyah(
    BuildContext context, {
    required int ayahNumber,
    required String translation,
    required bool isDark,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.5,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.ivory,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(
            color: AppColors.luxuryGold.withOpacity(0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.adaptivePadding(context, mobile: 16),
                vertical: 12,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.translate,
                    color: AppColors.luxuryGold,
                    size: 22,
                  ),
                  SizedBox(
                    width: ResponsiveUtils.adaptivePadding(context, mobile: 8),
                  ),
                  Text(
                    'Verset $ayahNumber',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 16,
                        tablet: 17,
                        desktop: 18,
                      ),
                      color: isDark
                          ? AppColors.pureWhite
                          : AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                    color: isDark
                        ? AppColors.pureWhite
                        : AppColors.textPrimary,
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: AppColors.luxuryGold.withOpacity(0.3),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  ResponsiveUtils.adaptivePadding(context, mobile: 16),
                ),
                child: Text(
                  translation,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 14,
                      tablet: 15,
                      desktop: 16,
                    ),
                    height: 1.5,
                    color: isDark
                        ? AppColors.pureWhite
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
            child: Consumer(
              builder: (context, ref, child) {
                final baseFontSize = ref.watch(arabicFontSizeProvider);
                final bismillahFontSize =
                    ResponsiveUtils.quranFontSize(context, baseFontSize * 1.07);
                return Text(
                  bismillah,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: bismillahFontSize,
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
                );
              },
            ),
          ),
        ],

        // Texte par ayah : tap sur un verset → afficher la traduction (bottom sheet)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < surahDetail.ayahs.length; i++) ...[
                MouseRegion(
                  cursor: SystemMouseCursors.help,
                  child: GestureDetector(
                    onTap: () => _showTranslationForAyah(
                      context,
                      ayahNumber: i + 1,
                      translation: surahDetail.ayahs[i].translation ??
                          'Traduction non disponible.',
                      isDark: isDark,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i < surahDetail.ayahs.length - 1
                            ? ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 6,
                                tablet: 8,
                                desktop: 10,
                              )
                            : 0,
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: _buildSpansForSingleAyah(
                            surahDetail,
                            i,
                            isDark,
                          ),
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.justify,
                      ),
                    ),
                  ),
                ),
              ],
            ],
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
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<InlineSpan> _buildAyahSpans(SurahDetailModel surahDetail, bool isDark) {
    final List<InlineSpan> spans = [];
    for (int i = 0; i < surahDetail.ayahs.length; i++) {
      spans.addAll(_buildSpansForSingleAyah(surahDetail, i, isDark));
      if (i < surahDetail.ayahs.length - 1) {
        spans.add(const TextSpan(text: '  '));
      }
    }
    return spans;
  }

  void _buildAyahSpansLegacy(SurahDetailModel surahDetail, bool isDark) {
    final currentPlayingSurah = ref.read(currentPlayingSurahProvider);
    final isAudioPlaying = ref.read(isAudioPlayingProvider);
    final isThisSurahPlaying = currentPlayingSurah == widget.surah.number;
    final baseFontSize = ref.read(arabicFontSizeProvider);
    final fontSize =
        ResponsiveUtils.quranFontSize(context, baseFontSize);
    final pauseMarksTanzil = ref.read(pauseMarksTanzilProvider);
    final List<InlineSpan> spans = [];

    for (int i = 0; i < surahDetail.ayahs.length; i++) {
      final ayah = surahDetail.ayahs[i];
      final isHighlighted = _highlightedAyahIndex == i;
      final isPlaying =
          isThisSurahPlaying && _currentAyahIndex == i && isAudioPlaying;
      final isActive = isHighlighted || isPlaying;
      // Mise en avant uniquement de l’ayah en lecture ou tapée (plus de « highlight » global)
      final shouldHighlight = isActive;

      // Texte arabe avec pause marks Tanzil (style web : marques en petit, couleur distincte)
      final baseStyle = TextStyle(
        fontFamily: 'Cairo',
        fontSize: fontSize,
        height: ResponsiveUtils.responsive(
          context,
          mobile: 2.0,
          tablet: 2.2,
          desktop: 2.4,
        ),
        fontWeight: shouldHighlight ? FontWeight.w700 : FontWeight.w600,
        color: shouldHighlight
            ? AppColors.luxuryGold
            : (isDark ? AppColors.pureWhite : AppColors.textPrimary),
        backgroundColor: isPlaying
            ? AppColors.luxuryGold.withOpacity(0.2)
            : isHighlighted
            ? AppColors.luxuryGold.withOpacity(0.25)
            : null,
        shadows: shouldHighlight
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
      );
      // Style Tanzil pour les marques de waqf : petit, exposant, couleur or
      final pauseMarkStyle = pauseMarksTanzil
          ? baseStyle.copyWith(
              fontSize: fontSize * 0.52,
              height: 1.0,
              color: AppColors.luxuryGold.withOpacity(isDark ? 0.92 : 0.88),
              fontWeight: FontWeight.w500,
            )
          : baseStyle.copyWith(fontSize: fontSize * 0.7, height: 1.2);
      final segments = splitByPauseMarks(ayah.text);
      for (final segment in segments) {
        final isPause = segmentIsPauseMark(segment);
        spans.add(
          TextSpan(
            text: segment,
            style: isPause ? pauseMarkStyle : baseStyle,
          ),
        );
      }
      spans.add(TextSpan(text: ' ', style: baseStyle));

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
  }

  /// Spans pour un seul ayah (texte + pause marks + badge). Utilisé pour le tooltip « translate on mouse over ».
  List<InlineSpan> _buildSpansForSingleAyah(
    SurahDetailModel surahDetail,
    int ayahIndex,
    bool isDark,
  ) {
    final ayah = surahDetail.ayahs[ayahIndex];
    final currentPlayingSurah = ref.read(currentPlayingSurahProvider);
    final isAudioPlaying = ref.read(isAudioPlayingProvider);
    final isThisSurahPlaying = currentPlayingSurah == widget.surah.number;
    final baseFontSize = ref.read(arabicFontSizeProvider);
    final fontSize =
        ResponsiveUtils.quranFontSize(context, baseFontSize);
    final pauseMarksTanzil = ref.read(pauseMarksTanzilProvider);
    final isHighlighted = _highlightedAyahIndex == ayahIndex;
    final isPlaying =
        isThisSurahPlaying && _currentAyahIndex == ayahIndex && isAudioPlaying;
    final isActive = isHighlighted || isPlaying;
    final shouldHighlight = isActive;

    final baseStyle = TextStyle(
      fontFamily: 'Cairo',
      fontSize: fontSize,
      height: ResponsiveUtils.responsive(
        context,
        mobile: 2.0,
        tablet: 2.2,
        desktop: 2.4,
      ),
      fontWeight: shouldHighlight ? FontWeight.w700 : FontWeight.w600,
      color: shouldHighlight
          ? AppColors.luxuryGold
          : (isDark ? AppColors.pureWhite : AppColors.textPrimary),
      backgroundColor: isPlaying
          ? AppColors.luxuryGold.withOpacity(0.2)
          : isHighlighted
              ? AppColors.luxuryGold.withOpacity(0.25)
              : null,
      shadows: shouldHighlight
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
    );
    final pauseMarkStyle = pauseMarksTanzil
        ? baseStyle.copyWith(
            fontSize: fontSize * 0.52,
            height: 1.0,
            color: AppColors.luxuryGold.withOpacity(isDark ? 0.92 : 0.88),
            fontWeight: FontWeight.w500,
          )
        : baseStyle.copyWith(fontSize: fontSize * 0.7, height: 1.2);

    final List<InlineSpan> out = [];
    final segments = splitByPauseMarks(ayah.text);
    for (final segment in segments) {
      final isPause = segmentIsPauseMark(segment);
      out.add(
        TextSpan(
          text: segment,
          style: isPause ? pauseMarkStyle : baseStyle,
        ),
      );
    }
    out.add(TextSpan(text: ' ', style: baseStyle));
    out.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _buildAyahBadge(
          ayahNumber: ayah.numberInSurah,
          isHighlighted: isHighlighted,
          isPlaying: isPlaying,
        ),
      ),
    );
    return out;
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

  /// Démarre la lecture de la sourate affichée (utilisé par le mini player)
  Future<void> _playCurrentSurah() async {
    try {
      final audioUrlsAsync = ref.read(
        surahAudioUrlsProvider(widget.surah.number),
      );
      final audioUrls = audioUrlsAsync.when(
        data: (urls) => urls,
        loading: () => <String>[],
        error: (_, __) => <String>[],
      );
      if (audioUrls.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                audioUrlsAsync.isLoading
                    ? 'Chargement des pistes audio…'
                    : 'Aucune piste audio disponible. Réessayez.',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      await _loadAndPlaySurah(audioUrls);
    } catch (e) {
      debugPrint('Error starting surah playback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadAndPlaySurah(List<String> audioUrls) async {
    final playlistService = ref.read(globalAudioPlaylistServiceProvider);
    ref.read(currentPlayingSurahProvider.notifier).state = widget.surah.number;
    ref.read(currentPlayingSurahNameProvider.notifier).state = widget.surah.name;
    ref.read(currentSurahTotalAyahsProvider.notifier).state =
        widget.surah.numberOfAyahs;
    await playlistService.loadSurahPlaylist(audioUrls);
    if (mounted) await playlistService.play();
  }

  /// Mini lecteur audio en bas (play/pause, next/previous ayah)
  Widget _buildBottomMiniAudioPlayer() {
    const barHeight = 80.0;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: _showBottomBar ? 0 : -barHeight,
      left: 0,
      right: 0,
      child: MiniAudioPlayer(
        onTap: () {},
        currentSurahNumber: widget.surah.number,
        currentSurahName: widget.surah.name,
        currentSurahTotalAyahs: widget.surah.numberOfAyahs,
        onPlayCurrentSurah: _playCurrentSurah,
      ),
    );
  }


  /// Afficher le panneau de paramètres (ouvre depuis la droite)
  void _showSettingsPanel(bool isDark) {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: 'Paramètres',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: _SettingsPanelContent(
              isDark: isDark,
              surahNumber: widget.surah.number,
              showScriptSelector: (ctx, dark, r) =>
                  _showScriptSelector(ctx, dark, r),
              showReciterSelector: (ctx, dark, r) =>
                  _showReciterSelector(ctx, dark, r),
              showTranslationSelector: (ctx, dark, r) =>
                  _showTranslationSelector(ctx, dark, r),
              showRepetitionSelector: (ctx, dark, r) =>
                  _showRepetitionSelector(ctx, dark, r),
              showPauseMarksLegend: (ctx, r) => _showPauseMarksLegend(ctx, r),
              downloadSurahAudio: (dark) => _downloadSurahAudio(dark),
              isAutoScrollEnabled: _isAutoScrollEnabled,
              showTranslation: _showTranslation,
              onAutoScrollChanged: (value) {
                setState(() {
                  _isAutoScrollEnabled = value;
                  _shouldAutoScroll = value;
                });
                final isAudioPlaying = ref.read(isAudioPlayingProvider);
                final currentSurah = ref.read(currentPlayingSurahProvider);
                final isThisSurahPlaying = currentSurah == widget.surah.number;

                if (_isAutoScrollEnabled &&
                    isAudioPlaying &&
                    isThisSurahPlaying) {
                  _startContinuousScroll();
                } else {
                  _stopContinuousScroll();
                }
              },
              onTranslationChanged: (value) {
                setState(() {
                  _showTranslation = value;
                });
              },
            ),
          ),
        );
      },
    );
  }

  /// Légende des marques de waqf (Tanzil) — م، لا، ج، etc.
  void _showPauseMarksLegend(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(
          ResponsiveUtils.adaptivePadding(context, mobile: 20.0),
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.luxuryGold.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(
                height: ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
              ),
              Text(
                'Marques de waqf (Tanzil)',
                style: TextStyle(
                  color: isDark ? AppColors.pureWhite : AppColors.textPrimary,
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Signes du Mushaf de Médine pour guider la récitation.',
                style: TextStyle(
                  color: isDark
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
              const SizedBox(height: 16),
              _legendRow(context, isDark, 'م', 'Pause obligatoire'),
              _legendRow(context, isDark, 'لا', 'Ne pas s’arrêter'),
              _legendRow(context, isDark, 'ج', 'Pause ou continuer (équivalent)'),
              _legendRow(context, isDark, 'قلی', 'Mieux s’arrêter'),
              _legendRow(context, isDark, 'صلی', 'Mieux continuer'),
              _legendRow(context, isDark, '∴ ∴', 'Pause à l’un ou l’autre, pas aux deux'),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendRow(BuildContext ctx, bool isDark, String mark, String meaning) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            alignment: Alignment.center,
            child: Text(
              mark,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: ResponsiveUtils.adaptiveFontSize(
                  ctx,
                  mobile: 20,
                  tablet: 22,
                  desktop: 24,
                ),
                color: AppColors.luxuryGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              meaning,
              style: TextStyle(
                color: isDark
                    ? AppColors.pureWhite.withOpacity(0.9)
                    : AppColors.textPrimary,
                fontSize: ResponsiveUtils.adaptiveFontSize(
                  ctx,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Afficher le sélecteur de récitateur
  void _showReciterSelector(BuildContext context, bool isDark, WidgetRef ref) {
    HapticFeedback.lightImpact();
    final popularReciters = AudioService.popularReciters;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, consumerRef, child) {
            final screenHeight = MediaQuery.of(context).size.height;
            final maxHeight = screenHeight * 0.85; // Max 85% of screen height
            final selectedReciterFromRef = consumerRef.read(
              selectedReciterPersistentProvider,
            );

            return Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
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
                        top: ResponsiveUtils.adaptivePadding(
                          context,
                          mobile: 12.0,
                        ),
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
                    // Title
                    Padding(
                      padding: EdgeInsets.all(
                        ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
                      ),
                      child: Text(
                        'Sélectionner un récitateur',
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
                    ),
                    // Scrollable list of reciters
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 16.0,
                            tablet: 20.0,
                            desktop: 24.0,
                          ),
                          vertical: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 8.0,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...popularReciters.map((reciter) {
                              final isSelected =
                                  selectedReciterFromRef == reciter['id'];
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    HapticFeedback.mediumImpact();
                                    final currentSurah = consumerRef.read(
                                      currentPlayingSurahProvider,
                                    );
                                    final isAudioPlaying = consumerRef.read(
                                      isAudioPlayingProvider,
                                    );
                                    // Get the surah number - this method is called from settings panel
                                    // so we need to get it from the current playing surah or use a default
                                    final surahNumber = currentSurah ?? 1;
                                    final isThisSurahPlaying =
                                        currentSurah != null;
                                    final wasPlaying =
                                        isThisSurahPlaying && isAudioPlaying;

                                    // Changer le récitateur
                                    await consumerRef
                                        .read(
                                          selectedReciterPersistentProvider
                                              .notifier,
                                        )
                                        .setReciter(reciter['id']!);

                                    // Si une sourate est en cours, la recharger avec le nouveau récitateur
                                    if (isThisSurahPlaying) {
                                      try {
                                        final audioService = consumerRef.read(
                                          audioServiceProvider,
                                        );
                                        final audioUrls = await audioService
                                            .getSurahAudioUrls(
                                              surahNumber,
                                              reciter: reciter['id']!,
                                            );

                                        if (audioUrls.isNotEmpty) {
                                          final playlistService = consumerRef.read(
                                            globalAudioPlaylistServiceProvider,
                                          );
                                          final currentIndex = consumerRef.read(
                                            currentAyahIndexProvider,
                                          );

                                          // Recharger avec le nouveau récitateur
                                          await playlistService
                                              .loadSurahPlaylist(
                                                audioUrls,
                                                startIndex: currentIndex,
                                              );

                                          // Redémarrer la lecture si elle était en cours
                                          if (wasPlaying) {
                                            await playlistService.play();
                                          }

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Récitateur changé: ${reciter['name']}',
                                                ),
                                                backgroundColor:
                                                    AppColors.luxuryGold,
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        debugPrint(
                                          'Error changing reciter: $e',
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Erreur: $e'),
                                              backgroundColor: AppColors.error,
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }

                                    // Invalider le provider pour recharger les URLs
                                    if (currentSurah != null) {
                                      consumerRef.invalidate(
                                        surahAudioUrlsProvider(currentSurah),
                                      );
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
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
                                        mobile: 12.0,
                                        tablet: 14.0,
                                        desktop: 16.0,
                                      ),
                                    ),
                                    margin: EdgeInsets.only(
                                      bottom: ResponsiveUtils.adaptivePadding(
                                        context,
                                        mobile: 8.0,
                                      ),
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDark
                                                ? AppColors.luxuryGold
                                                      .withOpacity(0.2)
                                                : AppColors.luxuryGold
                                                      .withOpacity(0.1))
                                          : (isDark
                                                ? AppColors.darkCard
                                                : AppColors.ivory.withOpacity(
                                                    0.5,
                                                  )),
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveUtils.adaptiveBorderRadius(
                                          context,
                                          base: 12.0,
                                        ),
                                      ),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.luxuryGold.withOpacity(
                                                0.5,
                                              )
                                            : (isDark
                                                  ? AppColors.pureWhite
                                                        .withOpacity(0.1)
                                                  : AppColors.deepBlue
                                                        .withOpacity(0.1)),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: AppColors.luxuryGold,
                                            size:
                                                ResponsiveUtils.adaptiveIconSize(
                                                  context,
                                                  base: 24.0,
                                                ),
                                          ),
                                        if (isSelected)
                                          SizedBox(
                                            width:
                                                ResponsiveUtils.adaptivePadding(
                                                  context,
                                                  mobile: 12.0,
                                                ),
                                          ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                reciter['name'] ?? '',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? AppColors.pureWhite
                                                      : AppColors.textPrimary,
                                                  fontSize:
                                                      ResponsiveUtils.adaptiveFontSize(
                                                        context,
                                                        mobile: 16,
                                                        tablet: 17,
                                                        desktop: 18,
                                                      ),
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                              SizedBox(
                                                height:
                                                    ResponsiveUtils.adaptivePadding(
                                                      context,
                                                      mobile: 4.0,
                                                    ),
                                              ),
                                              Text(
                                                reciter['arabicName'] ?? '',
                                                style: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  color: isDark
                                                      ? AppColors.pureWhite
                                                            .withOpacity(0.7)
                                                      : AppColors.textSecondary,
                                                  fontSize:
                                                      ResponsiveUtils.adaptiveFontSize(
                                                        context,
                                                        mobile: 14,
                                                        tablet: 15,
                                                        desktop: 16,
                                                      ),
                                                ),
                                                textDirection:
                                                    TextDirection.rtl,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            SizedBox(
                              height: ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 12.0,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Annuler',
                                style: TextStyle(
                                  color: isDark
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
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Afficher le sélecteur de traduction
  void _showTranslationSelector(
    BuildContext context,
    bool isDark,
    WidgetRef ref,
  ) {
    HapticFeedback.lightImpact();
    final selectedTranslation = ref.read(translationEditionProvider);
    final allTranslations = AvailableTranslations.all;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final maxHeight = screenHeight * 0.85;

        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
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
                // Title
                Padding(
                  padding: EdgeInsets.all(
                    ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
                  ),
                  child: Text(
                    'Sélectionner une traduction',
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
                ),
                // Scrollable list of translations
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 16.0,
                        tablet: 20.0,
                        desktop: 24.0,
                      ),
                      vertical: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 8.0,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...allTranslations.entries.map((entry) {
                          final language = entry.key;
                          final translations = entry.value;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: ResponsiveUtils.adaptivePadding(
                                    context,
                                    mobile: 8.0,
                                  ),
                                  top: ResponsiveUtils.adaptivePadding(
                                    context,
                                    mobile: 12.0,
                                  ),
                                ),
                                child: Text(
                                  language,
                                  style: TextStyle(
                                    color: AppColors.luxuryGold,
                                    fontSize: ResponsiveUtils.adaptiveFontSize(
                                      context,
                                      mobile: 14,
                                      tablet: 15,
                                      desktop: 16,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ...translations.map((translation) {
                                final isSelected =
                                    selectedTranslation == translation['id'];
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      HapticFeedback.mediumImpact();
                                      await ref
                                          .read(
                                            translationEditionProvider.notifier,
                                          )
                                          .setTranslationEdition(
                                            translation['id']!,
                                          );
                                      // Invalider le provider pour recharger avec la nouvelle traduction
                                      ref.invalidate(
                                        surahDetailProvider(
                                          widget.surah.number,
                                        ),
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Traduction: ${translation['name']}',
                                            ),
                                            backgroundColor:
                                                AppColors.luxuryGold,
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                          ),
                                        );
                                        Navigator.pop(context);
                                      }
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
                                          mobile: 12.0,
                                          tablet: 14.0,
                                          desktop: 16.0,
                                        ),
                                      ),
                                      margin: EdgeInsets.only(
                                        bottom: ResponsiveUtils.adaptivePadding(
                                          context,
                                          mobile: 8.0,
                                        ),
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (isDark
                                                  ? AppColors.luxuryGold
                                                        .withOpacity(0.2)
                                                  : AppColors.luxuryGold
                                                        .withOpacity(0.1))
                                            : (isDark
                                                  ? AppColors.darkCard
                                                  : AppColors.ivory.withOpacity(
                                                      0.5,
                                                    )),
                                        borderRadius: BorderRadius.circular(
                                          ResponsiveUtils.adaptiveBorderRadius(
                                            context,
                                            base: 12.0,
                                          ),
                                        ),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.luxuryGold
                                                    .withOpacity(0.5)
                                              : (isDark
                                                    ? AppColors.pureWhite
                                                          .withOpacity(0.1)
                                                    : AppColors.deepBlue
                                                          .withOpacity(0.1)),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          if (isSelected)
                                            Icon(
                                              Icons.check_circle,
                                              color: AppColors.luxuryGold,
                                              size:
                                                  ResponsiveUtils.adaptiveIconSize(
                                                    context,
                                                    base: 24.0,
                                                  ),
                                            ),
                                          if (isSelected)
                                            SizedBox(
                                              width:
                                                  ResponsiveUtils.adaptivePadding(
                                                    context,
                                                    mobile: 12.0,
                                                  ),
                                            ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  translation['name'] ?? '',
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? AppColors.pureWhite
                                                        : AppColors.textPrimary,
                                                    fontSize:
                                                        ResponsiveUtils.adaptiveFontSize(
                                                          context,
                                                          mobile: 16,
                                                          tablet: 17,
                                                          desktop: 18,
                                                        ),
                                                    fontWeight: isSelected
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                                if (translation['description'] !=
                                                    null)
                                                  SizedBox(
                                                    height:
                                                        ResponsiveUtils.adaptivePadding(
                                                          context,
                                                          mobile: 4.0,
                                                        ),
                                                  ),
                                                if (translation['description'] !=
                                                    null)
                                                  Text(
                                                    translation['description']!,
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? AppColors.pureWhite
                                                                .withOpacity(
                                                                  0.7,
                                                                )
                                                          : AppColors
                                                                .textSecondary,
                                                      fontSize:
                                                          ResponsiveUtils.adaptiveFontSize(
                                                            context,
                                                            mobile: 13,
                                                            tablet: 14,
                                                            desktop: 15,
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
                              }),
                            ],
                          );
                        }),
                        SizedBox(
                          height: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 12.0,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Annuler',
                            style: TextStyle(
                              color: isDark
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
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Afficher le sélecteur de répétition
  void _showRepetitionSelector(
    BuildContext context,
    bool isDark,
    WidgetRef ref,
  ) {
    HapticFeedback.lightImpact();
    final selectedRepetition = ref.read(repetitionProvider);
    final repetitionOptions = [
      {'value': 'never', 'label': 'Never', 'icon': Icons.block},
      {'value': 'once', 'label': 'Once', 'icon': Icons.repeat_one},
      {'value': 'twice', 'label': 'Twice', 'icon': Icons.repeat},
      {'value': 'thrice', 'label': '3 times', 'icon': Icons.repeat},
      {'value': 'infinite', 'label': 'Infinite', 'icon': Icons.all_inclusive},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final maxHeight = screenHeight * 0.6;

        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
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
                // Title
                Padding(
                  padding: EdgeInsets.all(
                    ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
                  ),
                  child: Text(
                    'Repetition',
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
                ),
                // Scrollable list of repetition options
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 16.0,
                        tablet: 20.0,
                        desktop: 24.0,
                      ),
                      vertical: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 8.0,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...repetitionOptions.map((option) {
                          final isSelected =
                              selectedRepetition == option['value'];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                HapticFeedback.mediumImpact();
                                await ref
                                    .read(repetitionProvider.notifier)
                                    .setRepetition(option['value'] as String);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Repetition: ${option['label']}',
                                      ),
                                      backgroundColor: AppColors.luxuryGold,
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  Navigator.pop(context);
                                }
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
                                    mobile: 12.0,
                                    tablet: 14.0,
                                    desktop: 16.0,
                                  ),
                                ),
                                margin: EdgeInsets.only(
                                  bottom: ResponsiveUtils.adaptivePadding(
                                    context,
                                    mobile: 8.0,
                                  ),
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark
                                            ? AppColors.luxuryGold.withOpacity(
                                                0.2,
                                              )
                                            : AppColors.luxuryGold.withOpacity(
                                                0.1,
                                              ))
                                      : (isDark
                                            ? AppColors.darkCard
                                            : AppColors.ivory.withOpacity(0.5)),
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveUtils.adaptiveBorderRadius(
                                      context,
                                      base: 12.0,
                                    ),
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.luxuryGold.withOpacity(0.5)
                                        : (isDark
                                              ? AppColors.pureWhite.withOpacity(
                                                  0.1,
                                                )
                                              : AppColors.deepBlue.withOpacity(
                                                  0.1,
                                                )),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      option['icon'] as IconData,
                                      color: isSelected
                                          ? AppColors.luxuryGold
                                          : (isDark
                                                ? AppColors.pureWhite
                                                      .withOpacity(0.7)
                                                : AppColors.textSecondary),
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
                                    Expanded(
                                      child: Text(
                                        option['label'] as String,
                                        style: TextStyle(
                                          color: isDark
                                              ? AppColors.pureWhite
                                              : AppColors.textPrimary,
                                          fontSize:
                                              ResponsiveUtils.adaptiveFontSize(
                                                context,
                                                mobile: 16,
                                                tablet: 17,
                                                desktop: 18,
                                              ),
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: AppColors.luxuryGold,
                                        size: ResponsiveUtils.adaptiveIconSize(
                                          context,
                                          base: 24.0,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        SizedBox(
                          height: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 12.0,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Annuler',
                            style: TextStyle(
                              color: isDark
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
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Afficher le sélecteur de script/édition arabe
  void _showScriptSelector(BuildContext context, bool isDark, WidgetRef ref) {
    HapticFeedback.lightImpact();
    final selectedScript = ref.read(arabicScriptProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final maxHeight = screenHeight * 0.85;

        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
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
                // Title
                Padding(
                  padding: EdgeInsets.all(
                    ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
                  ),
                  child: Text(
                    'Sélectionner un script/Édition',
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
                ),
                // Scrollable list of scripts - Use Consumer to get cached data
                Flexible(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final arabicScriptsAsync = ref.watch(
                        arabicScriptEditionsProvider,
                      );
                      return arabicScriptsAsync.when(
                        data: (editions) {
                          if (editions.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: EdgeInsets.all(
                                  ResponsiveUtils.adaptivePadding(
                                    context,
                                    mobile: 24.0,
                                  ),
                                ),
                                child: Text(
                                  'Aucune édition disponible',
                                  style: TextStyle(
                                    color: isDark
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
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 16.0,
                                tablet: 20.0,
                                desktop: 24.0,
                              ),
                              vertical: ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 8.0,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...editions.map((edition) {
                                  final isSelected =
                                      selectedScript == edition.identifier;
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        ref
                                            .read(arabicScriptProvider.notifier)
                                            .updateScript(edition.identifier);
                                        // Invalider le provider pour recharger avec la nouvelle édition
                                        ref.invalidate(
                                          surahDetailProvider(
                                            widget.surah.number,
                                          ),
                                        );
                                        setState(
                                          () {},
                                        ); // Rebuild to apply new script
                                        if (mounted) {
                                          Navigator.pop(context);
                                        }
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
                                            mobile: 12.0,
                                            tablet: 14.0,
                                            desktop: 16.0,
                                          ),
                                        ),
                                        margin: EdgeInsets.only(
                                          bottom:
                                              ResponsiveUtils.adaptivePadding(
                                                context,
                                                mobile: 8.0,
                                              ),
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? (isDark
                                                    ? AppColors.luxuryGold
                                                          .withOpacity(0.2)
                                                    : AppColors.luxuryGold
                                                          .withOpacity(0.1))
                                              : (isDark
                                                    ? AppColors.darkCard
                                                    : AppColors.ivory
                                                          .withOpacity(0.5)),
                                          borderRadius: BorderRadius.circular(
                                            ResponsiveUtils.adaptiveBorderRadius(
                                              context,
                                              base: 12.0,
                                            ),
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.luxuryGold
                                                      .withOpacity(0.5)
                                                : (isDark
                                                      ? AppColors.pureWhite
                                                            .withOpacity(0.1)
                                                      : AppColors.deepBlue
                                                            .withOpacity(0.1)),
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle,
                                                color: AppColors.luxuryGold,
                                                size:
                                                    ResponsiveUtils.adaptiveIconSize(
                                                      context,
                                                      base: 24.0,
                                                    ),
                                              ),
                                            if (isSelected)
                                              SizedBox(
                                                width:
                                                    ResponsiveUtils.adaptivePadding(
                                                      context,
                                                      mobile: 12.0,
                                                    ),
                                              ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    edition
                                                            .englishName
                                                            .isNotEmpty
                                                        ? edition.englishName
                                                        : edition.name,
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? AppColors.pureWhite
                                                          : AppColors
                                                                .textPrimary,
                                                      fontSize:
                                                          ResponsiveUtils.adaptiveFontSize(
                                                            context,
                                                            mobile: 16,
                                                            tablet: 17,
                                                            desktop: 18,
                                                          ),
                                                      fontWeight: isSelected
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                    ),
                                                  ),
                                                  if (edition.name.isNotEmpty &&
                                                      edition.name !=
                                                          edition.englishName)
                                                    SizedBox(
                                                      height:
                                                          ResponsiveUtils.adaptivePadding(
                                                            context,
                                                            mobile: 4.0,
                                                          ),
                                                    ),
                                                  if (edition.name.isNotEmpty &&
                                                      edition.name !=
                                                          edition.englishName)
                                                    Text(
                                                      edition.name,
                                                      style: TextStyle(
                                                        fontFamily: 'Cairo',
                                                        color: isDark
                                                            ? AppColors
                                                                  .pureWhite
                                                                  .withOpacity(
                                                                    0.7,
                                                                  )
                                                            : AppColors
                                                                  .textSecondary,
                                                        fontSize:
                                                            ResponsiveUtils.adaptiveFontSize(
                                                              context,
                                                              mobile: 14,
                                                              tablet: 15,
                                                              desktop: 16,
                                                            ),
                                                      ),
                                                      textDirection:
                                                          TextDirection.rtl,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                SizedBox(
                                  height: ResponsiveUtils.adaptivePadding(
                                    context,
                                    mobile: 12.0,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    'Annuler',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.pureWhite.withOpacity(0.7)
                                          : AppColors.textSecondary,
                                      fontSize:
                                          ResponsiveUtils.adaptiveFontSize(
                                            context,
                                            mobile: 16,
                                            tablet: 17,
                                            desktop: 18,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loading: () => Center(
                          child: Padding(
                            padding: EdgeInsets.all(
                              ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 24.0,
                              ),
                            ),
                            child: CircularProgressIndicator(
                              color: isDark
                                  ? AppColors.luxuryGold
                                  : AppColors.deepBlue,
                            ),
                          ),
                        ),
                        error: (error, stack) => Center(
                          child: Padding(
                            padding: EdgeInsets.all(
                              ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 24.0,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: AppColors.error,
                                ),
                                SizedBox(
                                  height: ResponsiveUtils.adaptivePadding(
                                    context,
                                    mobile: 12.0,
                                  ),
                                ),
                                Text(
                                  'Erreur de chargement',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.pureWhite
                                        : AppColors.textPrimary,
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
                                    ref.invalidate(
                                      arabicScriptEditionsProvider,
                                    );
                                  },
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Télécharger l'audio de la sourate pour l'écoute hors ligne
  Future<void> _downloadSurahAudio(bool isDark) async {
    HapticFeedback.lightImpact();

    // Afficher un dialog de confirmation
    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 20.0),
          ),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        title: Text(
          'Télécharger l\'audio',
          style: TextStyle(
            color: isDark ? AppColors.pureWhite : AppColors.textPrimary,
            fontSize: ResponsiveUtils.adaptiveFontSize(
              context,
              mobile: 18,
              tablet: 20,
              desktop: 22,
            ),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Voulez-vous télécharger l\'audio de "${widget.surah.name}" pour l\'écouter hors ligne ?',
          style: TextStyle(
            color: isDark
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Annuler',
              style: TextStyle(
                color: isDark
                    ? AppColors.pureWhite.withOpacity(0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.luxuryGold,
              foregroundColor: AppColors.pureWhite,
            ),
            child: const Text('Télécharger'),
          ),
        ],
      ),
    );

    if (shouldDownload != true || !mounted) return;

    try {
      // Afficher un indicateur de progression
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.adaptiveBorderRadius(context, base: 20.0),
            ),
          ),
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.pureWhite,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.luxuryGold),
              ),
              SizedBox(
                height: ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
              ),
              Text(
                'Téléchargement en cours...',
                style: TextStyle(
                  color: isDark ? AppColors.pureWhite : AppColors.textPrimary,
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 14,
                    tablet: 15,
                    desktop: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // Récupérer les URLs audio
      final audioUrlsAsync = ref.read(
        surahAudioUrlsProvider(widget.surah.number),
      );
      final audioUrls = audioUrlsAsync
          .whenData((urls) => urls)
          .when(
            data: (urls) => urls,
            loading: () => <String>[],
            error: (_, __) => <String>[],
          );

      if (audioUrls.isEmpty) {
        if (mounted) {
          Navigator.pop(context); // Fermer le dialog de progression
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Aucun audio disponible pour cette sourate'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Télécharger les fichiers audio
      // Note: Pour une implémentation complète, il faudrait utiliser
      // un package comme dio ou http pour télécharger et sauvegarder
      // les fichiers localement avec path_provider
      // Pour l'instant, on simule le téléchargement en mettant en cache
      final audioService = ref.read(audioServiceProvider);
      final selectedReciter = ref.read(selectedReciterPersistentProvider);

      // Forcer le rechargement pour mettre en cache
      await audioService.getSurahAudioUrls(
        widget.surah.number,
        reciter: selectedReciter,
        forceNetwork: true,
      );

      if (mounted) {
        Navigator.pop(context); // Fermer le dialog de progression
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.pureWhite, size: 20),
                SizedBox(
                  width: ResponsiveUtils.adaptivePadding(context, mobile: 12.0),
                ),
                Expanded(
                  child: Text(
                    'Audio de "${widget.surah.name}" mis en cache pour l\'écoute hors ligne',
                    style: TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 14,
                        tablet: 15,
                        desktop: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.luxuryGold,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.adaptiveBorderRadius(context, base: 12.0),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error downloading audio: $e');
      if (mounted) {
        Navigator.pop(context); // Fermer le dialog de progression
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de téléchargement: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Afficher le sélecteur de sourate avec recherche et navigation
  void _showSurahSelector(BuildContext context, bool isDark) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => _JuzSurahAyahSelectorBottomSheet(
        currentSurahNumber: widget.surah.number,
        currentAyahNumber: null, // Can be enhanced to track current ayah
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

                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
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

/// Widget pour le contenu du panneau de paramètres avec onglets
class _SettingsPanelContent extends ConsumerStatefulWidget {
  final bool isDark;
  final int surahNumber;
  final Function(BuildContext, bool, WidgetRef) showScriptSelector;
  final Function(BuildContext, bool, WidgetRef) showReciterSelector;
  final Function(BuildContext, bool, WidgetRef) showTranslationSelector;
  final Function(BuildContext, bool, WidgetRef) showRepetitionSelector;
  final void Function(BuildContext, WidgetRef) showPauseMarksLegend;
  final Function(bool) downloadSurahAudio;
  final bool isAutoScrollEnabled;
  final bool showTranslation;
  final Function(bool) onAutoScrollChanged;
  final Function(bool) onTranslationChanged;

  const _SettingsPanelContent({
    required this.isDark,
    required this.surahNumber,
    required this.showScriptSelector,
    required this.showReciterSelector,
    required this.showTranslationSelector,
    required this.showRepetitionSelector,
    required this.showPauseMarksLegend,
    required this.downloadSurahAudio,
    required this.isAutoScrollEnabled,
    required this.showTranslation,
    required this.onAutoScrollChanged,
    required this.onTranslationChanged,
  });

  @override
  ConsumerState<_SettingsPanelContent> createState() =>
      _SettingsPanelContentState();
}

class _SettingsPanelContentState extends ConsumerState<_SettingsPanelContent> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final panelWidth = ResponsiveUtils.responsive(
      context,
      mobile: screenWidth * 0.88,
      tablet: (screenWidth * 0.5).clamp(320.0, 420.0),
      desktop: 420.0,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: panelWidth,
      height: screenHeight,
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 24.0),
          ),
          bottomLeft: Radius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 24.0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: SafeArea(
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
            // Header
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
                  Expanded(
                    child: Text(
                      'Paramètres',
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
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.all(
                          ResponsiveUtils.adaptivePadding(context, mobile: 6.0),
                        ),
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? AppColors.pureWhite.withOpacity(0.1)
                              : AppColors.deepBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: widget.isDark
                              ? AppColors.pureWhite
                              : AppColors.textPrimary,
                          size: ResponsiveUtils.adaptiveIconSize(
                            context,
                            base: 20.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Single scrollable settings page
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 16.0,
                    tablet: 20.0,
                    desktop: 24.0,
                  ),
                  vertical: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 4.0,
                  ),
                ),
                child: _buildSinglePageContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(
        top: ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
        bottom: ResponsiveUtils.adaptivePadding(context, mobile: 8.0),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.luxuryGold,
          fontSize: ResponsiveUtils.adaptiveFontSize(
            context,
            mobile: 15,
            tablet: 16,
            desktop: 17,
          ),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _checkboxRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context, base: 8.0),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    onChanged(v ?? false);
                  },
                  activeColor: AppColors.luxuryGold,
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.luxuryGold;
                    }
                    return Colors.transparent;
                  }),
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.adaptivePadding(context, mobile: 12.0),
              ),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: widget.isDark
                        ? AppColors.pureWhite
                        : AppColors.textPrimary,
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
      ),
    );
  }

  Widget _settingsTile({
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context, base: 8.0),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.adaptivePadding(context, mobile: 12.0),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: TextStyle(
                    color: widget.isDark
                        ? AppColors.pureWhite
                        : AppColors.textPrimary,
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 15,
                      tablet: 16,
                      desktop: 17,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.adaptivePadding(context, mobile: 8.0),
              ),
              Flexible(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: widget.isDark
                        ? AppColors.pureWhite.withOpacity(0.6)
                        : AppColors.textSecondary,
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 13,
                      tablet: 14,
                      desktop: 15,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
              ),
              Icon(
                Icons.chevron_right,
                color: widget.isDark
                    ? AppColors.pureWhite.withOpacity(0.5)
                    : AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSinglePageContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ——— Vue ———
        _sectionHeader('Vue'),
        Consumer(
          builder: (context, ref, child) {
            final mode = ref.watch(readingModeProvider);
            return Column(
              children: [
                _radioRow('Page', 'page', mode, () {
                  HapticFeedback.selectionClick();
                  ref.read(readingModeProvider.notifier).setReadingMode('page');
                }),
                _radioRow('Liste', 'list', mode, () {
                  HapticFeedback.selectionClick();
                  ref.read(readingModeProvider.notifier).setReadingMode('list');
                }),
              ],
            );
          },
        ),

        // ——— Contenu ———
        _sectionHeader('Contenu'),
        _checkboxRow(
          label: 'Arabe',
          value: true,
          onChanged: (_) {}, // placeholder: Arabic always shown
        ),
        Consumer(
          builder: (context, ref, child) {
            final showTajweed = ref.watch(tajweedColorsProvider);
            return _checkboxRow(
              label: 'Tajwid',
              value: showTajweed,
              onChanged: (v) =>
                  ref.read(tajweedColorsProvider.notifier).toggle(v),
            );
          },
        ),
        _checkboxRow(
          label: 'Traduction',
          value: widget.showTranslation,
          onChanged: widget.onTranslationChanged,
        ),
        _checkboxRow(
          label: 'Tafsirs',
          value: false,
          onChanged: (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Les Tafsirs seront disponibles dans une prochaine mise à jour.',
                  ),
                  backgroundColor: AppColors.luxuryGold,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
        _checkboxRow(
          label: 'Mot par Mot',
          value: false,
          onChanged: (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'L\'affichage mot par mot sera disponible dans une prochaine mise à jour.',
                  ),
                  backgroundColor: AppColors.luxuryGold,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
        Consumer(
          builder: (context, ref, child) {
            final selectedId = ref.watch(translationEditionProvider);
            final name = AvailableTranslations.getName(selectedId);
            return _settingsTile(
              label: 'Traductions',
              subtitle: name.isNotEmpty ? name : '1 sélectionnée',
              onTap: () {
                Navigator.pop(context);
                widget.showTranslationSelector(context, widget.isDark, ref);
              },
            );
          },
        ),
        _settingsTile(
          label: 'Tafsirs',
          subtitle: 'Bientôt disponible',
          onTap: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'La sélection des Tafsirs sera disponible dans une prochaine mise à jour.',
                  ),
                  backgroundColor: AppColors.luxuryGold,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
        _settingsTile(
          label: 'Mot par Mot',
          subtitle: 'Bientôt disponible',
          onTap: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'L\'affichage mot par mot sera disponible dans une prochaine mise à jour.',
                  ),
                  backgroundColor: AppColors.luxuryGold,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),

        // ——— Type de Mushaf ———
        _sectionHeader('Type de Mushaf'),
        Consumer(
          builder: (context, ref, child) {
            final scriptId = ref.watch(arabicScriptProvider);
            final editionsAsync = ref.watch(arabicScriptEditionsProvider);
            final displayName = editionsAsync.when(
              data: (list) => list
                  .where((e) => e.identifier == scriptId)
                  .map((e) =>
                      e.englishName.isNotEmpty ? e.englishName : e.name)
                  .firstOrNull ??
                  'Mushaf Unicode Text',
              loading: () => 'Mushaf Unicode Text',
              error: (_, __) => 'Mushaf Unicode Text',
            );
            return _settingsTile(
              label: 'Type de Mushaf',
              subtitle: displayName,
              onTap: () {
                Navigator.pop(context);
                widget.showScriptSelector(context, widget.isDark, ref);
              },
            );
          },
        ),

        // ——— Règles de Tajwid ———
        _sectionHeader('Règles de Tajwid'),
        _settingsTile(
          label: 'Règles de Tajwid',
          subtitle: 'Symboles d\'arrêt, règles de prononciation',
          onTap: () {
            if (!mounted) return;
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
                title: Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.luxuryGold,
                      size: ResponsiveUtils.adaptiveIconSize(context, base: 24.0),
                    ),
                    SizedBox(
                      width: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
                    ),
                    Text(
                      'Règles de Tajwid',
                      style: TextStyle(
                        color: widget.isDark
                            ? AppColors.pureWhite
                            : AppColors.textPrimary,
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 18,
                          tablet: 20,
                          desktop: 22,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Text(
                    'Le Tajwid désigne les règles de prononciation et de récitation du Coran. '
                    'Il inclut les symboles d\'arrêt (waqf), les règles de prolongation (madd), '
                    'd\'assimilation (idgham) et d\'articulation (makharij). '
                    'Activez « Tajwid » dans Contenu pour afficher les couleurs de récitation dans le texte arabe.',
                    style: TextStyle(
                      color: widget.isDark
                          ? AppColors.pureWhite.withOpacity(0.9)
                          : AppColors.textSecondary,
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 14,
                        tablet: 15,
                        desktop: 16,
                      ),
                      height: 1.5,
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Fermer',
                      style: TextStyle(color: AppColors.luxuryGold),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // ——— Font ———
        _sectionHeader('Font'),
        Consumer(
          builder: (context, ref, child) {
            final scriptId = ref.watch(arabicScriptProvider);
            final editionsAsync = ref.watch(arabicScriptEditionsProvider);
            final fontLabel = editionsAsync.when(
              data: (list) {
                final e = list
                    .where((e) => e.identifier == scriptId)
                    .firstOrNull;
                if (e != null) {
                  return e.englishName.isNotEmpty ? e.englishName : e.name;
                }
                return 'KFGQPC Hafs, Uthmani/Madani';
              },
              loading: () => 'KFGQPC Hafs, Uthmani/Madani',
              error: (_, __) => 'KFGQPC Hafs, Uthmani/Madani',
            );
            return _settingsTile(
              label: 'Police du texte arabe',
              subtitle: fontLabel,
              onTap: () {
                Navigator.pop(context);
                widget.showScriptSelector(context, widget.isDark, ref);
              },
            );
          },
        ),
        Consumer(
          builder: (context, ref, child) {
            final fontSize = ref.watch(arabicFontSizeProvider);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: ResponsiveUtils.adaptivePadding(context, mobile: 8.0),
                    bottom: ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Taille police du texte arabe',
                        style: TextStyle(
                          color: widget.isDark
                              ? AppColors.pureWhite
                              : AppColors.textPrimary,
                          fontSize: ResponsiveUtils.adaptiveFontSize(
                            context,
                            mobile: 15,
                            tablet: 16,
                            desktop: 17,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 10.0,
                          ),
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.luxuryGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.adaptiveBorderRadius(
                              context,
                              base: 8.0,
                            ),
                          ),
                        ),
                        child: Text(
                          '${fontSize.toInt()}',
                          style: TextStyle(
                            color: AppColors.luxuryGold,
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 14,
                              tablet: 15,
                              desktop: 16,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: fontSize,
                  min: 20.0,
                  max: 40.0,
                  divisions: 20,
                  activeColor: AppColors.luxuryGold,
                  inactiveColor: widget.isDark
                      ? AppColors.pureWhite.withOpacity(0.2)
                      : AppColors.deepBlue.withOpacity(0.2),
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    ref.read(arabicFontSizeProvider.notifier).updateSize(value);
                  },
                ),
              ],
            );
          },
        ),

        // ——— Thème (optional, compact) ———
        _sectionHeader('Apparence'),
        Consumer(
          builder: (context, ref, child) {
            final currentThemeMode = ref.watch(themeModeProvider);
            final isLight = currentThemeMode == ThemeMode.light ||
                (currentThemeMode == ThemeMode.system && !widget.isDark);
            final isDark = currentThemeMode == ThemeMode.dark ||
                (currentThemeMode == ThemeMode.system && widget.isDark);
            return Row(
              children: [
                Expanded(
                  child: _buildThemeCard(
                    context,
                    'Clair',
                    AppColors.deepBlue,
                    isLight,
                    ThemeMode.light,
                    ref,
                  ),
                ),
                SizedBox(
                  width: ResponsiveUtils.adaptivePadding(context, mobile: 12.0),
                ),
                Expanded(
                  child: _buildThemeCard(
                    context,
                    'Sombre',
                    AppColors.darkBackground,
                    isDark,
                    ThemeMode.dark,
                    ref,
                  ),
                ),
              ],
            );
          },
        ),

        // ——— Audio ———
        _sectionHeader('Audio'),
        _settingsTile(
          label: 'Récitateur',
          subtitle: '',
          onTap: () {
            Navigator.pop(context);
            widget.showReciterSelector(context, widget.isDark, ref);
          },
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Défilement auto',
                style: TextStyle(
                  color: widget.isDark
                      ? AppColors.pureWhite
                      : AppColors.textPrimary,
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 15,
                    tablet: 16,
                    desktop: 17,
                  ),
                ),
              ),
              Switch(
                value: widget.isAutoScrollEnabled,
                onChanged: widget.onAutoScrollChanged,
                activeTrackColor: AppColors.luxuryGold.withOpacity(0.5),
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.luxuryGold;
                  }
                  return null;
                }),
              ),
            ],
          ),
        ),
        Consumer(
          builder: (context, ref, child) {
            final repetition = ref.watch(repetitionProvider);
            final labels = {
              'never': 'Jamais',
              'once': 'Une fois',
              'twice': 'Deux fois',
              'thrice': '3 fois',
              'infinite': 'Infini',
            };
            return _settingsTile(
              label: 'Répétition',
              subtitle: labels[repetition] ?? repetition,
              onTap: () {
                Navigator.pop(context);
                widget.showRepetitionSelector(context, widget.isDark, ref);
              },
            );
          },
        ),
        SizedBox(
          height: ResponsiveUtils.adaptivePadding(context, mobile: 12.0),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              widget.downloadSurahAudio(widget.isDark);
            },
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 12.0,
                ),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.luxuryGold,
                    AppColors.luxuryGold.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download_rounded,
                    color: AppColors.pureWhite,
                    size: ResponsiveUtils.adaptiveIconSize(context, base: 20.0),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 10.0,
                    ),
                  ),
                  Text(
                    'Télécharger l\'audio',
                    style: TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 15,
                        tablet: 16,
                        desktop: 17,
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
          height: ResponsiveUtils.adaptivePadding(context, mobile: 24.0),
        ),
      ],
    );
  }

  Widget _radioRow(
    String label,
    String value,
    String groupValue,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context, base: 8.0),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.adaptivePadding(context, mobile: 8.0),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Radio<String>(
                  value: value,
                  groupValue: groupValue,
                  onChanged: (_) => onTap(),
                  activeColor: AppColors.luxuryGold,
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.adaptivePadding(context, mobile: 12.0),
              ),
              Text(
                label,
                style: TextStyle(
                  color: widget.isDark
                      ? AppColors.pureWhite
                      : AppColors.textPrimary,
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 15,
                    tablet: 16,
                    desktop: 17,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element - kept for reference; settings moved to _buildSinglePageContent
  Widget _buildDisplayTab(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.adaptivePadding(
          context,
          mobile: 16.0,
          tablet: 20.0,
          desktop: 24.0,
        ),
        vertical: ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Themes section - Compact
          Text(
            'Themes',
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
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
          ),
          // Themes layout - Modern and Dark only
          Consumer(
            builder: (context, ref, child) {
              final currentThemeMode = ref.watch(themeModeProvider);
              final isSystemMode = currentThemeMode == ThemeMode.system;
              final isLightMode = currentThemeMode == ThemeMode.light;
              final isDarkMode = currentThemeMode == ThemeMode.dark;

              return Row(
                children: [
                  Expanded(
                    child: _buildThemeCard(
                      context,
                      'Modern',
                      AppColors.deepBlue,
                      isLightMode || (isSystemMode && !widget.isDark),
                      ThemeMode.light,
                      ref,
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
                    child: _buildThemeCard(
                      context,
                      'Dark',
                      AppColors.darkBackground,
                      isDarkMode || (isSystemMode && widget.isDark),
                      ThemeMode.dark,
                      ref,
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 20.0),
          ),
          // Text Size section - Improved
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Text Size',
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
              Consumer(
                builder: (context, ref, child) {
                  final fontSize = ref.watch(arabicFontSizeProvider);
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 10.0,
                      ),
                      vertical: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 4.0,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.luxuryGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.adaptiveBorderRadius(
                          context,
                          base: 8.0,
                        ),
                      ),
                    ),
                    child: Text(
                      '${fontSize.toInt()}',
                      style: TextStyle(
                        color: AppColors.luxuryGold,
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 14,
                          tablet: 15,
                          desktop: 16,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 12.0),
          ),
          Consumer(
            builder: (context, ref, child) {
              final fontSize = ref.watch(arabicFontSizeProvider);
              return Container(
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 12.0,
                  ),
                  horizontal: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 16.0,
                  ),
                ),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColors.darkCard
                      : AppColors.ivory.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.adaptiveBorderRadius(context, base: 12.0),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'A',
                          style: TextStyle(
                            color: widget.isDark
                                ? AppColors.pureWhite.withOpacity(0.5)
                                : AppColors.textSecondary,
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 16,
                              tablet: 17,
                              desktop: 18,
                            ),
                          ),
                        ),
                        Text(
                          'A',
                          style: TextStyle(
                            color: widget.isDark
                                ? AppColors.pureWhite
                                : AppColors.textPrimary,
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 24,
                              tablet: 26,
                              desktop: 28,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 8.0,
                      ),
                    ),
                    Slider(
                      value: fontSize,
                      min: 20.0,
                      max: 40.0,
                      divisions: 20,
                      activeColor: AppColors.luxuryGold,
                      inactiveColor: widget.isDark
                          ? AppColors.pureWhite.withOpacity(0.2)
                          : AppColors.deepBlue.withOpacity(0.2),
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        ref
                            .read(arabicFontSizeProvider.notifier)
                            .updateSize(value);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 20.0),
          ),
          // Reading mode section - Improved
          Text(
            'Reading mode',
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
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 12.0),
          ),
          Consumer(
            builder: (context, ref, child) {
              final currentReadingMode = ref.watch(readingModeProvider);

              return Row(
                children: [
                  Expanded(
                    child: _buildReadingModeCard(
                      context,
                      'List',
                      Icons.list_rounded,
                      currentReadingMode == 'list',
                      'list',
                      ref,
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
                    child: _buildReadingModeCard(
                      context,
                      'Page',
                      Icons.description_rounded,
                      currentReadingMode == 'page',
                      'page',
                      ref,
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 24.0),
          ),
          // Auto-scroll toggle - Improved
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.adaptivePadding(
                context,
                mobile: 16.0,
              ),
              vertical: ResponsiveUtils.adaptivePadding(context, mobile: 14.0),
            ),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppColors.darkCard
                  : AppColors.ivory.withOpacity(0.3),
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.adaptiveBorderRadius(context, base: 12.0),
              ),
              border: Border.all(
                color: widget.isAutoScrollEnabled
                    ? AppColors.luxuryGold.withOpacity(0.3)
                    : (widget.isDark
                          ? AppColors.pureWhite.withOpacity(0.1)
                          : AppColors.deepBlue.withOpacity(0.1)),
                width: widget.isAutoScrollEnabled ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(
                          ResponsiveUtils.adaptivePadding(context, mobile: 6.0),
                        ),
                        decoration: BoxDecoration(
                          color: widget.isAutoScrollEnabled
                              ? AppColors.luxuryGold.withOpacity(0.2)
                              : (widget.isDark
                                    ? AppColors.pureWhite.withOpacity(0.1)
                                    : AppColors.deepBlue.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.adaptiveBorderRadius(
                              context,
                              base: 8.0,
                            ),
                          ),
                        ),
                        child: Icon(
                          Icons.swap_vertical_circle_rounded,
                          color: widget.isAutoScrollEnabled
                              ? AppColors.luxuryGold
                              : (widget.isDark
                                    ? AppColors.pureWhite.withOpacity(0.6)
                                    : AppColors.textSecondary),
                          size: ResponsiveUtils.adaptiveIconSize(
                            context,
                            base: 20.0,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: ResponsiveUtils.adaptivePadding(
                          context,
                          mobile: 12.0,
                        ),
                      ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Auto-scroll',
                              style: TextStyle(
                                color: widget.isDark
                                    ? AppColors.pureWhite
                                    : AppColors.textPrimary,
                                fontSize: ResponsiveUtils.adaptiveFontSize(
                                  context,
                                  mobile: 15,
                                  tablet: 16,
                                  desktop: 17,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(
                              height: ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 2.0,
                              ),
                            ),
                            Text(
                              'Follow audio playback',
                              style: TextStyle(
                                color: widget.isDark
                                    ? AppColors.pureWhite.withOpacity(0.6)
                                    : AppColors.textSecondary,
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
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: widget.isAutoScrollEnabled,
                  onChanged: widget.onAutoScrollChanged,
                  activeThumbColor: AppColors.luxuryGold,
                ),
              ],
            ),
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    String name,
    Color backgroundColor,
    bool isSelected,
    ThemeMode themeMode,
    WidgetRef ref,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            // Switch theme
            ref.read(themeModeProvider.notifier).setThemeMode(themeMode);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Theme "$name" selected'),
                  backgroundColor: AppColors.luxuryGold,
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveUtils.adaptivePadding(context, mobile: 8.0),
              horizontal: ResponsiveUtils.adaptivePadding(context, mobile: 6.0),
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
              ),
              border: Border.all(
                color: isSelected
                    ? AppColors.luxuryGold
                    : (widget.isDark
                          ? AppColors.pureWhite.withOpacity(0.1)
                          : AppColors.deepBlue.withOpacity(0.1)),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.luxuryGold.withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: AppColors.luxuryGold,
                    size: ResponsiveUtils.adaptiveIconSize(context, base: 16.0),
                  ),
                if (isSelected)
                  SizedBox(
                    height: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 4.0,
                    ),
                  ),
                Text(
                  'بِسْمِ اللهِ',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 12,
                      tablet: 13,
                      desktop: 14,
                    ),
                    color: backgroundColor == AppColors.darkBackground
                        ? AppColors.pureWhite
                        : AppColors.textPrimary,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                SizedBox(
                  height: ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
                ),
                Text(
                  name,
                  style: TextStyle(
                    color: backgroundColor == AppColors.darkBackground
                        ? AppColors.pureWhite
                        : AppColors.textPrimary,
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 11,
                      tablet: 12,
                      desktop: 13,
                    ),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadingModeCard(
    BuildContext context,
    String name,
    IconData icon,
    bool isSelected,
    String modeValue,
    WidgetRef ref,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            ref.read(readingModeProvider.notifier).setReadingMode(modeValue);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Reading mode "$name" selected'),
                  backgroundColor: AppColors.luxuryGold,
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
              horizontal: ResponsiveUtils.adaptivePadding(context, mobile: 8.0),
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? (widget.isDark
                        ? AppColors.luxuryGold.withOpacity(0.15)
                        : AppColors.luxuryGold.withOpacity(0.1))
                  : (widget.isDark ? AppColors.darkCard : AppColors.pureWhite),
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
              ),
              border: Border.all(
                color: isSelected
                    ? AppColors.luxuryGold
                    : (widget.isDark
                          ? AppColors.pureWhite.withOpacity(0.1)
                          : AppColors.deepBlue.withOpacity(0.1)),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.luxuryGold.withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(
                    ResponsiveUtils.adaptivePadding(context, mobile: 6.0),
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.luxuryGold.withOpacity(0.2)
                        : (widget.isDark
                              ? AppColors.pureWhite.withOpacity(0.1)
                              : AppColors.deepBlue.withOpacity(0.1)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? AppColors.luxuryGold
                        : (widget.isDark
                              ? AppColors.pureWhite.withOpacity(0.7)
                              : AppColors.textSecondary),
                    size: ResponsiveUtils.adaptiveIconSize(context, base: 24.0),
                  ),
                ),
                SizedBox(
                  height: ResponsiveUtils.adaptivePadding(context, mobile: 6.0),
                ),
                Text(
                  name,
                  style: TextStyle(
                    color: widget.isDark
                        ? AppColors.pureWhite
                        : AppColors.textPrimary,
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 12,
                      tablet: 13,
                      desktop: 14,
                    ),
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element - kept for reference; settings moved to _buildSinglePageContent
  Widget _buildTextTab(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.adaptivePadding(
          context,
          mobile: 16.0,
          tablet: 20.0,
          desktop: 24.0,
        ),
        vertical: ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Script option section - Compact
          Text(
            'Script option',
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
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
          ),
          Consumer(
            builder: (context, ref, child) {
              final selectedScript = ref.watch(arabicScriptProvider);
              final arabicScriptsAsync = ref.watch(
                arabicScriptEditionsProvider,
              );

              return arabicScriptsAsync.when(
                data: (editions) {
                  // Show first 4 popular scripts horizontally
                  final displayEditions = editions.take(4).toList();
                  return Column(
                    children: [
                      SizedBox(
                        height: ResponsiveUtils.responsive(
                          context,
                          mobile: 100.0,
                          tablet: 110.0,
                          desktop: 120.0,
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: displayEditions.length,
                          itemBuilder: (context, index) {
                            final edition = displayEditions[index];
                            final isSelected =
                                selectedScript == edition.identifier;
                            return Padding(
                              padding: EdgeInsets.only(
                                right: ResponsiveUtils.adaptivePadding(
                                  context,
                                  mobile: 8.0,
                                ),
                              ),
                              child: SizedBox(
                                width: ResponsiveUtils.responsive(
                                  context,
                                  mobile: 100.0,
                                  tablet: 110.0,
                                  desktop: 120.0,
                                ),
                                child: _buildScriptCard(
                                  context,
                                  edition,
                                  isSelected,
                                  ref,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (editions.length > 4)
                        Padding(
                          padding: EdgeInsets.only(
                            top: ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 10.0,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                                widget.showScriptSelector(
                                  context,
                                  widget.isDark,
                                  ref,
                                );
                              },
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.adaptiveBorderRadius(
                                  context,
                                  base: 10.0,
                                ),
                              ),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveUtils.adaptivePadding(
                                    context,
                                    mobile: 12.0,
                                  ),
                                  vertical: ResponsiveUtils.adaptivePadding(
                                    context,
                                    mobile: 8.0,
                                  ),
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.luxuryGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveUtils.adaptiveBorderRadius(
                                      context,
                                      base: 10.0,
                                    ),
                                  ),
                                  border: Border.all(
                                    color: AppColors.luxuryGold.withOpacity(
                                      0.3,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Voir toutes',
                                      style: TextStyle(
                                        color: AppColors.luxuryGold,
                                        fontSize:
                                            ResponsiveUtils.adaptiveFontSize(
                                              context,
                                              mobile: 13,
                                              tablet: 14,
                                              desktop: 15,
                                            ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(
                                      width: ResponsiveUtils.adaptivePadding(
                                        context,
                                        mobile: 6.0,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: AppColors.luxuryGold,
                                      size: ResponsiveUtils.adaptiveIconSize(
                                        context,
                                        base: 12.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => Center(
                  child: Padding(
                    padding: EdgeInsets.all(
                      ResponsiveUtils.adaptivePadding(context, mobile: 20.0),
                    ),
                    child: CircularProgressIndicator(
                      color: AppColors.luxuryGold,
                    ),
                  ),
                ),
                error: (_, __) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(
                      ResponsiveUtils.adaptivePadding(context, mobile: 20.0),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 40,
                          color: AppColors.error,
                        ),
                        SizedBox(
                          height: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 8.0,
                          ),
                        ),
                        Text(
                          'Erreur de chargement',
                          style: TextStyle(
                            color: widget.isDark
                                ? AppColors.pureWhite
                                : AppColors.textPrimary,
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 14,
                              tablet: 15,
                              desktop: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 20.0),
          ),
          // Show Tajweed colours - Compact
          Consumer(
            builder: (context, ref, child) {
              final showTajweed = ref.watch(tajweedColorsProvider);
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 12.0,
                  ),
                  vertical: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 10.0,
                  ),
                ),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColors.darkCard
                      : AppColors.ivory.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Show Tajweed colours',
                          style: TextStyle(
                            color: widget.isDark
                                ? AppColors.pureWhite
                                : AppColors.textPrimary,
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 15,
                              tablet: 16,
                              desktop: 17,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 6.0,
                          ),
                        ),
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: widget.isDark
                              ? AppColors.pureWhite.withOpacity(0.6)
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                    Switch(
                      value: showTajweed,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        ref.read(tajweedColorsProvider.notifier).toggle(value);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'Tajweed colours enabled'
                                    : 'Tajweed colours disabled',
                              ),
                              backgroundColor: AppColors.luxuryGold,
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      activeThumbColor: AppColors.luxuryGold,
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 20.0),
          ),
          // Translation section - Compact
          Text(
            'Translation',
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
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.adaptivePadding(
                context,
                mobile: 12.0,
              ),
              vertical: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
            ),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppColors.darkCard
                  : AppColors.ivory.withOpacity(0.3),
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Show translation',
                    style: TextStyle(
                      color: widget.isDark
                          ? AppColors.pureWhite
                          : AppColors.textPrimary,
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 15,
                        tablet: 16,
                        desktop: 17,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Switch(
                  value: widget.showTranslation,
                  onChanged: widget.onTranslationChanged,
                  activeThumbColor: AppColors.luxuryGold,
                ),
              ],
            ),
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
          ),
          Consumer(
            builder: (context, ref, child) {
              final selectedTranslation = ref.watch(translationEditionProvider);
              final translationName = AvailableTranslations.getName(
                selectedTranslation,
              );
              final translationLanguage =
                  AvailableTranslations.all.entries
                      .expand((entry) => entry.value)
                      .firstWhere(
                        (t) => t['id'] == selectedTranslation,
                        orElse: () => {'language': 'Français'},
                      )['language'] ??
                  'Français';

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    widget.showTranslationSelector(context, widget.isDark, ref);
                  },
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 12.0,
                      ),
                      vertical: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 10.0,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? AppColors.darkCard
                          : AppColors.ivory.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.adaptiveBorderRadius(
                          context,
                          base: 10.0,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.language,
                          color: AppColors.luxuryGold,
                          size: ResponsiveUtils.adaptiveIconSize(
                            context,
                            base: 18.0,
                          ),
                        ),
                        SizedBox(
                          width: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 10.0,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$translationLanguage: $translationName',
                            style: TextStyle(
                              color: widget.isDark
                                  ? AppColors.pureWhite
                                  : AppColors.textPrimary,
                              fontSize: ResponsiveUtils.adaptiveFontSize(
                                context,
                                mobile: 14,
                                tablet: 15,
                                desktop: 16,
                              ),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: widget.isDark
                              ? AppColors.pureWhite.withOpacity(0.5)
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 20.0),
          ),
          // Marques de waqf (Tanzil) — guide la récitation (pause, continuer)
          Consumer(
            builder: (context, ref, child) {
              final pauseMarksTanzil = ref.watch(pauseMarksTanzilProvider);
              return InkWell(
                onTap: () => widget.showPauseMarksLegend(context, ref),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 12.0,
                    ),
                    vertical: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 10.0,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? AppColors.darkCard
                        : AppColors.ivory.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: ResponsiveUtils.adaptiveIconSize(
                              context,
                              base: 18.0,
                            ),
                            color: pauseMarksTanzil
                                ? AppColors.luxuryGold
                                : (widget.isDark
                                      ? AppColors.pureWhite.withOpacity(0.6)
                                      : AppColors.textSecondary),
                          ),
                          SizedBox(
                            width: ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 10.0,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Marques de waqf (Tanzil)',
                                style: TextStyle(
                                  color: widget.isDark
                                      ? AppColors.pureWhite
                                      : AppColors.textPrimary,
                                  fontSize: ResponsiveUtils.adaptiveFontSize(
                                    context,
                                    mobile: 15,
                                    tablet: 16,
                                    desktop: 17,
                                  ),
                                ),
                              ),
                              Text(
                                'م لا ج — pause, continuer',
                                style: TextStyle(
                                  color: widget.isDark
                                      ? AppColors.pureWhite.withOpacity(0.6)
                                      : AppColors.textSecondary,
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
                          SizedBox(
                            width: ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 6.0,
                            ),
                          ),
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.luxuryGold.withOpacity(0.7),
                          ),
                        ],
                      ),
                      Switch(
                        value: pauseMarksTanzil,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          ref.read(pauseMarksTanzilProvider.notifier).toggle(value);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  value
                                      ? 'Marques de waqf activées (Tanzil)'
                                      : 'Marques de waqf désactivées',
                                ),
                                backgroundColor: AppColors.luxuryGold,
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        activeThumbColor: AppColors.luxuryGold,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptCard(
    BuildContext context,
    EditionModel edition,
    bool isSelected,
    WidgetRef ref,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            ref
                .read(arabicScriptProvider.notifier)
                .updateScript(edition.identifier);
            ref.invalidate(surahDetailProvider(widget.surahNumber));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Script "${edition.englishName.isNotEmpty ? edition.englishName : edition.name}" sélectionné',
                  ),
                  backgroundColor: AppColors.luxuryGold,
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveUtils.adaptivePadding(context, mobile: 8.0),
              horizontal: ResponsiveUtils.adaptivePadding(context, mobile: 6.0),
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? (widget.isDark
                        ? AppColors.luxuryGold.withOpacity(0.15)
                        : AppColors.luxuryGold.withOpacity(0.1))
                  : (widget.isDark ? AppColors.darkCard : AppColors.pureWhite),
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
              ),
              border: Border.all(
                color: isSelected
                    ? AppColors.luxuryGold
                    : (widget.isDark
                          ? AppColors.pureWhite.withOpacity(0.1)
                          : AppColors.deepBlue.withOpacity(0.1)),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.luxuryGold.withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: AppColors.luxuryGold,
                    size: ResponsiveUtils.adaptiveIconSize(context, base: 14.0),
                  ),
                if (isSelected)
                  SizedBox(
                    height: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: 4.0,
                    ),
                  ),
                Text(
                  'بِسْمِ اللهِ',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 14,
                      tablet: 15,
                      desktop: 16,
                    ),
                    color: widget.isDark
                        ? AppColors.pureWhite
                        : AppColors.textPrimary,
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                  height: ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
                ),
                Text(
                  edition.englishName.isNotEmpty
                      ? edition.englishName
                      : edition.name,
                  style: TextStyle(
                    color: widget.isDark
                        ? AppColors.pureWhite
                        : AppColors.textPrimary,
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 10,
                      tablet: 11,
                      desktop: 12,
                    ),
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element - kept for reference; settings moved to _buildSinglePageContent
  Widget _buildAudioTab(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.adaptivePadding(
          context,
          mobile: 16.0,
          tablet: 20.0,
          desktop: 24.0,
        ),
        vertical: ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quran reciter section - Compact
          Text(
            'Quran reciter',
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
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
          ),
          Consumer(
            builder: (context, ref, child) {
              final selectedReciter = ref.watch(
                selectedReciterPersistentProvider,
              );
              final popularReciters = AudioService.popularReciters;
              if (popularReciters.isEmpty) return const SizedBox.shrink();
              final reciter = popularReciters.firstWhere(
                (r) => r['id'] == selectedReciter,
                orElse: () => popularReciters.first,
              );

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    widget.showReciterSelector(context, widget.isDark, ref);
                  },
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 12.0,
                      ),
                      vertical: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 10.0,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? AppColors.darkCard
                          : AppColors.ivory.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.adaptiveBorderRadius(
                          context,
                          base: 10.0,
                        ),
                      ),
                      border: Border.all(
                        color: widget.isDark
                            ? AppColors.pureWhite.withOpacity(0.1)
                            : AppColors.deepBlue.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 6.0,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.luxuryGold.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.flag,
                            color: AppColors.luxuryGold,
                            size: ResponsiveUtils.adaptiveIconSize(
                              context,
                              base: 18.0,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 10.0,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reciter['name'] ?? 'Mishary Alafasy',
                                style: TextStyle(
                                  color: widget.isDark
                                      ? AppColors.pureWhite
                                      : AppColors.textPrimary,
                                  fontSize: ResponsiveUtils.adaptiveFontSize(
                                    context,
                                    mobile: 14,
                                    tablet: 15,
                                    desktop: 16,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (reciter['arabicName'] != null &&
                                  reciter['arabicName'].toString().isNotEmpty)
                                Text(
                                  reciter['arabicName'].toString(),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: widget.isDark
                                        ? AppColors.pureWhite.withOpacity(0.7)
                                        : AppColors.textSecondary,
                                    fontSize: ResponsiveUtils.adaptiveFontSize(
                                      context,
                                      mobile: 12,
                                      tablet: 13,
                                      desktop: 14,
                                    ),
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: widget.isDark
                              ? AppColors.pureWhite.withOpacity(0.5)
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 20.0),
          ),
          // Playback controls section - Compact
          Text(
            'Playback controls',
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
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.adaptivePadding(
                context,
                mobile: 12.0,
              ),
              vertical: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
            ),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppColors.darkCard
                  : AppColors.ivory.withOpacity(0.3),
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Auto-scroll',
                  style: TextStyle(
                    color: widget.isDark
                        ? AppColors.pureWhite
                        : AppColors.textPrimary,
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 15,
                      tablet: 16,
                      desktop: 17,
                    ),
                  ),
                ),
                Switch(
                  value: widget.isAutoScrollEnabled,
                  onChanged: widget.onAutoScrollChanged,
                  activeThumbColor: AppColors.luxuryGold,
                ),
              ],
            ),
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
          ),
          Consumer(
            builder: (context, ref, child) {
              final repetition = ref.watch(repetitionProvider);
              final repetitionLabels = {
                'never': 'Never',
                'once': 'Once',
                'twice': 'Twice',
                'thrice': '3 times',
                'infinite': 'Infinite',
              };

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    widget.showRepetitionSelector(context, widget.isDark, ref);
                  },
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 12.0,
                      ),
                      vertical: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 10.0,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? AppColors.darkCard
                          : AppColors.ivory.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.adaptiveBorderRadius(
                          context,
                          base: 10.0,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Repetition',
                                style: TextStyle(
                                  color: widget.isDark
                                      ? AppColors.pureWhite
                                      : AppColors.textPrimary,
                                  fontSize: ResponsiveUtils.adaptiveFontSize(
                                    context,
                                    mobile: 15,
                                    tablet: 16,
                                    desktop: 17,
                                  ),
                                ),
                              ),
                              Text(
                                repetitionLabels[repetition] ?? 'Never',
                                style: TextStyle(
                                  color: widget.isDark
                                      ? AppColors.pureWhite.withOpacity(0.7)
                                      : AppColors.textSecondary,
                                  fontSize: ResponsiveUtils.adaptiveFontSize(
                                    context,
                                    mobile: 13,
                                    tablet: 14,
                                    desktop: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: widget.isDark
                              ? AppColors.pureWhite.withOpacity(0.5)
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 20.0),
          ),
          // Download audio section - Compact
          Text(
            'Offline Listening',
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
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(context, mobile: 10.0),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
                widget.downloadSurahAudio(widget.isDark);
              },
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 12.0,
                  ),
                  vertical: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 12.0,
                  ),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.luxuryGold,
                      AppColors.luxuryGold.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.adaptiveBorderRadius(context, base: 10.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.luxuryGold.withOpacity(0.3),
                      blurRadius: 6,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.download_rounded,
                      color: AppColors.pureWhite,
                      size: ResponsiveUtils.adaptiveIconSize(
                        context,
                        base: 20.0,
                      ),
                    ),
                    SizedBox(
                      width: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 10.0,
                      ),
                    ),
                    Text(
                      'Download Audio',
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 15,
                          tablet: 16,
                          desktop: 17,
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
            height: ResponsiveUtils.adaptivePadding(context, mobile: 16.0),
          ),
        ],
      ),
    );
  }
}

/// New three-column selector for Juz, Surah, and Ayah
class _JuzSurahAyahSelectorBottomSheet extends ConsumerStatefulWidget {
  final int currentSurahNumber;
  final int? currentAyahNumber;
  final bool isDark;
  final Function(Surah surah, int? ayahNumber) onSurahSelected;

  const _JuzSurahAyahSelectorBottomSheet({
    required this.currentSurahNumber,
    this.currentAyahNumber,
    required this.isDark,
    required this.onSurahSelected,
  });

  @override
  ConsumerState<_JuzSurahAyahSelectorBottomSheet> createState() =>
      _JuzSurahAyahSelectorBottomSheetState();
}

class _JuzSurahAyahSelectorBottomSheetState
    extends ConsumerState<_JuzSurahAyahSelectorBottomSheet> {
  int? _selectedJuz;
  int? _selectedSurah;
  int? _selectedAyah;
  final ScrollController _juzScrollController = ScrollController();
  final ScrollController _surahScrollController = ScrollController();
  final ScrollController _ayahScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize with current surah's Juz
    final juzs = getJuzsForSurah(widget.currentSurahNumber);
    if (juzs.isNotEmpty) {
      _selectedJuz = juzs.first;
      _selectedSurah = widget.currentSurahNumber;
      _selectedAyah = widget.currentAyahNumber ?? 1;
    }
    // Scroll to selected items after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedItems();
    });
  }

  void _scrollToSelectedItems() {
    // Wait a bit for the panel to fully open and lists to render
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      // Scroll to selected Juz
      if (_selectedJuz != null && _juzScrollController.hasClients) {
        final juzIndex = _selectedJuz! - 1;
        final itemHeight = ResponsiveUtils.responsive(
          context,
          mobile: 50.0,
          tablet: 55.0,
          desktop: 60.0,
        );
        final targetOffset = (juzIndex * itemHeight).clamp(
          0.0,
          _juzScrollController.position.maxScrollExtent,
        );
        _juzScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }

      // Scroll to selected Surah
      if (_selectedSurah != null && _surahScrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted || !_surahScrollController.hasClients) return;

          final surahsAsync = ref.read(surahsProvider);
          surahsAsync.whenData((surahs) {
            if (!mounted) return;

            final juzSurahs = _selectedJuz != null
                ? getSurahsInJuz(_selectedJuz!)
                      .map((surahNum) {
                        try {
                          return surahs.firstWhere((s) => s.number == surahNum);
                        } catch (e) {
                          return null;
                        }
                      })
                      .where((s) => s != null)
                      .cast<SurahModel>()
                      .toList()
                : <SurahModel>[];

            final uniqueSurahs = juzSurahs.toSet().toList()
              ..sort((a, b) => a.number.compareTo(b.number));

            final surahIndex = uniqueSurahs.indexWhere(
              (s) => s.number == _selectedSurah,
            );

            if (surahIndex >= 0 && _surahScrollController.hasClients) {
              final itemHeight = ResponsiveUtils.responsive(
                context,
                mobile: 48.0,
                tablet: 52.0,
                desktop: 56.0,
              );
              final targetOffset = (surahIndex * itemHeight).clamp(
                0.0,
                _surahScrollController.position.maxScrollExtent,
              );
              _surahScrollController.animateTo(
                targetOffset,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              );
            }
          });
        });
      }

      // Scroll to selected Ayah
      if (_selectedAyah != null &&
          _selectedSurah != null &&
          _ayahScrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted || !_ayahScrollController.hasClients) return;

          final surahsAsync = ref.read(surahsProvider);
          surahsAsync.whenData((surahs) {
            if (!mounted) return;

            try {
              final surahMatch = surahs
                  .where((s) => s.number == _selectedSurah)
                  .toList();
              if (surahMatch.isEmpty) return;
              final surah = surahMatch.first;
              final ayahIndex = (_selectedAyah! - 1).clamp(
                0,
                surah.numberOfAyahs - 1,
              );
              final itemHeight = ResponsiveUtils.responsive(
                context,
                mobile: 48.0,
                tablet: 52.0,
                desktop: 56.0,
              );
              final targetOffset = (ayahIndex * itemHeight).clamp(
                0.0,
                _ayahScrollController.position.maxScrollExtent,
              );
              _ayahScrollController.animateTo(
                targetOffset,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              );
            } catch (e) {
              debugPrint('Error scrolling to ayah: $e');
            }
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _juzScrollController.dispose();
    _surahScrollController.dispose();
    _ayahScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surahsAsync = ref.watch(surahsProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = ResponsiveUtils.responsive(
      context,
      mobile: screenHeight * 0.65,
      tablet: screenHeight * 0.6,
      desktop: screenHeight * 0.55,
    );

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 20.0),
          ),
          topRight: Radius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context, base: 20.0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar with close button
            Padding(
              padding: EdgeInsets.only(
                top: ResponsiveUtils.adaptivePadding(context, mobile: 8.0),
                bottom: ResponsiveUtils.adaptivePadding(context, mobile: 4.0),
                left: ResponsiveUtils.adaptivePadding(context, mobile: 12.0),
                right: ResponsiveUtils.adaptivePadding(context, mobile: 12.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Handle bar
                  Container(
                    width: ResponsiveUtils.responsive(
                      context,
                      mobile: 36.0,
                      tablet: 40.0,
                      desktop: 44.0,
                    ),
                    height: 3,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? AppColors.pureWhite.withOpacity(0.2)
                          : AppColors.textSecondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Close button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: EdgeInsets.all(
                          ResponsiveUtils.adaptivePadding(context, mobile: 6.0),
                        ),
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? AppColors.pureWhite.withOpacity(0.1)
                              : AppColors.deepBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: widget.isDark
                              ? AppColors.pureWhite
                              : AppColors.textPrimary,
                          size: ResponsiveUtils.adaptiveIconSize(
                            context,
                            base: 18.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Three columns header - Compact
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 12.0,
                ),
                vertical: ResponsiveUtils.adaptivePadding(context, mobile: 8.0),
              ),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? AppColors.darkCard
                    : AppColors.ivory.withOpacity(0.3),
                border: Border(
                  bottom: BorderSide(
                    color: widget.isDark
                        ? AppColors.pureWhite.withOpacity(0.1)
                        : AppColors.deepBlue.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Juz',
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
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 16,
                    color: widget.isDark
                        ? AppColors.pureWhite.withOpacity(0.1)
                        : AppColors.deepBlue.withOpacity(0.1),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Surah',
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
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 16,
                    color: widget.isDark
                        ? AppColors.pureWhite.withOpacity(0.1)
                        : AppColors.deepBlue.withOpacity(0.1),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Ayah',
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
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Three scrollable columns
            Expanded(
              child: surahsAsync.when(
                data: (surahs) => _buildThreeColumns(surahs),
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
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
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

            // Apply button - Compact
            if (_selectedSurah != null)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 12.0,
                  ),
                  vertical: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 10.0,
                  ),
                ),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColors.darkCard
                      : AppColors.ivory.withOpacity(0.3),
                  border: Border(
                    top: BorderSide(
                      color: widget.isDark
                          ? AppColors.pureWhite.withOpacity(0.1)
                          : AppColors.deepBlue.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_selectedSurah != null) {
                          final list = surahsAsync.value;
                          final surahModel = list != null && list.isNotEmpty
                              ? list
                                  .where((s) => s.number == _selectedSurah)
                                  .toList()
                              : <SurahModel>[];
                          if (surahModel.isNotEmpty) {
                            final surah = SurahAdapter.fromApiModel(
                                surahModel.first);
                            HapticFeedback.mediumImpact();
                            widget.onSurahSelected(surah, _selectedAyah);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.luxuryGold,
                        foregroundColor: AppColors.pureWhite,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: 12.0,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.adaptiveBorderRadius(
                              context,
                              base: 10.0,
                            ),
                          ),
                        ),
                      ),
                      child: Text(
                        'Go to Surah',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.adaptiveFontSize(
                            context,
                            mobile: 14,
                            tablet: 15,
                            desktop: 16,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreeColumns(List<SurahModel> surahs) {
    // Show ALL surahs (not filtered by Juz)
    final allSurahs = surahs.toList()
      ..sort((a, b) => a.number.compareTo(b.number));

    // Get selected surah model
    SurahModel? selectedSurahModel;
    if (_selectedSurah != null && surahs.isNotEmpty) {
      final matches =
          surahs.where((s) => s.number == _selectedSurah).toList();
      if (matches.isNotEmpty) selectedSurahModel = matches.first;
    }

    return Row(
      children: [
        // Juz column
        Expanded(flex: 2, child: _buildJuzColumn()),
        Container(
          width: 1,
          color: widget.isDark
              ? AppColors.pureWhite.withOpacity(0.1)
              : AppColors.deepBlue.withOpacity(0.1),
        ),
        // Surah column - Show ALL surahs
        Expanded(flex: 3, child: _buildSurahColumn(allSurahs)),
        Container(
          width: 1,
          color: widget.isDark
              ? AppColors.pureWhite.withOpacity(0.1)
              : AppColors.deepBlue.withOpacity(0.1),
        ),
        // Ayah column
        Expanded(flex: 2, child: _buildAyahColumn(selectedSurahModel)),
      ],
    );
  }

  Widget _buildJuzColumn() {
    final allJuzs = getAllJuzs();

    return ListView.builder(
      controller: _juzScrollController,
      padding: EdgeInsets.zero,
      itemCount: allJuzs.length,
      itemBuilder: (context, index) {
        final juz = allJuzs[index];
        final isSelected = _selectedJuz == juz;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedJuz = juz;
                // Don't auto-select surah when Juz changes - let user choose
                // Just scroll to current surah if it exists
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 10.0,
                ),
                horizontal: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 6.0,
                ),
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? (widget.isDark
                          ? AppColors.luxuryGold.withOpacity(0.2)
                          : AppColors.luxuryGold.withOpacity(0.1))
                    : Colors.transparent,
              ),
              child: Text(
                '$juz',
                style: TextStyle(
                  color: isSelected
                      ? AppColors.luxuryGold
                      : (widget.isDark
                            ? AppColors.pureWhite
                            : AppColors.textPrimary),
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 13,
                    tablet: 14,
                    desktop: 15,
                  ),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSurahColumn(List<SurahModel> allSurahs) {
    if (allSurahs.isEmpty) {
      return Center(
        child: Text(
          'Loading...',
          style: TextStyle(
            color: widget.isDark
                ? AppColors.pureWhite.withOpacity(0.5)
                : AppColors.textSecondary,
            fontSize: ResponsiveUtils.adaptiveFontSize(
              context,
              mobile: 12,
              tablet: 13,
              desktop: 14,
            ),
          ),
        ),
      );
    }

    // All surahs are already sorted
    final uniqueSurahs = allSurahs;

    return ListView.builder(
      controller: _surahScrollController,
      padding: EdgeInsets.zero,
      itemCount: uniqueSurahs.length,
      itemBuilder: (context, index) {
        final surah = uniqueSurahs[index];
        final surahModel = SurahAdapter.fromApiModel(surah);
        final isSelected = _selectedSurah == surah.number;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedSurah = surah.number;
                _selectedAyah = 1; // Reset to first ayah
              });
              // Scroll ayah column to top
              if (_ayahScrollController.hasClients) {
                _ayahScrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 12.0,
                ),
                horizontal: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 8.0,
                ),
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? (widget.isDark
                          ? AppColors.luxuryGold.withOpacity(0.2)
                          : AppColors.luxuryGold.withOpacity(0.1))
                    : Colors.transparent,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${surah.number}. ${surahModel.name}',
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.luxuryGold
                          : (widget.isDark
                                ? AppColors.pureWhite
                                : AppColors.textPrimary),
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 14,
                        tablet: 15,
                        desktop: 16,
                      ),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAyahColumn(SurahModel? surah) {
    if (_selectedSurah == null || surah == null) {
      return Center(
        child: Text(
          'Select Surah',
          style: TextStyle(
            color: widget.isDark
                ? AppColors.pureWhite.withOpacity(0.5)
                : AppColors.textSecondary,
            fontSize: ResponsiveUtils.adaptiveFontSize(
              context,
              mobile: 14,
              tablet: 15,
              desktop: 16,
            ),
          ),
        ),
      );
    }

    final ayahCount = surah.numberOfAyahs;
    final ayahs = List.generate(ayahCount, (index) => index + 1);

    return ListView.builder(
      controller: _ayahScrollController,
      padding: EdgeInsets.zero,
      itemCount: ayahs.length,
      itemBuilder: (context, index) {
        final ayah = ayahs[index];
        final isSelected = _selectedAyah == ayah;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedAyah = ayah;
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 10.0,
                ),
                horizontal: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 6.0,
                ),
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? (widget.isDark
                          ? AppColors.luxuryGold.withOpacity(0.2)
                          : AppColors.luxuryGold.withOpacity(0.1))
                    : Colors.transparent,
              ),
              child: Text(
                '$ayah',
                style: TextStyle(
                  color: isSelected
                      ? AppColors.luxuryGold
                      : (widget.isDark
                            ? AppColors.pureWhite
                            : AppColors.textPrimary),
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 13,
                    tablet: 14,
                    desktop: 15,
                  ),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}

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
