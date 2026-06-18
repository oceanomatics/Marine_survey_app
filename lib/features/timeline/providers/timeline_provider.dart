// lib/features/timeline/providers/timeline_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timeline_event_model.dart';
import '../../../core/api/supabase_client.dart';

final timelineProvider = AsyncNotifierProviderFamily<TimelineNotifier,
    List<TimelineEventModel>, String>(TimelineNotifier.new);

class TimelineNotifier
    extends FamilyAsyncNotifier<List<TimelineEventModel>, String> {
  @override
  Future<List<TimelineEventModel>> build(String arg) => _fetch();

  Future<List<TimelineEventModel>> _fetch() async {
    final data = await SupabaseService.client
        .from('timeline_events')
        .select()
        .eq('case_id', arg)
        .order('created_at', ascending: true);
    final list = (data as List)
        .map((j) => TimelineEventModel.fromJson(j as Map<String, dynamic>))
        .toList();
    list.sort(_byDate);
    return list;
  }

  Future<void> add(TimelineEventModel model) async {
    final inserted = await SupabaseService.client
        .from('timeline_events')
        .insert(model.toInsertJson())
        .select()
        .single();
    final created = TimelineEventModel.fromJson(inserted);
    final next = <TimelineEventModel>[...(state.value ?? []), created]..sort(_byDate);
    state = AsyncData(next);
  }

  Future<void> delete(String eventId) async {
    await SupabaseService.client
        .from('timeline_events')
        .delete()
        .eq('event_id', eventId);
    state = AsyncData(
        (state.value ?? []).where((e) => e.eventId != eventId).toList());
  }

  static int _byDate(TimelineEventModel a, TimelineEventModel b) {
    final ad = a.eventDate;
    final bd = b.eventDate;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }
}
