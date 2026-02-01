import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri_date_time/hijri_date_time.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../providers/prayer_times_providers.dart';
import '../providers/personalization_providers.dart';
import '../providers/duas_providers.dart';
import '../providers/content_rotation_providers.dart';
import '../providers/ramadan_content_providers.dart';
import '../services/prayer_times_service.dart';
import '../services/location_service.dart';
import '../services/content_rotation_service.dart';
import 'prayer_times_screen.dart';
import 'surah_detail_screen.dart';
import 'settings_screen.dart';
import '../providers/quran_providers.dart';
import '../utils/surah_adapter.dart';
import '../widgets/responsive_wrapper.dart';

/// Phase Ramadan pour l'accueil dynamique "Que dois-je faire maintenant ?"
enum RamadanPhase {
  /// Avant Fajr : intention & préparation (Suhoor / Imsak)
  suhoor,
  /// Journée de jeûne : Fajr → avant la fenêtre Iftar
  fastingDay,
  /// Avant Iftar : moment clé des invocations (≈ 45 min avant Maghrib)
  beforeIftar,
  /// Nuit : après Isha / Tarawih – Coran & introspection
  night,
}

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  Timer? _countdownTimer;
  Duration _countdownDuration = Duration.zero;
  String? _nextEventName;
  String? _nextEventDua;
  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final prayerTimesAsync = ref.read(todayPrayerTimesProvider);
      prayerTimesAsync.whenData((prayerTimes) {
        if (prayerTimes != null && mounted) {
          _updateCountdown(prayerTimes);
        }
      });
    });
  }

  void _updateCountdown(PrayerTimes prayerTimes) {
    final now = DateTime.now();
    final nextPrayer = _getNextEvent(prayerTimes, now);

    if (nextPrayer != null) {
      setState(() {
        _countdownDuration = nextPrayer['timeUntil'] as Duration;
        _nextEventName = nextPrayer['name'] as String;
        _nextEventDua = _getDuaForEvent(_nextEventName!);
      });
    }
  }

  Map<String, dynamic>? _getNextEvent(PrayerTimes prayerTimes, DateTime now) {
    // Logique dynamique selon l'heure
    if (now.isBefore(prayerTimes.imsak)) {
      // Avant Imsak -> compte à rebours vers Suhoor (Imsak - 30 min)
      final suhoor = prayerTimes.imsak.subtract(const Duration(minutes: 30));
      if (now.isBefore(suhoor)) {
        return {
          'name': 'Suhoor',
          'time': suhoor,
          'timeUntil': suhoor.difference(now),
        };
      }
      return {
        'name': 'Imsak',
        'time': prayerTimes.imsak,
        'timeUntil': prayerTimes.imsak.difference(now),
      };
    } else if (now.isBefore(prayerTimes.fajr)) {
      return {
        'name': 'Imsak',
        'time': prayerTimes.imsak,
        'timeUntil': prayerTimes.imsak.difference(now),
      };
    } else if (now.isBefore(prayerTimes.maghrib)) {
      return {
        'name': 'Iftar',
        'time': prayerTimes.maghrib,
        'timeUntil': prayerTimes.maghrib.difference(now),
      };
    } else if (now.isBefore(prayerTimes.isha)) {
      return {
        'name': 'Isha / Tarawih',
        'time': prayerTimes.isha,
        'timeUntil': prayerTimes.isha.difference(now),
      };
    } else {
      // Après Isha, prochaine est Suhoor du lendemain
      final tomorrowImsak = prayerTimes.imsak.add(const Duration(days: 1));
      final tomorrowSuhoor = tomorrowImsak.subtract(
        const Duration(minutes: 30),
      );
      return {
        'name': 'Suhoor',
        'time': tomorrowSuhoor,
        'timeUntil': tomorrowSuhoor.difference(now),
      };
    }
  }

  String _getDuaForEvent(String eventName) {
    switch (eventName) {
      case 'Suhoor':
        return 'اللهم إني نويت الصيام';
      case 'Imsak':
        return 'اللهم إني نويت الصيام';
      case 'Iftar':
        return 'اللهم لك صمت';
      case 'Isha / Tarawih':
        return 'اللهم تقبل منا';
      default:
        return 'اللهم تقبل منا';
    }
  }

  /// Fenêtre "Avant Iftar" : 45 minutes avant Maghrib
  static const int _beforeIftarMinutes = 45;

  RamadanPhase _getRamadanPhase(PrayerTimes prayerTimes, DateTime now) {
    if (now.isBefore(prayerTimes.fajr)) {
      return RamadanPhase.suhoor;
    }
    final iftarWindowStart =
        prayerTimes.maghrib.subtract(Duration(minutes: _beforeIftarMinutes));
    if (now.isBefore(iftarWindowStart)) {
      return RamadanPhase.fastingDay;
    }
    if (now.isBefore(prayerTimes.maghrib)) {
      return RamadanPhase.beforeIftar;
    }
    if (now.isBefore(prayerTimes.isha)) {
      return RamadanPhase.fastingDay; // Après Maghrib, avant Isha = soirée
    }
    return RamadanPhase.night;
  }

  /// Titre court pour la carte hero selon la phase
  String _getPhaseTitle(RamadanPhase phase) {
    switch (phase) {
      case RamadanPhase.suhoor:
        return 'C\'est le moment du Suhoor';
      case RamadanPhase.fastingDay:
        return 'Temps restant avant l\'Iftar';
      case RamadanPhase.beforeIftar:
        return 'Moment des invocations';
      case RamadanPhase.night:
        return 'La nuit, moment de proximité';
    }
  }

  /// Sous-titre / message spirituel selon la phase
  String _getPhaseMessage(RamadanPhase phase) {
    switch (phase) {
      case RamadanPhase.suhoor:
        return 'Niyyah et bénédiction – N\'oublie pas l\'intention du jeûne';
      case RamadanPhase.fastingDay:
        return 'Patience et rappel – Que ce jour soit béni';
      case RamadanPhase.beforeIftar:
        return 'C\'est l\'heure où les invocations sont exaucées';
      case RamadanPhase.night:
        return 'La nuit est un moment de proximité avec Allah';
    }
  }

  /// Compte à rebours affiché (label)
  String _getCountdownLabel(RamadanPhase phase, String? nextEventName) {
    switch (phase) {
      case RamadanPhase.suhoor:
        return nextEventName == 'Suhoor'
            ? 'Suhoor dans'
            : 'Imsak dans';
      case RamadanPhase.fastingDay:
        return 'Iftar dans';
      case RamadanPhase.beforeIftar:
        return 'Iftar dans';
      case RamadanPhase.night:
        return 'Suhoor demain dans';
    }
  }

  /// Prochaine prière affichée
  String _getNextPrayerLabel(RamadanPhase phase) {
    switch (phase) {
      case RamadanPhase.suhoor:
        return 'Prochaine prière : Fajr';
      case RamadanPhase.fastingDay:
        return 'Prochaine prière';
      case RamadanPhase.beforeIftar:
        return 'Prochaine prière : Maghrib';
      case RamadanPhase.night:
        return 'Tarawih / Qiyam';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return months[month - 1];
  }

  String _getRamadanGreeting(HijriDateTime hijriDate) {
    final day = hijriDate.day;
    final greetings = [
      'Qu\'Allah accepte ton jeûne aujourd\'hui',
      'Ramadan Mubarak',
      'Que ce jour soit béni',
      'Qu\'Allah bénisse ta journée',
      'Puisse Allah accepter tes prières',
    ];
    return greetings[day % greetings.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationAsync = ref.watch(currentLocationProvider);
    final prayerTimesAsync = ref.watch(todayPrayerTimesProvider);
    final personalizationConfigAsync = ref.watch(personalizationConfigProvider);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Top Context Header
          _buildAppBar(isDark, locationAsync),

          // Contenu principal
          SliverToBoxAdapter(
            child: ResponsiveWrapper(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingMedium,
                  ),
                  vertical: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingSmall,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primary Countdown Card - Hero Section (Ramadan Vision)
                    _buildSection(
                      child: prayerTimesAsync.when(
                        data: (prayerTimes) {
                          if (prayerTimes == null) {
                            return _buildEmptyState(
                              isDark,
                              'Chargement des horaires...',
                            );
                          }
                          final phase = _getRamadanPhase(
                            prayerTimes,
                            DateTime.now(),
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCountdownCard(isDark, prayerTimes),
                              if (phase == RamadanPhase.night) ...[
                                SizedBox(
                                  height: ResponsiveUtils.adaptivePadding(
                                    context,
                                    mobile: AppTheme.paddingLarge,
                                    tablet: AppTheme.paddingXLarge,
                                  ),
                                ),
                                _buildLastReadingCard(isDark),
                              ],
                            ],
                          );
                        },
                        loading: () => _buildCountdownCardShimmer(isDark),
                        error: (_, __) => _buildEmptyState(
                          isDark,
                          'Erreur de chargement des horaires',
                        ),
                      ),
                    ),

                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: AppTheme.paddingLarge,
                        tablet: AppTheme.paddingXLarge,
                      ),
                    ),

                    // Indicateur discret "En jeûne" (journée de jeûne)
                    prayerTimesAsync.when(
                      data: (prayerTimes) {
                        if (prayerTimes == null) return const SizedBox.shrink();
                        final phase = _getRamadanPhase(
                          prayerTimes,
                          DateTime.now(),
                        );
                        if (phase != RamadanPhase.fastingDay) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFastingDayIndicator(isDark),
                            SizedBox(
                              height: ResponsiveUtils.adaptivePadding(
                                context,
                                mobile: AppTheme.paddingMedium,
                                tablet: AppTheme.paddingLarge,
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    // Moment of the Day
                    _buildSection(child: _buildMomentOfTheDay(isDark)),

                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: AppTheme.paddingLarge,
                        tablet: AppTheme.paddingXLarge,
                      ),
                    ),

                    // Prayer Timeline
                    _buildSection(
                      title: 'Horaires de prières',
                      child: prayerTimesAsync.when(
                        data: (prayerTimes) => prayerTimes != null
                            ? _buildPrayerTimeline(isDark, prayerTimes)
                            : const SizedBox.shrink(),
                        loading: () => _buildPrayerTimelineShimmer(isDark),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),

                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: AppTheme.paddingLarge,
                        tablet: AppTheme.paddingXLarge,
                      ),
                    ),

                    // Contextual Quran Suggestion (based on personalization)
                    personalizationConfigAsync.when(
                      data: (config) {
                        if (config.preferredQuranTime == null) {
                          return const SizedBox.shrink();
                        }
                        final now = DateTime.now();
                        final hour = now.hour;
                        final preferredTime = config.preferredQuranTime!;

                        bool isPreferredTime = false;
                        if (preferredTime == 'fajr' && hour >= 4 && hour < 7) {
                          isPreferredTime = true;
                        } else if (preferredTime == 'dhuhr' &&
                            hour >= 12 &&
                            hour < 15) {
                          isPreferredTime = true;
                        } else if (preferredTime == 'asr' &&
                            hour >= 15 &&
                            hour < 18) {
                          isPreferredTime = true;
                        } else if (preferredTime == 'maghrib' &&
                            hour >= 18 &&
                            hour < 20) {
                          isPreferredTime = true;
                        } else if (preferredTime == 'isha' &&
                            (hour >= 20 || hour < 4)) {
                          isPreferredTime = true;
                        }

                        return isPreferredTime
                            ? _buildSection(
                                child: _buildContextualQuranSuggestion(
                                  isDark,
                                  preferredTime,
                                ),
                              )
                            : const SizedBox.shrink();
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    if (personalizationConfigAsync.hasValue &&
                        personalizationConfigAsync.value?.preferredQuranTime !=
                            null)
                      SizedBox(
                        height: ResponsiveUtils.adaptivePadding(
                          context,
                          mobile: AppTheme.paddingLarge,
                          tablet: AppTheme.paddingXLarge,
                        ),
                      ),

                    // Ramadan Progress Card
                    _buildSection(child: _buildRamadanProgressCard(isDark)),

                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: AppTheme.paddingLarge,
                        tablet: AppTheme.paddingXLarge,
                      ),
                    ),

                    // Quick Actions
                    _buildSection(
                      title: 'Actions rapides',
                      child: _buildQuickActions(isDark),
                    ),

                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: AppTheme.paddingLarge,
                        tablet: AppTheme.paddingXLarge,
                      ),
                    ),

                    // Contextual Banner Zone (via Content Rotation Engine)
                    _buildContextualBannerZone(isDark, prayerTimesAsync),

                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: AppTheme.paddingXLarge,
                        tablet: AppTheme.paddingXLarge * 1.5,
                      ),
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

  // ==================== BUILDERS D'ORGANISATION ====================

  Widget _buildAppBar(bool isDark, AsyncValue<LocationData?> locationAsync) {
    return SliverAppBar(
      expandedHeight: ResponsiveUtils.adaptiveAppBarHeight(context),
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
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
              padding: EdgeInsets.all(
                ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: AppTheme.paddingLarge,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [_buildTopHeader(isDark, locationAsync)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({String? title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: EdgeInsets.only(
              bottom: ResponsiveUtils.adaptivePadding(
                context,
                mobile: AppTheme.paddingMedium,
                tablet: AppTheme.paddingLarge,
              ),
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
        child,
      ],
    );
  }

  Widget _buildEmptyState(bool isDark, String message) {
    return Container(
      padding: EdgeInsets.all(
        ResponsiveUtils.adaptivePadding(context, mobile: AppTheme.paddingLarge),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context),
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(bool isDark, AsyncValue<LocationData?> locationAsync) {
    final now = DateTime.now();
    final hijriDate = HijriDateTime.now();
    // Format date grégorienne sans locale spécifique pour éviter l'erreur
    final gregorianDate = '${now.day} ${_getMonthName(now.month)} ${now.year}';

    // Noms des mois Hijri en français
    final hijriMonths = [
      'Muharram',
      'Safar',
      'Rabi\' al-awwal',
      'Rabi\' al-thani',
      'Jumada al-awwal',
      'Jumada al-thani',
      'Rajab',
      'Sha\'ban',
      'Ramadan',
      'Shawwal',
      'Dhu al-Qi\'dah',
      'Dhu al-Hijjah',
    ];
    final hijriDateStr =
        '${hijriDate.day} ${hijriMonths[hijriDate.month - 1]} ${hijriDate.year}';
    final greeting = _getRamadanGreeting(hijriDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // City / Location
        locationAsync.when(
          data: (location) => Row(
            children: [
              Icon(
                Icons.location_on,
                color: AppColors.luxuryGold,
                size: ResponsiveUtils.adaptiveIconSize(context, base: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location != null
                      ? location.city ?? 'Localisation'
                      : 'Localisation',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 18,
                      tablet: 20,
                      desktop: 22,
                    ),
                    fontWeight: FontWeight.bold,
                    color: AppColors.pureWhite,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: AppColors.luxuryGold,
                  size: ResponsiveUtils.adaptiveIconSize(context, base: 20),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  // Navigate to location settings
                },
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 8),

        // Dates
        Text(
          '$hijriDateStr · $gregorianDate',
          style: TextStyle(
            fontSize: ResponsiveUtils.adaptiveFontSize(
              context,
              mobile: 14,
              tablet: 15,
              desktop: 16,
            ),
            color: AppColors.pureWhite.withOpacity(0.9),
          ),
        ),

        const SizedBox(height: 8),

        // Ramadan Greeting
        Text(
          greeting,
          style: TextStyle(
            fontSize: ResponsiveUtils.adaptiveFontSize(
              context,
              mobile: 16,
              tablet: 17,
              desktop: 18,
            ),
            fontStyle: FontStyle.italic,
            color: AppColors.luxuryGold,
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownCard(bool isDark, PrayerTimes prayerTimes) {
    final now = DateTime.now();
    final phase = _getRamadanPhase(prayerTimes, now);
    final hours = _countdownDuration.inHours;
    final minutes = _countdownDuration.inMinutes.remainder(60);
    final countdownText =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';

    final isBeforeIftar = phase == RamadanPhase.beforeIftar;
    final isNight = phase == RamadanPhase.night;

    return Container(
      padding: EdgeInsets.all(
        ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingXLarge,
          tablet: AppTheme.paddingXLarge * 1.5,
        ),
      ),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                colors: [
                  AppColors.darkCard,
                  AppColors.darkCard.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: isBeforeIftar
                    ? [
                        AppColors.luxuryGold.withOpacity(0.2),
                        AppColors.paleGold.withOpacity(0.9),
                        AppColors.luxuryGold.withOpacity(0.12),
                      ]
                    : [
                        AppColors.luxuryGold.withOpacity(0.15),
                        AppColors.paleGold.withOpacity(0.8),
                        AppColors.luxuryGold.withOpacity(0.1),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context) + 4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.luxuryGold.withOpacity(isBeforeIftar ? 0.35 : 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          ...AppColors.cardShadow,
        ],
        border: Border.all(
          color: AppColors.luxuryGold.withOpacity(isBeforeIftar ? 0.55 : 0.4),
          width: isBeforeIftar ? 3 : 2.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Titre de phase (Que dois-je faire maintenant ?)
          Text(
            _getPhaseTitle(phase),
            style: TextStyle(
              fontSize: ResponsiveUtils.adaptiveFontSize(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.pureWhite
                  : AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(
              context,
              mobile: 4,
              tablet: 6,
            ),
          ),
          Text(
            _getPhaseMessage(phase),
            style: TextStyle(
              fontSize: ResponsiveUtils.adaptiveFontSize(
                context,
                mobile: 13,
                tablet: 14,
                desktop: 15,
              ),
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(
              context,
              mobile: AppTheme.paddingMedium,
              tablet: AppTheme.paddingLarge,
            ),
          ),
          // Compte à rebours (sauf en mode Nuit où on peut afficher autre chose)
          if (!isNight) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getEventIcon(_nextEventName ?? ''),
                  color: AppColors.luxuryGold,
                  size: ResponsiveUtils.adaptiveIconSize(context, base: 20),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _getCountdownLabel(phase, _nextEventName),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 15,
                        tablet: 17,
                        desktop: 19,
                      ),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: ResponsiveUtils.adaptivePadding(
                context,
                mobile: AppTheme.paddingMedium,
                tablet: AppTheme.paddingLarge,
              ),
            ),
            Text(
              countdownText,
              style: TextStyle(
                fontSize: ResponsiveUtils.adaptiveFontSize(
                  context,
                  mobile: 52,
                  tablet: 68,
                  desktop: 84,
                ),
                fontWeight: FontWeight.w900,
                color: AppColors.luxuryGold,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: -2,
                shadows: [
                  Shadow(
                    color: AppColors.luxuryGold.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(
              height: ResponsiveUtils.adaptivePadding(
                context,
                mobile: AppTheme.paddingSmall,
                tablet: AppTheme.paddingMedium,
              ),
            ),
            Text(
              _getNextPrayerLabel(phase), // Prochaine prière
              style: TextStyle(
                fontSize: ResponsiveUtils.adaptiveFontSize(
                  context,
                  mobile: 12,
                  tablet: 13,
                  desktop: 14,
                ),
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.pureWhite.withOpacity(0.7)
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(
              context,
              mobile: AppTheme.paddingLarge,
              tablet: AppTheme.paddingXLarge,
            ),
          ),
          // Verset / invocation (phase-specific)
          if (_nextEventDua != null && !isNight)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: AppTheme.paddingMedium,
                ),
                vertical: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: AppTheme.paddingSmall,
                ),
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface.withOpacity(0.5)
                    : AppColors.pureWhite.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _nextEventDua!,
                style: TextStyle(
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 17,
                    tablet: 19,
                    desktop: 21,
                  ),
                  fontFamily: 'Cairo',
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          // Rappel doux Suhoor
          if (phase == RamadanPhase.suhoor) ...[
            SizedBox(
              height: ResponsiveUtils.adaptivePadding(
                context,
                mobile: AppTheme.paddingSmall,
                tablet: AppTheme.paddingMedium,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: AppTheme.paddingMedium,
                ),
                vertical: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 8,
                  tablet: 10,
                ),
              ),
              decoration: BoxDecoration(
                color: AppColors.luxuryGold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.luxuryGold.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.volunteer_activism,
                    color: AppColors.luxuryGold,
                    size: ResponsiveUtils.adaptiveIconSize(context, base: 18),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'N\'oublie pas l\'intention du jeûne',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 13,
                          tablet: 14,
                          desktop: 15,
                        ),
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.luxuryGold
                            : AppColors.deepBlue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Nuit : message de quiétude + countdown discret vers Suhoor demain
          if (isNight) ...[
            Text(
              'Repose-toi et reprends ta lecture quand tu le souhaites.',
              style: TextStyle(
                fontSize: ResponsiveUtils.adaptiveFontSize(
                  context,
                  mobile: 15,
                  tablet: 16,
                  desktop: 17,
                ),
                fontStyle: FontStyle.italic,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(
              height: ResponsiveUtils.adaptivePadding(
                context,
                mobile: AppTheme.paddingMedium,
                tablet: AppTheme.paddingLarge,
              ),
            ),
            Text(
              '$_nextEventName demain dans $countdownText',
              style: TextStyle(
                fontSize: ResponsiveUtils.adaptiveFontSize(
                  context,
                  mobile: 13,
                  tablet: 14,
                  desktop: 15,
                ),
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.pureWhite.withOpacity(0.6)
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getEventIcon(String eventName) {
    switch (eventName) {
      case 'Suhoor':
        return Icons.wb_twilight;
      case 'Imsak':
        return Icons.alarm;
      case 'Iftar':
        return Icons.restaurant;
      case 'Isha / Tarawih':
        return Icons.nightlight_round;
      default:
        return Icons.access_time;
    }
  }

  Widget _buildCountdownCardShimmer(bool isDark) {
    return Container(
      height: 200,
      padding: EdgeInsets.all(
        ResponsiveUtils.adaptivePadding(context, mobile: AppTheme.paddingLarge),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context),
        ),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  /// Carte "Reprise de la dernière lecture" (phase Nuit)
  Widget _buildLastReadingCard(bool isDark) {
    final lastReadSurahNumber = ref.watch(lastReadSurahProvider);
    final lastReadAyah = ref.watch(lastReadAyahProvider);
    final surahsAsync = ref.watch(surahsProvider);

    if (lastReadSurahNumber <= 0) {
      return const SizedBox.shrink();
    }

    return surahsAsync.when(
      data: (apiSurahs) {
        if (apiSurahs.isEmpty) return const SizedBox.shrink();
        final matches = apiSurahs
            .where((s) => s.number == lastReadSurahNumber)
            .toList();
        if (matches.isEmpty) return const SizedBox.shrink();
        final surahModel = matches.first;
        final surah = SurahAdapter.fromApiModel(surahModel);
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SurahDetailScreen(
                      surah: surah,
                      initialAyahNumber: lastReadAyah > 0 ? lastReadAyah : null,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.adaptiveBorderRadius(context) + 4,
              ),
              child: Container(
                padding: EdgeInsets.all(
                  ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingLarge,
                    tablet: AppTheme.paddingXLarge,
                  ),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.luxuryGold.withOpacity(0.12),
                      AppColors.luxuryGold.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.adaptiveBorderRadius(context) + 4,
                  ),
                  border: Border.all(
                    color: AppColors.luxuryGold.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        ResponsiveUtils.adaptivePadding(
                          context,
                          mobile: 12,
                          tablet: 14,
                        ),
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.menu_book,
                        color: isDark
                            ? AppColors.darkBackground
                            : AppColors.deepBlue,
                        size: ResponsiveUtils.adaptiveIconSize(
                          context,
                          base: 24,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: AppTheme.paddingMedium,
                        tablet: AppTheme.paddingLarge,
                      ),
                    ),
                    Expanded(
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
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            surah.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (lastReadAyah > 0)
                            Text(
                              'Ayah $lastReadAyah',
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: ResponsiveUtils.adaptiveIconSize(
                        context,
                        base: 18,
                      ),
                      color: AppColors.luxuryGold,
                    ),
                  ],
                ),
              ),
            ),
          );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Indicateur visuel discret "En jeûne" (phase journée)
  Widget _buildFastingDayIndicator(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.adaptivePadding(
          context,
          mobile: 10,
          tablet: 12,
        ),
        horizontal: ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingMedium,
          tablet: AppTheme.paddingLarge,
        ),
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withOpacity(0.6)
            : AppColors.paleGold.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.luxuryGold.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.self_improvement,
            size: ResponsiveUtils.adaptiveIconSize(context, base: 18),
            color: AppColors.luxuryGold.withOpacity(0.9),
          ),
          SizedBox(width: ResponsiveUtils.adaptivePadding(context, mobile: 8)),
          Expanded(
            child: Text(
            'En jeûne – Que la patience t’accompagne',
            style: TextStyle(
              fontSize: ResponsiveUtils.adaptiveFontSize(
                context,
                mobile: 13,
                tablet: 14,
                desktop: 15,
              ),
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTimeline(bool isDark, PrayerTimes prayerTimes) {
    final now = DateTime.now();
    final prayers = [
      {'name': 'Fajr', 'time': prayerTimes.fajr, 'icon': Icons.wb_twilight},
      {'name': 'Dhuhr', 'time': prayerTimes.dhuhr, 'icon': Icons.wb_sunny},
      {'name': 'Asr', 'time': prayerTimes.asr, 'icon': Icons.wb_twilight},
      {
        'name': 'Maghrib',
        'time': prayerTimes.maghrib,
        'icon': Icons.nightlight_round,
      },
      {
        'name': 'Isha',
        'time': prayerTimes.isha,
        'icon': Icons.nightlight_round,
      },
    ];

    return SizedBox(
      height: ResponsiveUtils.adaptivePadding(
        context,
        mobile: 105,
        tablet: 115,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.adaptivePadding(
            context,
            mobile: 4,
            tablet: 8,
          ),
        ),
        itemCount: prayers.length,
        separatorBuilder: (context, index) => SizedBox(
          width: ResponsiveUtils.adaptivePadding(
            context,
            mobile: AppTheme.paddingSmall,
            tablet: AppTheme.paddingMedium,
          ),
        ),
        itemBuilder: (context, index) {
          final prayer = prayers[index];
          final prayerTime = prayer['time'] as DateTime;
          final isPassed = now.isAfter(prayerTime);
          final isCurrent =
              now.isBefore(prayerTime) &&
              (index == 0 ||
                  now.isAfter(prayers[index - 1]['time'] as DateTime));
          final isNext =
              !isPassed &&
              !isCurrent &&
              (index == 0 ||
                  now.isAfter(prayers[index - 1]['time'] as DateTime));

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrayerTimesScreen(),
                  ),
                );
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                // Set reminder
              },
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: 90,
                  tablet: 110,
                ),
                height: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 8,
                    tablet: 10,
                  ),
                  vertical: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 8,
                    tablet: 10,
                  ),
                ),
                decoration: BoxDecoration(
                  gradient: isCurrent
                      ? LinearGradient(
                          colors: [
                            AppColors.luxuryGold.withOpacity(0.3),
                            AppColors.luxuryGold.withOpacity(0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : isNext
                      ? LinearGradient(
                          colors: [
                            AppColors.luxuryGold.withOpacity(0.15),
                            AppColors.luxuryGold.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isCurrent || isNext
                      ? null
                      : (isDark ? AppColors.darkCard : AppColors.pureWhite),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.luxuryGold
                        : isNext
                        ? AppColors.luxuryGold.withOpacity(0.6)
                        : (isDark
                              ? AppColors.darkTextSecondary.withOpacity(0.15)
                              : AppColors.textSecondary.withOpacity(0.08)),
                    width: isCurrent
                        ? 2.5
                        : isNext
                        ? 2
                        : 1,
                  ),
                  boxShadow: isCurrent || isNext
                      ? [
                          BoxShadow(
                            color: AppColors.luxuryGold.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                            spreadRadius: 2,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon with badge for current prayer
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            ResponsiveUtils.adaptivePadding(
                              context,
                              mobile: 7,
                              tablet: 9,
                            ),
                          ),
                          decoration: BoxDecoration(
                            gradient: isCurrent || isNext
                                ? LinearGradient(
                                    colors: [
                                      AppColors.luxuryGold.withOpacity(0.3),
                                      AppColors.luxuryGold.withOpacity(0.15),
                                    ],
                                  )
                                : null,
                            color: isCurrent || isNext
                                ? null
                                : (isDark
                                      ? AppColors.darkSurface
                                      : AppColors.pureWhite),
                            shape: BoxShape.circle,
                            boxShadow: isCurrent || isNext
                                ? [
                                    BoxShadow(
                                      color: AppColors.luxuryGold.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            prayer['icon'] as IconData,
                            color: isPassed
                                ? (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary)
                                : AppColors.luxuryGold,
                            size: ResponsiveUtils.adaptiveIconSize(
                              context,
                              base: 20,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.luxuryGold,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkCard
                                      : AppColors.pureWhite,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 5,
                        tablet: 6,
                      ),
                    ),
                    // Prayer name
                    Flexible(
                      flex: 1,
                      child: Text(
                        prayer['name'] as String,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.adaptiveFontSize(
                            context,
                            mobile: 11,
                            tablet: 12,
                          ),
                          fontWeight: isCurrent || isNext
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isPassed
                              ? (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary)
                              : (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary),
                          letterSpacing: 0.2,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 3,
                        tablet: 4,
                      ),
                    ),
                    // Time
                    Flexible(
                      flex: 1,
                      child: Text(
                        '${prayerTime.hour.toString().padLeft(2, '0')}:${prayerTime.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.adaptiveFontSize(
                            context,
                            mobile: 13,
                            tablet: 15,
                          ),
                          fontWeight: FontWeight.bold,
                          color: isPassed
                              ? (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary)
                              : AppColors.luxuryGold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrayerTimelineShimmer(bool isDark) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => Container(
          width: 100,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildRamadanProgressCard(bool isDark) {
    final hijriDate = HijriDateTime.now();
    final ramadanDay = hijriDate.month == 9 ? hijriDate.day : 0;
    final ramadanDays = hijriDate.month == 9 ? 30 : 0;
    final progress = ramadanDays > 0 ? ramadanDay / ramadanDays : 0.0;

    return Container(
      padding: EdgeInsets.all(
        ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingLarge,
          tablet: AppTheme.paddingXLarge,
        ),
      ),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                colors: [
                  AppColors.darkCard,
                  AppColors.darkCard.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  AppColors.pureWhite,
                  AppColors.paleGold.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context) + 2,
        ),
        boxShadow: AppColors.cardShadow,
        border: Border.all(
          color: isDark
              ? AppColors.darkTextSecondary.withOpacity(0.1)
              : AppColors.textSecondary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: AppColors.luxuryGold,
                      size: ResponsiveUtils.adaptiveIconSize(context, base: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Progression Ramadan',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingSmall,
                    tablet: AppTheme.paddingMedium,
                  ),
                  vertical: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 4,
                    tablet: 6,
                  ),
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.goldAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Jour $ramadanDay / $ramadanDays',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 13,
                      tablet: 14,
                      desktop: 15,
                    ),
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkBackground
                        : AppColors.deepBlue,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(
              context,
              mobile: AppTheme.paddingLarge,
              tablet: AppTheme.paddingXLarge,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark
                  ? AppColors.darkTextSecondary.withOpacity(0.2)
                  : AppColors.textSecondary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.luxuryGold),
              minHeight: ResponsiveUtils.adaptivePadding(
                context,
                mobile: 10,
                tablet: 12,
              ),
            ),
          ),
          SizedBox(
            height: ResponsiveUtils.adaptivePadding(
              context,
              mobile: AppTheme.paddingMedium,
              tablet: AppTheme.paddingLarge,
            ),
          ),
          Text(
            'Chaque jour compte',
            style: TextStyle(
              fontSize: ResponsiveUtils.adaptiveFontSize(
                context,
                mobile: 14,
                tablet: 15,
                desktop: 16,
              ),
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    final actions = [
      {
        'icon': Icons.menu_book,
        'label': 'Lire Quran',
        'color': AppColors.deepBlue,
        'onTap': () => _navigateToQuran(),
      },
      {
        'icon': Icons.notifications,
        'label': 'Rappels',
        'color': AppColors.info,
        'onTap': () => _navigateToSettings(),
      },
      {
        'icon': Icons.favorite,
        'label': 'Du\'a du jour',
        'color': AppColors.error,
        'onTap': () => _showComingSoon(),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingSmall,
          tablet: AppTheme.paddingMedium,
        ),
        mainAxisSpacing: ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingSmall,
          tablet: AppTheme.paddingMedium,
        ),
        childAspectRatio: ResponsiveUtils.isTablet(context) ? 1.15 : 1.1,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              (action['onTap'] as VoidCallback)();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (action['color'] as Color).withOpacity(0.1),
                    (action['color'] as Color).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (action['color'] as Color).withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (action['color'] as Color).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(
                  ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingSmall,
                    tablet: AppTheme.paddingMedium,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        ResponsiveUtils.adaptivePadding(
                          context,
                          mobile: 8,
                          tablet: 10,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: (action['color'] as Color).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        action['icon'] as IconData,
                        color: action['color'] as Color,
                        size: ResponsiveUtils.adaptiveIconSize(
                          context,
                          base: 26,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 6,
                        tablet: 8,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        action['label'] as String,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.adaptiveFontSize(
                            context,
                            mobile: 11,
                            tablet: 12,
                            desktop: 13,
                          ),
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpiritualContent(bool isDark) {
    return Container(
      padding: EdgeInsets.all(
        ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingLarge,
          tablet: AppTheme.paddingXLarge,
        ),
      ),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                colors: [
                  AppColors.darkCard,
                  AppColors.darkCard.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  AppColors.paleGold.withOpacity(0.8),
                  AppColors.pureWhite,
                  AppColors.paleGold.withOpacity(0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context) + 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.luxuryGold.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          ...AppColors.cardShadow,
        ],
        border: Border.all(
          color: AppColors.luxuryGold.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 8,
                    tablet: 10,
                  ),
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.goldAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.music_note,
                  color: isDark ? AppColors.darkBackground : AppColors.deepBlue,
                  size: ResponsiveUtils.adaptiveIconSize(context, base: 24),
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: AppTheme.paddingSmall,
                  tablet: AppTheme.paddingMedium,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xassida du jour',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cheikh Ahmadou Bamba',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 12,
                          tablet: 13,
                        ),
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
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
              mobile: AppTheme.paddingLarge,
              tablet: AppTheme.paddingXLarge,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    // Play audio
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Écouter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.luxuryGold,
                    foregroundColor: AppColors.pureWhite,
                    padding: EdgeInsets.symmetric(
                      vertical: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: AppTheme.paddingMedium,
                        tablet: AppTheme.paddingLarge,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: AppTheme.paddingSmall,
                  tablet: AppTheme.paddingMedium,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.luxuryGold.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    // Download for offline
                  },
                  color: AppColors.luxuryGold,
                  iconSize: ResponsiveUtils.adaptiveIconSize(context, base: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== CONTEXTUAL BANNER ZONE ====================

  Widget _buildContextualBannerZone(
    bool isDark,
    AsyncValue<PrayerTimes?> prayerTimesAsync,
  ) {
    final bannerAsync = ref.watch(contextualBannerProvider);

    return bannerAsync.when(
      data: (bannerKey) {
        if (bannerKey == null) {
          return const SizedBox.shrink();
        }

        return prayerTimesAsync.when(
          data: (prayerTimes) {
            if (prayerTimes == null) {
              return const SizedBox.shrink();
            }
            return _buildContextualBanner(isDark, bannerKey, prayerTimes);
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildContextualBanner(
    bool isDark,
    String bannerKey,
    PrayerTimes prayerTimes,
  ) {
    final now = DateTime.now();
    final rotationService = ref.read(contentRotationServiceProvider);
    final priority = rotationService.getBannerPriority(bannerKey);

    // Couleurs selon la priorité
    Color bannerColor;
    IconData bannerIcon;
    String bannerText;

    switch (bannerKey) {
      case 'iftar_countdown':
        final minutes = prayerTimes.maghrib.difference(now).inMinutes;
        bannerColor = AppColors.luxuryGold;
        bannerIcon = Icons.restaurant;
        bannerText = 'Prépare ton iftar – Maghrib dans $minutes minutes';
        break;

      case 'suhoor_reminder':
        final minutes = prayerTimes.imsak
            .subtract(const Duration(minutes: 30))
            .difference(now)
            .inMinutes;
        bannerColor = AppColors.info;
        bannerIcon = Icons.wb_twilight;
        bannerText = 'Rappel Suhoor dans $minutes minutes';
        break;

      case 'prayer_reminder':
        bannerColor = AppColors.deepBlue;
        bannerIcon = Icons.access_time;
        bannerText = 'La prière va bientôt commencer';
        break;

      case 'laylat_al_qadr':
        bannerColor = AppColors.luxuryGold;
        bannerIcon = Icons.star;
        bannerText = 'Nuit du Destin – Augmentez vos invocations';
        break;

      case 'zakat_reminder':
        bannerColor = AppColors.success;
        bannerIcon = Icons.account_balance_wallet;
        bannerText = 'N\'oubliez pas votre Zakat al-Fitr';
        break;

      case 'offline_suggestion':
        bannerColor = AppColors.warning;
        bannerIcon = Icons.download;
        bannerText = 'Téléchargez du contenu pour l\'offline';
        break;

      default:
        return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingLarge,
          tablet: AppTheme.paddingXLarge,
        ),
      ),
      padding: EdgeInsets.all(
        ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingMedium,
          tablet: AppTheme.paddingLarge,
        ),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bannerColor.withOpacity(
              priority == BannerPriority.critical ? 0.25 : 0.15,
            ),
            bannerColor.withOpacity(
              priority == BannerPriority.critical ? 0.15 : 0.08,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bannerColor.withOpacity(0.5),
          width: priority == BannerPriority.critical ? 2 : 1.5,
        ),
        boxShadow: priority == BannerPriority.critical
            ? [
                BoxShadow(
                  color: bannerColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            bannerIcon,
            color: bannerColor,
            size: ResponsiveUtils.adaptiveIconSize(context, base: 24),
          ),
          SizedBox(
            width: ResponsiveUtils.adaptivePadding(
              context,
              mobile: AppTheme.paddingSmall,
              tablet: AppTheme.paddingMedium,
            ),
          ),
          Expanded(
            child: Text(
              bannerText,
              style: TextStyle(
                fontSize: ResponsiveUtils.adaptiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
                fontWeight: priority == BannerPriority.critical
                    ? FontWeight.bold
                    : FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              HapticFeedback.lightImpact();
              final rotationService = ref.read(contentRotationServiceProvider);
              await rotationService.dismissBanner(bannerKey);
              // Refresh banner provider
              ref.invalidate(contextualBannerProvider);
            },
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
            iconSize: ResponsiveUtils.adaptiveIconSize(context, base: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _navigateToQuran() async {
    // Track Quran open behavior
    final behaviorService = ref.read(userBehaviorServiceProvider);
    final now = DateTime.now();

    // Determine prayer time context
    final prayerTimesAsync = ref.read(todayPrayerTimesProvider);
    String? prayerTime;
    prayerTimesAsync.whenData((prayerTimes) async {
      if (prayerTimes != null) {
        if (now.isBefore(prayerTimes.fajr.add(const Duration(hours: 2))) &&
            now.isAfter(prayerTimes.fajr.subtract(const Duration(hours: 1)))) {
          prayerTime = 'fajr';
        } else if (now.isBefore(
              prayerTimes.dhuhr.add(const Duration(hours: 2)),
            ) &&
            now.isAfter(prayerTimes.dhuhr.subtract(const Duration(hours: 1)))) {
          prayerTime = 'dhuhr';
        } else if (now.isBefore(
              prayerTimes.asr.add(const Duration(hours: 2)),
            ) &&
            now.isAfter(prayerTimes.asr.subtract(const Duration(hours: 1)))) {
          prayerTime = 'asr';
        } else if (now.isBefore(
              prayerTimes.maghrib.add(const Duration(hours: 1)),
            ) &&
            now.isAfter(
              prayerTimes.maghrib.subtract(const Duration(hours: 1)),
            )) {
          prayerTime = 'maghrib';
        } else if (now.isAfter(
          prayerTimes.isha.subtract(const Duration(hours: 1)),
        )) {
          prayerTime = 'isha';
        }
      }
    });

    await behaviorService.trackQuranOpen(
      timestamp: now,
      prayerTime: prayerTime,
    );

    final surahsAsync = ref.read(surahsProvider);
    surahsAsync.whenData((surahs) {
      if (surahs.isNotEmpty) {
        final firstSurah = SurahAdapter.fromApiModelList(surahs).first;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SurahDetailScreen(surah: firstSurah),
          ),
        );
      }
    });
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Bientôt disponible'),
        backgroundColor: AppColors.luxuryGold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==================== MOMENT OF THE DAY ====================

  Widget _buildMomentOfTheDay(bool isDark) {
    final highlightAsync = ref.watch(todayHighlightProvider);
    final duaAsync = ref.watch(duaOfTheDayProvider);

    return highlightAsync.when(
      data: (highlightType) {
        // Sélectionner le contenu selon le type déterminé par le moteur de rotation
        return _buildHighlightContent(isDark, highlightType, duaAsync);
      },
      loading: () => _buildMomentCardShimmer(isDark),
      error: (_, __) {
        // Fallback: utiliser Dua du jour par défaut
        return duaAsync.when(
          data: (dua) {
            final moment = {
              'type': 'Du\'a du jour',
              'icon': Icons.favorite,
              'arabic': dua.arabic,
              'content': dua.translation,
              'source': dua.source ?? 'Hadith',
              'reference': dua.reference,
              'duaModel': dua,
            };
            return _buildMomentCardFromData(isDark, moment);
          },
          loading: () => _buildMomentCardShimmer(isDark),
          error: (_, __) {
            // Fallback ultime: données locales
            final today = DateTime.now();
            final dayOfYear = today
                .difference(DateTime(today.year, 1, 1))
                .inDays;
            final momentType = (dayOfYear % 4);
            final moment = _getMomentOfDay(momentType);
            return _buildMomentCardFromData(isDark, moment);
          },
        );
      },
    );
  }

  /// Construire le contenu selon le type de highlight sélectionné
  Widget _buildHighlightContent(
    bool isDark,
    DailyHighlightType highlightType,
    AsyncValue duaAsync,
  ) {
    final rotationService = ref.read(contentRotationServiceProvider);
    final displayName = rotationService.getHighlightDisplayName(highlightType);
    final iconName = rotationService.getHighlightIcon(highlightType);

    // Mapper les icônes
    IconData icon;
    switch (iconName) {
      case 'favorite':
        icon = Icons.favorite;
        break;
      case 'menu_book':
        icon = Icons.menu_book;
        break;
      case 'music_note':
        icon = Icons.music_note;
        break;
      case 'record_voice_over':
        icon = Icons.record_voice_over;
        break;
      case 'lightbulb_outline':
        icon = Icons.lightbulb_outline;
        break;
      case 'format_quote':
        icon = Icons.format_quote;
        break;
      default:
        icon = Icons.favorite;
    }

    // Track view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(userBehaviorServiceProvider)
          .trackMomentOfDayView(momentType: displayName, interacted: false);
    });

    // Construire le contenu selon le type
    switch (highlightType) {
      case DailyHighlightType.dua:
        return duaAsync.when(
          data: (dua) {
            final moment = {
              'type': displayName,
              'icon': icon,
              'arabic': dua.arabic,
              'content': dua.translation,
              'source': dua.source ?? 'Hadith',
              'reference': dua.reference,
              'duaModel': dua,
            };
            return _buildMomentCardFromData(isDark, moment);
          },
          loading: () => _buildMomentCardShimmer(isDark),
          error: (_, __) => _buildFallbackMomentCard(isDark, displayName, icon),
        );

      case DailyHighlightType.ayah:
        // TODO: Intégrer Ayah API
        return _buildFallbackMomentCard(isDark, displayName, icon);

      case DailyHighlightType.xassida:
      case DailyHighlightType.khutba:
        // Audio content - utiliser le contenu spirituel existant
        // Pour l'instant, utiliser le même contenu spirituel
        return _buildSpiritualContent(isDark);

      case DailyHighlightType.ramadanFact:
        return _buildRamadanFactContent(isDark, displayName, icon);

      case DailyHighlightType.scholarQuote:
        return _buildScholarQuoteContent(isDark, displayName, icon);
    }
  }

  /// Carte de moment de fallback
  Widget _buildFallbackMomentCard(
    bool isDark,
    String displayName,
    IconData icon,
  ) {
    final today = DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;
    final momentType = (dayOfYear % 4);
    final moment = _getMomentOfDay(momentType);
    moment['type'] = displayName;
    moment['icon'] = icon;
    return _buildMomentCardFromData(isDark, moment);
  }

  Widget _buildMomentCardFromData(bool isDark, Map<String, dynamic> moment) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showMomentDetails(isDark, moment);
        },
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context) + 4,
        ),
        child: Container(
          padding: EdgeInsets.all(
            ResponsiveUtils.adaptivePadding(
              context,
              mobile: AppTheme.paddingLarge,
              tablet: AppTheme.paddingXLarge,
            ),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.luxuryGold.withOpacity(0.12),
                AppColors.luxuryGold.withOpacity(0.05),
                AppColors.paleGold.withOpacity(0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.adaptiveBorderRadius(context) + 4,
            ),
            border: Border.all(
              color: AppColors.luxuryGold.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.luxuryGold.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 8,
                        tablet: 10,
                      ),
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      moment['icon'] as IconData,
                      color: isDark
                          ? AppColors.darkBackground
                          : AppColors.deepBlue,
                      size: ResponsiveUtils.adaptiveIconSize(context, base: 22),
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: AppTheme.paddingSmall,
                      tablet: AppTheme.paddingMedium,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Moment du jour',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 12,
                              tablet: 13,
                            ),
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          moment['type'] as String,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.share_outlined,
                          size: ResponsiveUtils.adaptiveIconSize(
                            context,
                            base: 20,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _shareMoment(moment);
                        },
                        color: AppColors.luxuryGold,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      SizedBox(
                        width: ResponsiveUtils.adaptivePadding(
                          context,
                          mobile: AppTheme.paddingSmall,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.favorite_border,
                          size: ResponsiveUtils.adaptiveIconSize(
                            context,
                            base: 20,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _saveMomentToFavorites(moment);
                        },
                        color: AppColors.luxuryGold,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(
                height: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: AppTheme.paddingLarge,
                  tablet: AppTheme.paddingXLarge,
                ),
              ),
              // Arabic text if present
              if (moment['arabic'] != null)
                Text(
                  moment['arabic'] as String,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 22,
                      tablet: 24,
                      desktop: 26,
                    ),
                    fontFamily: 'Cairo',
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    height: 1.8,
                  ),
                  textAlign: TextAlign.right,
                ),
              if (moment['arabic'] != null)
                SizedBox(
                  height: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingMedium,
                    tablet: AppTheme.paddingLarge,
                  ),
                ),
              // Title if present (for Ramadan facts)
              if (moment['title'] != null) ...[
                Text(
                  moment['title'] as String,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 16,
                      tablet: 18,
                      desktop: 20,
                    ),
                    fontWeight: FontWeight.bold,
                    color: AppColors.luxuryGold,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(
                  height: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingSmall,
                    tablet: AppTheme.paddingMedium,
                  ),
                ),
              ],
              // Translation/Content
              Text(
                moment['content'] as String,
                style: TextStyle(
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 15,
                    tablet: 16,
                    desktop: 17,
                  ),
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                  height: 1.6,
                  fontStyle:
                      moment['type'] == 'Citation' ||
                          moment['type'] == 'Citation du jour'
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
              if (moment['source'] != null) ...[
                SizedBox(
                  height: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingMedium,
                    tablet: AppTheme.paddingLarge,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.verified,
                      size: ResponsiveUtils.adaptiveIconSize(context, base: 16),
                      color: AppColors.luxuryGold.withOpacity(0.8),
                    ),
                    SizedBox(
                      width: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 4,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        moment['source'] as String,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.adaptiveFontSize(
                            context,
                            mobile: 13,
                            tablet: 14,
                          ),
                          fontWeight: FontWeight.w600,
                          color: AppColors.luxuryGold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getMomentOfDay(int dayIndex) {
    // Rotate between different content types
    final moments = [
      // Duʿā of the day
      {
        'type': 'Du\'a du jour',
        'icon': Icons.favorite,
        'arabic':
            'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
        'content':
            'Seigneur ! Accorde-nous le bien ici-bas et le bien dans l\'au-delà, et préserve-nous du châtiment du Feu.',
        'source': 'Sourate Al-Baqarah, verset 201',
      },
      // Ayah of the day
      {
        'type': 'Ayah du jour',
        'icon': Icons.menu_book,
        'arabic':
            'وَمَا تَوْفِيقِي إِلَّا بِاللَّهِ عَلَيْهِ تَوَكَّلْتُ وَإِلَيْهِ أُنِيبُ',
        'content':
            'Ma réussite ne dépend que d\'Allah. C\'est en Lui que je place ma confiance et c\'est vers Lui que je reviens repentant.',
        'source': 'Sourate Houd, verset 88',
      },
      // Hadith
      {
        'type': 'Hadith du jour',
        'icon': Icons.lightbulb_outline,
        'arabic': 'مَنْ أَحَبَّ لِقَاءَ اللَّهِ أَحَبَّ اللَّهُ لِقَاءَهُ',
        'content': 'Celui qui aime rencontrer Allah, Allah aime le rencontrer.',
        'source': 'Sahih Al-Bukhari',
      },
      // Quote from local cheikh
      {
        'type': 'Citation',
        'icon': Icons.format_quote,
        'arabic': null,
        'content':
            'Le jeûne n\'est pas seulement s\'abstenir de manger et de boire. C\'est surtout s\'abstenir de tout ce qui peut souiller l\'âme.',
        'source': 'Cheikh Ahmadou Bamba',
      },
    ];

    return moments[dayIndex % moments.length];
  }

  void _showMomentDetails(bool isDark, Map<String, dynamic> moment) {
    // Track interaction
    ref
        .read(userBehaviorServiceProvider)
        .trackMomentOfDayView(
          momentType: moment['type'] as String,
          interacted: true,
        );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.pureWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(
          ResponsiveUtils.adaptivePadding(
            context,
            mobile: AppTheme.paddingLarge,
            tablet: AppTheme.paddingXLarge,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(
                    bottom: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: AppTheme.paddingMedium,
                      tablet: AppTheme.paddingLarge,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkTextSecondary.withOpacity(0.3)
                        : AppColors.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 10,
                        tablet: 12,
                      ),
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      moment['icon'] as IconData,
                      color: isDark
                          ? AppColors.darkBackground
                          : AppColors.deepBlue,
                      size: ResponsiveUtils.adaptiveIconSize(context, base: 24),
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: AppTheme.paddingMedium,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Moment du jour',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 13,
                              tablet: 14,
                            ),
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          moment['type'] as String,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ],
              ),
              SizedBox(
                height: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: AppTheme.paddingXLarge,
                  tablet: AppTheme.paddingXLarge * 1.5,
                ),
              ),
              // Arabic text
              if (moment['arabic'] != null)
                Text(
                  moment['arabic'] as String,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 26,
                      tablet: 30,
                      desktop: 34,
                    ),
                    fontFamily: 'Cairo',
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    height: 2.0,
                  ),
                  textAlign: TextAlign.right,
                ),
              if (moment['arabic'] != null)
                SizedBox(
                  height: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingXLarge,
                    tablet: AppTheme.paddingXLarge * 1.5,
                  ),
                ),
              // Content
              Text(
                moment['content'] as String,
                style: TextStyle(
                  fontSize: ResponsiveUtils.adaptiveFontSize(
                    context,
                    mobile: 17,
                    tablet: 19,
                    desktop: 21,
                  ),
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                  height: 1.7,
                  fontStyle: moment['type'] == 'Citation'
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
              if (moment['source'] != null) ...[
                SizedBox(
                  height: ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingXLarge,
                    tablet: AppTheme.paddingXLarge * 1.5,
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(
                    ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: AppTheme.paddingMedium,
                      tablet: AppTheme.paddingLarge,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.luxuryGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.luxuryGold.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified,
                        size: ResponsiveUtils.adaptiveIconSize(
                          context,
                          base: 18,
                        ),
                        color: AppColors.luxuryGold,
                      ),
                      SizedBox(
                        width: ResponsiveUtils.adaptivePadding(
                          context,
                          mobile: AppTheme.paddingSmall,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          moment['source'] as String,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.adaptiveFontSize(
                              context,
                              mobile: 14,
                              tablet: 15,
                            ),
                            fontWeight: FontWeight.w600,
                            color: AppColors.luxuryGold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(
                height: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: AppTheme.paddingXLarge,
                  tablet: AppTheme.paddingXLarge * 1.5,
                ),
              ),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _shareMoment(moment);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Partager'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.luxuryGold,
                        foregroundColor: AppColors.pureWhite,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: AppTheme.paddingMedium,
                            tablet: AppTheme.paddingLarge,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.adaptivePadding(
                      context,
                      mobile: AppTheme.paddingMedium,
                    ),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _saveMomentToFavorites(moment);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.favorite),
                      label: const Text('Sauvegarder'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.luxuryGold,
                        side: BorderSide(color: AppColors.luxuryGold, width: 2),
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.adaptivePadding(
                            context,
                            mobile: AppTheme.paddingMedium,
                            tablet: AppTheme.paddingLarge,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: AppTheme.paddingLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareMoment(Map<String, dynamic> moment) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Partager: ${moment['type']}'),
        backgroundColor: AppColors.luxuryGold,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _saveMomentToFavorites(Map<String, dynamic> moment) {
    // TODO: Implement save to favorites functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${moment['type']} sauvegardé'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================== CONTEXTUAL SUGGESTIONS ====================

  Widget _buildContextualQuranSuggestion(bool isDark, String prayerTime) {
    final prayerNames = {
      'fajr': 'Fajr',
      'dhuhr': 'Dhuhr',
      'asr': 'Asr',
      'maghrib': 'Maghrib',
      'isha': 'Isha',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _navigateToQuran();
        },
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context) + 4,
        ),
        child: Container(
          padding: EdgeInsets.all(
            ResponsiveUtils.adaptivePadding(
              context,
              mobile: AppTheme.paddingLarge,
              tablet: AppTheme.paddingXLarge,
            ),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.luxuryGold.withOpacity(0.15),
                AppColors.luxuryGold.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.adaptiveBorderRadius(context) + 4,
            ),
            border: Border.all(
              color: AppColors.luxuryGold.withOpacity(0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.luxuryGold.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: 10,
                    tablet: 12,
                  ),
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.goldAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.menu_book,
                  color: isDark ? AppColors.darkBackground : AppColors.deepBlue,
                  size: ResponsiveUtils.adaptiveIconSize(context, base: 24),
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: AppTheme.paddingMedium,
                  tablet: AppTheme.paddingLarge,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Moment idéal pour la lecture',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 12,
                          tablet: 13,
                        ),
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 4,
                        tablet: 6,
                      ),
                    ),
                    Text(
                      'Après ${prayerNames[prayerTime]}, c\'est votre moment préféré pour lire le Quran',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: ResponsiveUtils.adaptiveIconSize(context, base: 18),
                color: AppColors.luxuryGold,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMomentCardShimmer(bool isDark) {
    return Container(
      padding: EdgeInsets.all(
        ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingLarge,
          tablet: AppTheme.paddingXLarge,
        ),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.luxuryGold.withOpacity(0.12),
            AppColors.luxuryGold.withOpacity(0.05),
            AppColors.paleGold.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.adaptiveBorderRadius(context) + 4,
        ),
        border: Border.all(
          color: AppColors.luxuryGold.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  // ==================== RAMADAN CONTENT BUILDERS ====================

  Widget _buildRamadanFactContent(
    bool isDark,
    String displayName,
    IconData icon,
  ) {
    final factAsync = ref.watch(ramadanFactOfTheDayProvider);

    return factAsync.when(
      data: (fact) {
        final moment = {
          'type': displayName,
          'icon': icon,
          'arabic': null,
          'content': fact['content'] as String,
          'source': fact['source'] as String,
          'title': fact['title'] as String?,
        };
        return _buildMomentCardFromData(isDark, moment);
      },
      loading: () => _buildMomentCardShimmer(isDark),
      error: (_, __) => _buildFallbackMomentCard(isDark, displayName, icon),
    );
  }

  Widget _buildScholarQuoteContent(
    bool isDark,
    String displayName,
    IconData icon,
  ) {
    final quoteAsync = ref.watch(scholarQuoteOfTheDayProvider);

    return quoteAsync.when(
      data: (quote) {
        final moment = {
          'type': displayName,
          'icon': icon,
          'arabic': null,
          'content': quote['content'] as String,
          'source':
              '${quote['author'] as String} - ${quote['source'] as String}',
          'title': null,
        };
        return _buildMomentCardFromData(isDark, moment);
      },
      loading: () => _buildMomentCardShimmer(isDark),
      error: (_, __) => _buildFallbackMomentCard(isDark, displayName, icon),
    );
  }
}
