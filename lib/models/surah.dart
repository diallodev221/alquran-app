class Surah {
  final int number;
  final String name;
  final String arabicName;
  final String englishName;
  final String revelationType;
  final int numberOfAyahs;
  final String meaning;

  const Surah({
    required this.number,
    required this.name,
    required this.arabicName,
    required this.englishName,
    required this.revelationType,
    required this.numberOfAyahs,
    required this.meaning,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      number: json['number'] as int,
      name: json['name'] as String,
      arabicName: json['arabicName'] as String,
      englishName: json['englishName'] as String,
      revelationType: json['revelationType'] as String,
      numberOfAyahs: json['numberOfAyahs'] as int,
      meaning: json['meaning'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'name': name,
      'arabicName': arabicName,
      'englishName': englishName,
      'revelationType': revelationType,
      'numberOfAyahs': numberOfAyahs,
      'meaning': meaning,
    };
  }
}

// Données de démonstration pour les 10 premières sourates
final List<Surah> demoSurahs = [
  const Surah(
    number: 1,
    name: 'Al-Fatiha',
    arabicName: 'الفاتحة',
    englishName: 'The Opening',
    revelationType: 'Meccan',
    numberOfAyahs: 7,
    meaning: 'The Opening',
  ),
  const Surah(
    number: 2,
    name: 'Al-Baqarah',
    arabicName: 'البقرة',
    englishName: 'The Cow',
    revelationType: 'Medinan',
    numberOfAyahs: 286,
    meaning: 'The Cow',
  ),
  const Surah(
    number: 3,
    name: 'Aal-E-Imran',
    arabicName: 'آل عمران',
    englishName: 'The Family of Imran',
    revelationType: 'Medinan',
    numberOfAyahs: 200,
    meaning: 'The Family of Imran',
  ),
  const Surah(
    number: 4,
    name: 'An-Nisa',
    arabicName: 'النساء',
    englishName: 'The Women',
    revelationType: 'Medinan',
    numberOfAyahs: 176,
    meaning: 'The Women',
  ),
  const Surah(
    number: 5,
    name: 'Al-Maidah',
    arabicName: 'المائدة',
    englishName: 'The Table',
    revelationType: 'Medinan',
    numberOfAyahs: 120,
    meaning: 'The Table Spread',
  ),
  const Surah(
    number: 6,
    name: 'Al-Anam',
    arabicName: 'الأنعام',
    englishName: 'The Cattle',
    revelationType: 'Meccan',
    numberOfAyahs: 165,
    meaning: 'The Cattle',
  ),
  const Surah(
    number: 7,
    name: 'Al-Araf',
    arabicName: 'الأعراف',
    englishName: 'The Heights',
    revelationType: 'Meccan',
    numberOfAyahs: 206,
    meaning: 'The Heights',
  ),
  const Surah(
    number: 8,
    name: 'Al-Anfal',
    arabicName: 'الأنفال',
    englishName: 'The Spoils of War',
    revelationType: 'Medinan',
    numberOfAyahs: 75,
    meaning: 'The Spoils of War',
  ),
  const Surah(
    number: 9,
    name: 'At-Tawbah',
    arabicName: 'التوبة',
    englishName: 'The Repentance',
    revelationType: 'Medinan',
    numberOfAyahs: 129,
    meaning: 'The Repentance',
  ),
  const Surah(
    number: 10,
    name: 'Yunus',
    arabicName: 'يونس',
    englishName: 'Jonah',
    revelationType: 'Meccan',
    numberOfAyahs: 109,
    meaning: 'Jonah',
  ),
];
