import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri_date_time/hijri_date_time.dart';
import '../services/content_rotation_service.dart';
import 'prayer_times_providers.dart';
import 'personalization_providers.dart';

/// Provider pour le service de rotation de contenu
final contentRotationServiceProvider = Provider<ContentRotationService>((ref) {
  return ContentRotationService();
});

/// Provider pour le highlight du jour
final todayHighlightProvider = FutureProvider<DailyHighlightType>((ref) async {
  final service = ref.watch(contentRotationServiceProvider);
  final hijriDate = HijriDateTime.now();
  final now = DateTime.now();

  final phase = service.getRamadanPhase(hijriDate);
  final window = service.getTimeWindow(now);

  // Obtenir l'affinité utilisateur (audio vs text)
  final behaviorService = ref.watch(userBehaviorServiceProvider);
  final preferredAudio = await behaviorService.getMostPlayedAudioType(days: 7);
  final userAffinity = preferredAudio == 'xassida' || preferredAudio == 'khutba' 
      ? 'audio' 
      : 'text';

  return await service.getTodayHighlight(
    phase: phase,
    window: window,
    userAffinity: userAffinity,
  );
});

/// Provider pour la bannière contextuelle
final contextualBannerProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(contentRotationServiceProvider);
  final now = DateTime.now();

  // Obtenir les horaires de prière
  final prayerTimesAsync = await ref.read(todayPrayerTimesProvider.future);
  final prayerTimes = prayerTimesAsync;

  if (prayerTimes == null) {
    return null;
  }

  final hijriDate = HijriDateTime.now();
  final ramadanDay = hijriDate.month == 9 ? hijriDate.day : null;

  // Calculer les prochains événements
  DateTime? nextIftar;
  DateTime? nextSuhoor;
  DateTime? nextPrayer;

  if (now.isBefore(prayerTimes.maghrib)) {
    nextIftar = prayerTimes.maghrib;
  }

  if (now.isBefore(prayerTimes.imsak)) {
    nextSuhoor = prayerTimes.imsak.subtract(const Duration(minutes: 30));
  } else if (now.isBefore(prayerTimes.fajr)) {
    nextSuhoor = prayerTimes.imsak.add(const Duration(days: 1)).subtract(const Duration(minutes: 30));
  }

  // Prochaine prière
  if (now.isBefore(prayerTimes.fajr)) {
    nextPrayer = prayerTimes.fajr;
  } else if (now.isBefore(prayerTimes.dhuhr)) {
    nextPrayer = prayerTimes.dhuhr;
  } else if (now.isBefore(prayerTimes.asr)) {
    nextPrayer = prayerTimes.asr;
  } else if (now.isBefore(prayerTimes.maghrib)) {
    nextPrayer = prayerTimes.maghrib;
  } else if (now.isBefore(prayerTimes.isha)) {
    nextPrayer = prayerTimes.isha;
  } else {
    nextPrayer = prayerTimes.fajr.add(const Duration(days: 1));
  }

  return await service.getContextualBanner(
    now: now,
    hasPrayerTimes: true,
    nextIftar: nextIftar,
    nextSuhoor: nextSuhoor,
    nextPrayer: nextPrayer,
    hasOfflineContent: false, // TODO: Vérifier le contenu offline
    ramadanDay: ramadanDay,
    reminderEnabled: null, // TODO: Vérifier les paramètres
  );
});
