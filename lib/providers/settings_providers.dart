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
