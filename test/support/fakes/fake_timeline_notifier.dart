// Widget-test doubles for the Timeline feature providers — no Supabase.
// See fake_checklist_notifier.dart for the pattern/rationale.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/timeline/models/timeline_entry.dart'
    show TimelineEntry, defaultIncludedForKey;
import 'package:marine_survey_app/features/timeline/models/timeline_event_model.dart';
import 'package:marine_survey_app/features/timeline/models/timeline_event_rating.dart';
import 'package:marine_survey_app/features/timeline/providers/timeline_provider.dart';
import 'package:marine_survey_app/features/timeline/providers/timeline_ratings_provider.dart';

class FakeTimelineNotifier extends TimelineNotifier {
  FakeTimelineNotifier(this._seed);
  final List<TimelineEventModel> _seed;
  int _n = 0;

  @override
  Future<List<TimelineEventModel>> build(String arg) async => _seed;

  @override
  Future<void> add(TimelineEventModel model) async {
    final created = TimelineEventModel(
      eventId:     'fake-${++_n}',
      caseId:      model.caseId,
      eventType:   model.eventType,
      eventDate:   model.eventDate,
      title:       model.title,
      location:    model.location,
      description: model.description,
      sourceKey:   model.sourceKey,
    );
    state = AsyncData([...?state.value, created]);
  }

  @override
  Future<void> promote(TimelineEntry entry) async {
    await add(TimelineEventModel(
      eventId:     '',
      caseId:      arg,
      eventType:   TimelineEventType.custom,
      eventDate:   entry.date,
      title:       entry.title,
      location:    entry.subtitle,
      description: entry.description,
      sourceKey:   entry.eventKey,
    ));
  }

  @override
  Future<void> unpromoteByKey(String sourceKey) async {
    state = AsyncData(
        (state.value ?? []).where((e) => e.sourceKey != sourceKey).toList());
  }

  @override
  Future<void> delete(String eventId) async {
    state = AsyncData(
        (state.value ?? []).where((e) => e.eventId != eventId).toList());
  }
}

class FakeTimelineRatingsNotifier extends TimelineRatingsNotifier {
  FakeTimelineRatingsNotifier([this._seed = const {}]);
  final Map<String, TimelineEventRating> _seed;

  @override
  Future<Map<String, TimelineEventRating>> build(String arg) async =>
      Map.of(_seed);

  Map<String, TimelineEventRating> get _cur =>
      state.value ?? const <String, TimelineEventRating>{};

  TimelineEventRating _blank(String key) =>
      _cur[key] ??
      TimelineEventRating(
        id: 'fake',
        caseId: arg,
        eventKey: key,
        includedInChronology: defaultIncludedForKey(key),
      );

  @override
  Future<void> setRelevance(String eventKey, EventRelevance relevance) async {
    final next =
        _blank(eventKey).copyWith(relevance: relevance, pendingReview: false);
    state = AsyncData({..._cur, eventKey: next});
  }

  @override
  Future<void> setIncluded(String eventKey, bool included) async {
    final next = _blank(eventKey).copyWith(includedInChronology: included);
    state = AsyncData({..._cur, eventKey: next});
  }

  @override
  Future<void> confirmSuggestion(String eventKey) async {
    final existing = _cur[eventKey];
    if (existing == null) return;
    state = AsyncData(
        {..._cur, eventKey: existing.copyWith(pendingReview: false)});
  }

  @override
  Future<void> applyAiSuggestions(
      Iterable<TimelineAiSuggestion> suggestions) async {
    final next = {..._cur};
    for (final s in suggestions) {
      if (next.containsKey(s.eventKey)) continue;
      next[s.eventKey] = TimelineEventRating(
        id: 'fake',
        caseId: arg,
        eventKey: s.eventKey,
        relevance: s.relevance,
        pendingReview: true,
        aiReason: s.reason,
      );
    }
    state = AsyncData(next);
  }
}
