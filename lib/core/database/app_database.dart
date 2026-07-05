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
      version: 14,
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
        photo_source    TEXT,
        drive_file_id   TEXT,
        thumbnail_drive_file_id TEXT,
        local_sync_status TEXT NOT NULL DEFAULT 'synced'
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
        created_at      TEXT NOT NULL,
        drive_file_id   TEXT,
        file_type       TEXT NOT NULL DEFAULT 'pdf',
        sync_status     TEXT NOT NULL DEFAULT 'synced'
      )
    ''');

    await db.execute('''
      CREATE TABLE surveyor_notes (
        id                  TEXT PRIMARY KEY,
        case_id             TEXT NOT NULL,
        content             TEXT NOT NULL,
        nature_of_content   TEXT,
        evidentiary_weight  TEXT,
        origin              TEXT,
        case_section        TEXT,
        priority            TEXT NOT NULL DEFAULT 'normal',
        lost_relevance_at   TEXT,
        linked_to_type      TEXT,
        linked_to_id        TEXT,
        source              TEXT,
        pending_review      INTEGER NOT NULL DEFAULT 0,
        created_at          TEXT NOT NULL,
        updated_at          TEXT NOT NULL,
        sync_status         TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }

  // As of the Drive-backed unified storage migration (2026-07-05), `photos`
  // and `correspondence` are genuine Supabase caches too (same
  // authoritative-remote/offline-cache pattern as `surveyor_notes`) — the
  // local rows here are per-device (local_path/thumbnail_path/sync_status),
  // with canonical metadata + drive_file_id mirrored from Supabase.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 11) {
      // Additive: placement_mode/photo_source for Section 7 photo
      // placement modes (docs/report_builder_editor_notes.md).
      await db.execute('ALTER TABLE photos ADD COLUMN placement_mode TEXT');
      await db.execute('ALTER TABLE photos ADD COLUMN photo_source TEXT');
    }
    if (oldVersion < 12) {
      // Context-cue system rework (docs/context_cue_system_review.md §3.4,
      // §3.6) — mirrors migration 022 on the Supabase side. `category` is
      // left in place as an unused orphan column rather than dropped —
      // SQLite DROP COLUMN needs a fairly recent SQLite build, and there's
      // no benefit to the removal on a local cache table.
      await db.execute(
          'ALTER TABLE surveyor_notes RENAME COLUMN report_section TO case_section');
      await db.execute(
          'ALTER TABLE surveyor_notes RENAME COLUMN resolved_at TO lost_relevance_at');
      await db.execute(
          'ALTER TABLE surveyor_notes ADD COLUMN nature_of_content TEXT');
      await db.execute(
          'ALTER TABLE surveyor_notes ADD COLUMN evidentiary_weight TEXT');
      await db.execute('ALTER TABLE surveyor_notes ADD COLUMN origin TEXT');
    }
    if (oldVersion < 13) {
      // Was missing from this upgrade path — pending_review shipped in
      // _onCreate for fresh installs (docs/context_cue_system_review.md
      // §3.5) but never got an upgrade block for existing local DBs.
      await db.execute(
          'ALTER TABLE surveyor_notes ADD COLUMN pending_review INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 14) {
      // Drive-backed unified storage — photos/correspondence gain a Drive
      // file id for the canonical cross-platform copy, alongside the
      // existing per-device local_path cache.
      await db.execute('ALTER TABLE photos ADD COLUMN drive_file_id TEXT');
      await db.execute(
          'ALTER TABLE photos ADD COLUMN thumbnail_drive_file_id TEXT');
      // Separate from the pre-existing `sync_status` (Google Photos album
      // sync bookkeeping: local_only/uploading/synced) — this is the
      // Supabase offline-write-queue status (synced/pending_upsert/
      // pending_delete), same vocabulary as surveyor_notes.sync_status.
      await db.execute(
          "ALTER TABLE photos ADD COLUMN local_sync_status TEXT NOT NULL DEFAULT 'synced'");
      await db
          .execute('ALTER TABLE correspondence ADD COLUMN drive_file_id TEXT');
      await db.execute(
          "ALTER TABLE correspondence ADD COLUMN file_type TEXT NOT NULL DEFAULT 'pdf'");
      await db.execute(
          "ALTER TABLE correspondence ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'");
    }
  }
}
