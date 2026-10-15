import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_request_app/features/requests/data/datasources/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('v1 -> v2 adds last_attempt_at and preserves existing rows', () async {
    final Directory dir = Directory.systemTemp.createTempSync('sr_migration_');
    final String path = '${dir.path}/app.db';

    // A v1 database containing one saved request.
    final Database v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute('''
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
        },
      ),
    );
    await v1.insert('requests', <String, Object?>{
      'id': 'legacy',
      'form_id': 'request-form',
      'form_version': 2,
      'title': 'Legacy row',
      'data_json': '{}',
      'status': 'pending',
      'created_at': '2025-01-01T00:00:00.000',
      'updated_at': '2025-01-01T00:00:00.000',
      'attempts': 0,
    });
    await v1.close();

    // Opening through AppDatabase runs onUpgrade.
    final AppDatabase app = AppDatabase(
      factory: databaseFactoryFfi,
      path: path,
    );
    final Database db = await app.database;

    final List<Map<String, Object?>> columns = await db.rawQuery(
      'PRAGMA table_info(requests)',
    );
    final List<String> names = columns.map((c) => c['name'] as String).toList();
    expect(names, contains('last_attempt_at'));

    final List<Map<String, Object?>> rows = await db.query(
      'requests',
      where: 'id = ?',
      whereArgs: <Object?>['legacy'],
    );
    expect(rows.single['title'], 'Legacy row');
    expect(rows.single['last_attempt_at'], isNull);

    await app.close();
    dir.deleteSync(recursive: true);
  });

  test('a fresh database is created directly at the latest version', () async {
    final AppDatabase app = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final Database db = await app.database;

    final List<Map<String, Object?>> columns = await db.rawQuery(
      'PRAGMA table_info(requests)',
    );
    final List<String> names = columns.map((c) => c['name'] as String).toList();

    expect(names, contains('last_attempt_at'));
    expect(await db.getVersion(), AppDatabase.schemaVersion);
    await app.close();
  });
}
