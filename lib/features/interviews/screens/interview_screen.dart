// lib/features/interviews/screens/interview_screen.dart

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
import '../../settings/providers/speech_settings_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';

class InterviewScreen extends ConsumerStatefulWidget {
  const InterviewScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends ConsumerState<InterviewScreen> {
  final _sherpa     = SherpaService.instance;
  final _scrollCtrl = ScrollController();
  final _editCtrl   = TextEditingController();

  bool   _modelReady   = false;
  bool   _modelLoading = false;
  double _dlProgress   = 0;
  String _dlFile       = '';

  bool   _isRecording  = false;
  bool   _done         = false;
  bool   _saving       = false;
  String _livePartial  = '';
  int    _seconds      = 0;
  Timer? _timer;
  StreamSubscription<SherpaResult>? _sherpaSub;

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
    _scrollCtrl.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  // ── Model ─────────────────────────────────────────────────────────────────

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

  // ── Recording ─────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (!_modelReady) return;
    _editCtrl.clear();
    setState(() { _livePartial = ''; _done = false; _seconds = 0; });

    _sherpaSub?.cancel();
    _sherpaSub = _sherpa.startStreaming().listen(_onResult);

    setState(() => _isRecording = true);
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => _seconds++));
  }

  void _onResult(SherpaResult result) {
    if (result.isFinal) {
      final existing = _editCtrl.text.trimRight();
      _editCtrl.text =
          existing.isEmpty ? result.text : '$existing ${result.text}';
      setState(() => _livePartial = '');
      _scrollToBottom();
    } else {
      setState(() => _livePartial = result.text);
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _sherpaSub?.cancel();
    _sherpaSub = null;
    final trailing = await _sherpa.stop();
    if (trailing.isNotEmpty) {
      final existing = _editCtrl.text.trimRight();
      _editCtrl.text =
          existing.isEmpty ? trailing : '$existing $trailing';
    }
    setState(() { _isRecording = false; _livePartial = ''; _done = true; });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final text = _editCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nothing to save')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(interviewsProvider(widget.caseId).notifier).save(
            caseId:       widget.caseId,
            participants: _participants,
            transcript:   text,
            durationSecs: _seconds,
          );
      if (mounted) {
        showSavedToast(context, label: 'Interview saved');
        _reset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    _editCtrl.clear();
    setState(() {
      _isRecording = false;
      _done        = false;
      _livePartial = '';
      _seconds     = 0;
    });
  }

  // ── Participants ──────────────────────────────────────────────────────────

  void _showParticipantPicker() {
    final contacts =
        ref.read(assuredContactsProvider(widget.caseId)).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ParticipantSheet(
        contacts: contacts,
        selected: _participants,
        onToggle: _toggleParticipant,
      ),
    );
  }

  void _toggleParticipant(AssuredContactModel c) {
    setState(() {
      final idx = _participants.indexWhere((p) => p.contactId == c.contactId);
      if (idx >= 0) {
        _participants.removeAt(idx);
      } else {
        _participants.add(InterviewParticipant(
          contactId: c.contactId,
          fullName:  c.fullName,
          roleTitle: c.roleTitle,
          company:   c.company,
        ));
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(assuredContactsProvider(widget.caseId));
    final hasText = _editCtrl.text.isNotEmpty || _livePartial.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: Text(_isRecording
            ? 'Recording…'
            : _done
                ? 'Review & Save'
                : 'Interview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_outlined, size: 20),
            tooltip: 'Past interviews',
            onPressed: () => context.go('/cases/${widget.caseId}/interviews'),
          ),
          if (_done && hasText)
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)),
                  )
                : TextButton(
                    onPressed: _save,
                    child: const Text('Save',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
        ],
      ),
      body: Column(children: [
        // ── Download progress ────────────────────────────────────────────
        if (_modelLoading) _DownloadBanner(progress: _dlProgress, fileName: _dlFile),

        // ── Recording status strip ───────────────────────────────────────
        _StatusStrip(
          isRecording:  _isRecording,
          done:         _done,
          modelReady:   _modelReady,
          modelLoading: _modelLoading,
          seconds:      _seconds,
        ),

        // ── Participant bar ──────────────────────────────────────────────
        _ParticipantsBar(
          participants: _participants,
          onAdd:    _showParticipantPicker,
          onRemove: (p) => setState(() => _participants.remove(p)),
        ),

        const Divider(height: 1),

        // ── Transcript ───────────────────────────────────────────────────
        Expanded(
          child: _TranscriptView(
            scrollCtrl:  _scrollCtrl,
            editCtrl:    _editCtrl,
            livePartial: _livePartial,
            isRecording: _isRecording,
            done:        _done,
          ),
        ),

        // ── Mic bar ──────────────────────────────────────────────────────
        _MicBar(
          isRecording: _isRecording,
          done:        _done,
          modelReady:  _modelReady,
          modelLoading: _modelLoading,
          onStart:     _startRecording,
          onStop:      _stopRecording,
          onDiscard:   _done ? _reset : null,
        ),
      ]),
    );
  }
}

// ── Status strip ──────────────────────────────────────────────────────────

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.isRecording,
    required this.done,
    required this.modelReady,
    required this.modelLoading,
    required this.seconds,
  });
  final bool isRecording, done, modelReady, modelLoading;
  final int  seconds;

  @override
  Widget build(BuildContext context) {
    Color  bg;
    Color  fg;
    String label;
    IconData icon;

    if (isRecording) {
      bg    = AppColors.lightCoral;
      fg    = AppColors.error;
      icon  = Icons.fiber_manual_record;
      label = 'Recording  ${_fmt(seconds)}';
    } else if (done) {
      bg    = AppColors.lightTeal;
      fg    = AppColors.teal;
      icon  = Icons.check_circle_outline;
      label = 'Stopped · ${_fmt(seconds)} · Review and save or discard';
    } else if (modelLoading) {
      bg    = AppColors.lightAmber;
      fg    = AppColors.amber;
      icon  = Icons.downloading_outlined;
      label = 'Downloading speech model…';
    } else if (modelReady) {
      bg    = AppColors.lightBlue;
      fg    = AppColors.midBlue;
      icon  = Icons.mic_none_outlined;
      label = 'Ready — tap the microphone to start';
    } else {
      bg    = AppColors.surface;
      fg    = AppColors.textTertiary;
      icon  = Icons.warning_amber_outlined;
      label = 'Speech model unavailable';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: fg)),
      ]),
    );
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

// ── Participant bar ───────────────────────────────────────────────────────

class _ParticipantsBar extends StatelessWidget {
  const _ParticipantsBar({
    required this.participants,
    required this.onAdd,
    required this.onRemove,
  });
  final List<InterviewParticipant>         participants;
  final VoidCallback                       onAdd;
  final void Function(InterviewParticipant) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        // "Add" pill
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        AppColors.lightBlue,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.midBlue.withValues(alpha: 0.3)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_add_outlined, size: 13, color: AppColors.midBlue),
              SizedBox(width: 5),
              Text('Add',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.midBlue)),
            ]),
          ),
        ),

        const SizedBox(width: 8),

        if (participants.isEmpty)
          const Text('No participants',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic))
        else
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount:       participants.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final p = participants[i];
                return _ParticipantChip(
                    label: p.fullName, onRemove: () => onRemove(p));
              },
            ),
          ),
      ]),
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  const _ParticipantChip({required this.label, required this.onRemove});
  final String       label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 10, right: 6, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color:        AppColors.navy.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.navy.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_outline, size: 11, color: AppColors.navy),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navy)),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close,
                size: 12, color: AppColors.navy.withValues(alpha: 0.5)),
          ),
        ]),
      );
}

// ── Transcript view ───────────────────────────────────────────────────────

class _TranscriptView extends StatelessWidget {
  const _TranscriptView({
    required this.scrollCtrl,
    required this.editCtrl,
    required this.livePartial,
    required this.isRecording,
    required this.done,
  });
  final ScrollController      scrollCtrl;
  final TextEditingController editCtrl;
  final String livePartial;
  final bool   isRecording, done;

  @override
  Widget build(BuildContext context) {
    // Post-recording: editable field
    if (done) {
      return Container(
        color: AppColors.background,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.edit_outlined,
                  size: 12, color: AppColors.textTertiary),
              SizedBox(width: 6),
              Text('Transcript  ·  edit if needed',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.3)),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller:  editCtrl,
                maxLines:    null,
                expands:     true,
                style: const TextStyle(
                    fontSize: 15,
                    color:    AppColors.textPrimary,
                    height:   1.75),
                decoration: const InputDecoration(
                  hintText:  'Transcript is empty',
                  border:    InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      );
    }

    // Idle empty state
    if (editCtrl.text.isEmpty && livePartial.isEmpty) {
      return Container(
        color: AppColors.background,
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.format_quote_outlined,
                size: 52,
                color: AppColors.border),
            SizedBox(height: 14),
            Text('Transcript appears here\nas you speak',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color:  AppColors.textTertiary,
                    height: 1.6)),
          ]),
        ),
      );
    }

    // Live scroll view
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Committed text
            if (editCtrl.text.isNotEmpty)
              Text(
                editCtrl.text,
                style: const TextStyle(
                    fontSize: 16,
                    color:  AppColors.textPrimary,
                    height: 1.8,
                    letterSpacing: 0.1),
              ),

            // Live partial
            if (livePartial.isNotEmpty) ...[
              if (editCtrl.text.isNotEmpty) const SizedBox(height: 2),
              _LiveText(text: livePartial),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Live partial with blinking cursor ─────────────────────────────────────

class _LiveText extends StatefulWidget {
  const _LiveText({required this.text});
  final String text;

  @override
  State<_LiveText> createState() => _LiveTextState();
}

class _LiveTextState extends State<_LiveText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 530))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                widget.text,
                style: const TextStyle(
                    fontSize: 16,
                    color:      AppColors.midBlue,
                    height:     1.8,
                    fontStyle:  FontStyle.italic,
                    letterSpacing: 0.1),
              ),
            ),
            const SizedBox(width: 2),
            Opacity(
              opacity: _ctrl.value,
              child: Container(
                width: 2, height: 18,
                decoration: BoxDecoration(
                  color: AppColors.midBlue,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Mic bar ───────────────────────────────────────────────────────────────

class _MicBar extends StatelessWidget {
  const _MicBar({
    required this.isRecording,
    required this.done,
    required this.modelReady,
    required this.modelLoading,
    required this.onStart,
    required this.onStop,
    this.onDiscard,
  });
  final bool isRecording, done, modelReady, modelLoading;
  final VoidCallback  onStart, onStop;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(24, 14, 24, 14 + bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: discard (post-recording)
          SizedBox(
            width: 68,
            child: onDiscard != null
                ? TextButton(
                    onPressed: onDiscard,
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: EdgeInsets.zero),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 20),
                        SizedBox(height: 3),
                        Text('Discard', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Centre: big mic button
          _MicButton(
            isRecording:  isRecording,
            modelReady:   modelReady,
            modelLoading: modelLoading,
            onTap: isRecording ? onStop : onStart,
          ),

          // Right: placeholder spacer
          const SizedBox(width: 68),
        ],
      ),
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton({
    required this.isRecording,
    required this.modelReady,
    required this.modelLoading,
    required this.onTap,
  });
  final bool         isRecording, modelReady, modelLoading;
  final VoidCallback onTap;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void didUpdateWidget(_MicButton old) {
    super.didUpdateWidget(old);
    if (widget.isRecording && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isRecording) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final active = widget.isRecording;
    final color  = active
        ? AppColors.error
        : widget.modelReady
            ? AppColors.navy
            : AppColors.textTertiary;

    return GestureDetector(
      onTap: (widget.modelReady && !widget.modelLoading) ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Transform.scale(
          scale: active
              ? 1.0 + _pulse.value * 0.10
              : 1.0,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 70, height: 70,
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            color:  color,
            boxShadow: [
              BoxShadow(
                color:       color.withValues(alpha: active ? 0.35 : 0.18),
                blurRadius:  active ? 22 : 10,
                spreadRadius: active ? 4  : 0,
              ),
            ],
          ),
          child: widget.modelLoading
              ? const Padding(
                  padding: EdgeInsets.all(22),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Icon(
                  active ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 28,
                ),
        ),
      ),
    );
  }
}

// ── Download banner ────────────────────────────────────────────────────────

class _DownloadBanner extends StatelessWidget {
  const _DownloadBanner({required this.progress, required this.fileName});
  final double progress;
  final String fileName;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.lightAmber,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(children: [
          Row(children: [
            const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.amber)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName.isEmpty
                    ? 'Downloading speech model (one-time)…'
                    : 'Downloading $fileName',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.amber),
              ),
            ),
            Text('${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.amber)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value:           progress,
              backgroundColor: AppColors.lightAmber,
              color:           AppColors.amber,
              minHeight:       3,
            ),
          ),
        ]),
      );
}

// ── Participant picker sheet ───────────────────────────────────────────────

class _ParticipantSheet extends StatelessWidget {
  const _ParticipantSheet({
    required this.contacts,
    required this.selected,
    required this.onToggle,
  });
  final List<AssuredContactModel>          contacts;
  final List<InterviewParticipant>         selected;
  final void Function(AssuredContactModel) onToggle;

  @override
  Widget build(BuildContext context) {
    final selectedIds = selected.map((p) => p.contactId).toSet();

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
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Add Participants',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 6),
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
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  itemCount: contacts.length,
                  itemBuilder: (_, i) {
                    final c   = contacts[i];
                    final sel = selectedIds.contains(c.contactId);
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 17,
                        backgroundColor: AppColors.navy
                            .withValues(alpha: sel ? 0.14 : 0.06),
                        child: Text(
                          c.fullName.isNotEmpty
                              ? c.fullName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy
                                  .withValues(alpha: sel ? 1 : 0.4)),
                        ),
                      ),
                      title: Text(c.fullName,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: c.roleTitle != null
                          ? Text(c.roleTitle!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary))
                          : null,
                      trailing: sel
                          ? const Icon(Icons.check_circle,
                              color: AppColors.teal, size: 22)
                          : const Icon(Icons.circle_outlined,
                              color: AppColors.border, size: 22),
                      onTap: () => onToggle(c),
                      dense: true,
                    );
                  },
                ),
              ),
            SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
