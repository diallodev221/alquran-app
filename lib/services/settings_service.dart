import 'package:hive/hive.dart';

/// Service pour gérer les paramètres de l'application
class SettingsService {
  static const String _boxName = 'settings';
  static const String _autoPlayKey = 'auto_play_next';
  static const String _showTranslationKey = 'show_translation_default';
  static const String _arabicFontSizeKey = 'arabic_font_size';
  static const String _arabicScriptKey = 'arabic_script';
  static const String _playbackSpeedKey = 'playback_speed';
  static const String _selectedReciterKey = 'selected_reciter';
  static const String _themeModeKey = 'theme_mode';
  static const String _readingModeKey = 'reading_mode';
  static const String _tajweedColorsKey = 'tajweed_colors';
  static const String _translationEditionKey = 'translation_edition';
  static const String _repetitionKey = 'repetition';
  static const String _highlightAyahKey = 'highlight_ayah';
  static const String _calculationMethodKey = 'calculation_method';
  static const String _prayedPrayersKey = 'prayed_prayers'; // Format: "date:prayer1,prayer2,..."
  static const String _adhanEnabledKey = 'adhan_enabled'; // Format: "prayerName:true/false"
  static const String _selectedAdhanKey = 'selected_adhan';
  static const String _suhoorReminderKey = 'suhoor_reminder';
  static const String _suhoorReminderMinutesKey = 'suhoor_reminder_minutes';
  static const String _iftarReminderKey = 'iftar_reminder';
  static const String _silentModeDuringPrayerKey = 'silent_mode_during_prayer';
  static const String _adaptiveNotificationsKey = 'adaptive_notifications';
  static const String _lastReadSurahKey = 'last_read_surah';
  static const String _lastReadAyahKey = 'last_read_ayah';

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

  // ==================== SCRIPT ARABE ====================

  /// Obtenir le script/édition arabe
  Future<String> getArabicScript() async {
    final box = await _getBox();
    return box.get(_arabicScriptKey, defaultValue: 'quran-madinah') as String;
  }

  /// Définir le script/font family arabe
  Future<void> setArabicScript(String value) async {
    final box = await _getBox();
    await box.put(_arabicScriptKey, value);
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

  // ==================== THÈME ====================

  /// Obtenir le mode de thème (0=System, 1=Light, 2=Dark)
  Future<int> getThemeMode() async {
    final box = await _getBox();
    return box.get(_themeModeKey, defaultValue: 0) as int;
  }

  /// Définir le mode de thème (0=System, 1=Light, 2=Dark)
  Future<void> setThemeMode(int value) async {
    final box = await _getBox();
    await box.put(_themeModeKey, value);
  }

  // ==================== MODE DE LECTURE ====================

  /// Obtenir le mode de lecture ('list' ou 'page')
  Future<String> getReadingMode() async {
    final box = await _getBox();
    return box.get(_readingModeKey, defaultValue: 'page') as String;
  }

  /// Définir le mode de lecture ('list' ou 'page')
  Future<void> setReadingMode(String value) async {
    final box = await _getBox();
    await box.put(_readingModeKey, value);
  }

  // ==================== COULEURS TAJWEED ====================

  /// Obtenir l'état des couleurs Tajweed
  Future<bool> getTajweedColors() async {
    final box = await _getBox();
    return box.get(_tajweedColorsKey, defaultValue: false) as bool;
  }

  /// Définir l'état des couleurs Tajweed
  Future<void> setTajweedColors(bool value) async {
    final box = await _getBox();
    await box.put(_tajweedColorsKey, value);
  }

  // ==================== ÉDITION DE TRADUCTION ====================

  /// Obtenir l'édition de traduction sélectionnée
  Future<String> getTranslationEdition() async {
    final box = await _getBox();
    return box.get(_translationEditionKey, defaultValue: 'fr.hamidullah')
        as String;
  }

  /// Définir l'édition de traduction sélectionnée
  Future<void> setTranslationEdition(String value) async {
    final box = await _getBox();
    await box.put(_translationEditionKey, value);
  }

  // ==================== RÉPÉTITION ====================

  /// Obtenir le mode de répétition ('never', 'once', 'twice', 'thrice', 'infinite')
  Future<String> getRepetition() async {
    final box = await _getBox();
    return box.get(_repetitionKey, defaultValue: 'never') as String;
  }

  /// Définir le mode de répétition
  Future<void> setRepetition(String value) async {
    final box = await _getBox();
    await box.put(_repetitionKey, value);
  }

  // ==================== MARQUES DE WAQF (TANZIL) ====================

  /// Afficher les marques de waqf (pause marks) à la manière Tanzil (petit, distinct).
  /// Remplace l’ancien « highlight ayah » : guide la récitation par les signes م، لا، ج، etc.
  Future<bool> getPauseMarksTanzil() async {
    final box = await _getBox();
    return box.get(_highlightAyahKey, defaultValue: true) as bool;
  }

  Future<void> setPauseMarksTanzil(bool value) async {
    final box = await _getBox();
    await box.put(_highlightAyahKey, value);
  }

  // ==================== MÉTHODE DE CALCUL DES PRIÈRES ====================

  /// Obtenir la méthode de calcul des prières
  Future<int?> getCalculationMethod() async {
    final box = await _getBox();
    return box.get(_calculationMethodKey) as int?;
  }

  /// Définir la méthode de calcul des prières
  Future<void> setCalculationMethod(int methodIndex) async {
    final box = await _getBox();
    await box.put(_calculationMethodKey, methodIndex);
  }

  // ==================== PRIÈRES RÉCITÉES ====================

  /// Obtenir la clé pour une date donnée
  String _getPrayedPrayersKey(DateTime date) {
    final dateStr = '${date.year}-${date.month}-${date.day}';
    return '$_prayedPrayersKey:$dateStr';
  }

  /// Obtenir les prières récitées pour une date donnée
  Future<Set<String>> getPrayedPrayers(DateTime date) async {
    final box = await _getBox();
    final key = _getPrayedPrayersKey(date);
    final prayedStr = box.get(key) as String?;
    if (prayedStr == null || prayedStr.isEmpty) {
      return <String>{};
    }
    return prayedStr.split(',').toSet();
  }

  /// Vérifier si une prière est marquée comme récitée
  Future<bool> isPrayerPrayed(DateTime date, String prayerName) async {
    final prayed = await getPrayedPrayers(date);
    return prayed.contains(prayerName);
  }

  /// Marquer une prière comme récitée
  Future<void> markPrayerAsPrayed(DateTime date, String prayerName) async {
    final box = await _getBox();
    final key = _getPrayedPrayersKey(date);
    final prayed = await getPrayedPrayers(date);
    prayed.add(prayerName);
    await box.put(key, prayed.join(','));
  }

  /// Retirer une prière de la liste des prières récitées
  Future<void> unmarkPrayerAsPrayed(DateTime date, String prayerName) async {
    final box = await _getBox();
    final key = _getPrayedPrayersKey(date);
    final prayed = await getPrayedPrayers(date);
    prayed.remove(prayerName);
    await box.put(key, prayed.join(','));
  }

  /// Marquer toutes les prières comme récitées pour une date
  Future<void> markAllPrayersAsPrayed(DateTime date, List<String> prayerNames) async {
    final box = await _getBox();
    final key = _getPrayedPrayersKey(date);
    await box.put(key, prayerNames.join(','));
  }

  /// Obtenir le nombre de prières récitées pour une date
  Future<int> getPrayedPrayersCount(DateTime date) async {
    final prayed = await getPrayedPrayers(date);
    return prayed.length;
  }

  // ==================== NOTIFICATIONS ADHAN ====================

  /// Obtenir l'état de notification Adhan pour une prière
  Future<bool> isAdhanEnabled(String prayerName) async {
    final box = await _getBox();
    final key = '$_adhanEnabledKey:$prayerName';
    return box.get(key, defaultValue: true) as bool; // Par défaut activé
  }

  /// Définir l'état de notification Adhan pour une prière
  Future<void> setAdhanEnabled(String prayerName, bool enabled) async {
    final box = await _getBox();
    final key = '$_adhanEnabledKey:$prayerName';
    await box.put(key, enabled);
  }

  /// Obtenir tous les états de notification Adhan
  Future<Map<String, bool>> getAllAdhanStates() async {
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final Map<String, bool> states = {};
    for (final prayer in prayers) {
      states[prayer] = await isAdhanEnabled(prayer);
    }
    return states;
  }

  // ==================== SÉLECTION ADHAN ====================

  /// Obtenir l'Adhan sélectionné
  Future<String> getSelectedAdhan() async {
    final box = await _getBox();
    return box.get(_selectedAdhanKey, defaultValue: 'classic') as String;
  }

  /// Définir l'Adhan sélectionné
  Future<void> setSelectedAdhan(String adhanName) async {
    final box = await _getBox();
    await box.put(_selectedAdhanKey, adhanName);
  }

  // ==================== RAPPELS SUHOOR ====================

  /// Obtenir l'état du rappel suhoor
  Future<bool> isSuhoorReminderEnabled() async {
    final box = await _getBox();
    return box.get(_suhoorReminderKey, defaultValue: false) as bool;
  }

  /// Définir l'état du rappel suhoor
  Future<void> setSuhoorReminderEnabled(bool enabled) async {
    final box = await _getBox();
    await box.put(_suhoorReminderKey, enabled);
  }

  /// Obtenir les minutes avant imsak pour le rappel suhoor
  Future<int> getSuhoorReminderMinutes() async {
    final box = await _getBox();
    return box.get(_suhoorReminderMinutesKey, defaultValue: 30) as int;
  }

  /// Définir les minutes avant imsak pour le rappel suhoor
  Future<void> setSuhoorReminderMinutes(int minutes) async {
    final box = await _getBox();
    await box.put(_suhoorReminderMinutesKey, minutes);
  }

  // ==================== RAPPEL IFTAR ====================

  /// Obtenir l'état du rappel iftar
  Future<bool> isIftarReminderEnabled() async {
    final box = await _getBox();
    return box.get(_iftarReminderKey, defaultValue: false) as bool;
  }

  /// Définir l'état du rappel iftar
  Future<void> setIftarReminderEnabled(bool enabled) async {
    final box = await _getBox();
    await box.put(_iftarReminderKey, enabled);
  }

  // ==================== MODE SILENCIEUX ====================

  /// Obtenir l'état du mode silencieux pendant la prière
  Future<bool> isSilentModeDuringPrayerEnabled() async {
    final box = await _getBox();
    return box.get(_silentModeDuringPrayerKey, defaultValue: false) as bool;
  }

  /// Définir l'état du mode silencieux pendant la prière
  Future<void> setSilentModeDuringPrayerEnabled(bool enabled) async {
    final box = await _getBox();
    await box.put(_silentModeDuringPrayerKey, enabled);
  }

  // ==================== NOTIFICATIONS ADAPTATIVES ====================

  /// Obtenir l'état des notifications adaptatives
  Future<bool> isAdaptiveNotificationsEnabled() async {
    final box = await _getBox();
    return box.get(_adaptiveNotificationsKey, defaultValue: true) as bool;
  }

  /// Définir l'état des notifications adaptatives
  Future<void> setAdaptiveNotificationsEnabled(bool enabled) async {
    final box = await _getBox();
    await box.put(_adaptiveNotificationsKey, enabled);
  }

  // ==================== DERNIÈRE LECTURE (CLÉ DU PRODUIT) ====================

  /// Obtenir la dernière sourate lue (numéro, 1–114)
  Future<int> getLastReadSurah() async {
    final box = await _getBox();
    final v = box.get(_lastReadSurahKey);
    if (v == null) return 1;
    final n = v is int ? v : int.tryParse(v.toString());
    return (n != null && n >= 1 && n <= 114) ? n : 1;
  }

  /// Obtenir le dernier verset lu (numéro d'ayah dans la sourate)
  Future<int> getLastReadAyah() async {
    final box = await _getBox();
    final v = box.get(_lastReadAyahKey);
    if (v == null) return 1;
    final n = v is int ? v : int.tryParse(v.toString());
    return (n != null && n >= 1) ? n : 1;
  }

  /// Sauvegarder la dernière lecture (sourate + verset). Appelé à chaque progression dans le lecteur.
  Future<void> setLastRead({required int surahNumber, required int ayahNumber}) async {
    final box = await _getBox();
    await box.put(_lastReadSurahKey, surahNumber.clamp(1, 114));
    await box.put(_lastReadAyahKey, ayahNumber.clamp(1, 1000));
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
