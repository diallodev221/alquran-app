import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

/// Provider pour le service de paramètres (singleton)
final settingsServiceProvider = Provider<SettingsService>((ref) {
  final service = SettingsService();
  service.init(); // Initialiser automatiquement
  return service;
});

/// Provider pour la lecture automatique
final autoPlayNextProvider = StateNotifierProvider<AutoPlayNotifier, bool>((
  ref,
) {
  final service = ref.watch(settingsServiceProvider);
  return AutoPlayNotifier(service);
});

class AutoPlayNotifier extends StateNotifier<bool> {
  final SettingsService _service;

  AutoPlayNotifier(this._service) : super(true) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.getAutoPlayNext();
  }

  Future<void> toggle(bool value) async {
    await _service.setAutoPlayNext(value);
    state = value;
  }
}

/// Provider pour l'affichage par défaut de la traduction
final showTranslationDefaultProvider =
    StateNotifierProvider<ShowTranslationNotifier, bool>((ref) {
      final service = ref.watch(settingsServiceProvider);
      return ShowTranslationNotifier(service);
    });

class ShowTranslationNotifier extends StateNotifier<bool> {
  final SettingsService _service;

  ShowTranslationNotifier(this._service) : super(true) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.getShowTranslationDefault();
  }

  Future<void> toggle(bool value) async {
    await _service.setShowTranslationDefault(value);
    state = value;
  }
}

/// Provider pour la taille de police arabe
final arabicFontSizeProvider =
    StateNotifierProvider<ArabicFontSizeNotifier, double>((ref) {
      final service = ref.watch(settingsServiceProvider);
      return ArabicFontSizeNotifier(service);
    });

class ArabicFontSizeNotifier extends StateNotifier<double> {
  final SettingsService _service;

  ArabicFontSizeNotifier(this._service) : super(28.0) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.getArabicFontSize();
  }

  Future<void> updateSize(double value) async {
    await _service.setArabicFontSize(value);
    state = value;
  }
}

/// Provider pour le script/font family arabe
final arabicScriptProvider =
    StateNotifierProvider<ArabicScriptNotifier, String>((ref) {
      final service = ref.watch(settingsServiceProvider);
      return ArabicScriptNotifier(service);
    });

class ArabicScriptNotifier extends StateNotifier<String> {
  final SettingsService _service;

  ArabicScriptNotifier(this._service) : super('quran-madinah') {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.getArabicScript();
  }

  Future<void> updateScript(String value) async {
    await _service.setArabicScript(value);
    state = value;
  }
}

/// Provider pour la vitesse de lecture
final playbackSpeedProvider =
    StateNotifierProvider<PlaybackSpeedNotifier, double>((ref) {
      final service = ref.watch(settingsServiceProvider);
      return PlaybackSpeedNotifier(service);
    });

class PlaybackSpeedNotifier extends StateNotifier<double> {
  final SettingsService _service;

  PlaybackSpeedNotifier(this._service) : super(1.0) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.getPlaybackSpeed();
  }

  Future<void> updateSpeed(double value) async {
    await _service.setPlaybackSpeed(value);
    state = value;
  }
}

/// Provider pour le récitateur sélectionné avec persistance
final selectedReciterPersistentProvider =
    StateNotifierProvider<SelectedReciterNotifier, String>((ref) {
      final service = ref.watch(settingsServiceProvider);
      return SelectedReciterNotifier(service);
    });

class SelectedReciterNotifier extends StateNotifier<String> {
  final SettingsService _service;

  SelectedReciterNotifier(this._service) : super('ar.alafasy') {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.getSelectedReciter();
  }

  Future<void> setReciter(String value) async {
    await _service.setSelectedReciter(value);
    state = value;
  }
}

/// Provider pour le mode de thème
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  final service = ref.watch(settingsServiceProvider);
  return ThemeModeNotifier(service);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SettingsService _service;

  ThemeModeNotifier(this._service) : super(ThemeMode.system) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final modeInt = await _service.getThemeMode();
    state = _intToThemeMode(modeInt);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _service.setThemeMode(_themeModeToInt(mode));
    state = mode;
  }

  ThemeMode _intToThemeMode(int value) {
    switch (value) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  int _themeModeToInt(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 1;
      case ThemeMode.dark:
        return 2;
      default:
        return 0;
    }
  }
}

/// Provider pour le mode de lecture
final readingModeProvider = StateNotifierProvider<ReadingModeNotifier, String>((
  ref,
) {
  final service = ref.watch(settingsServiceProvider);
  return ReadingModeNotifier(service);
});

class ReadingModeNotifier extends StateNotifier<String> {
  final SettingsService _service;

  ReadingModeNotifier(this._service) : super('page') {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.getReadingMode();
  }

  Future<void> setReadingMode(String value) async {
    await _service.setReadingMode(value);
    state = value;
  }
}

/// Provider pour les couleurs Tajweed
final tajweedColorsProvider =
    StateNotifierProvider<TajweedColorsNotifier, bool>((ref) {
      final service = ref.watch(settingsServiceProvider);
      return TajweedColorsNotifier(service);
    });

class TajweedColorsNotifier extends StateNotifier<bool> {
  final SettingsService _service;

  TajweedColorsNotifier(this._service) : super(false) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.getTajweedColors();
  }

  Future<void> toggle(bool value) async {
    await _service.setTajweedColors(value);
    state = value;
  }
}

/// Provider pour l'édition de traduction
final translationEditionProvider =
    StateNotifierProvider<TranslationEditionNotifier, String>((ref) {
      final service = ref.watch(settingsServiceProvider);
      return TranslationEditionNotifier(service);
    });

class TranslationEditionNotifier extends StateNotifier<String> {
  final SettingsService _service;

  TranslationEditionNotifier(this._service) : super('fr.hamidullah') {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.getTranslationEdition();
  }

  Future<void> setTranslationEdition(String value) async {
    await _service.setTranslationEdition(value);
    state = value;
  }
}

/// Provider pour la répétition
final repetitionProvider = StateNotifierProvider<RepetitionNotifier, String>((
  ref,
) {
  final service = ref.watch(settingsServiceProvider);
  return RepetitionNotifier(service);
});

class RepetitionNotifier extends StateNotifier<String> {
  final SettingsService _service;

  RepetitionNotifier(this._service) : super('never') {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.getRepetition();
  }

  Future<void> setRepetition(String value) async {
    await _service.setRepetition(value);
    state = value;
  }
}

/// Marques de waqf Tanzil (pause marks) — remplace le highlight ayah.
final pauseMarksTanzilProvider =
    StateNotifierProvider<PauseMarksTanzilNotifier, bool>((ref) {
      final service = ref.watch(settingsServiceProvider);
      return PauseMarksTanzilNotifier(service);
    });

class PauseMarksTanzilNotifier extends StateNotifier<bool> {
  final SettingsService _service;

  PauseMarksTanzilNotifier(this._service) : super(true) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.getPauseMarksTanzil();
  }

  Future<void> toggle(bool value) async {
    await _service.setPauseMarksTanzil(value);
    state = value;
  }
}

/// Provider pour le rappel suhoor
final suhoorReminderProvider =
    StateNotifierProvider<SuhoorReminderNotifier, bool>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return SuhoorReminderNotifier(service);
});

class SuhoorReminderNotifier extends StateNotifier<bool> {
  final SettingsService _service;

  SuhoorReminderNotifier(this._service) : super(false) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.isSuhoorReminderEnabled();
  }

  Future<void> toggle(bool value) async {
    await _service.setSuhoorReminderEnabled(value);
    state = value;
  }
}

/// Provider pour les minutes de rappel suhoor
final suhoorReminderMinutesProvider =
    StateNotifierProvider<SuhoorReminderMinutesNotifier, int>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return SuhoorReminderMinutesNotifier(service);
});

class SuhoorReminderMinutesNotifier extends StateNotifier<int> {
  final SettingsService _service;

  SuhoorReminderMinutesNotifier(this._service) : super(30) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.getSuhoorReminderMinutes();
  }

  Future<void> setMinutes(int minutes) async {
    await _service.setSuhoorReminderMinutes(minutes);
    state = minutes;
  }
}

/// Provider pour le rappel iftar
final iftarReminderProvider =
    StateNotifierProvider<IftarReminderNotifier, bool>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return IftarReminderNotifier(service);
});

class IftarReminderNotifier extends StateNotifier<bool> {
  final SettingsService _service;

  IftarReminderNotifier(this._service) : super(false) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.isIftarReminderEnabled();
  }

  Future<void> toggle(bool value) async {
    await _service.setIftarReminderEnabled(value);
    state = value;
  }
}

/// Provider pour le mode silencieux pendant la prière
final silentModeDuringPrayerProvider =
    StateNotifierProvider<SilentModeDuringPrayerNotifier, bool>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return SilentModeDuringPrayerNotifier(service);
});

class SilentModeDuringPrayerNotifier extends StateNotifier<bool> {
  final SettingsService _service;

  SilentModeDuringPrayerNotifier(this._service) : super(false) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.isSilentModeDuringPrayerEnabled();
  }

  Future<void> toggle(bool value) async {
    await _service.setSilentModeDuringPrayerEnabled(value);
    state = value;
  }
}

/// Provider pour les notifications adaptatives
final adaptiveNotificationsProvider =
    StateNotifierProvider<AdaptiveNotificationsNotifier, bool>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return AdaptiveNotificationsNotifier(service);
});

class AdaptiveNotificationsNotifier extends StateNotifier<bool> {
  final SettingsService _service;

  AdaptiveNotificationsNotifier(this._service) : super(true) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _service.isAdaptiveNotificationsEnabled();
  }

  Future<void> toggle(bool value) async {
    await _service.setAdaptiveNotificationsEnabled(value);
    state = value;
  }
}
