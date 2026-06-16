// lib/features/capture/screens/voice_note_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/voice_note_provider.dart';
import '../providers/quick_capture_provider.dart';
import '../widgets/voice_note_card.dart';
import '../widgets/web_audio_recorder_stub.dart'
    if (dart.library.html) '../widgets/web_audio_recorder.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

class VoiceNoteScreen extends ConsumerStatefulWidget {
  const VoiceNoteScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<VoiceNoteScreen> createState() => _VoiceNoteScreenState();
}

class _VoiceNoteScreenState extends ConsumerState<VoiceNoteScreen> {
  WebAudioRecorder? _webRecorder;
  Timer? _timer;

  int     _seconds     = 0;
  bool    _isRecording = false;
  bool    _saving      = false;
  bool    _transcribing = false;
  String? _permissionError;
  String? _transcribeError;

  // Result of current recording session
  Uint8List? _audioBytes;
  String?    _transcript;
  final _transcriptCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _webRecorder = WebAudioRecorder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _transcriptCtrl.dispose();
    _webRecorder?.dispose();
    ref.read(recordingStateProvider.notifier).reset();
    super.dispose();
  }

  // ── Recording ─────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    setState(() {
      _permissionError = null;
      _transcribeError = null;
      _seconds = 0;
      _audioBytes = null;
      _transcript = null;
      _transcriptCtrl.clear();
    });

    try {
      if (kIsWeb) await _webRecorder!.start();
      setState(() => _isRecording = true);
      ref.read(recordingStateProvider.notifier).setRecording(0);

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _seconds++);
        ref.read(recordingStateProvider.notifier).setRecording(_seconds);
      });
    } catch (e) {
      setState(() => _permissionError =
          'Microphone access denied. Please allow microphone in your browser.');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    setState(() => _isRecording = false);

    try {
      if (kIsWeb) {
        final bytes = await _webRecorder!.stop();
        setState(() => _audioBytes = bytes);
        ref.read(recordingStateProvider.notifier)
            .setStopped(audioBytes: bytes);
        // Auto-transcribe
        await _transcribeBytes(bytes);
      }
    } catch (e) {
      debugPrint('Stop recording error: $e');
      ref.read(recordingStateProvider.notifier).setError(e.toString());
    }
  }

  // ── Whisper transcription (web — bytes via multipart) ─────────────────────

  Future<void> _transcribeBytes(Uint8List bytes) async {
    setState(() { _transcribing = true; _transcribeError = null; });
    ref.read(recordingStateProvider.notifier).setTranscribing();

    try {
      final transcript = await _callWhisperWeb(bytes);
      setState(() {
        _transcript = transcript;
        _transcriptCtrl.text = transcript;
        _transcribing = false;
      });
      ref.read(recordingStateProvider.notifier).setTranscript(transcript);
    } catch (e) {
      debugPrint('Whisper error: $e');
      setState(() {
        _transcribing = false;
        _transcribeError = 'Transcription failed — you can still save manually below.';
      });
      // Set a stopped state so save button appears
      ref.read(recordingStateProvider.notifier)
          .setStopped(audioBytes: bytes);
    }
  }

  /// Call OpenAI Whisper with audio bytes directly (web-compatible)
  Future<String> _callWhisperWeb(Uint8List bytes) async {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.openai.com/v1',
      headers: {'Authorization': 'Bearer ${AppConfig.openAiApiKey}'},
      receiveTimeout: const Duration(seconds: 120),
      connectTimeout: const Duration(seconds: 30),
    ));

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: 'recording.webm',
        contentType: DioMediaType('audio', 'webm'),
      ),
      'model':           'whisper-1',
      'language':        'en',
      'response_format': 'text',
    });

    final response = await dio.post(
      '/audio/transcriptions',
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
        responseType: ResponseType.plain,
      ),
    );
    return response.data?.toString().trim() ?? '';
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    // Allow saving even without transcript
    final transcript = _transcriptCtrl.text.trim();
    final hasAudio   = _audioBytes != null && _audioBytes!.isNotEmpty;

    if (!hasAudio && transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to save yet')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // 1. Save voice note (storage upload is best-effort inside provider)
      await ref
          .read(voiceNotesProvider(widget.caseId).notifier)
          .saveRecording(
            caseId:      widget.caseId,
            durationSecs: _seconds,
            transcript:  transcript.isEmpty ? null : transcript,
            audioBytes:  _audioBytes,
          );

      // 2. If transcript exists, also push to quick capture inbox
      if (transcript.isNotEmpty) {
        await ref
            .read(quickCaptureProvider(widget.caseId).notifier)
            .addCapture(
              caseId:      widget.caseId,
              content:     transcript,
              captureType: 'voice',
            );
      }

      // 3. Reset recording state
      setState(() {
        _audioBytes      = null;
        _transcript      = null;
        _seconds         = 0;
        _transcribeError = null;
        _saving          = false;
      });
      _transcriptCtrl.clear();
      ref.read(recordingStateProvider.notifier).reset();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(transcript.isNotEmpty
                ? 'Voice note saved and sent to inbox ✓'
                : 'Voice note saved ✓'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Save failed: $e'),
              backgroundColor: AppColors.error),
        );
      }
      setState(() => _saving = false);
    }
  }

  void _discard() {
    setState(() {
      _audioBytes      = null;
      _transcript      = null;
      _seconds         = 0;
      _transcribeError = null;
    });
    _transcriptCtrl.clear();
    ref.read(recordingStateProvider.notifier).reset();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(voiceNotesProvider(widget.caseId));
    final hasRecording = _audioBytes != null;
    final hasTranscript = _transcript != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Voice Notes')),
      body: Column(
        children: [
          // ── Recorder panel ─────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timer + button row
                Row(children: [
                  // Record button
                  GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: _isRecording ? AppColors.error : AppColors.navy,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording
                                    ? AppColors.error
                                    : AppColors.navy)
                                .withValues(alpha: 0.3),
                            blurRadius: _isRecording ? 20 : 8,
                            spreadRadius: _isRecording ? 4 : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Duration
                        Text(
                          _formatDuration(_seconds),
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        // Status
                        Text(
                          _statusLabel(),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _isRecording
                                  ? AppColors.error
                                  : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Pulse dot while recording
                  if (_isRecording) _PulseDot(),
                ]),

                // Permission error
                if (_permissionError != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(_permissionError!),
                ],

                // Transcribing spinner
                if (_transcribing) ...[
                  const SizedBox(height: 16),
                  const Row(children: [
                    SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            color: AppColors.midBlue, strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Transcribing with Whisper...',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.midBlue)),
                  ]),
                ],

                // Transcription error — still show save
                if (_transcribeError != null && !_transcribing) ...[
                  const SizedBox(height: 12),
                  _WarningBanner(_transcribeError!),
                ],

                // Transcript editor (shown once transcription done
                // OR if transcription failed but we have audio)
                if ((hasTranscript || (hasRecording && _transcribeError != null))
                    && !_transcribing) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.text_snippet_outlined,
                        size: 14, color: AppColors.midBlue),
                    const SizedBox(width: 6),
                    const Text('Transcript',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.midBlue)),
                    const Spacer(),
                    Text(
                      hasTranscript ? 'Edit if needed' : 'Type notes manually',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textTertiary),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _transcriptCtrl,
                    maxLines: 4,
                    autofocus: !hasTranscript,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.4),
                    decoration: InputDecoration(
                      hintText: hasTranscript
                          ? 'Edit transcript...'
                          : 'Type your observation here...',
                      filled: true,
                      fillColor:
                          AppColors.lightBlue.withValues(alpha: 0.4),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.midBlue, width: 0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.midBlue, width: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action buttons
                  Row(children: [
                    OutlinedButton(
                      onPressed: _discard,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                      child: const Text('Discard',
                          style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_outlined, size: 15),
                        label: Text(
                          _saving ? 'Saving...' : 'Save & Send to Inbox',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Previous voice notes list ──────────────────────────────
          Expanded(
            child: notesAsync.when(
              loading: () =>
                  const AppLoadingWidget(message: 'Loading voice notes...'),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (notes) => notes.isEmpty
                  ? _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: notes.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => VoiceNoteCard(
                        note: notes[i],
                        onDelete: () => ref
                            .read(voiceNotesProvider(widget.caseId)
                                .notifier)
                            .deleteNote(notes[i].noteId),
                        onRouteToInbox: () => ref
                            .read(voiceNotesProvider(widget.caseId)
                                .notifier)
                            .routeToInbox(
                              note: notes[i],
                              caseId: widget.caseId,
                            ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  String _statusLabel() {
    if (_isRecording)             return 'Recording — tap to stop';
    if (_transcribing)            return 'Transcribing...';
    if (_transcribeError != null) return 'Transcription failed';
    if (_transcript != null)      return 'Transcribed — review and save';
    if (_audioBytes != null)      return 'Recorded';
    return 'Tap to start recording';
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: _anim.value),
            shape: BoxShape.circle,
          ),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.lightCoral,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.mic_off, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.error)),
          ),
        ]),
      );
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.lightAmber,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_outlined,
              color: AppColors.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.amber)),
          ),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.mic_none_outlined,
                size: 48, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text('No voice notes yet',
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
            SizedBox(height: 6),
            Text(
              'Tap the mic above to record\nyour first observation',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: AppColors.textTertiary),
            ),
          ]),
        ),
      );
}
