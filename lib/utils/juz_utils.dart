/// Utility functions for Juz calculations and mappings
library;

/// Map of Juz number to the range of Surahs it contains
/// This is based on standard Quran divisions (Hizb divisions)
/// Note: Some surahs span multiple Juzs, so they appear in multiple entries
final Map<int, List<int>> juzToSurahs = {
  1: [1, 2], // Al-Fatiha, Al-Baqarah (partial)
  2: [2], // Al-Baqarah (partial)
  3: [2, 3], // Al-Baqarah (partial), Aal-E-Imran (partial)
  4: [3, 4], // Aal-E-Imran (partial), An-Nisa (partial)
  5: [4], // An-Nisa (partial)
  6: [4, 5], // An-Nisa (partial), Al-Maidah (partial)
  7: [5, 6], // Al-Maidah (partial), Al-Anam (partial)
  8: [6, 7], // Al-Anam (partial), Al-Araf (partial)
  9: [7, 8], // Al-Araf (partial), Al-Anfal
  10: [8, 9], // Al-Anfal (partial), At-Tawbah (partial)
  11: [9, 10, 11], // At-Tawbah (partial), Yunus, Hud (partial)
  12: [11, 12], // Hud (partial), Yusuf
  13: [12, 13, 14], // Yusuf (partial), Ar-Ra'd, Ibrahim
  14: [15, 16], // Al-Hijr, An-Nahl (partial)
  15: [16, 17], // An-Nahl (partial), Al-Isra (partial)
  16: [17, 18], // Al-Isra (partial), Al-Kahf (partial)
  17: [18, 19, 20], // Al-Kahf (partial), Maryam, Ta-Ha (partial)
  18: [20, 21, 22], // Ta-Ha (partial), Al-Anbiya, Al-Hajj (partial)
  19: [22, 23, 24], // Al-Hajj (partial), Al-Muminun, An-Nur (partial)
  20: [24, 25], // An-Nur (partial), Al-Furqan (partial)
  21: [25, 26, 27], // Al-Furqan (partial), Ash-Shu'ara, An-Naml (partial)
  22: [27, 28], // An-Naml (partial), Al-Qasas (partial)
  23: [28, 29], // Al-Qasas (partial), Al-Ankabut (partial)
  24: [29, 30, 31], // Al-Ankabut (partial), Ar-Rum, Luqman (partial)
  25: [31, 32, 33], // Luqman (partial), As-Sajdah, Al-Ahzab (partial)
  26: [33, 34, 35], // Al-Ahzab (partial), Saba, Fatir (partial)
  27: [35, 36, 37], // Fatir (partial), Ya-Sin, As-Saffat (partial)
  28: [37, 38, 39], // As-Saffat (partial), Sad, Az-Zumar (partial)
  29: [39, 40, 41], // Az-Zumar (partial), Ghafir, Fussilat (partial)
  30: [
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55,
    56,
    57,
    58,
    59,
    60,
    61,
    62,
    63,
    64,
    65,
    66,
    67,
    68,
    69,
    70,
    71,
    72,
    73,
    74,
    75,
    76,
    77,
    78,
    79,
    80,
    81,
    82,
    83,
    84,
    85,
    86,
    87,
    88,
    89,
    90,
    91,
    92,
    93,
    94,
    95,
    96,
    97,
    98,
    99,
    100,
    101,
    102,
    103,
    104,
    105,
    106,
    107,
    108,
    109,
    110,
    111,
    112,
    113,
    114,
  ], // Fussilat (partial) to An-Nas
};

/// Get the Juz number(s) that contain a specific surah
List<int> getJuzsForSurah(int surahNumber) {
  final List<int> juzs = [];
  for (final entry in juzToSurahs.entries) {
    if (entry.value.contains(surahNumber)) {
      juzs.add(entry.key);
    }
  }
  return juzs;
}

/// Get all surahs in a specific Juz
List<int> getSurahsInJuz(int juzNumber) {
  return juzToSurahs[juzNumber] ?? [];
}

/// Get all Juz numbers (1-30)
List<int> getAllJuzs() {
  return List.generate(30, (index) => index + 1);
}

/// Page mushaf standard Uthmani (604 pages, 6236 ayahs).
/// Retourne la page (1–604) pour un numéro d'ayah global (1–6236).
int getPageForGlobalAyah(int numberGlobal) {
  if (numberGlobal < 1) return 1;
  if (numberGlobal >= 6236) return 604;
  return ((numberGlobal - 1) * 604 / 6236).floor() + 1;
}
