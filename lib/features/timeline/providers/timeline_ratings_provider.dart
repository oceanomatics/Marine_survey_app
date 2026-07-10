// lib/features/timeline/providers/timeline_ratings_provider.dart
//
// TODO.md §3.16 — persistence for per-event relevance ratings + chronology
// inclusion decisions. Supabase-direct, matching timeline_provider.dart (the
// Timeline feature does not use the local SQLite cache).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timeline_entry.dart' show defaultIncludedForKey;
import '../models/timeline_event_rating.dart';
import '../../../core/api/supabase_client.dart';

/// Ratings for a case, keyed by [TimelineEventRating.eventKey].
final timelineRatingsProvider = AsyncNotifierProviderFamily<
    TimelineRatingsNotifier,
    Map<String, TimelineEventRating>,
    String>(TimelineRatingsNotifier.new);

class TimelineRatingsNotifier
    extends FamilyAsyncNotifier<Map<String, TimelineEventRating>, String> {
  @override
  Future<Map<String, TimelineEventRating>> build(String arg) => _fetch();

  Future<Map<String, TimelineEventRating>> _fetch() async {
    final data = await SupabaseService.client
        .from('timeline_event_ratings')
        .select()
        .eq('case_id', arg);
    final map = <String, TimelineEventRating>{};
    for (final row in (data as List)) {
      final r = TimelineEventRating.fromMap(row as Map<String, dynamic>);
      map[r.eventKey] = r;
    }
    return map;
  }

  Map<String, TimelineEventRating> get _current =>
      state.value ?? const <String, TimelineEventRating>{};

  /// Upsert (keyed on case_id, event_key) and reflect the stored row locally.
  Future<void> _persist(TimelineEventRating desired) async {
    final stored = await SupabaseService.client
        .from('timeline_event_ratings')
        .upsert(desired.toUpsertMap(), onConflict: 'case_id,event_key')
        .select()
        .single();
    final saved = TimelineEventRating.fromMap(stored);
    state = AsyncData({..._current, saved.eventKey: saved});
  }

  TimelineEventRating _existingOrBlank(String eventKey) =>
      _current[eventKey] ??
      TimelineEventRating(
        id: '',
        caseId: arg,
        eventKey: eventKey,
        // Seed inclusion from the source-type default so that merely changing
        // an event's *relevance* never silently drops a manual timeline event
        // out of the chronology (manual events are included by default).
        includedInChronology: defaultIncludedForKey(eventKey),
      );

  /// Set relevance from an explicit surveyor action — this counts as review, so
  /// [TimelineEventRating.pendingReview] is cleared.
  Future<void> setRelevance(String eventKey, EventRelevance relevance) async {
    final next = _existingOrBlank(eventKey)
        .copyWith(relevance: relevance, pendingReview: false);
    await _persist(next);
  }

  /// Select / deselect an event for the report Chronology.
  Future<void> setIncluded(String eventKey, bool included) async {
    final next = _existingOrBlank(eventKey)
        .copyWith(includedInChronology: included);
    await _persist(next);
  }

  /// One-tap "the AI got it right" — clears the pending-review flag without
  /// otherwise changing the suggested relevance (mirrors the cue system's
  /// `confirmAllocation`).
  Future<void> confirmSuggestion(String eventKey) async {
    final existing = _current[eventKey];
    if (existing == null || !existing.pendingReview) return;
    await _persist(existing.copyWith(pendingReview: false));
  }

  /// Apply AI-suggested relevance ratings. Only writes events that have **no**
  /// rating yet (cost/annotation safety: never overwrite a surveyor's decision,
  /// and — as with the cue system — never re-classify an already-rated event).
  /// Each written rating is marked [pendingReview] so it lands in the review
  /// flow rather than being silently trusted.
  Future<void> applyAiSuggestions(
      Iterable<TimelineAiSuggestion> suggestions) async {
    for (final s in suggestions) {
      if (_current.containsKey(s.eventKey)) continue;
      final next = TimelineEventRating(
        id:            '',
        caseId:        arg,
        eventKey:      s.eventKey,
        relevance:     s.relevance,
        pendingReview: true,
        aiReason:      s.reason,
      );
      await _persist(next);
    }
  }

  /// Event keys with no rating yet — the set the AI pass should classify.
  Set<String> unratedKeysAmong(Iterable<String> allKeys) =>
      allKeys.where((k) => !_current.containsKey(k)).toSet();
}

/// A single AI relevance suggestion for an event.
class TimelineAiSuggestion {
  const TimelineAiSuggestion({
    required this.eventKey,
    required this.relevance,
    this.reason,
  });
  final String eventKey;
  final EventRelevance relevance;
  final String? reason;
}
