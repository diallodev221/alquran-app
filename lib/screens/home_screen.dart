import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/surah.dart';
import '../widgets/surah_card.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/responsive_wrapper.dart';
import '../providers/quran_providers.dart';
import '../providers/audio_providers.dart';
import '../utils/surah_adapter.dart';
import '../utils/responsive_utils.dart';
import 'surah_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<Surah> _filteredSurahs = [];
  String _searchQuery = '';
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

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
    _fadeController.dispose();
    super.dispose();
  }

  void _onSearch(String query, List<Surah> allSurahs) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSurahs = allSurahs;
      } else {
        _filteredSurahs = allSurahs.where((surah) {
          return surah.name.toLowerCase().contains(query.toLowerCase()) ||
              surah.arabicName.contains(query) ||
              surah.englishName.toLowerCase().contains(query.toLowerCase()) ||
              surah.number.toString().contains(query);
        }).toList();
      }
    });
  }

  void _navigateToSurah(Surah surah) {
    // Feedback haptique léger
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
    final surahsAsync = ref.watch(surahsProvider);
    final lastReadSurahNumber = ref.watch(lastReadSurahProvider);
    final currentPlayingSurah = ref.watch(currentPlayingSurahProvider);
    final isAudioPlaying = currentPlayingSurah != null;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const ConnectivityBanner(),
              Expanded(
                child: surahsAsync.when(
                  data: (apiSurahs) {
                    final surahs = SurahAdapter.fromApiModelList(apiSurahs);

                    // Initialiser les sourates filtrées si vide
                    if (_filteredSurahs.isEmpty && _searchQuery.isEmpty) {
                      Future.microtask(() {
                        setState(() => _filteredSurahs = surahs);
                      });
                    }

                    return _buildContent(surahs, lastReadSurahNumber, isDark);
                  },
                  loading: () => _buildLoadingState(isDark),
                  error: (error, stack) => _buildErrorState(error),
                ),
              ),
              // Espacement pour le mini player quand il est visible
              if (isAudioPlaying) const SizedBox(height: 80),
            ],
          ),
          // Mini lecteur audio en bas
          if (isAudioPlaying)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: const MiniAudioPlayer(),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(
    List<Surah> surahs,
    int lastReadSurahNumber,
    bool isDark,
  ) {
    final responsivePadding = ResponsiveUtils.adaptivePadding(
      context,
      mobile: AppTheme.paddingMedium,
    );

    return CustomScrollView(
      slivers: [
        // App Bar avec dégradé
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
                  padding: EdgeInsets.all(responsivePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                              ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: 12,
                                tablet: 14,
                                desktop: 16,
                              ),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.luxuryGold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.menu_book,
                              color: AppColors.luxuryGold,
                              size: ResponsiveUtils.adaptiveIconSize(
                                context,
                                base: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.paddingMedium),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'القرآن الكريم',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: ResponsiveUtils.adaptiveFontSize(
                                      context,
                                      mobile: 28,
                                      tablet: 32,
                                      desktop: 36,
                                    ),
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.pureWhite,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Le Saint Coran',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.adaptiveFontSize(
                                      context,
                                      mobile: 14,
                                      tablet: 16,
                                      desktop: 18,
                                    ),
                                    color: AppColors.pureWhite,
                                    fontWeight: FontWeight.w300,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              // Toggle theme
                            },
                            icon: Icon(
                              isDark ? Icons.light_mode : Icons.dark_mode,
                              color: AppColors.luxuryGold,
                            ),
                            iconSize: ResponsiveUtils.adaptiveIconSize(
                              context,
                              base: 24,
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
        ),

        // Contenu principal
        SliverToBoxAdapter(
          child: ResponsiveWrapper(
            child: Padding(
              padding: EdgeInsets.all(responsivePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barre de recherche
                  CustomSearchBar(
                    onSearch: (String query) => _onSearch(query, surahs),
                  ),

                  const SizedBox(height: AppTheme.paddingLarge),

                  // Section "Reprendre la lecture" si applicable
                  if (lastReadSurahNumber > 0)
                    _buildResumeReading(surahs, lastReadSurahNumber, isDark),

                  const SizedBox(height: AppTheme.paddingLarge),

                  // Titre de la liste
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Toutes les Sourates',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.goldAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_filteredSurahs.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkBackground
                                : AppColors.deepBlue,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.paddingMedium),
                ],
              ),
            ),
          ),
        ),

        // Liste des Surahs
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: responsivePadding),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final surah = _filteredSurahs[index];
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(_fadeAnimation),
                  child: SurahCard(
                    surah: surah,
                    isLastRead: surah.number == lastReadSurahNumber,
                    onTap: () => _navigateToSurah(surah),
                  ),
                ),
              );
            }, childCount: _filteredSurahs.length),
          ),
        ),

        // Espacement en bas (plus d'espace si le lecteur audio est visible)
        const SliverToBoxAdapter(
          child: SizedBox(height: AppTheme.paddingXLarge),
        ),
      ],
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(isDark),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: Column(
              children: [
                CustomSearchBar(onSearch: (query) {}),
                const SizedBox(height: AppTheme.paddingLarge),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.paddingMedium),
              child: SurahCardShimmer(),
            ),
            childCount: 5,
          ),
        ),
      ],
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
              onPressed: () => ref.refresh(surahsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(
                    colors: [AppColors.darkSurface, AppColors.darkBackground],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : AppColors.headerGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
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
                          Icons.menu_book,
                          color: AppColors.luxuryGold,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: AppTheme.paddingMedium),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'القرآن الكريم',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.pureWhite,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Le Saint Coran',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.pureWhite,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                        },
                        icon: Icon(
                          isDark ? Icons.light_mode : Icons.dark_mode,
                          color: AppColors.luxuryGold,
                        ),
                        iconSize: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResumeReading(
    List<Surah> surahs,
    int lastReadSurahNumber,
    bool isDark,
  ) {
    final lastReadSurah = surahs.firstWhere(
      (s) => s.number == lastReadSurahNumber,
      orElse: () => surahs.first,
    );
    final lastReadAyah = ref.watch(lastReadAyahProvider);

    final responsivePadding = ResponsiveUtils.adaptivePadding(
      context,
      mobile: AppTheme.paddingLarge,
    );

    return GestureDetector(
      onTap: () => _navigateToSurah(lastReadSurah),
      child: Container(
        padding: EdgeInsets.all(responsivePadding),
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  colors: [
                    AppColors.darkCard,
                    AppColors.darkCard.withOpacity(0.8),
                  ],
                )
              : const LinearGradient(
                  colors: [AppColors.paleGold, AppColors.pureWhite],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.adaptiveBorderRadius(context),
          ),
          boxShadow: AppColors.cardShadow,
          border: Border.all(
            color: AppColors.luxuryGold.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(
                ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
              ),
              decoration: BoxDecoration(
                gradient: AppColors.goldAccent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.play_circle_filled,
                size: ResponsiveUtils.adaptiveIconSize(context, base: 32),
                color: isDark ? AppColors.darkBackground : AppColors.deepBlue,
              ),
            ),
            const SizedBox(width: AppTheme.paddingMedium),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reprendre la lecture',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastReadSurah.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ayah $lastReadAyah sur ${lastReadSurah.numberOfAyahs}',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 2,
              child: Text(
                lastReadSurah.arabicName,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 24,
                    tablet: 28,
                    desktop: 32,
                  ),
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
}
