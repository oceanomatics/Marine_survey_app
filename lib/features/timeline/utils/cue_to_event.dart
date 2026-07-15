// lib/features/timeline/utils/cue_to_event.dart
//
// Reusable "convert this context cue into a real Timeline event" flow,
// callable from any cue-displaying screen (ContextCuesPanel, Advice to
// Owner) — not just the Timeline screen's own "Quick note -> event"
// button (14 July 2026 walkthrough §15). Same AI-extraction-then-review
// pattern: never auto-commits, the surveyor always sees the Add Event
// sheet pre-filled and can edit or cancel. 15 July 2026 walkthrough §16 —
// "if a cue creates a Timeline event, the cue should show a small 'Event
// created' pill for traceability back from the cue."

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timeline_event_model.dart';
import '../providers/timeline_provider.dart';
import '../widgets/add_timeline_event_sheet.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../../../core/api/claude_api.dart';
import '../../ai_tasks/providers/ai_tasks_provider.dart';

/// The stable key used to link a created TimelineEvent back to its
/// originating cue — check this against `TimelineEventModel.sourceKey` to
/// know whether a given cue already has an event ("Event created" pill).
String cueEventSourceKey(String noteId) => 'cue:$noteId';

Future<void> convertCueToTimelineEvent(
  BuildContext context,
  WidgetRef ref, {
  required String caseId,
  required SurveyorNote note,
}) async {
  final loadingCtx = context;
  showDialog<void>(
    context: loadingCtx,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  Map<String, dynamic> result = const {};
  try {
    result = await ref.read(aiTasksProvider.notifier).run(
          label: 'Reading event details from cue',
          caseId: caseId,
          estimate: const Duration(seconds: 10),
          action: () =>
              ClaudeApi.extractEventFromNote(text: note.content, caseId: caseId),
        );
  } catch (_) {
    // Fall through with an empty result — the surveyor still gets the Add
    // Event sheet, just without a pre-filled date/title.
  }
  if (loadingCtx.mounted) Navigator.of(loadingCtx, rootNavigator: true).pop();
  if (!context.mounted) return;

  final extractedDate = result['date'] != null
      ? DateTime.tryParse(result['date'].toString())
      : null;
  final extractedTitle = (result['title'] as String?)?.trim();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddTimelineEventSheet(
      initialTitle: extractedTitle?.isNotEmpty == true ? extractedTitle : null,
      initialDate: extractedDate,
      initialDescription: note.content,
      sourceKey: cueEventSourceKey(note.id),
      onSave: (model) async {
        final m = TimelineEventModel(
          eventId:     '',
          caseId:      caseId,
          eventType:   model.eventType,
          eventDate:   model.eventDate,
          title:       model.title,
          location:    model.location,
          description: model.description,
          sourceKey:   model.sourceKey,
        );
        await ref.read(timelineProvider(caseId).notifier).add(m);
      },
    ),
  );
}
