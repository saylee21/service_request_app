import 'package:sqflite/sqflite.dart';

import '../../../../core/app_logger.dart';

/// Owns the SQLite connection and schema.
///
/// The database factory and path are injectable so tests can run against an
/// in-memory database via `sqflite_common_ffi`.
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? path})
    : _factory = factory,
      _path = path;

  static const int schemaVersion = 2;
  static const String fileName = 'service_requests.db';

  final DatabaseFactory? _factory;
  final String? _path;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final DatabaseFactory factory = _factory ?? databaseFactory;
    final String path =
        _path ?? '${await factory.getDatabasesPath()}/$fileName';
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (Database db, int version) async {
          await _createV1(db);
          // Fresh installs run the same migrations so the schema has exactly one
          // source of truth.
          await _migrateV1toV2(db);
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          if (oldVersion < 2) await _migrateV1toV2(db);
        },
      ),
    );
  }

  Future<void> _createV1(Database db) async {
    final Batch batch = db.batch();

    batch.execute('''
      CREATE TABLE form_definitions (
        id TEXT NOT NULL,
        version INTEGER NOT NULL,
        fetched_at TEXT NOT NULL,
        json TEXT NOT NULL,
        PRIMARY KEY (id, version)
      )
    ''');

    batch.execute('''
      CREATE TABLE requests (
        id TEXT PRIMARY KEY,
        form_id TEXT NOT NULL,
        form_version INTEGER NOT NULL,
        title TEXT NOT NULL,
        priority TEXT,
        data_json TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced_at TEXT,
        server_message TEXT,
        attempts INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE outbox (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id TEXT NOT NULL UNIQUE,
        idempotency_key TEXT NOT NULL,
        enqueued_at TEXT NOT NULL,
        FOREIGN KEY (request_id) REFERENCES requests (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE sync_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id TEXT NOT NULL,
        attempt INTEGER NOT NULL,
        result TEXT NOT NULL,
        http_status INTEGER,
        duration_ms INTEGER,
        message TEXT,
        at TEXT NOT NULL,
        FOREIGN KEY (request_id) REFERENCES requests (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('CREATE INDEX idx_requests_status ON requests(status)');
    batch.execute('CREATE INDEX idx_requests_created ON requests(created_at)');
    batch.execute('CREATE INDEX idx_outbox_request ON outbox(request_id)');
    batch.execute(
      'CREATE INDEX idx_attempts_request ON sync_attempts(request_id)',
    );

    await batch.commit(noResult: true);
    AppLogger.d('Database created at schema v1');
  }

  /// v2: remember when the last sync attempt happened, so the detail screen can
  /// show it and the attempt counter continues after a restart.
  Future<void> _migrateV1toV2(Database db) async {
    await db.execute('ALTER TABLE requests ADD COLUMN last_attempt_at TEXT');
    AppLogger.d('DB migrated to schema v2 (requests.last_attempt_at)');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
