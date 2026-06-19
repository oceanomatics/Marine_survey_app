// lib/features/correspondence/providers/correspondence_provider.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/api/claude_api.dart';
import '../models/correspondence_model.dart';

const _uuid = Uuid();

final correspondenceProvider = AsyncNotifierProviderFamily<
    CorrespondenceNotifier, List<CorrespondenceModel>, String>(
  CorrespondenceNotifier.new,
);

class CorrespondenceNotifier
    extends FamilyAsyncNotifier<List<CorrespondenceModel>, String> {
  @override
  Future<List<CorrespondenceModel>> build(String caseId) => _fetch(caseId);

  Future<List<CorrespondenceModel>> _fetch(String caseId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'correspondence',
      where: 'case_id = ?',
      whereArgs: [caseId],
      orderBy: 'created_at DESC',
    );
    return rows.map(CorrespondenceModel.fromMap).toList();
  }

  /// Copy a PDF from [bytes] into local storage and create a record.
  Future<CorrespondenceModel> addFromBytes({
    required String caseId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final corrDir =
        Directory(p.join(dir.path, 'cases', caseId, 'correspondence'));
    await corrDir.create(recursive: true);

    final id = _uuid.v4();
    final ext = filename.split('.').last.toLowerCase();
    final localPath = p.join(corrDir.path, '$id.$ext');
    await File(localPath).writeAsBytes(bytes);

    final corr = CorrespondenceModel(
      id:         id,
      caseId:     caseId,
      title:      filename,
      localPath:  localPath,
      fileSizeKb: bytes.length / 1024,
      createdAt:  DateTime.now(),
    );

    final db = await AppDatabase.instance.database;
    await db.insert('correspondence', corr.toMap());

    final current = state.value ?? [];
    state = AsyncData([corr, ...current]);
    return corr;
  }

  /// Run Claude extraction on an uploaded PDF.
  Future<void> extract(String corrId) async {
    _setStatus(corrId, CorrStatus.processing);
    try {
      final current = state.value ?? [];
      final corr = current.firstWhere((c) => c.id == corrId);
      final bytes = await File(corr.localPath).readAsBytes();
      final base64Pdf = base64Encode(bytes);

      final result = await ClaudeApi.extractCorrespondence(
        base64Pdf: base64Pdf,
        filename: corr.title,
      );

      // Parse parties
      final partiesList = (result['parties'] as List? ?? []);
      final parties = partiesList
          .map((e) => ExtractedParty.fromMap(e as Map<String, dynamic>))
          .toList();

      final actions = (result['action_items'] as List? ?? [])
          .map((e) => e.toString())
          .toList();

      final keyDates = (result['key_dates'] as List? ?? [])
          .map((e) => e.toString())
          .toList();

      final updated = corr.copyWith(
        summary:   result['summary'] as String?,
        sender:    result['sender'] as String?,
        recipient: result['recipient'] as String?,
        parties:   parties,
        actions:   actions,
        keyDates:  keyDates,
        status:    CorrStatus.completed,
      );

      await _persist(updated);
    } catch (e) {
      _setStatus(corrId, CorrStatus.failed);
    }
  }

  Future<void> delete(String corrId) async {
    final current = state.value ?? [];
    final corr = current.firstWhere((c) => c.id == corrId);
    try { await File(corr.localPath).delete(); } catch (_) {}
    final db = await AppDatabase.instance.database;
    await db.delete('correspondence', where: 'id = ?', whereArgs: [corrId]);
    state = AsyncData(current.where((c) => c.id != corrId).toList());
  }

  void _setStatus(String corrId, CorrStatus status) {
    final current = state.value ?? [];
    state = AsyncData(current
        .map((c) => c.id == corrId ? c.copyWith(status: status) : c)
        .toList());
  }

  Future<void> _persist(CorrespondenceModel corr) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'correspondence',
      corr.toMap(),
      where: 'id = ?',
      whereArgs: [corr.id],
    );
    final current = state.value ?? [];
    state = AsyncData(
        current.map((c) => c.id == corr.id ? corr : c).toList());
  }
}
