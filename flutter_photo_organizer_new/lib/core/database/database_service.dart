// Database service for the photo organizer app

import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/photo_models.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'photos.db';

  // Table names
  static const String _photosTable = 'photos';
  static const String _knownFacesTable = 'known_faces';
  static const String _chatHistoryTable = 'chat_history';

  // Singleton pattern
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _dbName);
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Photos table
    await db.execute('''
      CREATE TABLE $_photosTable (
        id TEXT PRIMARY KEY,
        path TEXT UNIQUE,
        filename TEXT,
        category TEXT,
        persons TEXT,
        scenes TEXT,
        objects TEXT,
        date_taken TEXT,
        gps_lat REAL,
        gps_lon REAL,
        created_at TEXT,
        width INTEGER,
        height INTEGER
      )
    ''');

    // Known faces table
    await db.execute('''
      CREATE TABLE $_knownFacesTable (
        id TEXT PRIMARY KEY,
        name TEXT,
        embedding_paths TEXT,
        sample_images TEXT,
        created_at TEXT
      )
    ''');

    // Chat history table
    await db.execute('''
      CREATE TABLE $_chatHistoryTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT,
        content TEXT,
        photo_context TEXT,
        timestamp TEXT
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_photos_category ON $_photosTable(category)');
    await db.execute('CREATE INDEX idx_photos_path ON $_photosTable(path)');
    await db.execute('CREATE INDEX idx_photos_date ON $_photosTable(date_taken)');
  }

  // Photo operations
  Future<void> storePhoto(String photoPath, ImageAnalysis analysis, String category) async {
    final db = await database;
    final photoId = photoPath.hashCode.abs().toString();
    final now = DateTime.now().toIso8601String();

    final sceneNames = analysis.scenes.map((s) => s.scene).toList();
    final objectNames = analysis.objects.map((o) => o.label).toList();
    final personNames = analysis.faces.map((f) => f.name).toList();

    await db.insert(
      _photosTable,
      {
        'id': photoId,
        'path': photoPath,
        'filename': analysis.filename,
        'category': category,
        'persons': jsonEncode(personNames),
        'scenes': jsonEncode(sceneNames),
        'objects': jsonEncode(objectNames),
        'date_taken': analysis.metadata?.date,
        'gps_lat': analysis.metadata?.gpsLat,
        'gps_lon': analysis.metadata?.gpsLon,
        'created_at': now,
        'width': analysis.metadata?.width,
        'height': analysis.metadata?.height,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Photo>> getAllPhotos() async {
    final db = await database;
    final maps = await db.query(_photosTable);
    return maps.map((map) => _mapToPhoto(map)).toList();
  }

  Future<List<Photo>> searchPhotos(String query, {int limit = 50}) async {
    final db = await database;
    final q = '%$query%';
    final maps = await db.query(
      _photosTable,
      where: 'persons LIKE ? OR scenes LIKE ? OR objects LIKE ? OR category LIKE ? OR filename LIKE ?',
      whereArgs: [q, q, q, q, q],
      limit: limit,
    );
    return maps.map((map) => _mapToPhoto(map)).toList();
  }

  Future<bool> photoExists(String photoPath) async {
    final db = await database;
    final result = await db.query(
      _photosTable,
      where: 'path = ?',
      whereArgs: [photoPath],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Photo _mapToPhoto(Map<String, dynamic> map) {
    return Photo(
      id: map['id'] as String,
      path: map['path'] as String,
      filename: map['filename'] as String,
      category: map['category'] as String,
      persons: jsonDecode(map['persons'] as String? ?? '[]') as List<String>,
      scenes: jsonDecode(map['scenes'] as String? ?? '[]') as List<String>,
      objects: jsonDecode(map['objects'] as String? ?? '[]') as List<String>,
      dateTaken: map['date_taken'] as String?,
      gpsLat: map['gps_lat'] as double?,
      gpsLon: map['gps_lon'] as double?,
      createdAt: map['created_at'] as String,
      width: map['width'] as int?,
      height: map['height'] as int?,
    );
  }

  // Known faces operations
  Future<void> storeKnownFace(KnownFace face) async {
    final db = await database;
    await db.insert(
      _knownFacesTable,
      {
        'id': face.id,
        'name': face.name,
        'embedding_paths': jsonEncode(face.embeddingPaths),
        'sample_images': jsonEncode(face.sampleImages),
        'created_at': face.createdAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<KnownFace>> getKnownFaces() async {
    final db = await database;
    final maps = await db.query(_knownFacesTable);
    return maps.map((map) => KnownFace(
      id: map['id'] as String,
      name: map['name'] as String,
      embeddingPaths: jsonDecode(map['embedding_paths'] as String? ?? '[]') as List<String>,
      sampleImages: jsonDecode(map['sample_images'] as String? ?? '[]') as List<String>,
      createdAt: map['created_at'] as String,
    )).toList();
  }

  Future<void> removeKnownFace(String name) async {
    final db = await database;
    await db.delete(
      _knownFacesTable,
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  // Chat history operations
  Future<void> storeChatMessage(ChatMessage message) async {
    final db = await database;
    await db.insert(_chatHistoryTable, {
      'role': message.role,
      'content': message.content,
      'photo_context': message.photoContext,
      'timestamp': message.timestamp,
    });
  }

  Future<List<ChatMessage>> getChatHistory({int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      _chatHistoryTable,
      orderBy: 'id DESC',
      limit: limit,
    );
    return maps.reversed.map((map) => ChatMessage(
      id: map['id'] as int,
      role: map['role'] as String,
      content: map['content'] as String,
      photoContext: map['photo_context'] as String?,
      timestamp: map['timestamp'] as String,
    )).toList();
  }

  Future<void> clearChatHistory() async {
    final db = await database;
    await db.delete(_chatHistoryTable);
  }

  // Stats
  Future<AppStats> getStats() async {
    final db = await database;
    
    final totalPhotosResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_photosTable');
    final totalPhotos = totalPhotosResult.first['count'] as int;

    final categoriesResult = await db.rawQuery('SELECT category, COUNT(*) as count FROM $_photosTable GROUP BY category');
    final categories = {for (var row in categoriesResult) row['category'] as String: row['count'] as int};

    final totalFacesResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_photosTable WHERE persons != "[]"');
    final totalFaces = totalFacesResult.first['count'] as int;

    final knownFacesResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_knownFacesTable');
    final knownFaces = knownFacesResult.first['count'] as int;

    final totalPersonsResult = await db.rawQuery('SELECT COUNT(DISTINCT name) as count FROM $_knownFacesTable');
    final totalPersons = totalPersonsResult.first['count'] as int;

    final totalScenesResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT json_each.value) as count 
      FROM $_photosTable, json_each(scenes) 
      WHERE scenes != "[]"
    ''');
    final totalScenes = totalScenesResult.first['count'] as int;

    return AppStats(
      totalPhotos: totalPhotos,
      knownFaces: knownFaces,
      categories: categories,
      totalFaces: totalFaces,
      totalPersons: totalPersons,
      totalScenes: totalScenes,
    );
  }

  Future<List<Map<String, dynamic>>> getAllLocations() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT category as name, COUNT(*) as photo_count 
      FROM $_photosTable 
      WHERE category = "locations" 
      GROUP BY category
    ''');
  }

  Future<int> getTotalPhotoCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_photosTable');
    return result.first['count'] as int;
  }

  Future<List<KnownFace>> getAllFaces() async {
    return getKnownFaces();
  }

  Future<List<Map<String, dynamic>>> getAllScenes() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT scenes FROM $_photosTable WHERE scenes != "[]"');
    final sceneSet = <String>{};
    for (final row in rows) {
      try {
        final scenes = jsonDecode(row['scenes'] as String) as List<dynamic>;
        for (final s in scenes) {
          sceneSet.add(s as String);
        }
      } catch (_) {}
    }
    return sceneSet.map((s) => {'name': s}).toList();
  }

  Future<int> countPhotosByScene(String sceneName) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_photosTable WHERE scenes LIKE ?',
      ['%$sceneName%'],
    );
    return result.first['count'] as int;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}