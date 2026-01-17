import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'location_service.dart';
import 'package:intl/intl.dart';

/// Méthodes de calcul des horaires de prière
enum CalculationMethod {
  muslimWorldLeague, // Muslim World League
  egyptian, // Egyptian General Authority of Survey
  karachi, // University of Islamic Sciences, Karachi
  ummAlQura, // Umm Al-Qura University, Makkah
  dubai, // Dubai
  qatar, // Qatar
  kuwait, // Kuwait
  moonsightingCommittee, // Moonsighting Committee
  singapore, // Singapore
  turkey, // Turkey
  tehran, // Institute of Geophysics, University of Tehran
  northAmerica, // North America (ISNA)
  other, // Other
}

/// Paramètres de calcul pour chaque méthode
class CalculationParameters {
  final CalculationMethod method;
  final double fajrAngle;
  final double ishaAngle;
  final int ishaInterval; // Minutes après Maghrib (pour certaines méthodes)
  final adhan.Madhab madhab;
  final adhan.HighLatitudeRule highLatitudeRule;

  CalculationParameters({
    required this.method,
    required this.fajrAngle,
    required this.ishaAngle,
    this.ishaInterval = 0,
    this.madhab = adhan.Madhab.hanafi,
    this.highLatitudeRule = adhan.HighLatitudeRule.middleOfTheNight,
  });
}

/// Horaires de prière pour une journée
class PrayerTimes {
  final DateTime date;
  final DateTime fajr;
  final DateTime imsak; // 10 minutes avant Fajr
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final DateTime? tarawih; // Pour Ramadan, après Isha

  PrayerTimes({
    required this.date,
    required this.fajr,
    required this.imsak,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.tarawih,
  });

  /// Vérifie si c'est le mois de Ramadan
  bool get isRamadan {
    // Calcul simplifié - peut être amélioré avec un calendrier Hijri
    final month = date.month;
    // Ramadan est généralement en avril-mai (approximation)
    // Pour une implémentation précise, utiliser un calendrier Hijri
    return month >= 3 && month <= 5;
  }

  /// Retourne le nom de la prière actuelle
  String? getCurrentPrayerName(DateTime now) {
    if (now.isBefore(fajr)) return 'Isha';
    if (now.isBefore(sunrise)) return 'Fajr';
    if (now.isBefore(dhuhr)) return 'Sunrise';
    if (now.isBefore(asr)) return 'Dhuhr';
    if (now.isBefore(maghrib)) return 'Asr';
    if (now.isBefore(isha)) return 'Maghrib';
    return 'Isha';
  }

  /// Retourne la prochaine prière
  Map<String, dynamic>? getNextPrayer(DateTime now) {
    final prayers = [
      {'name': 'Fajr', 'time': fajr},
      {'name': 'Dhuhr', 'time': dhuhr},
      {'name': 'Asr', 'time': asr},
      {'name': 'Maghrib', 'time': maghrib},
      {'name': 'Isha', 'time': isha},
    ];

    for (final prayer in prayers) {
      if (now.isBefore(prayer['time'] as DateTime)) {
        final timeUntil = (prayer['time'] as DateTime).difference(now);
        return {
          'name': prayer['name'],
          'time': prayer['time'],
          'timeUntil': timeUntil,
        };
      }
    }

    // Si toutes les prières sont passées, la prochaine est Fajr du lendemain
    return {
      'name': 'Fajr',
      'time': fajr.add(const Duration(days: 1)),
      'timeUntil': fajr.add(const Duration(days: 1)).difference(now),
    };
  }
}

/// Service pour calculer les horaires de prière
class PrayerTimesService {
  static final PrayerTimesService _instance = PrayerTimesService._internal();
  factory PrayerTimesService() => _instance;
  PrayerTimesService._internal();

  /// Convertit notre enum en méthode Adhan
  adhan.CalculationMethod _getAdhanMethod(CalculationMethod method) {
    switch (method) {
      case CalculationMethod.muslimWorldLeague:
        return adhan.CalculationMethod.muslimWorldLeague;
      case CalculationMethod.egyptian:
        return adhan.CalculationMethod.egyptian;
      case CalculationMethod.karachi:
        return adhan.CalculationMethod.karachi;
      case CalculationMethod.ummAlQura:
        return adhan.CalculationMethod.ummAlQura;
      case CalculationMethod.dubai:
        return adhan.CalculationMethod.dubai;
      case CalculationMethod.qatar:
        return adhan.CalculationMethod.qatar;
      case CalculationMethod.kuwait:
        return adhan.CalculationMethod.kuwait;
      case CalculationMethod.moonsightingCommittee:
        return adhan.CalculationMethod.moonsightingCommittee;
      case CalculationMethod.singapore:
        return adhan.CalculationMethod.singapore;
      case CalculationMethod.turkey:
        return adhan.CalculationMethod.other; // Fallback si turkey n'existe pas
      case CalculationMethod.tehran:
        return adhan.CalculationMethod.tehran;
      case CalculationMethod.northAmerica:
        return adhan.CalculationMethod.northAmerica;
      case CalculationMethod.other:
        return adhan.CalculationMethod.other;
    }
  }

  /// Obtient les paramètres de calcul pour une méthode donnée
  CalculationParameters getCalculationParameters(CalculationMethod method) {
    switch (method) {
      case CalculationMethod.muslimWorldLeague:
        return CalculationParameters(
          method: method,
          fajrAngle: 18.0,
          ishaAngle: 17.0,
          madhab: adhan.Madhab.shafi,
        );
      case CalculationMethod.egyptian:
        return CalculationParameters(
          method: method,
          fajrAngle: 19.5,
          ishaAngle: 17.5,
          madhab: adhan.Madhab.shafi,
        );
      case CalculationMethod.karachi:
        return CalculationParameters(
          method: method,
          fajrAngle: 18.0,
          ishaAngle: 18.0,
          madhab: adhan.Madhab.hanafi,
        );
      case CalculationMethod.ummAlQura:
        return CalculationParameters(
          method: method,
          fajrAngle: 18.5,
          ishaAngle: 0.0, // Utilise un intervalle fixe
          ishaInterval: 90, // 90 minutes après Maghrib
          madhab: adhan.Madhab.shafi,
        );
      case CalculationMethod.dubai:
        return CalculationParameters(
          method: method,
          fajrAngle: 18.2,
          ishaAngle: 18.2,
          madhab: adhan.Madhab.shafi,
        );
      case CalculationMethod.qatar:
        return CalculationParameters(
          method: method,
          fajrAngle: 18.0,
          ishaAngle: 18.0,
          madhab: adhan.Madhab.shafi,
        );
      case CalculationMethod.kuwait:
        return CalculationParameters(
          method: method,
          fajrAngle: 18.0,
          ishaAngle: 17.5,
          madhab: adhan.Madhab.shafi,
        );
      case CalculationMethod.moonsightingCommittee:
        return CalculationParameters(
          method: method,
          fajrAngle: 18.0,
          ishaAngle: 18.0,
          madhab: adhan.Madhab.shafi,
        );
      case CalculationMethod.singapore:
        return CalculationParameters(
          method: method,
          fajrAngle: 20.0,
          ishaAngle: 18.0,
          madhab: adhan.Madhab.shafi,
        );
      case CalculationMethod.turkey:
        return CalculationParameters(
          method: method,
          fajrAngle: 18.0,
          ishaAngle: 17.0,
          madhab: adhan.Madhab.hanafi,
        );
      case CalculationMethod.tehran:
        return CalculationParameters(
          method: method,
          fajrAngle: 17.7,
          ishaAngle: 14.0,
          madhab: adhan.Madhab.shafi,
        );
      case CalculationMethod.northAmerica:
        return CalculationParameters(
          method: method,
          fajrAngle: 15.0,
          ishaAngle: 15.0,
          madhab: adhan.Madhab.shafi,
        );
      case CalculationMethod.other:
        return CalculationParameters(
          method: method,
          fajrAngle: 18.0,
          ishaAngle: 17.0,
          madhab: adhan.Madhab.shafi,
        );
    }
  }

  /// Calcule les horaires de prière pour une date et localisation données
  PrayerTimes calculatePrayerTimes({
    required DateTime date,
    required LocationData location,
    CalculationMethod method = CalculationMethod.muslimWorldLeague,
  }) {
    final params = getCalculationParameters(method);
    
    // Créer les coordonnées
    final coordinates = adhan.Coordinates(
      location.latitude,
      location.longitude,
    );

    // Créer les paramètres de calcul Adhan
    final calculationParams = adhan.CalculationParameters(
      method: _getAdhanMethod(method),
      fajrAngle: params.fajrAngle,
      ishaAngle: params.ishaAngle,
      ishaInterval: params.ishaInterval,
      madhab: params.madhab,
      highLatitudeRule: params.highLatitudeRule,
    );

    // Calculer les horaires avec adhan_dart
    final adhanPrayerTimes = adhan.PrayerTimes(
      coordinates: coordinates,
      date: date,
      calculationParameters: calculationParams,
    );

    // Imsak est généralement 10 minutes avant Fajr
    final imsak = adhanPrayerTimes.fajr.subtract(const Duration(minutes: 10));

    // Tarawih pour Ramadan (environ 1h30 après Isha)
    DateTime? tarawih;
    final isRamadan = _isRamadan(date);
    if (isRamadan) {
      tarawih = adhanPrayerTimes.isha.add(const Duration(minutes: 90));
    }

    return PrayerTimes(
      date: date,
      fajr: adhanPrayerTimes.fajr,
      imsak: imsak,
      sunrise: adhanPrayerTimes.sunrise,
      dhuhr: adhanPrayerTimes.dhuhr,
      asr: adhanPrayerTimes.asr,
      maghrib: adhanPrayerTimes.maghrib,
      isha: adhanPrayerTimes.isha,
      tarawih: tarawih,
    );
  }

  /// Vérifie si c'est le mois de Ramadan (approximation)
  bool _isRamadan(DateTime date) {
    // Pour une implémentation précise, utiliser un calendrier Hijri
    // Ici, on utilise une approximation basée sur le calendrier grégorien
    // Ramadan 2024: ~11 mars - 9 avril
    // Ramadan 2025: ~1 mars - 29 mars
    // Cette fonction devrait être améliorée avec un vrai calendrier Hijri
    final month = date.month;
    final day = date.day;
    
    // Approximation pour 2024-2025
    if (date.year == 2024) {
      if (month == 3 && day >= 11) return true;
      if (month == 4 && day <= 9) return true;
    }
    if (date.year == 2025) {
      if (month == 3 && day <= 29) return true;
    }
    
    return false;
  }

  /// Formate une heure pour l'affichage
  String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }
}
