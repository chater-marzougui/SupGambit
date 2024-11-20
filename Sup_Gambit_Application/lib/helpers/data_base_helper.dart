import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'dart:math';

class DatabaseHelper {
  static Future<Database> initializeDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'embeddings.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE embeddings(id INTEGER PRIMARY KEY, chunk TEXT, embedding BLOB)',
        );
      },
      version: 1,
    );
  }

  static Future<void> insertEmbedding(Database db, String chunk, List<double> embedding) async {
    await db.insert('embeddings', {
      'chunk': chunk,
      'embedding': embedding,
    });
  }
}
