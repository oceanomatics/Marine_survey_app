// lib/features/timeline/models/timeline_aggregation.dart
//
// TODO.md §3.16 — the single, pure aggregation that turns every dated case
// source into a unified, chronologically-sorted Full Event Log. Kept as free
// functions (no Flutter/Riverpod deps) so both the in-app Timeline screen and
// the unit tests build the identical list, and so the chronology-inclusion
// rule lives in exactly one place (no renderer/selection drift — see the
// top-of-file note in reports/utils/section_table_rows.dart).

import '../../attendances/models/attendance_model.dart';
import '../../correspondence/models/correspondence_model.dart';
import '../../documents/providers/document_provider.dart' show DocumentModel;
import '../../reports/providers/report_provider.dart' show ReportOutput;
import '../../survey/providers/damage_provider.dart';
import 'timeline_entry.dart';
import 'timeline_event_rating.dart';
import 'timeline_event_model.dart';

/// Single source of truth for "does this event populate the report Chronology?"
/// Used by both [TimelineEntry.includedInChronology] and the report builder's
/// timeline filter, so the in-app selection and the rendered report never
/// disagree.
///
/// Simplified 14 July 2026 walkthrough: rating an event **is** the
/// chronology-inclusion mechanism — no separate promote/select-for-
/// chronology step. Important -> included; Ignored -> never; Normal ->
/// stays Full-Log-only unless it's a manual (`timeline_events`-backed)
/// event, which stays included by default absent an explicit Normal/Ignore
/// rating (preserves "list every timeline row" for un-curated cases, and
/// custom event creation's existing behaviour — that flow wasn't changed).
/// [promoted] is kept in the signature for call-site compatibility but no
/// longer independently drives inclusion — see
/// `TimelineRatingsNotifier.setRelevance` for how an aggregated entry's
/// underlying `timeline_events` row is now created/removed automatically
/// to follow the relevance decision instead of a separate manual action.
bool chronologyIncludeForRating({
  required TimelineSourceType sourceType,
  required TimelineEventRating? rating,
  bool promoted = false,
}) {
  final relevance = rating?.relevance ?? EventRelevance.normal;
  if (relevance == EventRelevance.ignore) return false;
  if (relevance == EventRelevance.important) return true;
  return sourceType == TimelineSourceType.manual;
}

/// Aggregate every dated source into one sorted Full Event Log.
///
/// `ratingsByKey` and `promotedSourceKeys` are joined in by
/// [TimelineEntry.eventKey]; `promotedSourceKeys` are the `source_key` values
/// found on existing `timeline_events` rows (a non-timeline event already
/// pushed into the chronology).
List<TimelineEntry> aggregateTimelineEntries({
  List<TimelineEventModel> manualEvents = const [],
  List<SurveyAttendanceModel> attendances = const [],
  DamageState? damage,
  List<CorrespondenceModel> correspondence = const [],
  List<DocumentModel> documents = const [],
  List<ReportOutput> reportOutputs = const [],
  Map<String, TimelineEventRating> ratingsByKey = const {},
  Set<String> promotedSourceKeys = const {},
}) {
  final list = <TimelineEntry>[];

  TimelineEntry join(TimelineEntry e) {
    final promoted = promotedSourceKeys.contains(e.eventKey);
    return e.copyWith(rating: ratingsByKey[e.eventKey], promoted: promoted);
  }

  // Occurrences
  for (final occ in damage?.occurrences ?? const []) {
    list.add(join(TimelineEntry(
      sourceType:  TimelineSourceType.occurrence,
      sourceId:    occ.occurrenceId,
      date:        occ.dateTime,
      title:       occ.title ?? 'Incident / Occurrence',
      subtitle:    occ.location,
      description: occ.briefDescription,
      badge:       'Occurrence',
    )));
  }

  // Attendances
  for (final att in attendances) {
    final parts = <String>[
      if (att.surveyorName != null) att.surveyorName!,
      if (att.vesselStatus != null) att.vesselStatus!.label,
    ];
    final desc = [
      if (parts.isNotEmpty) parts.join(' · '),
      if (att.summary != null && att.summary!.isNotEmpty) att.summary!,
    ].join('\n');
    list.add(join(TimelineEntry(
      sourceType:  TimelineSourceType.attendance,
      sourceId:    att.attendanceId,
      date:        att.attendanceDate,
      title:       att.attendanceType.label,
      subtitle:    att.location,
      description: desc.isEmpty ? null : desc,
      badge:       'Attendance',
    )));
  }

  // Completed repairs (auto-sourced from a repair's completionDate)
  for (final r in damage?.repairs ?? const []) {
    if (r.completionDate == null) continue;
    list.add(join(TimelineEntry(
      sourceType:  TimelineSourceType.repair,
      sourceId:    r.repairId,
      date:        r.completionDate,
      title:       r.description ?? '${r.repairType.label} repairs completed',
      description: r.notes,
      badge:       '${r.repairType.label} · Completed',
    )));
  }

  // Correspondence (14 July 2026 walkthrough — was entirely absent from
  // the Full Log).
  for (final c in correspondence) {
    list.add(join(TimelineEntry(
      sourceType:  TimelineSourceType.correspondence,
      sourceId:    c.id,
      date:        c.corrDate,
      title:       c.title,
      subtitle:    [
        if (c.sender != null) 'From: ${c.sender}',
        if (c.recipient != null) 'To: ${c.recipient}',
      ].join(' · '),
      description: c.summary,
      badge:       'Correspondence',
    )));
  }

  // Documents — the date extracted from the document's own content
  // (docDate), never the import/upload timestamp. Documents with no
  // extracted content date simply don't appear here (there's nothing
  // dated to log).
  for (final d in documents) {
    if (d.docDate == null) continue;
    list.add(join(TimelineEntry(
      sourceType: TimelineSourceType.document,
      sourceId:   d.docId,
      date:       d.docDate,
      title:      d.title,
      badge:      d.docCategory?.label ?? 'Document',
    )));
  }

  // Report issuance — the surveyor's own issued-report milestone.
  // issuedDate only, never createdAt (report-generation timestamps stay
  // excluded from the log).
  for (final r in reportOutputs) {
    if (r.issuedDate == null) continue;
    list.add(join(TimelineEntry(
      sourceType: TimelineSourceType.report,
      sourceId:   r.outputId,
      date:       r.issuedDate,
      title:      '${r.outputType.label} issued'
          '${r.reportNumber != null ? ' (${r.reportNumber})' : ''}',
      subtitle:   r.issuedTo,
      badge:      'Report',
    )));
  }

  // Manual timeline events
  for (final ev in manualEvents) {
    list.add(join(TimelineEntry(
      sourceType:    TimelineSourceType.manual,
      sourceId:      ev.eventId,
      date:          ev.eventDate,
      title:         ev.title ?? ev.eventType.label,
      subtitle:      ev.location,
      description:   ev.description,
      badge:         'Timeline',
      manualEventId: ev.eventId,
    )));
  }

  list.sort(_byDate);
  return list;
}

int _byDate(TimelineEntry a, TimelineEntry b) {
  if (a.date == null && b.date == null) return 0;
  if (a.date == null) return 1;
  if (b.date == null) return -1;
  return a.date!.compareTo(b.date!);
}
