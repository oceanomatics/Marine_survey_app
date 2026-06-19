// lib/features/surveyor_notes/providers/surveyor_notes_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../models/surveyor_note_model.dart';

const _uuid = Uuid();

final surveyorNotesProvider = AsyncNotifierProviderFamily<
    SurveyorNotesNotifier, List<SurveyorNote>, String>(
  SurveyorNotesNotifier.new,
);

class SurveyorNotesNotifier
    extends FamilyAsyncNotifier<List<SurveyorNote>, String> {
  @override
  Future<List<SurveyorNote>> build(String caseId) => _fetch(caseId);

  Future<List<SurveyorNote>> _fetch(String caseId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'surveyor_notes',
      where: 'case_id = ?',
      whereArgs: [caseId],
      orderBy: 'created_at DESC',
    );
    return rows.map(SurveyorNote.fromMap).toList();
  }

  Future<SurveyorNote> add({
    required String caseId,
    required String content,
    NoteCategory category = NoteCategory.general,
    String? linkedToType,
    String? linkedToId,
  }) async {
    final now = DateTime.now();
    final note = SurveyorNote(
      id:           _uuid.v4(),
      caseId:       caseId,
      content:      content,
      category:     category,
      linkedToType: linkedToType,
      linkedToId:   linkedToId,
      createdAt:    now,
      updatedAt:    now,
    );

    final db = await AppDatabase.instance.database;
    await db.insert('surveyor_notes', note.toMap());

    final current = state.value ?? [];
    state = AsyncData([note, ...current]);
    return note;
  }

  Future<void> editNote(String noteId, {
    required String content,
    NoteCategory? category,
  }) async {
    final current = state.value ?? [];
    final note = current.firstWhere((n) => n.id == noteId);
    final updated = note.copyWith(content: content, category: category);

    final db = await AppDatabase.instance.database;
    await db.update(
      'surveyor_notes',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [noteId],
    );
    state = AsyncData(
        current.map((n) => n.id == noteId ? updated : n).toList());
  }

  Future<void> delete(String noteId) async {
    final db = await AppDatabase.instance.database;
    await db.delete('surveyor_notes', where: 'id = ?', whereArgs: [noteId]);
    final current = state.value ?? [];
    state = AsyncData(current.where((n) => n.id != noteId).toList());
  }
}
