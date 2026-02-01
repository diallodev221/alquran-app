import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/surah.dart';
import '../widgets/shimmer_loading.dart';
import '../providers/favorites_providers.dart';
import '../providers/quran_providers.dart';
import '../providers/audio_providers.dart';
import '../providers/settings_providers.dart';
import '../utils/surah_adapter.dart';
import '../utils/responsive_utils.dart';
import 'surah_detail_screen.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _fadeController = AnimationController(
      duration: AppTheme.animationDuration,
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: AppTheme.animationCurve,
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _navigateToSurah(Surah surah) {
    HapticFeedback.lightImpact();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SurahDetailScreen(surah: surah),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: AppTheme.animationDuration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favoritesAsync = ref.watch(favoritesProvider);
    final totalCount = ref.watch(totalFavoritesCountProvider);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: ResponsiveUtils.adaptiveAppBarHeight(context),
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(
                          colors: [
                            AppColors.darkSurface,
                            AppColors.darkBackground,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : AppColors.headerGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(
                      ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: AppTheme.paddingLarge,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.luxuryGold.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.bookmark,
                                color: AppColors.luxuryGold,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: AppTheme.paddingMedium),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mes Favoris',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.pureWhite,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$totalCount favori${totalCount > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.pureWhite,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.luxuryGold,
              indicatorWeight: 3,
              labelColor: isDark
                  ? AppColors.luxuryGold
                  : AppColors.pureWhite, // isDark == AppColors.deepBlue
              unselectedLabelColor: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.pureWhite,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: 'Sourates'),
                Tab(text: 'Versets'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Onglet Sourates
            favoritesAsync.when(
              data: (favoritesState) =>
                  _buildSurahsTab(favoritesState.favoriteSurahs, isDark),
              loading: () => _buildLoadingState(),
              error: (error, stack) => _buildErrorState(error),
            ),

            // Onglet Versets
            favoritesAsync.when(
              data: (favoritesState) =>
                  _buildAyahsTab(favoritesState.favoriteAyahs, isDark),
              loading: () => _buildLoadingState(),
              error: (error, stack) => _buildErrorState(error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahsTab(List<int> favoriteSurahNumbers, bool isDark) {
    if (favoriteSurahNumbers.isEmpty) {
      return _buildEmptyState(
        'Aucune sourate favorite',
        'Ajoutez des sourates à vos favoris pour les retrouver ici',
        Icons.bookmark_border,
        isDark,
      );
    }

    final surahsAsync = ref.watch(surahsProvider);

    return surahsAsync.when(
      data: (apiSurahs) {
        final allSurahs = SurahAdapter.fromApiModelList(apiSurahs);

        // Filtrer seulement les sourates favorites
        final favoriteSurahs = allSurahs
            .where((surah) => favoriteSurahNumbers.contains(surah.number))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          itemCount: favoriteSurahs.length,
          itemBuilder: (context, index) {
            final surah = favoriteSurahs[index];
            return FadeTransition(
              opacity: _fadeAnimation,
              child: _buildSurahFavoriteCard(surah, isDark),
            );
          },
        );
      },
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(error),
    );
  }

  Widget _buildSurahFavoriteCard(Surah surah, bool isDark) {
    final currentPlayingSurah = ref.watch(currentPlayingSurahProvider);
    final isPlaying = currentPlayingSurah == surah.number;

    return GestureDetector(
      onTap: () => _navigateToSurah(surah),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.paddingMedium),
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.pureWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppColors.cardShadow,
          border: isPlaying
              ? Border.all(color: AppColors.luxuryGold, width: 2)
              : null,
        ),
        child: Row(
          children: [
            // Numéro de la Sourate
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
                  '${surah.number}',
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(width: AppTheme.paddingMedium),

            // Informations de la Sourate
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${surah.revelationType} • ${surah.numberOfAyahs} Ayahs',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),

            // Bouton Play
            IconButton(
              onPressed: () async {
                HapticFeedback.lightImpact();

                // Récupérer le messenger avant l'async
                final messenger = ScaffoldMessenger.of(context);

                // Récupérer les URLs audio
                final audioService = ref.read(audioServiceProvider);
                final selectedReciter = ref.read(
                  selectedReciterPersistentProvider,
                );

                try {
                  final audioUrls = await audioService.getSurahAudioUrls(
                    surah.number,
                    reciter: selectedReciter,
                  );

                  if (audioUrls.isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Audio non disponible pour cette sourate',
                        ),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  // Charger la sourate dans le lecteur audio
                  final playlistService = ref.read(
                    globalAudioPlaylistServiceProvider,
                  );
                  await playlistService.loadSurahPlaylist(audioUrls);

                  // Démarrer la lecture
                  await playlistService.play();

                  // Mettre à jour les providers
                  ref.read(currentPlayingSurahProvider.notifier).state =
                      surah.number;
                  ref.read(currentPlayingSurahNameProvider.notifier).state =
                      surah.name;
                  ref.read(currentSurahTotalAyahsProvider.notifier).state =
                      surah.numberOfAyahs;
                  ref.read(currentAyahIndexProvider.notifier).state = 0;

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Lecture de ${surah.name}'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.luxuryGold,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: isPlaying ? null : AppColors.goldAccent,
                  color: isPlaying
                      ? AppColors.luxuryGold.withOpacity(0.2)
                      : null,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: AppColors.luxuryGold,
                  size: 24,
                ),
              ),
              tooltip: isPlaying ? 'En cours de lecture' : 'Écouter',
            ),

            // Nom arabe
            Flexible(
              flex: 2,
              child: Text(
                surah.arabicName,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.luxuryGold : AppColors.deepBlue,
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
    );
  }

  Widget _buildAyahsTab(List<String> favoriteAyahs, bool isDark) {
    if (favoriteAyahs.isEmpty) {
      return _buildEmptyState(
        'Aucun verset favori',
        'Marquez des versets en favoris pour les retrouver ici',
        Icons.bookmark_border,
        isDark,
      );
    }

    final surahsAsync = ref.watch(surahsProvider);

    return surahsAsync.when(
      data: (apiSurahs) {
        final allSurahs = SurahAdapter.fromApiModelList(apiSurahs);

        return ListView.builder(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          itemCount: favoriteAyahs.length,
          itemBuilder: (context, index) {
            final ayahKey = favoriteAyahs[index];
            final parts = ayahKey.split(':');

            if (parts.length != 2) return const SizedBox.shrink();

            final surahNumber = int.tryParse(parts[0]);
            final ayahNumber = int.tryParse(parts[1]);

            if (surahNumber == null || ayahNumber == null) {
              return const SizedBox.shrink();
            }

            // Trouver la sourate correspondante
            final matches =
                allSurahs.where((s) => s.number == surahNumber).toList();
            if (matches.isEmpty) return const SizedBox.shrink();
            final surah = matches.first;

            return FadeTransition(
              opacity: _fadeAnimation,
              child: _buildAyahFavoriteCard(
                surah: surah,
                ayahNumber: ayahNumber,
                isDark: isDark,
              ),
            );
          },
        );
      },
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(error),
    );
  }

  Widget _buildAyahFavoriteCard({
    required Surah surah,
    required int ayahNumber,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => _navigateToSurah(surah),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.paddingMedium),
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.pureWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppColors.cardShadow,
          border: Border.all(
            color: AppColors.luxuryGold.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec info sourate
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${surah.number}:$ayahNumber',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkBackground
                          : AppColors.deepBlue,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.paddingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Verset $ayahNumber',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  surah.arabicName,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.luxuryGold : AppColors.deepBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingMedium),
            // Divider
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.luxuryGold.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.paddingMedium),
            // Actions: Play, Voir, Supprimer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Bouton Play
                IconButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();

                    final messenger = ScaffoldMessenger.of(context);
                    final audioService = ref.read(audioServiceProvider);
                    final selectedReciter = ref.read(
                      selectedReciterPersistentProvider,
                    );

                    try {
                      final audioUrls = await audioService.getSurahAudioUrls(
                        surah.number,
                        reciter: selectedReciter,
                      );

                      if (audioUrls.isEmpty || ayahNumber > audioUrls.length) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Audio non disponible pour ce verset',
                            ),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      // Charger la sourate et commencer au verset spécifique
                      final playlistService = ref.read(
                        globalAudioPlaylistServiceProvider,
                      );
                      await playlistService.loadSurahPlaylist(
                        audioUrls,
                        startIndex: ayahNumber - 1,
                      );

                      // Démarrer la lecture
                      await playlistService.play();

                      // Mettre à jour les providers
                      ref.read(currentPlayingSurahProvider.notifier).state =
                          surah.number;
                      ref.read(currentPlayingSurahNameProvider.notifier).state =
                          surah.name;
                      ref.read(currentSurahTotalAyahsProvider.notifier).state =
                          surah.numberOfAyahs;
                      ref.read(currentAyahIndexProvider.notifier).state =
                          ayahNumber - 1;

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Lecture du verset $ayahNumber - ${surah.name}',
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.luxuryGold,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Erreur: $e'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 20,
                      color: AppColors.pureWhite,
                    ),
                  ),
                  tooltip: 'Écouter ce verset',
                ),

                // Bouton Voir
                TextButton.icon(
                  onPressed: () => _navigateToSurah(surah),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Voir'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.luxuryGold,
                  ),
                ),

                // Bouton Supprimer
                IconButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();

                    // Capturer le ScaffoldMessenger avant l'opération async
                    final messenger = ScaffoldMessenger.of(context);

                    final notifier = ref.read(favoritesProvider.notifier);
                    await notifier.toggleAyahFavorite(surah.number, ayahNumber);

                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Verset retiré des favoris'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                  tooltip: 'Retirer des favoris',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    String title,
    String subtitle,
    IconData icon,
    bool isDark,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingXLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingXLarge),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.luxuryGold.withOpacity(0.1),
                    AppColors.luxuryGold.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: AppColors.luxuryGold.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.paddingSmall),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      itemCount: 3,
      itemBuilder: (context, index) => const SurahCardShimmer(),
    );
  }

  Widget _buildErrorState(Object error) {
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
                ref.invalidate(favoritesProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
