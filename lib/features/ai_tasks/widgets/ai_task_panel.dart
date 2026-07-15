// lib/features/ai_tasks/widgets/ai_task_panel.dart
//
// The "task explorer" itself — opened from AiTaskIndicator. Lists every
// tracked AI call: running first (oldest first, so the one closest to
// finishing sits at top), then recently completed/failed. Refreshes its own
// elapsed/remaining text once a second while open; the underlying provider
// doesn't tick on its own (that would rebuild every screen holding an
// AiTaskIndicator once a second even with nothing running).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../providers/ai_tasks_provider.dart';

class AiTaskPanel extends ConsumerStatefulWidget {
  const AiTaskPanel({super.key});

  @override
  ConsumerState<AiTaskPanel> createState() => _AiTaskPanelState();
}

class _AiTaskPanelState extends ConsumerState<AiTaskPanel> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = [...ref.watch(aiTasksProvider)];
    tasks.sort((a, b) {
      // Running first; within each group, oldest-started first (closest to
      // finishing, or longest-failed) sits at the top.
      final aRunning = a.status == AiTaskStatus.running;
      final bRunning = b.status == AiTaskStatus.running;
      if (aRunning != bRunning) return aRunning ? -1 : 1;
      return a.startedAt.compareTo(b.startedAt);
    });

    return SafeArea(
      child: Material(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 16, color: AppColors.midBlue),
                  const SizedBox(width: 8),
                  const Text('AI Activity',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: tasks.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No AI activity right now.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (_, i) => _TaskRow(
                          task: tasks[i],
                          onDismiss: () => ref
                              .read(aiTasksProvider.notifier)
                              .dismiss(tasks[i].id),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onDismiss});
  final AiTaskModel task;
  final VoidCallback onDismiss;

  String _fmt(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    final Widget statusIcon = switch (task.status) {
      AiTaskStatus.running => const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      AiTaskStatus.completed =>
        const Icon(Icons.check_circle, size: 16, color: AppColors.success),
      AiTaskStatus.failed =>
        const Icon(Icons.error_outline, size: 16, color: AppColors.error),
    };

    final String timeText = switch (task.status) {
      AiTaskStatus.running => task.remaining == Duration.zero
          ? 'any moment now…'
          : '~${_fmt(task.remaining!)} remaining',
      AiTaskStatus.completed => 'done in ${_fmt(task.elapsed)}',
      AiTaskStatus.failed => 'failed after ${_fmt(task.elapsed)}',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: statusIcon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(task.label,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                  if (task.caseLabel != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(task.caseLabel!,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(timeText,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: task.status == AiTaskStatus.failed
                          ? AppColors.error
                          : AppColors.textTertiary)),
              if (task.status == AiTaskStatus.failed &&
                  task.errorMessage != null) ...[
                const SizedBox(height: 2),
                Text(task.errorMessage!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
        if (task.status != AiTaskStatus.running)
          IconButton(
            icon: const Icon(Icons.close, size: 15),
            color: AppColors.textTertiary,
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
          ),
      ],
    );
  }
}
