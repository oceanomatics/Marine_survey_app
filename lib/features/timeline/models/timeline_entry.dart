// lib/features/timeline/models/timeline_entry.dart
//
// TODO.md §3.16 — a single unified event in the Full Event Log. Aggregated
// from every dated source collected across a case (occurrences, attendances,
// completed repairs, manual timeline events) and joined to its optional
// [TimelineEventRating]. This is the in-memory shape; entries are never stored
// directly — only their ratings are (see timeline_event_rating.dart).

import 'package:flutter/foundation.dart';

import 'timeline_event_rating.dart';

// ── Source ──────────────────────────────────────────────────────────────────

/// Which case-data source an aggregated event came from. The [value] is the
/// prefix of the event's stable [TimelineEntry.eventKey].
enum TimelineSourceType {
  occurrence('occurrence', 'Occurrence'),
  attendance('attendance', 'Attendance'),
  repair('repair', 'Repair'),
  manual('manual', 'Timeline Event');

  const TimelineSourceType(this.value, this.label);
  final String value;
  final String label;

  static TimelineSourceType? fromValue(String? v) =>
      values.where((e) => e.value == v).firstOrNull;
}

/// Whether an event with this stable [TimelineEntry.eventKey] should default
/// into the report Chronology when it has no explicit inclusion decision.
/// Manual timeline events do (preserving the report builder's long-standing
/// behaviour); aggregated occurrences/attendances/repairs do not until picked.
bool defaultIncludedForKey(String eventKey) =>
    eventKey.startsWith('${TimelineSourceType.manual.value}:');

// ── Entry ─────────────────────────────────────────────────────────────────

@immutable
class TimelineEntry {
  const TimelineEntry({
    required this.sourceType,
    required this.sourceId,
    this.date,
    required this.title,
    this.subtitle,
    this.description,
    this.badge,
    this.rating,
    this.promoted = false,
    this.manualEventId,
  });

  final TimelineSourceType sourceType;

  /// The source row's own id (occurrence_id, attendance_id, repair_id, or the
  /// timeline_events event_id).
  final String sourceId;

  final DateTime? date;
  final String title;
  final String? subtitle;
  final String? description;
  final String? badge;

  /// Joined rating row, if the surveyor (or AI) has rated this event.
  final TimelineEventRating? rating;

  /// True when a non-timeline event has already been promoted into a real
  /// `timeline_events` row (so it feeds the report Chronology). Set by the
  /// aggregator when a timeline_events row carries this entry's `source_key`.
  final bool promoted;

  /// For manual (`timeline_events`-backed) entries: the deletable row id.
  final String? manualEventId;

  /// Stable synthetic identity, "<source>:<source_id>". The join key against
  /// [TimelineEventRating.eventKey] and the `source_key` stamped on promoted
  /// timeline_events rows.
  String get eventKey => '${sourceType.value}:$sourceId';

  EventRelevance get relevance => rating?.relevance ?? EventRelevance.normal;

  bool get isIgnored => relevance == EventRelevance.ignore;

  /// True while the relevance is an unconfirmed AI suggestion.
  bool get pendingReview => rating?.pendingReview ?? false;

  String? get aiReason => rating?.aiReason;

  /// Whether this event should populate the report's Chronology table.
  ///
  /// Ignored events never do. Otherwise: a manual timeline event defaults to
  /// *included* (preserves the report builder's long-standing behaviour of
  /// listing every timeline_events row) unless a rating explicitly excludes
  /// it; aggregated non-timeline events default to *excluded* until the
  /// surveyor promotes them (which sets [promoted]) or ticks inclusion.
  bool get includedInChronology {
    if (isIgnored) return false;
    if (promoted) return true;
    if (rating != null) return rating!.includedInChronology;
    return sourceType == TimelineSourceType.manual;
  }

  /// The single-line text used in the report Chronology's "Event" column —
  /// description preferred, title as fallback. Kept here so the in-app view and
  /// the report row-builder never diverge on what an event's chronology text is.
  String get chronologyText {
    final d = description?.trim();
    if (d != null && d.isNotEmpty) return d;
    return title;
  }

  TimelineEntry copyWith({
    TimelineEventRating? rating,
    bool? promoted,
  }) =>
      TimelineEntry(
        sourceType:    sourceType,
        sourceId:      sourceId,
        date:          date,
        title:         title,
        subtitle:      subtitle,
        description:   description,
        badge:         badge,
        rating:        rating ?? this.rating,
        promoted:      promoted ?? this.promoted,
        manualEventId: manualEventId,
      );
}
