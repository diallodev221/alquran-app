/// Schéma SQLite pour le texte Qur'an offline (Tanzil – script Uthmani).
/// Lecture seule, aucune API pour le texte.
library;

const int kSchemaVersion = 2;
const String kDbFileName = 'quran.db';

const String kTableSchemaInfo = 'schema_info';
const String kTableSurahs = 'surahs';
const String kTableAyahs = 'ayahs';
const String kTableBookmarks = 'bookmarks';

const String kCreateSchemaInfo = '''
CREATE TABLE IF NOT EXISTS $kTableSchemaInfo (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
''';

const String kCreateSurahs = '''
CREATE TABLE IF NOT EXISTS $kTableSurahs (
  number INTEGER PRIMARY KEY CHECK (number BETWEEN 1 AND 114),
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  name_en_translation TEXT,
  revelation_type TEXT NOT NULL,
  number_of_ayahs INTEGER NOT NULL,
  created_at TEXT DEFAULT (datetime('now'))
);
''';

const String kIndexSurahsNumber = 'CREATE INDEX IF NOT EXISTS idx_surahs_number ON $kTableSurahs(number);';

const String kCreateAyahs = '''
CREATE TABLE IF NOT EXISTS $kTableAyahs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  surah_number INTEGER NOT NULL,
  number_in_surah INTEGER NOT NULL,
  number_global INTEGER NOT NULL,
  text_ar TEXT NOT NULL,
  juz INTEGER NOT NULL,
  page INTEGER NOT NULL,
  UNIQUE(surah_number, number_in_surah),
  FOREIGN KEY (surah_number) REFERENCES $kTableSurahs(number)
);
''';

const String kIndexAyahsSurah = 'CREATE INDEX IF NOT EXISTS idx_ayahs_surah ON $kTableAyahs(surah_number);';
const String kIndexAyahsJuz = 'CREATE INDEX IF NOT EXISTS idx_ayahs_juz ON $kTableAyahs(juz);';
const String kIndexAyahsPage = 'CREATE INDEX IF NOT EXISTS idx_ayahs_page ON $kTableAyahs(page);';
const String kIndexAyahsGlobal = 'CREATE INDEX IF NOT EXISTS idx_ayahs_global ON $kTableAyahs(number_global);';

const String kCreateBookmarks = '''
CREATE TABLE IF NOT EXISTS $kTableBookmarks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  surah_number INTEGER NOT NULL,
  number_in_surah INTEGER NOT NULL,
  created_at TEXT DEFAULT (datetime('now')),
  UNIQUE(surah_number, number_in_surah),
  FOREIGN KEY (surah_number) REFERENCES $kTableSurahs(number)
);
''';

const String kIndexBookmarksSurah = 'CREATE INDEX IF NOT EXISTS idx_bookmarks_surah ON $kTableBookmarks(surah_number);';

List<String> get createStatements => [
      kCreateSchemaInfo,
      kCreateSurahs,
      kIndexSurahsNumber,
      kCreateAyahs,
      kIndexAyahsSurah,
      kIndexAyahsJuz,
      kIndexAyahsPage,
      kIndexAyahsGlobal,
      kCreateBookmarks,
      kIndexBookmarksSurah,
    ];
