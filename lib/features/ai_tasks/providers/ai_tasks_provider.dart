// lib/features/ai_tasks/providers/ai_tasks_provider.dart
//
// Global, in-memory, app-session-lifetime tracker for AI calls — the
// unification asked for in the 14/15 July 2026 walkthrough (§13/§17/§23):
// "unify with the existing AI extraction queue system so all AI interactions
// are queued" and surfaced somewhere the surveyor can check status/count/
// time remaining without staring at the exact screen that started it, "a
// little bit like a task explorer."
//
// Deliberately NOT persisted to Supabase — unlike document extraction
// (`extraction_status` on a durable `documents` row, meant to survive app
// restarts because a document's extraction is itself a durable fact worth
// keeping), every AI call tracked here is a short-lived (~5-30s), purely
// client-side operation whose result lands in either a widget's local state
// or another provider's own persisted state. There's nothing to recover
// after a restart — the task list is meant to answer "what's happening
// right now", not "what happened".

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/claude_api.dart' show aiTaskCaseIdZoneKey;

enum AiTaskStatus { running, completed, failed }

class AiTaskModel {
  const AiTaskModel({
    required this.id,
    required this.label,
    required this.status,
    required this.startedAt,
    required this.estimate,
    this.caseId,
    this.caseLabel,
    this.completedAt,
    this.errorMessage,
  });

  final String id;
  final String label;
  final AiTaskStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;

  /// Rough per-task-type duration estimate (e.g. 15s for a short polish,
  /// 25s for a multi-page extraction) — used only to render a "~Ns
  /// remaining" hint, never to time anything out.
  final Duration estimate;

  /// Case this task belongs to, and a short display label for it (e.g. the
  /// vessel name) — both optional since a couple of call sites (Case
  /// Analyst chat) aren't case-scoped in a way worth surfacing.
  final String? caseId;
  final String? caseLabel;
  final String? errorMessage;

  Duration get elapsed => (completedAt ?? DateTime.now()).difference(startedAt);

  /// Null once the task isn't running any more. Never negative — clamped to
  /// zero so a task that's overrun its estimate reads "any moment now"
  /// rather than a confusing negative duration.
  Duration? get remaining {
    if (status != AiTaskStatus.running) return null;
    final r = estimate - elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  AiTaskModel copyWith({
    AiTaskStatus? status,
    DateTime? completedAt,
    String? errorMessage,
  }) =>
      AiTaskModel(
        id: id,
        label: label,
        status: status ?? this.status,
        startedAt: startedAt,
        estimate: estimate,
        caseId: caseId,
        caseLabel: caseLabel,
        completedAt: completedAt ?? this.completedAt,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class AiTasksNotifier extends Notifier<List<AiTaskModel>> {
  @override
  List<AiTaskModel> build() => [];

  int _counter = 0;
  final Map<String, Timer> _removalTimers = {};

  /// Wraps [action] as a tracked task for its whole lifetime — register
  /// before starting, mark completed/failed on the way out, always via
  /// `try`/`catch`+`rethrow` so callers see the exact same result/exception
  /// they would have without tracking. This is the one call site every
  /// screen should route its `ClaudeApi.*` calls through instead of a local
  /// `setState(() => _busy = true)` flag, so the task shows up in the
  /// shared indicator/panel regardless of which screen started it or
  /// whether the surveyor has since navigated away.
  Future<T> run<T>({
    required String label,
    required Future<T> Function() action,
    String? caseId,
    String? caseLabel,
    Duration estimate = const Duration(seconds: 15),
  }) async {
    final id = 'ai-task-${++_counter}';
    _removalTimers.remove(id)?.cancel();
    state = [
      ...state,
      AiTaskModel(
        id: id,
        label: label,
        status: AiTaskStatus.running,
        startedAt: DateTime.now(),
        estimate: estimate,
        caseId: caseId,
        caseLabel: caseLabel,
      ),
    ];
    try {
      // Run the action inside a zone carrying this caseId so ClaudeApi's
      // usage/audit interceptor can attribute token_usage.case_id even when
      // the call site didn't thread caseId into the ClaudeApi method
      // itself (14 July 2026 walkthrough §25). aiTaskCaseIdZoneKey is the
      // symbol the interceptor reads.
      final result = caseId == null
          ? await action()
          : await runZoned(action, zoneValues: {aiTaskCaseIdZoneKey: caseId});
      _finish(id, AiTaskStatus.completed);
      return result;
    } catch (e) {
      _finish(id, AiTaskStatus.failed, error: e.toString());
      rethrow;
    }
  }

  void _finish(String id, AiTaskStatus status, {String? error}) {
    state = [
      for (final t in state)
        if (t.id == id)
          t.copyWith(
              status: status, completedAt: DateTime.now(), errorMessage: error)
        else
          t,
    ];
    // Completed tasks self-clear quickly (just long enough to register as
    // "done" if the panel happens to be open); failures linger longer since
    // an error is worth actually noticing.
    _scheduleRemoval(id,
        status == AiTaskStatus.failed
            ? const Duration(seconds: 25)
            : const Duration(seconds: 6));
  }

  void _scheduleRemoval(String id, Duration delay) {
    _removalTimers[id] = Timer(delay, () {
      _removalTimers.remove(id);
      state = state.where((t) => t.id != id).toList();
    });
  }

  /// Manual dismiss from the panel (e.g. clearing a failed task early).
  void dismiss(String id) {
    _removalTimers.remove(id)?.cancel();
    state = state.where((t) => t.id != id).toList();
  }
}

final aiTasksProvider = NotifierProvider<AiTasksNotifier, List<AiTaskModel>>(
  AiTasksNotifier.new,
);
