import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'quran_schema.dart';

/// Base SQLite pour le texte Qur'an (Tanzil). Texte 100 % offline.
class QuranDatabase {
  QuranDatabase._();

  static Database? _db;

  static Database? get db => _db;

  /// Initialisation unique. À appeler après [copyFromAssetsIfNeeded].
  static Future<void> initialize() async {
    if (_db != null && _db!.isOpen) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, kDbFileName);
    _db = await openDatabase(
      path,
      version: kSchemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      singleInstance: true,
    );
    debugPrint('QuranDatabase initialized: $path');
  }

  static Future<void> _onCreate(Database db, int version) async {
    for (final sql in createStatements) {
      await db.execute(sql);
    }
    await db.insert(
      kTableSchemaInfo,
      {'key': 'version', 'value': '$version'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(kCreateBookmarks);
      await db.execute(kIndexBookmarksSurah);
    }
  }

  /// Copie assets/db/quran.db vers le répertoire documents si le fichier n'existe pas
  /// ou si la base locale est vide (< 114 sourates). Ainsi, après avoir ajouté
  /// assets/db/quran.db, un simple redémarrage de l'app suffit.
  /// À appeler depuis le main (Flutter) avant [initialize].
  static Future<void> copyFromAssetsIfNeeded(
    Future<ByteData> Function(String) loadAsset,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, kDbFileName);
    final file = File(dbPath);

    bool shouldCopy = false;
    if (!await file.exists()) {
      shouldCopy = true;
    } else {
      // Base locale existante : vérifier si elle contient les 114 sourates
      Database? checkDb;
      try {
        checkDb = await openDatabase(dbPath, readOnly: true);
        final count = Sqflite.firstIntValue(
          await checkDb.rawQuery('SELECT COUNT(*) FROM $kTableSurahs'),
        );
        if (count == null || count < 114) shouldCopy = true;
      } catch (_) {
        shouldCopy = true;
      } finally {
        await checkDb?.close();
      }
    }

    if (!shouldCopy) return;

    if (await file.exists()) {
      await file.delete();
      debugPrint('QuranDatabase: base vide ou incomplète, recopie depuis assets.');
    }

    try {
      final data = await loadAsset('assets/db/quran.db');
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await file.writeAsBytes(bytes);
      debugPrint('QuranDatabase: assets/db/quran.db copié ($dbPath).');
    } catch (_) {
      // Pas d'asset : initialize() ouvrira/créera une base vide
    }
  }

  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
