import 'package:hive/hive.dart';

/// Service pour gérer les paramètres de l'application
class SettingsService {
  static const String _boxName = 'settings';
  static const String _autoPlayKey = 'auto_play_next';
  static const String _showTranslationKey = 'show_translation_default';
  static const String _arabicFontSizeKey = 'arabic_font_size';
  static const String _playbackSpeedKey = 'playback_speed';
  static const String _selectedReciterKey = 'selected_reciter';

  Box<dynamic>? _box;

  /// Initialiser le service
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Obtenir la box (avec initialisation automatique si nécessaire)
  Future<Box<dynamic>> _getBox() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    return _box!;
  }

  // ==================== LECTURE AUTOMATIQUE ====================

  /// Obtenir l'état de la lecture automatique
  Future<bool> getAutoPlayNext() async {
    final box = await _getBox();
    return box.get(_autoPlayKey, defaultValue: true) as bool;
  }

  /// Définir l'état de la lecture automatique
  Future<void> setAutoPlayNext(bool value) async {
    final box = await _getBox();
    await box.put(_autoPlayKey, value);
  }

  // ==================== TRADUCTION ====================

  /// Obtenir l'affichage par défaut de la traduction
  Future<bool> getShowTranslationDefault() async {
    final box = await _getBox();
    return box.get(_showTranslationKey, defaultValue: true) as bool;
  }

  /// Définir l'affichage par défaut de la traduction
  Future<void> setShowTranslationDefault(bool value) async {
    final box = await _getBox();
    await box.put(_showTranslationKey, value);
  }

  // ==================== TAILLE DE POLICE ====================

  /// Obtenir la taille de police arabe
  Future<double> getArabicFontSize() async {
    final box = await _getBox();
    return box.get(_arabicFontSizeKey, defaultValue: 28.0) as double;
  }

  /// Définir la taille de police arabe
  Future<void> setArabicFontSize(double value) async {
    final box = await _getBox();
    await box.put(_arabicFontSizeKey, value);
  }

  // ==================== VITESSE DE LECTURE ====================

  /// Obtenir la vitesse de lecture
  Future<double> getPlaybackSpeed() async {
    final box = await _getBox();
    return box.get(_playbackSpeedKey, defaultValue: 1.0) as double;
  }

  /// Définir la vitesse de lecture
  Future<void> setPlaybackSpeed(double value) async {
    final box = await _getBox();
    await box.put(_playbackSpeedKey, value);
  }

  // ==================== RÉCITATEUR ====================

  /// Obtenir le récitateur sélectionné
  Future<String> getSelectedReciter() async {
    final box = await _getBox();
    return box.get(_selectedReciterKey, defaultValue: 'ar.alafasy') as String;
  }

  /// Définir le récitateur sélectionné
  Future<void> setSelectedReciter(String value) async {
    final box = await _getBox();
    await box.put(_selectedReciterKey, value);
  }

  // ==================== GESTION GLOBALE ====================

  /// Réinitialiser tous les paramètres
  Future<void> resetAllSettings() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Fermer le service
  Future<void> close() async {
    await _box?.close();
  }
}
