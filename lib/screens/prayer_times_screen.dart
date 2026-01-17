import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../providers/prayer_times_providers.dart';
import '../services/prayer_times_service.dart';
import '../providers/settings_providers.dart';

class PrayerTimesScreen extends ConsumerStatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  ConsumerState<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends ConsumerState<PrayerTimesScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prayerTimesAsync = ref.watch(todayPrayerTimesProvider);
    final locationAsync = ref.watch(currentLocationProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  colors: [AppColors.darkBackground, AppColors.darkSurface],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : LinearGradient(
                  colors: [AppColors.ivory, AppColors.pureWhite],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // App Bar
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
                            mobile: AppTheme.paddingMedium,
                          ),
                        ),
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
                                    color: AppColors.luxuryGold.withOpacity(
                                      0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.access_time,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Horaires de prières',
                                        style: TextStyle(
                                          fontSize:
                                              ResponsiveUtils.adaptiveFontSize(
                                                context,
                                                mobile: 28,
                                                tablet: 32,
                                                desktop: 36,
                                              ),
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.pureWhite,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      locationAsync.when(
                                        data: (location) => Text(
                                          location?.toString() ??
                                              'Localisation...',
                                          style: TextStyle(
                                            fontSize:
                                                ResponsiveUtils.adaptiveFontSize(
                                                  context,
                                                  mobile: 14,
                                                  tablet: 16,
                                                  desktop: 18,
                                                ),
                                            color: AppColors.pureWhite
                                                .withOpacity(0.8),
                                            fontWeight: FontWeight.w300,
                                          ),
                                        ),
                                        loading: () => Text(
                                          'Chargement...',
                                          style: TextStyle(
                                            fontSize:
                                                ResponsiveUtils.adaptiveFontSize(
                                                  context,
                                                  mobile: 14,
                                                  tablet: 16,
                                                  desktop: 18,
                                                ),
                                            color: AppColors.pureWhite
                                                .withOpacity(0.8),
                                          ),
                                        ),
                                        error: (_, __) => Text(
                                          'Erreur de localisation',
                                          style: TextStyle(
                                            fontSize:
                                                ResponsiveUtils.adaptiveFontSize(
                                                  context,
                                                  mobile: 14,
                                                  tablet: 16,
                                                  desktop: 18,
                                                ),
                                            color: AppColors.pureWhite
                                                .withOpacity(0.8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Bouton sélection Adhan
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Consumer(
                                  builder: (context, ref, child) {
                                    final selectedAdhan = ref.watch(
                                      selectedAdhanProvider,
                                    );
                                    return GestureDetector(
                                      onTap: () =>
                                          _showAdhanSelector(context, ref),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal:
                                              ResponsiveUtils.adaptivePadding(
                                                context,
                                                mobile: 12,
                                              ),
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.pureWhite
                                              .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.music_note,
                                              color: AppColors.pureWhite,
                                              size:
                                                  ResponsiveUtils.adaptiveIconSize(
                                                    context,
                                                    base: 16,
                                                  ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _getAdhanDisplayName(
                                                selectedAdhan,
                                              ),
                                              style: TextStyle(
                                                fontSize:
                                                    ResponsiveUtils.adaptiveFontSize(
                                                      context,
                                                      mobile: 11,
                                                      tablet: 12,
                                                      desktop: 13,
                                                    ),
                                                color: AppColors.pureWhite,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
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

              // Contenu
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(
                    ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: AppTheme.paddingMedium,
                    ),
                  ),
                  child: prayerTimesAsync.when(
                    data: (prayerTimes) {
                      if (prayerTimes == null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_off,
                                size: 64,
                                color: isDark
                                    ? AppColors.pureWhite.withOpacity(0.5)
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(height: AppTheme.paddingLarge),
                              Text(
                                'Localisation requise',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.adaptiveFontSize(
                                    context,
                                    mobile: 18,
                                    tablet: 20,
                                    desktop: 22,
                                  ),
                                  color: isDark
                                      ? AppColors.pureWhite
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppTheme.paddingMedium),
                              ElevatedButton(
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  ref.invalidate(currentLocationProvider);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.luxuryGold,
                                  foregroundColor: AppColors.pureWhite,
                                ),
                                child: const Text('Activer la localisation'),
                              ),
                            ],
                          ),
                        );
                      }

                      return _buildPrayerTimesList(prayerTimes, isDark);
                    },
                    loading: () => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.paddingXLarge),
                        child: CircularProgressIndicator(
                          color: AppColors.luxuryGold,
                        ),
                      ),
                    ),
                    error: (error, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.paddingXLarge),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: AppColors.error,
                            ),
                            const SizedBox(height: AppTheme.paddingLarge),
                            Text(
                              'Erreur de chargement',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.adaptiveFontSize(
                                  context,
                                  mobile: 18,
                                  tablet: 20,
                                  desktop: 22,
                                ),
                                color: isDark
                                    ? AppColors.pureWhite
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppTheme.paddingMedium),
                            ElevatedButton(
                              onPressed: () {
                                ref.invalidate(todayPrayerTimesProvider);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.luxuryGold,
                                foregroundColor: AppColors.pureWhite,
                              ),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildPrayerTimesList(PrayerTimes prayerTimes, bool isDark) {
    final service = PrayerTimesService();
    final now = DateTime.now();
    final nextPrayer = prayerTimes.getNextPrayer(now);
    final prayedPrayersAsync = ref.watch(todayPrayedPrayersProvider);
    final prayedCountAsync = ref.watch(todayPrayedCountProvider);

    // Liste des noms de prières (5 prières principales, sans Imsak)
    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final totalPrayers = prayerNames.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cartes résumé : Prochaine prière et Compteur
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Carte prochaine prière
              if (nextPrayer != null)
                Expanded(
                  child: _buildNextPrayerCard(nextPrayer, service, isDark),
                ),
              if (nextPrayer != null)
                const SizedBox(width: AppTheme.paddingMedium),
              // Carte compteur de prières récitées
              Expanded(
                child: prayedCountAsync.when(
                  data: (count) =>
                      _buildPrayedCountCard(count, totalPrayers, isDark),
                  loading: () => _buildPrayedCountCard(0, totalPrayers, isDark),
                  error: (_, __) =>
                      _buildPrayedCountCard(0, totalPrayers, isDark),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.paddingLarge),

        // Liste des prières
        prayedPrayersAsync.when(
          data: (prayedPrayers) {
            return Column(
              children: [
                _buildPrayerItem(
                  'Imsak',
                  prayerTimes.imsak,
                  isDark,
                  Icons.wb_twilight,
                  false,
                  null,
                  ref,
                ),
                _buildPrayerItem(
                  'Fajr',
                  prayerTimes.fajr,
                  isDark,
                  Icons.wb_sunny,
                  prayedPrayers.contains('Fajr'),
                  'Fajr',
                  ref,
                ),
                _buildPrayerItem(
                  'Dhuhr',
                  prayerTimes.dhuhr,
                  isDark,
                  Icons.wb_sunny_outlined,
                  prayedPrayers.contains('Dhuhr'),
                  'Dhuhr',
                  ref,
                ),
                _buildPrayerItem(
                  'Asr',
                  prayerTimes.asr,
                  isDark,
                  Icons.cloud,
                  prayedPrayers.contains('Asr'),
                  'Asr',
                  ref,
                ),
                _buildPrayerItem(
                  'Maghrib',
                  prayerTimes.maghrib,
                  isDark,
                  Icons.wb_twilight,
                  prayedPrayers.contains('Maghrib'),
                  'Maghrib',
                  ref,
                ),
                _buildPrayerItem(
                  'Isha',
                  prayerTimes.isha,
                  isDark,
                  Icons.nightlight_round,
                  prayedPrayers.contains('Isha'),
                  'Isha',
                  ref,
                ),
                if (prayerTimes.tarawih != null)
                  _buildPrayerItem(
                    'Tarawih',
                    prayerTimes.tarawih!,
                    isDark,
                    Icons.stars,
                    false,
                    null,
                    ref,
                  ),
                const SizedBox(height: AppTheme.paddingMedium),
                // Bouton "Mark all as prayed"
                ElevatedButton(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final settingsService = ref.read(settingsServiceProvider);
                    await settingsService.markAllPrayersAsPrayed(
                      DateTime.now(),
                      prayerNames,
                    );
                    ref.invalidate(todayPrayedPrayersProvider);
                    ref.invalidate(todayPrayedCountProvider);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.luxuryGold,
                    foregroundColor: AppColors.pureWhite,
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: AppTheme.paddingLarge,
                      ),
                      vertical: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: AppTheme.paddingMedium,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Marquer toutes comme récitées',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 16,
                        tablet: 17,
                        desktop: 18,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => Column(
            children: [
              _buildPrayerItem(
                'Imsak',
                prayerTimes.imsak,
                isDark,
                Icons.wb_twilight,
                false,
                null,
                ref,
              ),
              _buildPrayerItem(
                'Fajr',
                prayerTimes.fajr,
                isDark,
                Icons.wb_sunny,
                false,
                null,
                ref,
              ),
              _buildPrayerItem(
                'Dhuhr',
                prayerTimes.dhuhr,
                isDark,
                Icons.wb_sunny_outlined,
                false,
                null,
                ref,
              ),
              _buildPrayerItem(
                'Asr',
                prayerTimes.asr,
                isDark,
                Icons.cloud,
                false,
                null,
                ref,
              ),
              _buildPrayerItem(
                'Maghrib',
                prayerTimes.maghrib,
                isDark,
                Icons.wb_twilight,
                false,
                null,
                ref,
              ),
              _buildPrayerItem(
                'Isha',
                prayerTimes.isha,
                isDark,
                Icons.nightlight_round,
                false,
                null,
                ref,
              ),
              if (prayerTimes.tarawih != null)
                _buildPrayerItem(
                  'Tarawih',
                  prayerTimes.tarawih!,
                  isDark,
                  Icons.stars,
                  false,
                  null,
                  ref,
                ),
            ],
          ),
          error: (_, __) => Column(
            children: [
              _buildPrayerItem(
                'Imsak',
                prayerTimes.imsak,
                isDark,
                Icons.wb_twilight,
                false,
                null,
                ref,
              ),
              _buildPrayerItem(
                'Fajr',
                prayerTimes.fajr,
                isDark,
                Icons.wb_sunny,
                false,
                null,
                ref,
              ),
              _buildPrayerItem(
                'Dhuhr',
                prayerTimes.dhuhr,
                isDark,
                Icons.wb_sunny_outlined,
                false,
                null,
                ref,
              ),
              _buildPrayerItem(
                'Asr',
                prayerTimes.asr,
                isDark,
                Icons.cloud,
                false,
                null,
                ref,
              ),
              _buildPrayerItem(
                'Maghrib',
                prayerTimes.maghrib,
                isDark,
                Icons.wb_twilight,
                false,
                null,
                ref,
              ),
              _buildPrayerItem(
                'Isha',
                prayerTimes.isha,
                isDark,
                Icons.nightlight_round,
                false,
                null,
                ref,
              ),
              if (prayerTimes.tarawih != null)
                _buildPrayerItem(
                  'Tarawih',
                  prayerTimes.tarawih!,
                  isDark,
                  Icons.stars,
                  false,
                  null,
                  ref,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNextPrayerCard(
    Map<String, dynamic> nextPrayer,
    PrayerTimesService service,
    bool isDark,
  ) {
    final timeUntil = nextPrayer['timeUntil'] as Duration;
    final hours = timeUntil.inHours;
    final minutes = timeUntil.inMinutes.remainder(60);
    final seconds = timeUntil.inSeconds.remainder(60);

    return Container(
      constraints: BoxConstraints(
        minHeight: ResponsiveUtils.responsive(
          context,
          mobile: 140,
          tablet: 160,
          desktop: 180,
        ),
      ),
      padding: EdgeInsets.all(
        ResponsiveUtils.adaptivePadding(context, mobile: AppTheme.paddingLarge),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.luxuryGold, AppColors.luxuryGold.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.luxuryGold.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Maintenant',
            style: TextStyle(
              fontSize: ResponsiveUtils.adaptiveFontSize(
                context,
                mobile: 12,
                tablet: 13,
                desktop: 14,
              ),
              color: AppColors.pureWhite.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.cloud,
                color: AppColors.pureWhite,
                size: ResponsiveUtils.adaptiveIconSize(context, base: 20),
              ),
              const SizedBox(width: 8),
              Text(
                nextPrayer['name'] as String,
                style: TextStyle(
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 20,
                    tablet: 22,
                    desktop: 24,
                  ),
                  color: AppColors.pureWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            service.formatTime(nextPrayer['time'] as DateTime),
            style: TextStyle(
              fontSize: ResponsiveUtils.adaptiveFontSize(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
              color: AppColors.pureWhite.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hours > 0
                ? 'Dans ${hours}h ${minutes}m'
                : minutes > 0
                ? 'Dans ${minutes}m ${seconds}s'
                : 'Dans ${seconds}s',
            style: TextStyle(
              fontSize: ResponsiveUtils.adaptiveFontSize(
                context,
                mobile: 14,
                tablet: 15,
                desktop: 16,
              ),
              color: AppColors.pureWhite.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayedCountCard(int count, int total, bool isDark) {
    final progress = total > 0 ? count / total : 0.0;
    final isComplete = count == total && count > 0;

    return Container(
      constraints: BoxConstraints(
        minHeight: ResponsiveUtils.responsive(
          context,
          mobile: 140,
          tablet: 160,
          desktop: 180,
        ),
      ),
      padding: EdgeInsets.all(
        ResponsiveUtils.adaptivePadding(context, mobile: AppTheme.paddingLarge),
      ),
      decoration: BoxDecoration(
        gradient: isComplete
            ? LinearGradient(
                colors: [
                  AppColors.luxuryGold.withOpacity(0.15),
                  AppColors.luxuryGold.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isComplete
            ? null
            : (isDark ? AppColors.darkCard : AppColors.pureWhite),
        borderRadius: BorderRadius.circular(16),
        border: isComplete
            ? Border.all(
                color: AppColors.luxuryGold.withOpacity(0.3),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: isComplete
                ? AppColors.luxuryGold.withOpacity(0.2)
                : Colors.black.withOpacity(0.1),
            blurRadius: isComplete ? 12 : 8,
            spreadRadius: isComplete ? 2 : 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Titre en haut
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: isComplete
                      ? AppColors.luxuryGold
                      : (isDark
                            ? AppColors.pureWhite.withOpacity(0.6)
                            : AppColors.textSecondary),
                  size: ResponsiveUtils.adaptiveIconSize(context, base: 18),
                ),
                const SizedBox(width: 6),
                Text(
                  'Prières récitées',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 13,
                      tablet: 14,
                      desktop: 15,
                    ),
                    fontWeight: FontWeight.w600,
                    color: isComplete
                        ? AppColors.luxuryGold
                        : (isDark
                              ? AppColors.pureWhite.withOpacity(0.8)
                              : AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          // Indicateur circulaire avec contenu
          SizedBox(
            width: ResponsiveUtils.responsive(
              context,
              mobile: 100,
              tablet: 120,
              desktop: 140,
            ),
            height: ResponsiveUtils.responsive(
              context,
              mobile: 100,
              tablet: 120,
              desktop: 140,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Cercle de progression
                SizedBox(
                  width: ResponsiveUtils.responsive(
                    context,
                    mobile: 100,
                    tablet: 120,
                    desktop: 140,
                  ),
                  height: ResponsiveUtils.responsive(
                    context,
                    mobile: 100,
                    tablet: 120,
                    desktop: 140,
                  ),
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: ResponsiveUtils.responsive(
                      context,
                      mobile: 10,
                      tablet: 12,
                      desktop: 14,
                    ),
                    backgroundColor: isDark
                        ? AppColors.darkSurface
                        : AppColors.ivory,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete
                          ? AppColors.luxuryGold
                          : AppColors.luxuryGold.withOpacity(0.8),
                    ),
                  ),
                ),
                // Contenu au centre
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isComplete)
                      Icon(
                        Icons.check_circle,
                        color: AppColors.luxuryGold,
                        size: ResponsiveUtils.adaptiveIconSize(
                          context,
                          base: 28,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (isComplete) const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$count',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.adaptiveFontSize(
                                context,
                                mobile: 28,
                                tablet: 34,
                                desktop: 40,
                              ),
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.pureWhite
                                  : AppColors.textPrimary,
                              height: 1.0,
                            ),
                          ),
                          TextSpan(
                            text: '/$total',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.adaptiveFontSize(
                                context,
                                mobile: 20,
                                tablet: 24,
                                desktop: 28,
                              ),
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.pureWhite.withOpacity(0.6)
                                  : AppColors.textSecondary,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Icône de célébration
          if (isComplete)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.luxuryGold.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration,
                color: AppColors.luxuryGold,
                size: ResponsiveUtils.adaptiveIconSize(context, base: 24),
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildPrayerItem(
    String name,
    DateTime time,
    bool isDark,
    IconData icon,
    bool isPrayed,
    String? prayerName,
    WidgetRef ref,
  ) {
    final service = PrayerTimesService();
    final now = DateTime.now();
    final isPast = now.isAfter(time);
    final isNext =
        now.isBefore(time) && (now.add(const Duration(hours: 1)).isAfter(time));

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.paddingMedium),
      padding: EdgeInsets.all(
        ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingMedium,
        ),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: isNext
            ? Border.all(color: AppColors.luxuryGold, width: 2)
            : null,
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: AppColors.luxuryGold.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Checkbox circulaire
          if (prayerName != null)
            GestureDetector(
              onTap: () async {
                HapticFeedback.lightImpact();
                final settingsService = ref.read(settingsServiceProvider);
                if (isPrayed) {
                  await settingsService.unmarkPrayerAsPrayed(
                    DateTime.now(),
                    prayerName,
                  );
                } else {
                  await settingsService.markPrayerAsPrayed(
                    DateTime.now(),
                    prayerName,
                  );
                }
                ref.invalidate(todayPrayedPrayersProvider);
                ref.invalidate(todayPrayedCountProvider);
              },
              child: Container(
                width: ResponsiveUtils.responsive(
                  context,
                  mobile: 24,
                  tablet: 26,
                  desktop: 28,
                ),
                height: ResponsiveUtils.responsive(
                  context,
                  mobile: 24,
                  tablet: 26,
                  desktop: 28,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPrayed
                        ? AppColors.luxuryGold
                        : (isDark
                              ? AppColors.pureWhite.withOpacity(0.3)
                              : AppColors.textSecondary.withOpacity(0.3)),
                    width: 2,
                  ),
                  color: isPrayed ? AppColors.luxuryGold : Colors.transparent,
                ),
                child: isPrayed
                    ? Icon(
                        Icons.check,
                        color: AppColors.pureWhite,
                        size: ResponsiveUtils.adaptiveIconSize(
                          context,
                          base: 16,
                        ),
                      )
                    : null,
              ),
            ),
          if (prayerName != null) const SizedBox(width: AppTheme.paddingMedium),
          // Icône de la prière
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  (isNext
                          ? AppColors.luxuryGold
                          : (isDark ? AppColors.darkSurface : AppColors.ivory))
                      .withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isNext
                  ? AppColors.luxuryGold
                  : (isDark
                        ? AppColors.pureWhite.withOpacity(0.7)
                        : AppColors.textSecondary),
              size: ResponsiveUtils.adaptiveIconSize(context, base: 24),
            ),
          ),
          const SizedBox(width: AppTheme.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 16,
                      tablet: 18,
                      desktop: 20,
                    ),
                    fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
                    color: isDark ? AppColors.pureWhite : AppColors.textPrimary,
                  ),
                ),
                if (isNext)
                  Text(
                    'Prochaine prière',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                      color: AppColors.luxuryGold,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            service.formatTime(time),
            style: TextStyle(
              fontSize: ResponsiveUtils.adaptiveFontSize(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
              fontWeight: FontWeight.bold,
              color: isPast
                  ? (isDark
                        ? AppColors.pureWhite.withOpacity(0.5)
                        : AppColors.textSecondary)
                  : (isDark ? AppColors.pureWhite : AppColors.textPrimary),
            ),
          ),
          // Icône de notification Adhan
          if (prayerName != null) ...[
            const SizedBox(width: AppTheme.paddingMedium),
            Consumer(
              builder: (context, ref, child) {
                final adhanStatesAsync = ref.watch(adhanStatesProvider);
                return adhanStatesAsync.when(
                  data: (states) {
                    final isEnabled = states[prayerName] ?? true;
                    return GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final settingsService = ref.read(
                          settingsServiceProvider,
                        );
                        await settingsService.setAdhanEnabled(
                          prayerName,
                          !isEnabled,
                        );
                        ref.invalidate(adhanStatesProvider);
                      },
                      child: Icon(
                        isEnabled ? Icons.volume_up : Icons.volume_off,
                        color: isEnabled
                            ? (isNext
                                  ? AppColors.luxuryGold
                                  : (isDark
                                        ? AppColors.pureWhite.withOpacity(0.7)
                                        : AppColors.textSecondary))
                            : (isDark
                                  ? AppColors.pureWhite.withOpacity(0.3)
                                  : AppColors.textSecondary.withOpacity(0.3)),
                        size: ResponsiveUtils.adaptiveIconSize(
                          context,
                          base: 20,
                        ),
                      ),
                    );
                  },
                  loading: () => Icon(
                    Icons.volume_up,
                    color: isDark
                        ? AppColors.pureWhite.withOpacity(0.3)
                        : AppColors.textSecondary.withOpacity(0.3),
                    size: ResponsiveUtils.adaptiveIconSize(context, base: 20),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _getAdhanDisplayName(String adhanName) {
    switch (adhanName) {
      case 'classic':
        return 'Classique';
      case 'makkah':
        return 'Makkah';
      case 'madinah':
        return 'Madinah';
      case 'egyptian':
        return 'Égyptien';
      case 'turkish':
        return 'Turc';
      default:
        return 'Classique';
    }
  }

  void _showAdhanSelector(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    final selectedAdhan = ref.read(selectedAdhanProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.pureWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(
          ResponsiveUtils.adaptivePadding(
            context,
            mobile: AppTheme.paddingLarge,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sélectionner l\'Adhan',
              style: TextStyle(
                fontSize: ResponsiveUtils.adaptiveFontSize(
                  context,
                  mobile: 20,
                  tablet: 22,
                  desktop: 24,
                ),
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.pureWhite : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            ...['classic', 'makkah', 'madinah', 'egyptian', 'turkish']
                .map(
                  (adhan) => ListTile(
                    leading: Icon(
                      selectedAdhan == adhan
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selectedAdhan == adhan
                          ? AppColors.luxuryGold
                          : (isDark
                                ? AppColors.pureWhite.withOpacity(0.5)
                                : AppColors.textSecondary),
                    ),
                    title: Text(
                      _getAdhanDisplayName(adhan),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 16,
                          tablet: 17,
                          desktop: 18,
                        ),
                        color: isDark
                            ? AppColors.pureWhite
                            : AppColors.textPrimary,
                        fontWeight: selectedAdhan == adhan
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(selectedAdhanProvider.notifier).setAdhan(adhan);
                      Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
            const SizedBox(height: AppTheme.paddingMedium),
          ],
        ),
      ),
    );
  }
}
