import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/memory_item.dart';

class MemoryRepository {
  static const _dbName = 'project_evo_memory.db';
  static const _dbVersion = 1;
  Database? _db;
  final _uuid = const Uuid();

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE memory_items (
            id TEXT PRIMARY KEY,
            category TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            source_url TEXT,
            source_title TEXT,
            confidence REAL NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            user_approved INTEGER NOT NULL,
            expires_at TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_memory_category ON memory_items(category)',
        );
        await db.execute(
          'CREATE INDEX idx_memory_updated ON memory_items(updated_at)',
        );
      },
    );
    return _db!;
  }

  Future<MemoryItem> save({
    required MemoryCategory category,
    required String title,
    required String content,
    String? sourceUrl,
    String? sourceTitle,
    double confidence = 0.7,
    bool userApproved = true,
  }) async {
    final now = DateTime.now().toUtc();
    final item = MemoryItem(
      id: _uuid.v4(),
      category: category,
      title: title,
      content: content,
      sourceUrl: sourceUrl,
      sourceTitle: sourceTitle,
      confidence: confidence.clamp(0.0, 1.0),
      createdAt: now,
      updatedAt: now,
      userApproved: userApproved,
    );
    final db = await database;
    await db.insert('memory_items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return item;
  }

  Future<List<MemoryItem>> listAll({int limit = 200}) async {
    final db = await database;
    final rows = await db.query(
      'memory_items',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(MemoryItem.fromMap).toList();
  }

  Future<List<MemoryItem>> search(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return listAll(limit: limit);
    final db = await database;
    final like = '%${q.replaceAll('%', '')}%';
    final rows = await db.query(
      'memory_items',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: [like, like],
      orderBy: 'confidence DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map(MemoryItem.fromMap).toList();
  }

  Future<void> delete(String id) async {
    final db = await database;
    await db.delete('memory_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('memory_items');
  }

  Future<int> count() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM memory_items');
    return Sqflite.firstIntValue(r) ?? 0;
  }
}
