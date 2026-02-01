import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../local/quran_database.dart';
import '../local/quran_schema.dart';
import '../../models/quran_models.dart';

/// Marque-page : sourate + verset.
class QuranBookmark {
  const QuranBookmark({
    required this.surahNumber,
    required this.numberInSurah,
    required this.createdAt,
  });
  final int surahNumber;
  final int numberInSurah;
  final String createdAt;
}

/// Accès local au texte Qur'an (Tanzil). Aucun appel réseau pour le texte.
abstract class QuranLocalRepository {
  Future<bool> hasData();
  Future<List<SurahModel>?> getSurahs();
  Future<SurahDetailModel?> getSurahDetail(int surahNumber);
  /// Recherche par numéro ou nom de sourate (arabe / anglais).
  Future<List<SurahModel>?> searchSurahsByNameOrNumber(String query);
  Future<List<AyahModel>?> getAyahsByJuz(int juzNumber);
  Future<List<AyahModel>?> getAyahsByPage(int pageNumber);
  Future<List<QuranBookmark>> getBookmarks();
  Future<void> addBookmark(int surahNumber, int numberInSurah);
  Future<void> removeBookmark(int surahNumber, int numberInSurah);
  Future<bool> isBookmarked(int surahNumber, int numberInSurah);
}

class QuranLocalRepositoryImpl implements QuranLocalRepository {
  QuranLocalRepositoryImpl() : _db = QuranDatabase.db;
  final Database? _db;

  @override
  Future<bool> hasData() async {
    final db = _db;
    if (db == null || !db.isOpen) return false;
    try {
      final n = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $kTableSurahs'),
      );
      return (n ?? 0) >= 114;
    } catch (e) {
      debugPrint('QuranLocalRepository.hasData: $e');
      return false;
    }
  }

  @override
  Future<List<SurahModel>?> getSurahs() async {
    final db = _db;
    if (db == null || !db.isOpen) return null;
    try {
      final rows = await db.query(kTableSurahs, orderBy: 'number ASC');
      return rows.map(_rowToSurah).toList();
    } catch (e) {
      debugPrint('QuranLocalRepository.getSurahs: $e');
      return null;
    }
  }

  static SurahModel _rowToSurah(Map<String, Object?> r) {
    return SurahModel(
      number: r['number'] as int,
      name: r['name_ar'] as String,
      englishName: r['name_en'] as String,
      englishNameTranslation: (r['name_en_translation'] as String?) ?? '',
      numberOfAyahs: r['number_of_ayahs'] as int,
      revelationType: r['revelation_type'] as String,
    );
  }

  @override
  Future<SurahDetailModel?> getSurahDetail(int surahNumber) async {
    final db = _db;
    if (db == null || !db.isOpen) return null;
    try {
      final surahRows = await db.query(
        kTableSurahs,
        where: 'number = ?',
        whereArgs: [surahNumber],
      );
      if (surahRows.isEmpty) return null;
      final sr = surahRows.first;
      final ayahRows = await db.query(
        kTableAyahs,
        where: 'surah_number = ?',
        whereArgs: [surahNumber],
        orderBy: 'number_in_surah ASC',
      );
      final ayahs = ayahRows
          .map((r) => AyahModel(
                number: r['number_global'] as int,
                numberInSurah: r['number_in_surah'] as int,
                juz: r['juz'] as int,
                text: r['text_ar'] as String,
                translation: null,
                audioUrl: null,
              ))
          .toList();
      return SurahDetailModel(
        number: sr['number'] as int,
        name: sr['name_ar'] as String,
        englishName: sr['name_en'] as String,
        englishNameTranslation: (sr['name_en_translation'] as String?) ?? '',
        revelationType: sr['revelation_type'] as String,
        numberOfAyahs: sr['number_of_ayahs'] as int,
        ayahs: ayahs,
      );
    } catch (e) {
      debugPrint('QuranLocalRepository.getSurahDetail: $e');
      return null;
    }
  }

  @override
  Future<List<SurahModel>?> searchSurahsByNameOrNumber(String query) async {
    final db = _db;
    if (db == null || !db.isOpen) return null;
    final q = query.trim();
    if (q.isEmpty) return getSurahs();
    try {
      final num = int.tryParse(q);
      if (num != null && num >= 1 && num <= 114) {
        final rows = await db.query(
          kTableSurahs,
          where: 'number = ?',
          whereArgs: [num],
        );
        return rows.map(_rowToSurah).toList();
      }
      final pattern = '%$q%';
      final rows = await db.rawQuery(
        '''
        SELECT * FROM $kTableSurahs
        WHERE name_ar LIKE ? OR name_en LIKE ? OR name_en_translation LIKE ?
        ORDER BY number ASC
        ''',
        [pattern, pattern, pattern],
      );
      return rows.map(_rowToSurah).toList();
    } catch (e) {
      debugPrint('QuranLocalRepository.searchSurahsByNameOrNumber: $e');
      return null;
    }
  }

  @override
  Future<List<AyahModel>?> getAyahsByJuz(int juzNumber) async {
    final db = _db;
    if (db == null || !db.isOpen) return null;
    try {
      final rows = await db.query(
        kTableAyahs,
        where: 'juz = ?',
        whereArgs: [juzNumber],
        orderBy: 'number_global ASC',
      );
      return rows.map(_rowToAyah).toList();
    } catch (e) {
      debugPrint('QuranLocalRepository.getAyahsByJuz: $e');
      return null;
    }
  }

  @override
  Future<List<AyahModel>?> getAyahsByPage(int pageNumber) async {
    final db = _db;
    if (db == null || !db.isOpen) return null;
    try {
      final rows = await db.query(
        kTableAyahs,
        where: 'page = ?',
        whereArgs: [pageNumber],
        orderBy: 'number_global ASC',
      );
      return rows.map(_rowToAyah).toList();
    } catch (e) {
      debugPrint('QuranLocalRepository.getAyahsByPage: $e');
      return null;
    }
  }

  static AyahModel _rowToAyah(Map<String, Object?> r) {
    return AyahModel(
      number: r['number_global'] as int,
      numberInSurah: r['number_in_surah'] as int,
      juz: r['juz'] as int,
      text: r['text_ar'] as String,
      translation: null,
      audioUrl: null,
    );
  }

  @override
  Future<List<QuranBookmark>> getBookmarks() async {
    final db = _db;
    if (db == null || !db.isOpen) return [];
    try {
      final rows = await db.query(kTableBookmarks, orderBy: 'created_at DESC');
      return rows
          .map((r) => QuranBookmark(
                surahNumber: r['surah_number'] as int,
                numberInSurah: r['number_in_surah'] as int,
                createdAt: r['created_at'] as String? ?? '',
              ))
          .toList();
    } catch (e) {
      debugPrint('QuranLocalRepository.getBookmarks: $e');
      return [];
    }
  }

  @override
  Future<void> addBookmark(int surahNumber, int numberInSurah) async {
    final db = _db;
    if (db == null || !db.isOpen) return;
    try {
      await db.insert(
        kTableBookmarks,
        {'surah_number': surahNumber, 'number_in_surah': numberInSurah},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('QuranLocalRepository.addBookmark: $e');
    }
  }

  @override
  Future<void> removeBookmark(int surahNumber, int numberInSurah) async {
    final db = _db;
    if (db == null || !db.isOpen) return;
    try {
      await db.delete(
        kTableBookmarks,
        where: 'surah_number = ? AND number_in_surah = ?',
        whereArgs: [surahNumber, numberInSurah],
      );
    } catch (e) {
      debugPrint('QuranLocalRepository.removeBookmark: $e');
    }
  }

  @override
  Future<bool> isBookmarked(int surahNumber, int numberInSurah) async {
    final db = _db;
    if (db == null || !db.isOpen) return false;
    try {
      final rows = await db.query(
        kTableBookmarks,
        where: 'surah_number = ? AND number_in_surah = ?',
        whereArgs: [surahNumber, numberInSurah],
      );
      return rows.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
