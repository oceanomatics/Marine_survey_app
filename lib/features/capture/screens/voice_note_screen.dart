// lib/features/capture/screens/voice_note_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/voice_note_provider.dart';
import '../providers/quick_capture_provider.dart';
import '../widgets/voice_note_card.dart';
import '../../../core/services/model_manager.dart';
import '../../../core/services/sherpa_service.dart';
import '../../settings/providers/speech_settings_provider.dart';
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
  final _sherpa         = SherpaService.instance;
  final _transcriptCtrl = TextEditingController();

  // Model readiness
  bool    _modelReady   = false;
  bool    _modelLoading = false;
  double  _downloadProgress = 0;
  String  _downloadFile     = '';

  // Recording state
  bool    _isRecording  = false;
  bool    _saving       = false;
  bool    _done         = false;
  String  _liveWords    = '';
  int     _seconds      = 0;
  Timer?  _timer;
  StreamSubscription<SherpaResult>? _sherpaSub;


  @override
  void initState() {
    super.initState();
    _initModel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sherpaSub?.cancel();
    _sherpa.stop();
    _transcriptCtrl.dispose();
    ref.read(recordingStateProvider.notifier).reset();
    super.dispose();
  }

  // ── Model init ─────────────────────────────────────────────────────────────

  Future<void> _initModel() async {
    if (_sherpa.isInitialized) {
      setState(() => _modelReady = true);
      return;
    }
    setState(() => _modelLoading = true);
    try {
      final settings = await ref.read(speechSettingsProvider.future);
      final paths = await ModelManager.instance.ensureModel(
        settings.modelId,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _downloadProgress = p.totalFraction;
              _downloadFile     = p.fileName;
            });
          }
        },
      );
      await _sherpa.initialize(paths, settings);
      if (mounted) setState(() { _modelReady = true; _modelLoading = false; });
    } catch (e, st) {
      if (mounted) {
        setState(() => _modelLoading = false);
        showError(context, 'Failed to load speech model: $e',
            error: e, stack: st, tag: 'Voice');
      }
    }
  }

  // ── Recording ──────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (!_modelReady) return;
    setState(() {
      _liveWords = '';
      _done      = false;
      _seconds   = 0;
    });
    _transcriptCtrl.clear();

    final stream = _sherpa.startStreaming();

    _sherpaSub?.cancel();
    _sherpaSub = stream.listen(_onResult);

    setState(() => _isRecording = true);
    ref.read(recordingStateProvider.notifier).setRecording(0);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      ref.read(recordingStateProvider.notifier).setRecording(_seconds);
    });
  }

  void _onResult(SherpaResult result) {
    if (result.isFinal) {
      final existing  = _transcriptCtrl.text.trimRight();
      final separator = existing.isEmpty ? '' : ' ';
      _transcriptCtrl.text =
          '$existing$separator${result.text}';
      _transcriptCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _transcriptCtrl.text.length));
      setState(() => _liveWords = '');
    } else {
      setState(() => _liveWords = result.text);
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _sherpaSub?.cancel();
    _sherpaSub = null;

    final trailing = await _sherpa.stop();
    if (trailing.isNotEmpty) {
      final existing = _transcriptCtrl.text.trimRight();
      final sep      = existing.isEmpty ? '' : ' ';
      _transcriptCtrl.text = '$existing$sep$trailing';
    }

    setState(() {
      _isRecording = false;
      _done        = true;
      _liveWords   = '';
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
            caseId:       widget.caseId,
            durationSecs: _seconds,
            transcript:   transcript,
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
      if (mounted) {
        showError(context, 'Save failed: $e', error: e, stack: st, tag: 'App');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _discard() {
    _timer?.cancel();
    _sherpaSub?.cancel();
    _sherpaSub = null;
    _sherpa.stop();
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
              // Model loading indicator
              if (_modelLoading) ...[
                _DownloadBanner(
                    progress: _downloadProgress, fileName: _downloadFile),
                const SizedBox(height: 14),
              ],

              // Mic button + timer row
              Row(children: [
                GestureDetector(
                  onTap: _isRecording
                      ? _stopRecording
                      : (_modelReady ? _startRecording : null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? AppColors.error
                          : _modelReady
                              ? AppColors.navy
                              : AppColors.textTertiary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording
                                  ? AppColors.error
                                  : AppColors.navy)
                              .withValues(
                                  alpha: _isRecording ? 0.3 : 0.15),
                          blurRadius:  _isRecording ? 20 : 8,
                          spreadRadius: _isRecording ? 4  : 0,
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

              // Live words bubble
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

              // Transcript editor
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
    final m   = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  String _statusLabel() {
    if (_modelLoading)  return 'Loading speech model…';
    if (!_modelReady)   return 'Speech model unavailable';
    if (_isRecording)   return 'Listening — tap to stop';
    if (_done)          return 'Done — review and save';
    return 'Tap to start recording';
  }
}

// ── Download progress banner ──────────────────────────────────────────────────

class _DownloadBanner extends StatelessWidget {
  const _DownloadBanner({required this.progress, required this.fileName});
  final double progress;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.teal),
          ),
          const SizedBox(width: 8),
          Text(
            fileName.isEmpty
                ? 'Downloading speech model…'
                : 'Downloading $fileName',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.teal),
          ),
        ]),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.lightTeal,
          color: AppColors.teal,
          minHeight: 3,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
              'Tap the mic to record your first observation.\n'
              'Words appear as you speak.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ]),
        ),
      );
}
