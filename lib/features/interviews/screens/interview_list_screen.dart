// lib/features/interviews/screens/interview_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/interview_model.dart';
import '../providers/interview_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

class InterviewListScreen extends ConsumerWidget {
  const InterviewListScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(interviewsProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Interviews'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New interview',
            onPressed: () => context.go('/cases/$caseId/interviews/record'),
          ),
        ],
      ),
      body: async.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading interviews…'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (interviews) => interviews.isEmpty
            ? _EmptyState(
                onStart: () =>
                    context.go('/cases/$caseId/interviews/record'),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: interviews.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _InterviewCard(
                  interview: interviews[i],
                  onTap: () => context.go(
                      '/cases/$caseId/interviews/${interviews[i].interviewId}'),
                  onDelete: () => ref
                      .read(interviewsProvider(caseId).notifier)
                      .delete(interviews[i].interviewId),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/cases/$caseId/interviews/record'),
        icon: const Icon(Icons.mic),
        label: const Text('Record Interview'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ── Interview card ─────────────────────────────────────────────────────────

class _InterviewCard extends StatelessWidget {
  const _InterviewCard({
    required this.interview,
    required this.onTap,
    required this.onDelete,
  });

  final InterviewModel interview;
  final VoidCallback   onTap;
  final VoidCallback   onDelete;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy – HH:mm');
    final duration = interview.durationSecs != null
        ? _formatDuration(interview.durationSecs!)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.record_voice_over_outlined,
                      size: 20, color: AppColors.navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        interview.displayTitle,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        df.format(interview.createdAt.toLocal()),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                      if (interview.participants.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          interview.participants
                              .map((p) => p.fullName)
                              .join(', '),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (duration != null)
                      Text(duration,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary)),
                    if (interview.filedToVault == true) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Filed',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success)),
                      ),
                    ],
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _confirmDelete(context),
                      child: const Icon(Icons.delete_outline,
                          size: 16, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete interview?'),
        content: const Text(
            'The transcript and recording will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                onDelete();
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete')),
        ],
      ),
    );
  }

  String _formatDuration(int s) {
    final m   = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.record_voice_over_outlined,
                  size: 32, color: AppColors.navy),
            ),
            const SizedBox(height: 16),
            const Text('No interviews recorded',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Record interviews with crew, officers, or other parties.\n'
              'Transcripts are automatically generated and filed to the case.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.mic, size: 16),
              label: const Text('Start Recording'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white),
            ),
          ]),
        ),
      );
}
