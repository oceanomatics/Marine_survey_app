// lib/features/interviews/screens/interview_detail_screen.dart
//
// Post-processing for a saved interview (14 July 2026 walkthrough —
// "derive summary/cues after the fact"). Plays back the raw audio if one
// was captured, lets the surveyor touch up the transcript, and generates
// an AI summary + candidate follow-up cues on demand. Also fills a
// previously dead route: the interview list linked here but nothing was
// registered for it.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:intl/intl.dart';
import '../models/interview_model.dart';
import '../providers/interview_provider.dart';
import '../../../core/api/claude_api.dart';
import '../../ai_tasks/providers/ai_tasks_provider.dart';
import '../../../core/api/supabase_client.dart';
import '../../surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';

class InterviewDetailScreen extends ConsumerStatefulWidget {
  const InterviewDetailScreen(
      {super.key, required this.caseId, required this.interviewId});
  final String caseId;
  final String interviewId;

  @override
  ConsumerState<InterviewDetailScreen> createState() =>
      _InterviewDetailScreenState();
}

class _InterviewDetailScreenState extends ConsumerState<InterviewDetailScreen> {
  final _player = AudioPlayer();
  late final TextEditingController _transcriptCtrl;

  bool _editingTranscript = false;
  bool _savingTranscript = false;
  bool _summarizing = false;
  bool _audioReady = false;
  bool _audioPlaying = false;
  StreamSubscription<bool>? _playingSub;

  InterviewModel? get _interview {
    final list = ref
        .read(interviewsProvider(widget.caseId))
        .valueOrNull;
    if (list == null) return null;
    for (final m in list) {
      if (m.interviewId == widget.interviewId) return m;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _transcriptCtrl = TextEditingController();
    _playingSub = _player.playingStream.listen((p) {
      if (mounted) setState(() => _audioPlaying = p);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAudio());
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _player.dispose();
    _transcriptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAudio() async {
    final path = _interview?.audioPath;
    if (path == null) return;
    try {
      final url = await SupabaseService.getSignedUrl('interview-audio', path);
      await _player.setUrl(url);
      if (mounted) setState(() => _audioReady = true);
    } catch (_) {
      // No playback available — the transcript still stands alone.
    }
  }

  void _toggleAudio() {
    if (_audioPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  Future<void> _saveTranscript() async {
    final interview = _interview;
    if (interview == null) return;
    setState(() => _savingTranscript = true);
    try {
      await ref.read(interviewsProvider(widget.caseId).notifier).updateInterview(
            interview.copyWith(transcript: _transcriptCtrl.text.trim()),
          );
      if (mounted) {
        setState(() => _editingTranscript = false);
        showSavedToast(context, label: 'Transcript updated');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingTranscript = false);
    }
  }

  Future<void> _generateSummary() async {
    final interview = _interview;
    if (interview == null || interview.transcript.trim().isEmpty) return;
    setState(() => _summarizing = true);
    try {
      final result = await ref.read(aiTasksProvider.notifier).run(
            label: 'Summarising "${interview.displayTitle}"',
            caseId: widget.caseId,
            estimate: const Duration(seconds: 20),
            action: () => ClaudeApi.summarizeInterview(
              transcript: interview.transcript,
              caseId: widget.caseId,
            ),
          );
      final summary = (result['summary'] as String?)?.trim();
      final cues = (result['cues'] as List?)?.whereType<String>().toList() ?? [];

      if (summary != null && summary.isNotEmpty) {
        await ref
            .read(interviewsProvider(widget.caseId).notifier)
            .updateInterview(interview.copyWith(summary: summary));
      }

      for (final cue in cues) {
        if (cue.trim().isEmpty) continue;
        await ref.read(surveyorNotesProvider(widget.caseId).notifier).add(
              caseId: widget.caseId,
              content: cue.trim(),
              caseSection: null,
              source: 'Interview: ${interview.displayTitle}',
              pendingReview: true,
            );
      }

      if (mounted) {
        showSavedToast(
          context,
          label: cues.isEmpty
              ? 'Summary generated'
              : 'Summary generated · ${cues.length} cue${cues.length == 1 ? '' : 's'} added to Unallocated',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Summary failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete interview?'),
        content: const Text(
            'The transcript and recording will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(interviewsProvider(widget.caseId).notifier)
        .delete(widget.interviewId);
    if (mounted) context.go('/cases/${widget.caseId}/interviews');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(interviewsProvider(widget.caseId));
    final interview = _interview;

    if (interview == null) {
      return const Scaffold(
        appBar: BackAppBar(title: Text('Interview')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_editingTranscript && _transcriptCtrl.text != interview.transcript) {
      _transcriptCtrl.text = interview.transcript;
    }

    final df = DateFormat('d MMM yyyy – HH:mm');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: Text(interview.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Delete',
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(df.format(interview.createdAt.toLocal()),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (interview.participants.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: interview.participants
                  .map((p) => Chip(
                        label: Text(p.displayName, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.navy.withValues(alpha: 0.06),
                      ))
                  .toList(),
            ),
          ],

          if (interview.audioPath != null) ...[
            const SizedBox(height: 16),
            _AudioBar(
              ready: _audioReady,
              playing: _audioPlaying,
              onToggle: _toggleAudio,
            ),
          ],

          const SizedBox(height: 20),
          const _SectionLabel(label: 'Summary', icon: Icons.auto_awesome_outlined),
          const SizedBox(height: 8),
          if (interview.summary != null && interview.summary!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(interview.summary!,
                  style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary)),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _summarizing ? null : _generateSummary,
              icon: _summarizing
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_outlined, size: 16),
              label: Text(interview.summary == null
                  ? 'Generate summary & cues'
                  : 'Regenerate summary & cues'),
            ),
          ),

          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionLabel(label: 'Transcript', icon: Icons.article_outlined),
              if (!_editingTranscript)
                TextButton(
                  onPressed: () => setState(() => _editingTranscript = true),
                  child: const Text('Edit', style: TextStyle(fontSize: 12)),
                )
              else
                _savingTranscript
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : TextButton(
                        onPressed: _saveTranscript,
                        child: const Text('Save', style: TextStyle(fontSize: 12)),
                      ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: _editingTranscript
                ? TextField(
                    controller: _transcriptCtrl,
                    maxLines: null,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                    decoration: const InputDecoration(border: InputBorder.none),
                  )
                : Text(
                    interview.transcript.isEmpty ? 'No transcript' : interview.transcript,
                    style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: AppColors.textTertiary)),
      ]);
}

class _AudioBar extends StatelessWidget {
  const _AudioBar({required this.ready, required this.playing, required this.onToggle});
  final bool ready;
  final bool playing;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: ready ? onToggle : null,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ready ? AppColors.navy : AppColors.border,
              ),
              child: Icon(
                ready
                    ? (playing ? Icons.pause : Icons.play_arrow)
                    : Icons.hourglass_empty,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            ready ? 'Original recording' : 'Loading recording…',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ]),
      );
}
