// lib/features/timeline/models/timeline_event_rating.dart
//
// TODO.md §3.16 — per-event relevance rating + chronology inclusion decision.
// Mirrors the context-cue review pattern (docs/context_cue_system_review.md
// §3.5): AI suggests the relevance first (`pendingReview = true`), and nothing
// the AI guessed is treated as confirmed until the surveyor reviews it.

import 'package:flutter/foundation.dart';

// ── Relevance ───────────────────────────────────────────────────────────────

/// How relevant an aggregated timeline event is. Deliberately the same three
/// levels the context-cue system uses for [CuePriority] — Important / Normal /
/// Ignore — so the two review flows feel identical to the surveyor.
enum EventRelevance {
  important,
  normal,
  ignore;

  static EventRelevance fromValue(String? v) => switch (v) {
        'important' => important,
        'ignore'    => ignore,
        _           => normal,
      };

  String get value => name;

  String get label => switch (this) {
        important => 'Important',
        normal    => 'Normal',
        ignore    => 'Ignore',
      };
}

// ── Rating record ─────────────────────────────────────────────────────────

@immutable
class TimelineEventRating {
  const TimelineEventRating({
    required this.id,
    required this.caseId,
    required this.eventKey,
    this.relevance = EventRelevance.normal,
    this.includedInChronology = false,
    this.pendingReview = false,
    this.aiReason,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String caseId;

  /// Stable synthetic identity of the rated event — "<source>:<source_id>",
  /// e.g. "occurrence:<uuid>". See [TimelineEntry.eventKey].
  final String eventKey;
  final EventRelevance relevance;

  /// Whether the surveyor has selected this event to appear in the report's
  /// Chronology section.
  final bool includedInChronology;

  /// True while [relevance] is an unconfirmed AI suggestion — surfaced with a
  /// "Suggested" chip in the Full Event Log until the surveyor confirms it.
  final bool pendingReview;

  /// Short AI rationale for the suggested relevance, if any.
  final String? aiReason;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TimelineEventRating.fromMap(Map<String, dynamic> m) =>
      TimelineEventRating(
        id:      m['id'] as String,
        caseId:  m['case_id'] as String,
        eventKey: m['event_key'] as String,
        relevance: EventRelevance.fromValue(m['relevance'] as String?),
        includedInChronology:
            m['included_in_chronology'] == true || m['included_in_chronology'] == 1,
        pendingReview: m['pending_review'] == true || m['pending_review'] == 1,
        aiReason: m['ai_reason'] as String?,
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'] as String)
            : null,
        updatedAt: m['updated_at'] != null
            ? DateTime.tryParse(m['updated_at'] as String)
            : null,
      );

  /// Upsert payload (keyed on `case_id, event_key`). Omits `id` so Postgres
  /// keeps the existing row's id on conflict.
  Map<String, dynamic> toUpsertMap() => {
        'case_id':                caseId,
        'event_key':              eventKey,
        'relevance':              relevance.value,
        'included_in_chronology': includedInChronology,
        'pending_review':         pendingReview,
        'ai_reason':              aiReason,
        'updated_at':             DateTime.now().toIso8601String(),
      };

  TimelineEventRating copyWith({
    EventRelevance? relevance,
    bool? includedInChronology,
    bool? pendingReview,
    Object? aiReason = _sentinel,
  }) =>
      TimelineEventRating(
        id:       id,
        caseId:   caseId,
        eventKey: eventKey,
        relevance: relevance ?? this.relevance,
        includedInChronology:
            includedInChronology ?? this.includedInChronology,
        pendingReview: pendingReview ?? this.pendingReview,
        aiReason: aiReason == _sentinel ? this.aiReason : aiReason as String?,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

const Object _sentinel = Object();
