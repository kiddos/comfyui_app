import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/generation_record.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  static const String defaultServerUrl = 'http://192.168.0.198:8188';
  static const String _settingsTable = 'settings';
  static const String _generationsTable = 'generations';
  static const String _serverUrlKey = 'server_url';

  Database? _db;
  bool _useMemoryFallback = false;
  final Map<String, String> _memorySettings = {_serverUrlKey: defaultServerUrl};
  final List<GenerationRecord> _memoryGenerations = [];
  int _nextMemoryId = 1;

  Future<Database?> get database async {
    if (_useMemoryFallback) return null;
    if (_db != null) return _db!;
    try {
      _db = await _initDatabase();
      return _db!;
    } catch (e) {
      debugPrint('SQLite init failed ($e). Falling back to in-memory store.');
      _useMemoryFallback = true;
      return null;
    }
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for desktop platforms if running on Linux/Windows/macOS
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'comfyui_app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_settingsTable (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $_generationsTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workflow_name TEXT NOT NULL,
            positive_prompt TEXT,
            negative_prompt TEXT,
            prompt_id TEXT,
            image_path TEXT,
            server_url TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        // Insert default server URL
        await db.insert(_settingsTable, {
          'key': _serverUrlKey,
          'value': defaultServerUrl,
        });
      },
    );
  }

  Future<String> getServerUrl() async {
    try {
      final db = await database;
      if (db != null) {
        final results = await db.query(
          _settingsTable,
          where: 'key = ?',
          whereArgs: [_serverUrlKey],
          limit: 1,
        );

        if (results.isNotEmpty && results.first['value'] != null) {
          return results.first['value'] as String;
        }
      }
    } catch (_) {}

    return _memorySettings[_serverUrlKey] ?? defaultServerUrl;
  }

  Future<void> setServerUrl(String url) async {
    final trimmed = url.trim();
    _memorySettings[_serverUrlKey] = trimmed;
    try {
      final db = await database;
      if (db != null) {
        await db.insert(
          _settingsTable,
          {'key': _serverUrlKey, 'value': trimmed},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {}
  }

  Future<int> insertGeneration(GenerationRecord record) async {
    try {
      final db = await database;
      if (db != null) {
        return await db.insert(_generationsTable, record.toMap());
      }
    } catch (_) {}

    final id = _nextMemoryId++;
    _memoryGenerations.insert(
      0,
      GenerationRecord(
        id: id,
        workflowName: record.workflowName,
        positivePrompt: record.positivePrompt,
        negativePrompt: record.negativePrompt,
        promptId: record.promptId,
        imagePath: record.imagePath,
        serverUrl: record.serverUrl,
        createdAt: record.createdAt,
      ),
    );
    return id;
  }

  Future<List<GenerationRecord>> getGenerations() async {
    try {
      final db = await database;
      if (db != null) {
        final results = await db.query(
          _generationsTable,
          orderBy: 'id DESC',
        );
        return results.map((row) => GenerationRecord.fromMap(row)).toList();
      }
    } catch (_) {}

    return List<GenerationRecord>.from(_memoryGenerations);
  }

  Future<void> deleteGeneration(int id) async {
    try {
      final db = await database;
      if (db != null) {
        await db.delete(_generationsTable, where: 'id = ?', whereArgs: [id]);
      }
    } catch (_) {}

    _memoryGenerations.removeWhere((r) => r.id == id);
  }

  Future<void> clearGenerations() async {
    try {
      final db = await database;
      if (db != null) {
        await db.delete(_generationsTable);
      }
    } catch (_) {}

    _memoryGenerations.clear();
  }
}
