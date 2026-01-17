import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/prayer_times_service.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import 'settings_providers.dart';

/// Provider pour le service de prières (singleton)
final prayerTimesServiceProvider = Provider<PrayerTimesService>((ref) {
  return PrayerTimesService();
});

/// Provider pour le service de localisation (singleton)
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Provider pour la localisation actuelle
final currentLocationProvider = FutureProvider<LocationData?>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return await locationService.getCurrentLocation();
});

/// Provider pour la méthode de calcul sélectionnée
final calculationMethodProvider =
    StateNotifierProvider<CalculationMethodNotifier, CalculationMethod>((ref) {
      final service = ref.watch(settingsServiceProvider);
      return CalculationMethodNotifier(service);
    });

class CalculationMethodNotifier extends StateNotifier<CalculationMethod> {
  final SettingsService _service;

  CalculationMethodNotifier(this._service)
    : super(CalculationMethod.muslimWorldLeague) {
    _loadMethod();
  }

  Future<void> _loadMethod() async {
    final methodIndex = await _service.getCalculationMethod();
    if (methodIndex != null) {
      state = CalculationMethod.values[methodIndex];
    }
  }

  Future<void> setMethod(CalculationMethod method) async {
    state = method;
    await _service.setCalculationMethod(method.index);
  }
}

/// Provider pour les horaires de prière du jour
final todayPrayerTimesProvider = FutureProvider<PrayerTimes?>((ref) async {
  final location = await ref.watch(currentLocationProvider.future);
  if (location == null) return null;

  final method = ref.watch(calculationMethodProvider);
  final service = ref.watch(prayerTimesServiceProvider);

  return service.calculatePrayerTimes(
    date: DateTime.now(),
    location: location,
    method: method,
  );
});

/// Provider pour les prières récitées aujourd'hui
final todayPrayedPrayersProvider = FutureProvider<Set<String>>((ref) async {
  final settingsService = ref.watch(settingsServiceProvider);
  return await settingsService.getPrayedPrayers(DateTime.now());
});

/// Provider pour le nombre de prières récitées aujourd'hui
final todayPrayedCountProvider = FutureProvider<int>((ref) async {
  final settingsService = ref.watch(settingsServiceProvider);
  return await settingsService.getPrayedPrayersCount(DateTime.now());
});

/// Provider pour les états de notification Adhan
final adhanStatesProvider = FutureProvider<Map<String, bool>>((ref) async {
  final settingsService = ref.watch(settingsServiceProvider);
  return await settingsService.getAllAdhanStates();
});

/// Provider pour l'Adhan sélectionné
final selectedAdhanProvider =
    StateNotifierProvider<SelectedAdhanNotifier, String>((ref) {
      final service = ref.watch(settingsServiceProvider);
      return SelectedAdhanNotifier(service);
    });

class SelectedAdhanNotifier extends StateNotifier<String> {
  final SettingsService _service;

  SelectedAdhanNotifier(this._service) : super('classic') {
    _loadAdhan();
  }

  Future<void> _loadAdhan() async {
    state = await _service.getSelectedAdhan();
  }

  Future<void> setAdhan(String adhanName) async {
    state = adhanName;
    await _service.setSelectedAdhan(adhanName);
  }
}
