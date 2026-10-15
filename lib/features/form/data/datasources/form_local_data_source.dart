import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../requests/data/datasources/app_database.dart';
import '../../domain/entities/form_definition.dart';

/// Caches forms locally, keyed by `(id, version)`.
///
/// Keeping every fetched version means an old request can still render its
/// original labels after the server rolls out a new form.
class FormLocalDataSource {
  FormLocalDataSource(this._db);

  final AppDatabase _db;

  Future<void> upsert(FormDefinition form) async {
    final Database db = await _db.database;
    await db.insert('form_definitions', <String, Object?>{
      'id': form.id,
      'version': form.version,
      'fetched_at': DateTime.now().toIso8601String(),
      'json': jsonEncode(form.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<FormDefinition?> latest() async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'form_definitions',
      orderBy: 'version DESC',
      limit: 1,
    );
    return _fromRow(rows.isEmpty ? null : rows.first);
  }

  Future<FormDefinition?> byIdVersion(String id, int version) async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'form_definitions',
      where: 'id = ? AND version = ?',
      whereArgs: <Object?>[id, version],
      limit: 1,
    );
    return _fromRow(rows.isEmpty ? null : rows.first);
  }

  FormDefinition? _fromRow(Map<String, Object?>? row) {
    if (row == null) return null;
    final Object? decoded = jsonDecode(row['json'] as String);
    if (decoded is! Map) return null;
    return FormDefinition.fromJson(decoded.cast<String, dynamic>());
  }
}
