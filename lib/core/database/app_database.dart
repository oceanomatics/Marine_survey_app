// lib/core/database/app_database.dart
//
// SQLite is the offline cache / write queue.
// Supabase is the authoritative cloud store — data is synced to Supabase
// as soon as connectivity is available.
//
// sync_status values (used by tables that mirror a Supabase table):
//   'synced'         — matches Supabase
//   'pending_upsert' — created or edited offline; needs upsert to Supabase
//   'pending_delete' — deleted offline; needs delete on Supabase before removal here

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'marine_survey.db');
    return openDatabase(
      dbPath,
      version: 11,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE photos (
        id              TEXT PRIMARY KEY,
        case_id         TEXT NOT NULL,
        local_path      TEXT NOT NULL,
        thumbnail_path  TEXT,
        caption         TEXT,
        photo_allocation TEXT,
        linked_to_type  TEXT,
        linked_to_id    TEXT,
        attendance_id   TEXT,
        taken_at        TEXT NOT NULL,
        sync_status     TEXT NOT NULL DEFAULT 'local_only',
        remote_path     TEXT,
        file_size_kb    REAL,
        placement_mode  TEXT,
        photo_source    TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE correspondence (
        id              TEXT PRIMARY KEY,
        case_id         TEXT NOT NULL,
        title           TEXT NOT NULL,
        sender          TEXT,
        recipient       TEXT,
        corr_date       TEXT,
        local_path      TEXT NOT NULL,
        summary         TEXT,
        body_text       TEXT,
        parties_json    TEXT,
        actions_json    TEXT,
        key_dates_json  TEXT,
        status          TEXT NOT NULL DEFAULT 'pending',
        file_size_kb    REAL,
        created_at      TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE surveyor_notes (
        id              TEXT PRIMARY KEY,
        case_id         TEXT NOT NULL,
        content         TEXT NOT NULL,
        category        TEXT NOT NULL DEFAULT 'general',
        report_section  TEXT,
        priority        TEXT NOT NULL DEFAULT 'normal',
        resolved_at     TEXT,
        linked_to_type  TEXT,
        linked_to_id    TEXT,
        source          TEXT,
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL,
        sync_status     TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }

  // NOTE: despite the module comment above, `photos` and `correspondence`
  // are NOT Supabase-backed — both are 100% local (dart:io files indexed
  // here), so dropping them on upgrade permanently destroys captions,
  // allocations, links, and extracted summaries with no way to recover
  // them (only the bare files would survive, via photos' orphan-file
  // recovery scan). Only `surveyor_notes` is a genuine Supabase cache.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 11) {
      // Additive: placement_mode/photo_source for Section 7 photo
      // placement modes (docs/report_builder_editor_notes.md).
      await db.execute('ALTER TABLE photos ADD COLUMN placement_mode TEXT');
      await db.execute('ALTER TABLE photos ADD COLUMN photo_source TEXT');
    }
  }
}
