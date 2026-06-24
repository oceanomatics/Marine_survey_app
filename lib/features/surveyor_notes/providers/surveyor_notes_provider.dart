// lib/features/surveyor_notes/providers/surveyor_notes_provider.dart
//
// Strategy:
//   • Supabase is the authoritative store.
//   • SQLite is an offline cache and write queue.
//   • On every load we try Supabase first; on failure we fall back to SQLite.
//   • Every write tries Supabase; on failure the record is queued in SQLite
//     with sync_status = 'pending_upsert' or 'pending_delete'.
//   • When connectivity is restored the pending queue is flushed automatically.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/supabase_client.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/connectivity_service.dart';
import '../models/surveyor_note_model.dart';

const _uuid = Uuid();
const _table = 'surveyor_notes';

// ── Provider ──────────────────────────────────────────────────────────────

final surveyorNotesProvider = AsyncNotifierProviderFamily<
    SurveyorNotesNotifier, List<SurveyorNote>, String>(
  SurveyorNotesNotifier.new,
);

// ── Notifier ──────────────────────────────────────────────────────────────

class SurveyorNotesNotifier
    extends FamilyAsyncNotifier<List<SurveyorNote>, String> {
  String get _caseId => arg;

  @override
  Future<List<SurveyorNote>> build(String caseId) async {
    ref.listen<AsyncValue<bool>>(connectivityProvider, (_, next) {
      if (next.value == true) _refresh();
    });
    // Return the SQLite cache immediately (includes pending_upsert notes),
    // then update the state from Supabase in the background.
    _refresh();
    return _fetchOffline();
  }

  // ── Supabase sync (runs in background, updates state when done) ──────────

  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _syncPending();

      final rows = await SupabaseService.client
          .from(_table)
          .select()
          .eq('case_id', _caseId)
          .order('created_at', ascending: false);

      final notes =
          (rows as List).map((r) => SurveyorNote.fromMap(r)).toList();

      await _refreshCache(notes);

      final pending = await _fetchPending();
      final syncedIds = notes.map((n) => n.id).toSet();
      state = AsyncData([
        ...pending.where((n) => !syncedIds.contains(n.id)),
        ...notes,
      ]);
    } catch (e, st) {
      debugPrint('SurveyorNotes._refresh error: $e\n$st');
      // Keep whatever state is already shown — do not blank the screen.
    } finally {
      _refreshing = false;
    }
  }

  // ── Public mutations ─────────────────────────────────────────────────────

  Future<SurveyorNote> add({
    required String caseId,
    required String content,
    NoteCategory category = NoteCategory.general,
    ReportSection? reportSection,
    CuePriority priority = CuePriority.normal,
    DateTime? resolvedAt,
    String? linkedToType,
    String? linkedToId,
    String? source,
  }) async {
    final now = DateTime.now();
    final note = SurveyorNote(
      id:            _uuid.v4(),
      caseId:        caseId,
      content:       content,
      category:      category,
      reportSection: reportSection,
      priority:      priority,
      resolvedAt:    resolvedAt,
      linkedToType:  linkedToType,
      linkedToId:    linkedToId,
      source:        source,
      createdAt:     now,
      updatedAt:     now,
    );

    var syncStatus = 'pending_upsert';
    try {
      await SupabaseService.client.from(_table).insert(note.toMap());
      syncStatus = 'synced';
    } catch (_) {
      // Offline — note will be queued
    }

    await _writeSQLite(note, syncStatus: syncStatus);

    final current = state.value ?? [];
    state = AsyncData([note, ...current]);
    return note;
  }

  Future<void> editNote(
    String noteId, {
    required String content,
    NoteCategory? category,
    ReportSection? reportSection,
    CuePriority? priority,
    bool updateResolvedAt = false,
    DateTime? resolvedAt,
  }) async {
    final current = state.value ?? [];
    final note = current.firstWhere((n) => n.id == noteId);
    final updated = SurveyorNote(
      id:            note.id,
      caseId:        note.caseId,
      content:       content,
      category:      category ?? note.category,
      reportSection: reportSection,
      priority:      priority ?? note.priority,
      resolvedAt:    updateResolvedAt ? resolvedAt : note.resolvedAt,
      linkedToType:  note.linkedToType,
      linkedToId:    note.linkedToId,
      source:        note.source,
      createdAt:     note.createdAt,
      updatedAt:     DateTime.now(),
    );

    var syncStatus = 'pending_upsert';
    try {
      await SupabaseService.client
          .from(_table)
          .update(updated.toMap())
          .eq('id', noteId);
      syncStatus = 'synced';
    } catch (_) {
      // Offline
    }

    await _writeSQLite(updated, syncStatus: syncStatus);
    state = AsyncData(
        current.map((n) => n.id == noteId ? updated : n).toList());
  }

  Future<void> delete(String noteId) async {
    var deleted = false;
    try {
      await SupabaseService.client
          .from(_table)
          .delete()
          .eq('id', noteId);
      deleted = true;
    } catch (_) {
      // Offline
    }

    final db = await AppDatabase.instance.database;
    if (deleted) {
      await db.delete(_table, where: 'id = ?', whereArgs: [noteId]);
    } else {
      // Mark for deferred deletion — will be removed once we reach Supabase
      await db.update(
        _table,
        {'sync_status': 'pending_delete'},
        where: 'id = ?',
        whereArgs: [noteId],
      );
    }

    final current = state.value ?? [];
    state = AsyncData(current.where((n) => n.id != noteId).toList());
  }

  // ── Convenience filter helpers (used by section screens) ─────────────────

  List<SurveyorNote> forSection(ReportSection section) =>
      (state.value ?? [])
          .where((n) => n.reportSection == section)
          .toList();

  List<SurveyorNote> get untagged =>
      (state.value ?? []).where((n) => n.reportSection == null).toList();

  // ── Sync queue ────────────────────────────────────────────────────────────

  Future<void> _syncPending() async {
    final db = await AppDatabase.instance.database;

    // ── 1. Upsert pending inserts/edits ────────────────────────────────────
    final toUpsert = await db.query(
      _table,
      where: 'case_id = ? AND sync_status = ?',
      whereArgs: [_caseId, 'pending_upsert'],
    );

    for (final row in toUpsert) {
      try {
        final note = SurveyorNote.fromMap(row);
        await SupabaseService.client
            .from(_table)
            .upsert(note.toMap(), onConflict: 'id');
        await db.update(
          _table,
          {'sync_status': 'synced'},
          where: 'id = ?',
          whereArgs: [note.id],
        );
      } catch (_) {
        return; // Still offline — stop and retry later
      }
    }

    // ── 2. Execute pending deletions ───────────────────────────────────────
    final toDelete = await db.query(
      _table,
      where: 'case_id = ? AND sync_status = ?',
      whereArgs: [_caseId, 'pending_delete'],
    );

    for (final row in toDelete) {
      final id = row['id'] as String;
      try {
        await SupabaseService.client
            .from(_table)
            .delete()
            .eq('id', id);
        await db.delete(_table, where: 'id = ?', whereArgs: [id]);
      } catch (_) {
        return; // Still offline
      }
    }
  }

  // ── SQLite helpers ─────────────────────────────────────────────────────

  Future<void> _writeSQLite(SurveyorNote note,
      {required String syncStatus}) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      _table,
      {...note.toMap(), 'sync_status': syncStatus},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Replace all 'synced' records for this case with fresh Supabase data.
  /// Leaves 'pending_upsert' / 'pending_delete' records untouched —
  /// they haven't reached Supabase yet.
  Future<void> _refreshCache(List<SurveyorNote> notes) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        _table,
        where: 'case_id = ? AND sync_status = ?',
        whereArgs: [_caseId, 'synced'],
      );
      for (final note in notes) {
        await txn.insert(
          _table,
          {...note.toMap(), 'sync_status': 'synced'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Return cached notes, excluding records queued for deletion.
  Future<List<SurveyorNote>> _fetchOffline() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      _table,
      where: 'case_id = ? AND sync_status != ?',
      whereArgs: [_caseId, 'pending_delete'],
      orderBy: 'created_at DESC',
    );
    return rows.map(SurveyorNote.fromMap).toList();
  }

  /// Return only notes that are queued for upsert (not yet confirmed by Supabase).
  Future<List<SurveyorNote>> _fetchPending() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      _table,
      where: 'case_id = ? AND sync_status = ?',
      whereArgs: [_caseId, 'pending_upsert'],
      orderBy: 'created_at DESC',
    );
    return rows.map(SurveyorNote.fromMap).toList();
  }
}
