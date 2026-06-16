// lib/features/capture/providers/voice_note_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';

// ── Recording state ────────────────────────────────────────────────────────

enum RecordingStatus {
  idle, recording, stopped, transcribing, done, error,
}

@immutable
class RecordingState {
  const RecordingState({
    this.status = RecordingStatus.idle,
    this.durationSeconds = 0,
    this.audioPath,
    this.audioBytes,
    this.transcript,
    this.error,
  });

  final RecordingStatus status;
  final int durationSeconds;
  final String? audioPath;
  final Uint8List? audioBytes;
  final String? transcript;
  final String? error;

  bool get isRecording => status == RecordingStatus.recording;
  bool get hasSomethingToSave =>
      audioBytes != null || audioPath != null || (transcript != null && transcript!.isNotEmpty);

  String get durationLabel {
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  RecordingState copyWith({
    RecordingStatus? status,
    int? durationSeconds,
    String? audioPath,
    Uint8List? audioBytes,
    String? transcript,
    String? error,
  }) =>
      RecordingState(
        status:          status          ?? this.status,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        audioPath:       audioPath       ?? this.audioPath,
        audioBytes:      audioBytes      ?? this.audioBytes,
        transcript:      transcript      ?? this.transcript,
        error:           error           ?? this.error,
      );
}

// ── Voice note model ───────────────────────────────────────────────────────

@immutable
class VoiceNoteModel {
  const VoiceNoteModel({
    required this.noteId,
    required this.caseId,
    this.recordedAt,
    this.durationSecs,
    this.audioPath,
    this.transcript,
    this.status = 'pending',
    this.routedTo,
    this.linkedId,
  });

  final String noteId;
  final String caseId;
  final DateTime? recordedAt;
  final int? durationSecs;
  final String? audioPath;
  final String? transcript;
  final String status;
  final String? routedTo;
  final String? linkedId;

  bool get hasTranscript =>
      transcript != null && transcript!.isNotEmpty;
  bool get isPending => status == 'pending';

  factory VoiceNoteModel.fromJson(Map<String, dynamic> j) => VoiceNoteModel(
        noteId:       j['note_id'] as String,
        caseId:       j['case_id'] as String,
        recordedAt:   j['recorded_at'] != null
            ? DateTime.tryParse(j['recorded_at'] as String)
            : null,
        durationSecs: j['duration_secs'] as int?,
        audioPath:    j['audio_path'] as String?,
        transcript:   j['transcript'] as String?,
        status:       j['status'] as String? ?? 'pending',
        routedTo:     j['routed_to'] as String?,
        linkedId:     j['linked_id'] as String?,
      );
}

// ── Recording provider ─────────────────────────────────────────────────────

final recordingStateProvider =
    StateNotifierProvider<RecordingNotifier, RecordingState>(
  (_) => RecordingNotifier(),
);

class RecordingNotifier extends StateNotifier<RecordingState> {
  RecordingNotifier() : super(const RecordingState());

  void setRecording(int durationSeconds) => state =
      state.copyWith(status: RecordingStatus.recording,
          durationSeconds: durationSeconds);

  void setStopped({String? audioPath, Uint8List? audioBytes}) =>
      state = state.copyWith(
          status: RecordingStatus.stopped,
          audioPath: audioPath,
          audioBytes: audioBytes);

  void setTranscribing() =>
      state = state.copyWith(status: RecordingStatus.transcribing);

  void setTranscript(String transcript) =>
      state = state.copyWith(
          status: RecordingStatus.done, transcript: transcript);

  void setError(String error) =>
      state = state.copyWith(status: RecordingStatus.error, error: error);

  void reset() => state = const RecordingState();
}

// ── Voice notes list provider ──────────────────────────────────────────────

final voiceNotesProvider =
    AsyncNotifierProviderFamily<VoiceNotesNotifier, List<VoiceNoteModel>, String>(
  VoiceNotesNotifier.new,
);

class VoiceNotesNotifier
    extends FamilyAsyncNotifier<List<VoiceNoteModel>, String> {
  @override
  Future<List<VoiceNoteModel>> build(String caseId) => _fetch(caseId);

  Future<List<VoiceNoteModel>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('voice_notes')
        .select()
        .eq('case_id', caseId)
        .order('recorded_at', ascending: false);
    return (data as List).map((e) => VoiceNoteModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Save a recording to the DB.
  /// Storage upload is best-effort — DB insert always happens.
  Future<VoiceNoteModel> saveRecording({
    required String caseId,
    required int durationSecs,
    required String? transcript,
    String? audioPath,
    Uint8List? audioBytes,
  }) async {
    // ── Storage upload — best-effort, don't block DB insert ────────
    String? storagePath;
    if (audioBytes != null && audioBytes.isNotEmpty) {
      try {
        storagePath =
            '$caseId/audio/${DateTime.now().millisecondsSinceEpoch}.webm';
        await SupabaseService.uploadFile(
          bucket: 'audio',
          path: storagePath,
          bytes: audioBytes,
          mimeType: 'audio/webm',
        );
      } catch (e) {
        // Storage upload failed (e.g. CORS on web, bucket permissions)
        // Log but don't throw — we still save the text record
        debugPrint('Voice note storage upload failed: $e');
        storagePath = null;
      }
    }

    // ── DB insert — always happens ──────────────────────────────────
    final data = await SupabaseService.client
        .from('voice_notes')
        .insert({
          'case_id':       caseId,
          'recorded_at':   DateTime.now().toIso8601String(),
          'duration_secs': durationSecs,
          if (storagePath != null) 'audio_path': storagePath,
          if (transcript != null && transcript.isNotEmpty)
            'transcript': transcript,
          'status': (transcript != null && transcript.isNotEmpty)
              ? 'transcribed'
              : 'pending',
        })
        .select()
        .single();

    final note = VoiceNoteModel.fromJson(data);
    final current = state.value ?? [];
    state = AsyncData([note, ...current]);
    return note;
  }

  Future<void> routeToInbox({
    required VoiceNoteModel note,
    required String caseId,
  }) async {
    await SupabaseService.client.from('quick_captures').insert({
      'case_id':      caseId,
      'content':      note.transcript ?? 'Voice note (no transcript)',
      'capture_type': 'voice',
      'status':       'pending',
      'captured_at':  note.recordedAt?.toIso8601String() ??
          DateTime.now().toIso8601String(),
    });

    await SupabaseService.client
        .from('voice_notes')
        .update({'status': 'routed', 'routed_to': 'general_note'})
        .eq('note_id', note.noteId);

    _updateNote(note.noteId,
        {'status': 'routed', 'routed_to': 'general_note'});
  }

  void _updateNote(String noteId, Map<String, dynamic> fields) {
    final current = state.value ?? [];
    state = AsyncData(current.map((n) {
      if (n.noteId != noteId) return n;
      return VoiceNoteModel.fromJson({
        'note_id':       n.noteId,
        'case_id':       n.caseId,
        'recorded_at':   n.recordedAt?.toIso8601String(),
        'duration_secs': n.durationSecs,
        'audio_path':    n.audioPath,
        'transcript':    fields['transcript'] ?? n.transcript,
        'status':        fields['status']     ?? n.status,
        'routed_to':     fields['routed_to']  ?? n.routedTo,
        'linked_id':     n.linkedId,
      });
    }).toList());
  }

  Future<void> deleteNote(String noteId) async {
    await SupabaseService.client
        .from('voice_notes')
        .delete()
        .eq('note_id', noteId);
    final current = state.value ?? [];
    state =
        AsyncData(current.where((n) => n.noteId != noteId).toList());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}
