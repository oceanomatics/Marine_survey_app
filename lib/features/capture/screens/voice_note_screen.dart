// lib/features/capture/screens/voice_note_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../providers/voice_note_provider.dart';
import '../providers/quick_capture_provider.dart';
import '../widgets/voice_note_card.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

class VoiceNoteScreen extends ConsumerStatefulWidget {
  const VoiceNoteScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<VoiceNoteScreen> createState() => _VoiceNoteScreenState();
}

class _VoiceNoteScreenState extends ConsumerState<VoiceNoteScreen> {
  final _stt = SpeechToText();
  final _transcriptCtrl = TextEditingController();

  bool _sttReady       = false;
  bool _isRecording    = false;
  bool _saving         = false;
  bool _done           = false;  // recording stopped, ready to review
  String? _permissionError;
  String  _liveWords   = '';     // interim words while recording
  int     _seconds     = 0;
  Timer?  _timer;

  @override
  void initState() {
    super.initState();
    _initStt();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stt.stop();
    _transcriptCtrl.dispose();
    ref.read(recordingStateProvider.notifier).reset();
    super.dispose();
  }

  Future<void> _initStt() async {
    final available = await _stt.initialize(
      onError: (e) => setState(() =>
          _permissionError = 'Speech recognition error: ${e.errorMsg}'),
      onStatus: (status) {
        // 'done' fires when the engine stops (e.g. silence timeout).
        if (status == 'done' && _isRecording) _onEngineStopped();
      },
    );
    setState(() => _sttReady = available);
    if (!available) {
      setState(() =>
          _permissionError = 'Speech recognition not available on this device.');
    }
  }

  // ── Recording ──────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (!_sttReady) return;
    setState(() {
      _permissionError = null;
      _liveWords       = '';
      _done            = false;
      _seconds         = 0;
    });
    _transcriptCtrl.clear();

    await _stt.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        // Give long pauses — surveyor may stop to look at equipment.
        pauseFor: const Duration(seconds: 6),
        partialResults: true,
      ),
    );

    setState(() => _isRecording = true);
    ref.read(recordingStateProvider.notifier).setRecording(0);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      ref.read(recordingStateProvider.notifier).setRecording(_seconds);
    });
  }

  void _onResult(SpeechRecognitionResult result) {
    setState(() => _liveWords = result.recognizedWords);
    if (result.finalResult) {
      // Append finalised sentence to the editable field.
      final existing = _transcriptCtrl.text.trimRight();
      final separator = existing.isEmpty ? '' : ' ';
      _transcriptCtrl.text = '$existing$separator${result.recognizedWords}';
      _transcriptCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _transcriptCtrl.text.length));
      setState(() => _liveWords = '');
    }
  }

  // Called when the STT engine stops due to silence — let the user decide.
  void _onEngineStopped() {
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _done        = true;
      if (_liveWords.isNotEmpty) {
        final existing = _transcriptCtrl.text.trimRight();
        final sep = existing.isEmpty ? '' : ' ';
        _transcriptCtrl.text = '$existing$sep$_liveWords';
        _liveWords = '';
      }
    });
    ref.read(recordingStateProvider.notifier)
        .setTranscript(_transcriptCtrl.text);
  }

  Future<void> _stopRecording() async {
    await _stt.stop();
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _done        = true;
      if (_liveWords.isNotEmpty) {
        final existing = _transcriptCtrl.text.trimRight();
        final sep = existing.isEmpty ? '' : ' ';
        _transcriptCtrl.text = '$existing$sep$_liveWords';
        _liveWords = '';
      }
    });
    ref.read(recordingStateProvider.notifier)
        .setTranscript(_transcriptCtrl.text);
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final transcript = _transcriptCtrl.text.trim();
    if (transcript.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nothing to save yet')));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(voiceNotesProvider(widget.caseId).notifier)
          .saveRecording(
            caseId:      widget.caseId,
            durationSecs: _seconds,
            transcript:  transcript,
          );

      await ref
          .read(quickCaptureProvider(widget.caseId).notifier)
          .addCapture(
            caseId:      widget.caseId,
            content:     transcript,
            captureType: 'voice',
          );

      _discard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Voice note saved and sent to inbox ✓'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e, st) {
      if (mounted) showError(context, 'Save failed: $e', error: e, stack: st, tag: 'App');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _discard() {
    _stt.cancel();
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _done        = false;
      _liveWords   = '';
      _seconds     = 0;
    });
    _transcriptCtrl.clear();
    ref.read(recordingStateProvider.notifier).reset();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(voiceNotesProvider(widget.caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Voice Notes')),
      body: Column(children: [
        // ── Recorder panel ───────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mic button + timer row
              Row(children: [
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : (_sttReady ? _startRecording : null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? AppColors.error
                          : _sttReady
                              ? AppColors.navy
                              : AppColors.textTertiary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? AppColors.error : AppColors.navy)
                              .withValues(alpha: _isRecording ? 0.3 : 0.15),
                          blurRadius: _isRecording ? 20 : 8,
                          spreadRadius: _isRecording ? 4 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white, size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDuration(_seconds),
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        _statusLabel(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _isRecording
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isRecording) _PulseDot(),
              ]),

              if (_permissionError != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(_permissionError!),
              ],

              // Live words bubble during recording
              if (_isRecording && _liveWords.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.midBlue.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _liveWords,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.midBlue,
                        fontStyle: FontStyle.italic,
                        height: 1.4),
                  ),
                ),
              ],

              // Transcript editor — shown once stopped
              if (_done || _transcriptCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Row(children: [
                  Icon(Icons.text_snippet_outlined,
                      size: 14, color: AppColors.midBlue),
                  SizedBox(width: 6),
                  Text('Transcript',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.midBlue)),
                  Spacer(),
                  Text('Edit if needed',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textTertiary)),
                ]),
                const SizedBox(height: 6),
                TextField(
                  controller: _transcriptCtrl,
                  maxLines: 4,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4),
                  decoration: InputDecoration(
                    hintText: 'Transcript appears here as you speak…',
                    filled: true,
                    fillColor: AppColors.lightBlue.withValues(alpha: 0.4),
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
                        _saving ? 'Saving…' : 'Save & Send to Inbox',
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

        // ── Previous voice notes ─────────────────────────────────────
        Expanded(
          child: notesAsync.when(
            loading: () =>
                const AppLoadingWidget(message: 'Loading voice notes…'),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (notes) => notes.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => VoiceNoteCard(
                      note: notes[i],
                      onDelete: () => ref
                          .read(voiceNotesProvider(widget.caseId).notifier)
                          .deleteNote(notes[i].noteId),
                      onRouteToInbox: () => ref
                          .read(voiceNotesProvider(widget.caseId).notifier)
                          .routeToInbox(
                              note: notes[i], caseId: widget.caseId),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }

  String _formatDuration(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  String _statusLabel() {
    if (!_sttReady)    return 'Speech recognition unavailable';
    if (_isRecording)  return 'Listening — tap to stop';
    if (_done)         return 'Done — review and save';
    return 'Tap to start recording';
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────────

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
                style: const TextStyle(fontSize: 11, color: AppColors.error)),
          ),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              'Tap the mic to record your first observation.\nWords appear as you speak.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ]),
        ),
      );
}
