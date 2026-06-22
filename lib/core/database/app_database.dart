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
      version: 6,
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
        caption         TEXT,
        linked_to_type  TEXT,
        linked_to_id    TEXT,
        attendance_id   TEXT,
        taken_at        TEXT NOT NULL,
        sync_status     TEXT NOT NULL DEFAULT 'local_only',
        remote_path     TEXT,
        file_size_kb    REAL
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
        linked_to_type  TEXT,
        linked_to_id    TEXT,
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL,
        sync_status     TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE photos ADD COLUMN attendance_id TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correspondence (
          id              TEXT PRIMARY KEY,
          case_id         TEXT NOT NULL,
          title           TEXT NOT NULL,
          sender          TEXT,
          recipient       TEXT,
          corr_date       TEXT,
          local_path      TEXT NOT NULL,
          summary         TEXT,
          parties_json    TEXT,
          actions_json    TEXT,
          key_dates_json  TEXT,
          status          TEXT NOT NULL DEFAULT 'pending',
          file_size_kb    REAL,
          created_at      TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS surveyor_notes (
          id              TEXT PRIMARY KEY,
          case_id         TEXT NOT NULL,
          content         TEXT NOT NULL,
          category        TEXT NOT NULL DEFAULT 'general',
          linked_to_type  TEXT,
          linked_to_id    TEXT,
          created_at      TEXT NOT NULL,
          updated_at      TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
            'ALTER TABLE surveyor_notes ADD COLUMN report_section TEXT');
      } catch (_) {
        // Column already present (fresh install into v3+ path)
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
            "ALTER TABLE surveyor_notes ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'");
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
            "ALTER TABLE surveyor_notes ADD COLUMN priority TEXT NOT NULL DEFAULT 'normal'");
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE surveyor_notes ADD COLUMN resolved_at TEXT');
      } catch (_) {}
    }
  }
}
