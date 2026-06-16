// lib/features/capture/widgets/voice_note_card.dart

import 'package:flutter/material.dart';
import '../providers/voice_note_provider.dart';
import '../../../shared/theme/app_theme.dart';

class VoiceNoteCard extends StatefulWidget {
  const VoiceNoteCard({
    super.key,
    required this.note,
    required this.onDelete,
    required this.onRouteToInbox,
  });

  final VoiceNoteModel note;
  final VoidCallback onDelete;
  final VoidCallback onRouteToInbox;

  @override
  State<VoiceNoteCard> createState() => _VoiceNoteCardState();
}

class _VoiceNoteCardState extends State<VoiceNoteCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;

    return Card(
      child: Column(
        children: [
          // ── Main row ──────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Status icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _statusBg(note.status),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      _statusIcon(note.status),
                      color: _statusColor(note.status),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Transcript preview or status
                        Text(
                          note.hasTranscript
                              ? note.transcript!
                              : _statusText(note.status),
                          style: TextStyle(
                            fontSize: 13,
                            color: note.hasTranscript
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontStyle: note.hasTranscript
                                ? FontStyle.normal
                                : FontStyle.italic,
                            height: 1.3,
                          ),
                          maxLines: _expanded ? null : 2,
                          overflow: _expanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          if (note.recordedAt != null)
                            Text(
                              _formatTime(note.recordedAt!),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiary),
                            ),
                          if (note.durationSecs != null) ...[
                            const Text(' · ',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textTertiary)),
                            Text(
                              _formatDuration(note.durationSecs!),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiary),
                            ),
                          ],
                          if (note.routedTo != null) ...[
                            const Text(' · ',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textTertiary)),
                            const Text(
                              'Sent to inbox',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ),

                  // Expand chevron
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more,
                        color: AppColors.textTertiary, size: 20),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded actions ──────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(children: [
                // Route to inbox (only if has transcript and not already routed)
                if (note.hasTranscript && note.routedTo == null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onRouteToInbox,
                      icon: const Icon(Icons.inbox_outlined, size: 15),
                      label: const Text('Send to Inbox',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        side: const BorderSide(color: AppColors.teal),
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                if (note.hasTranscript && note.routedTo == null)
                  const SizedBox(width: 10),
                // Delete
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline,
                      size: 15, color: AppColors.error),
                  label: const Text('Delete',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete voice note?'),
        content: const Text('The audio and transcript will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Color _statusBg(String status) => switch (status) {
        'transcribed' => AppColors.lightTeal,
        'processing'  => AppColors.lightBlue,
        'routed'      => AppColors.lightGreen,
        'failed'      => AppColors.lightCoral,
        _             => AppColors.lightAmber,
      };

  Color _statusColor(String status) => switch (status) {
        'transcribed' => AppColors.teal,
        'processing'  => AppColors.midBlue,
        'routed'      => AppColors.green,
        'failed'      => AppColors.error,
        _             => AppColors.amber,
      };

  IconData _statusIcon(String status) => switch (status) {
        'transcribed' => Icons.text_snippet_outlined,
        'processing'  => Icons.hourglass_empty_outlined,
        'routed'      => Icons.check_circle_outline,
        'failed'      => Icons.error_outline,
        _             => Icons.mic_outlined,
      };

  String _statusText(String status) => switch (status) {
        'processing' => 'Transcription in progress...',
        'failed'     => 'Transcription failed — tap to retry',
        _            => 'No transcript available',
      };

  String _formatTime(DateTime dt) {
    final d   = dt.day.toString().padLeft(2, '0');
    final m   = dt.month.toString().padLeft(2, '0');
    final h   = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  }

  String _formatDuration(int s) {
    final m   = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}
