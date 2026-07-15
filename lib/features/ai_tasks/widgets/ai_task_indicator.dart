// lib/features/ai_tasks/widgets/ai_task_indicator.dart
//
// Small app-bar button surfacing aiTasksProvider — "somewhere a small
// button where we can check the status of the AI calls... a little bit
// like a task explorer" (15 July 2026). Dropped into BackAppBar (47 call
// sites) and case_home_screen.dart's own app bar, so it's visible from
// nearly every screen in the app regardless of which one kicked off a
// given AI call.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ai_tasks_provider.dart';
import 'ai_task_panel.dart';

class AiTaskIndicator extends ConsumerWidget {
  const AiTaskIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(aiTasksProvider);
    final runningCount =
        tasks.where((t) => t.status == AiTaskStatus.running).length;
    final hasFailure = tasks.any((t) => t.status == AiTaskStatus.failed);

    final icon = IconButton(
      icon: const Icon(Icons.auto_awesome),
      tooltip: runningCount > 0
          ? '$runningCount AI ${runningCount == 1 ? 'task' : 'tasks'} running'
          : 'AI activity',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AiTaskPanel(),
      ),
    );

    if (runningCount == 0 && !hasFailure) return icon;

    return Badge(
      label: runningCount > 0 ? Text('$runningCount') : null,
      // A lingering failure with nothing currently running still needs to
      // catch the eye — small red dot, no count, since "how many failed
      // a moment ago" isn't as useful as "something needs a look".
      smallSize: runningCount == 0 ? 8 : null,
      backgroundColor: runningCount > 0 ? null : Colors.red,
      child: icon,
    );
  }
}
