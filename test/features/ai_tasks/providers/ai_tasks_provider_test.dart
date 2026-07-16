import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/core/api/claude_api.dart'
    show aiTaskCaseIdZoneKey;
import 'package:marine_survey_app/features/ai_tasks/providers/ai_tasks_provider.dart';

void main() {
  group('AiTasksNotifier.run — ambient caseId zone (§25 usage attribution)', () {
    test('the caseId is readable via Zone.current inside the action, '
        'including across an async gap', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiTasksProvider.notifier);

      String? seenBefore;
      String? seenAfterAwait;
      await notifier.run(
        label: 'Zone test',
        caseId: 'case-42',
        action: () async {
          seenBefore = Zone.current[aiTaskCaseIdZoneKey] as String?;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          seenAfterAwait = Zone.current[aiTaskCaseIdZoneKey] as String?;
        },
      );

      expect(seenBefore, 'case-42');
      expect(seenAfterAwait, 'case-42',
          reason: 'zone value must survive async gaps (Dio interceptor '
              'runs after an await)');
    });

    test('no zone value leaks when caseId is null', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiTasksProvider.notifier);

      String? seen = 'sentinel';
      await notifier.run(
        label: 'No-case test',
        action: () async {
          seen = Zone.current[aiTaskCaseIdZoneKey] as String?;
        },
      );
      expect(seen, isNull);
    });
  });

  group('AiTasksNotifier.run', () {
    test('registers a running task immediately, before the action resolves',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiTasksProvider.notifier);

      final future = notifier.run(
        label: 'Test task',
        action: () async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 'done';
        },
      );

      // Registered synchronously, before the action has resolved.
      final tasks = container.read(aiTasksProvider);
      expect(tasks, hasLength(1));
      expect(tasks.single.label, 'Test task');
      expect(tasks.single.status, AiTaskStatus.running);

      final result = await future;
      expect(result, 'done');
    });

    test('marks the task completed and returns the action result', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiTasksProvider.notifier);

      final result = await notifier.run(
        label: 'Test task',
        action: () async => 42,
      );

      expect(result, 42);
      final tasks = container.read(aiTasksProvider);
      expect(tasks.single.status, AiTaskStatus.completed);
    });

    test('marks the task failed and rethrows on error', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiTasksProvider.notifier);

      await expectLater(
        notifier.run(
          label: 'Test task',
          action: () async => throw Exception('boom'),
        ),
        throwsException,
      );

      final tasks = container.read(aiTasksProvider);
      expect(tasks.single.status, AiTaskStatus.failed);
      expect(tasks.single.errorMessage, contains('boom'));
    });

    test('multiple concurrent tasks are all tracked independently', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiTasksProvider.notifier);

      final f1 = notifier.run(
          label: 'Task A',
          action: () => Future.delayed(const Duration(milliseconds: 30), () => 1));
      final f2 = notifier.run(
          label: 'Task B',
          action: () => Future.delayed(const Duration(milliseconds: 10), () => 2));

      expect(container.read(aiTasksProvider), hasLength(2));

      await Future.wait([f1, f2]);
      final tasks = container.read(aiTasksProvider);
      expect(tasks, hasLength(2));
      expect(tasks.every((t) => t.status == AiTaskStatus.completed), isTrue);
    });

    test('AiTaskModel.remaining clamps to zero once the estimate is exceeded',
        () {
      final task = AiTaskModel(
        id: '1',
        label: 'Test',
        status: AiTaskStatus.running,
        startedAt: DateTime.now().subtract(const Duration(seconds: 30)),
        estimate: const Duration(seconds: 15),
      );
      expect(task.remaining, Duration.zero);
    });

    test('AiTaskModel.remaining is null once the task is no longer running',
        () {
      final task = AiTaskModel(
        id: '1',
        label: 'Test',
        status: AiTaskStatus.completed,
        startedAt: DateTime.now(),
        estimate: const Duration(seconds: 15),
      );
      expect(task.remaining, isNull);
    });
  });
}
