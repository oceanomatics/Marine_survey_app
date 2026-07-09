// lib/features/interviews/screens/record_interview_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/interview_model.dart';
import '../providers/interview_provider.dart';
import '../../parties/models/party_model.dart';
import '../../parties/providers/parties_provider.dart';
import '../../../core/services/model_manager.dart';
import '../../../core/services/sherpa_service.dart';
import '../../../features/settings/providers/speech_settings_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';

class RecordInterviewScreen extends ConsumerStatefulWidget {
  const RecordInterviewScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<RecordInterviewScreen> createState() =>
      _RecordInterviewScreenState();
}

class _RecordInterviewScreenState
    extends ConsumerState<RecordInterviewScreen> {
  final _sherpa      = SherpaService.instance;
  final _titleCtrl   = TextEditingController();
  final _transcriptCtrl = TextEditingController();

  // Model
  bool   _modelReady    = false;
  bool   _modelLoading  = false;
  double _dlProgress    = 0;
  String _dlFile        = '';

  // Recording
  bool   _isRecording   = false;
  bool   _done          = false;
  bool   _saving        = false;
  String _liveWords     = '';
  int    _seconds       = 0;
  Timer? _timer;
  StreamSubscription<SherpaResult>? _sherpaSub;

  // Participants
  final List<InterviewParticipant> _participants = [];

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
    _titleCtrl.dispose();
    _transcriptCtrl.dispose();
    super.dispose();
  }

  // ── Model ──────────────────────────────────────────────────────────────────

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
              _dlProgress = p.totalFraction;
              _dlFile     = p.fileName;
            });
          }
        },
      );
      await _sherpa.initialize(paths, settings);
      if (mounted) setState(() { _modelReady = true; _modelLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _modelLoading = false);
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

    final stream = _sherpa.startStreaming();
    _sherpaSub?.cancel();
    _sherpaSub = stream.listen(_onResult);

    setState(() => _isRecording = true);
    _timer = Timer.periodic(const Duration(seconds: 1),
        (_) => setState(() => _seconds++));
  }

  void _onResult(SherpaResult result) {
    if (result.isFinal) {
      final existing  = _transcriptCtrl.text.trimRight();
      final sep       = existing.isEmpty ? '' : ' ';
      _transcriptCtrl.text = '$existing$sep${result.text}';
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
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final transcript = _transcriptCtrl.text.trim();
    if (transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to save yet')));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(interviewsProvider(widget.caseId).notifier).save(
            caseId:       widget.caseId,
            participants: _participants,
            transcript:   transcript,
            durationSecs: _seconds,
            title:        _titleCtrl.text.trim().isEmpty
                ? null
                : _titleCtrl.text.trim(),
          );
      if (mounted) {
        showSavedToast(context, label: 'Interview saved');
        context.go('/cases/${widget.caseId}/interviews');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Participant picker ─────────────────────────────────────────────────────

  void _showParticipantPicker() {
    final contactsAsync =
        ref.read(assuredContactsProvider(widget.caseId));
    final contacts = contactsAsync.valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ParticipantPickerSheet(
        contacts:    contacts,
        selected:    _participants,
        onToggle:    _toggleParticipant,
        caseId:      widget.caseId,
      ),
    );
  }

  void _toggleParticipant(AssuredContactModel contact) {
    setState(() {
      final idx = _participants
          .indexWhere((p) => p.contactId == contact.contactId);
      if (idx >= 0) {
        _participants.removeAt(idx);
      } else {
        _participants.add(InterviewParticipant(
          contactId: contact.contactId,
          fullName:  contact.fullName,
          roleTitle: contact.roleTitle,
          company:   contact.company,
        ));
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Preload contacts for participant picker
    ref.watch(assuredContactsProvider(widget.caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: const Text('Record Interview'),
        actions: [
          if (_done)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Model download banner ──────────────────────────────────
            if (_modelLoading) ...[
              _DownloadBanner(progress: _dlProgress, fileName: _dlFile),
              const SizedBox(height: 16),
            ],

            // ── Title (optional) ───────────────────────────────────────
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Interview title (optional)',
                hintText: 'e.g. Chief Officer – damage walkthrough',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Participants ───────────────────────────────────────────
            _SectionLabel(
              label: 'Participants',
              action: TextButton.icon(
                onPressed: _showParticipantPicker,
                icon: const Icon(Icons.person_add_outlined, size: 14),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4)),
              ),
            ),
            if (_participants.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'No participants selected — add from case contacts',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _participants
                    .map((p) => _ParticipantChip(
                          participant: p,
                          onRemove: () =>
                              setState(() => _participants.remove(p)),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 20),

            // ── Recorder ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(children: [
                    GestureDetector(
                      onTap: _isRecording
                          ? _stopRecording
                          : (_modelReady ? _startRecording : null),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 64,
                        height: 64,
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
                                      alpha: _isRecording ? 0.3 : 0.12),
                              blurRadius:  _isRecording ? 18 : 6,
                              spreadRadius: _isRecording ? 3  : 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDuration(_seconds),
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          ),
                          Text(
                            _statusLabel(),
                            style: TextStyle(
                              fontSize: 11,
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

                  // Live words
                  if (_isRecording && _liveWords.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                AppColors.midBlue.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _liveWords,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.midBlue,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Transcript ────────────────────────────────────────────
            if (_done || _transcriptCtrl.text.isNotEmpty) ...[
              const _SectionLabel(label: 'Transcript'),
              const SizedBox(height: 6),
              TextField(
                controller: _transcriptCtrl,
                maxLines: null,
                minLines: 6,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Transcript builds here as you speak…',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 16),
                  label: Text(_saving ? 'Saving…' : 'Save Interview'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
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
    if (_isRecording)   return 'Recording — tap to stop';
    if (_done)          return 'Done — review and save';
    return 'Tap microphone to start';
  }
}

// ── Download banner ────────────────────────────────────────────────────────

class _DownloadBanner extends StatelessWidget {
  const _DownloadBanner({required this.progress, required this.fileName});
  final double progress;
  final String fileName;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.lightTeal.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.teal)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName.isEmpty
                      ? 'Downloading speech model…'
                      : 'Downloading $fileName',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal)),
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
        ),
      );
}

// ── Participant chip ───────────────────────────────────────────────────────

class _ParticipantChip extends StatelessWidget {
  const _ParticipantChip(
      {required this.participant, required this.onRemove});
  final InterviewParticipant participant;
  final VoidCallback          onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.navy.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_outline, size: 12, color: AppColors.navy),
          const SizedBox(width: 4),
          Text(participant.fullName,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.navy,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 12, color: AppColors.navy),
          ),
        ]),
      );
}

// ── Participant picker sheet ───────────────────────────────────────────────

class _ParticipantPickerSheet extends StatelessWidget {
  const _ParticipantPickerSheet({
    required this.contacts,
    required this.selected,
    required this.onToggle,
    required this.caseId,
  });

  final List<AssuredContactModel>    contacts;
  final List<InterviewParticipant>   selected;
  final void Function(AssuredContactModel) onToggle;
  final String caseId;

  @override
  Widget build(BuildContext context) {
    final selectedIds =
        selected.map((p) => p.contactId).toSet();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Text('Add Participants',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 8),
            if (contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No contacts found.\nAdd contacts in the Parties section first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                itemCount: contacts.length,
                itemBuilder: (_, i) {
                  final c   = contacts[i];
                  final sel = selectedIds.contains(c.contactId);
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.navy
                          .withValues(alpha: sel ? 0.18 : 0.07),
                      child: Text(
                        c.fullName.isNotEmpty
                            ? c.fullName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.navy
                                .withValues(alpha: sel ? 1 : 0.5)),
                      ),
                    ),
                    title: Text(c.fullName,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: c.roleTitle != null
                        ? Text(c.roleTitle!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary))
                        : null,
                    trailing: sel
                        ? const Icon(Icons.check_circle,
                            color: AppColors.teal, size: 20)
                        : const Icon(Icons.circle_outlined,
                            color: AppColors.textTertiary, size: 20),
                    onTap: () => onToggle(c),
                    dense: true,
                  );
                },
              ),
            SizedBox(
                height: 16 +
                    MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.action});
  final String  label;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5)),
          const Spacer(),
          if (action != null) action!,
        ],
      );
}

// ── Pulse dot ─────────────────────────────────────────────────────────────

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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: _anim.value),
            shape: BoxShape.circle,
          ),
        ),
      );
}
