// lib/features/timeline/screens/timeline_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/timeline_event_model.dart';
import '../models/timeline_entry.dart';
import '../models/timeline_event_rating.dart';
import '../models/timeline_aggregation.dart';
import '../providers/timeline_provider.dart';
import '../providers/timeline_ratings_provider.dart';
import '../widgets/add_timeline_event_sheet.dart';
import '../../survey/providers/damage_provider.dart';
import '../../attendances/providers/attendances_provider.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart' show CaseSection;
import '../../../core/api/claude_api.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/context_cues_panel.dart';

const _kColor = Color(0xFF2E7CB7);

// ── Screen ────────────────────────────────────────────────────────────────

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String get caseId => widget.caseId;

  @override
  Widget build(BuildContext context) {
    final manual      = ref.watch(timelineProvider(caseId)).value ?? [];
    final attendances = ref.watch(attendancesProvider(caseId)).value ?? [];
    final damage      = ref.watch(damageProvider(caseId)).value;
    final ratings     = ref.watch(timelineRatingsProvider(caseId)).value ??
        const <String, TimelineEventRating>{};

    final promotedKeys = manual
        .where((e) => e.sourceKey != null)
        .map((e) => e.sourceKey!)
        .toSet();

    final entries = aggregateTimelineEntries(
      manualEvents:       manual,
      attendances:        attendances,
      damage:             damage,
      ratingsByKey:       ratings,
      promotedSourceKeys: promotedKeys,
    );

    // A promoted manual row is the chronology twin of an aggregated entry —
    // hide it from the log so an occurrence/attendance/repair shows once, as
    // its own aggregated card (now flagged "In chronology").
    final visible =
        entries.where((e) => !(e.sourceType == TimelineSourceType.manual &&
            e.manualEventId != null &&
            manual
                .firstWhere((m) => m.eventId == e.manualEventId)
                .sourceKey != null)).toList();

    final active   = visible.where((e) => !e.isIgnored).toList();
    final ignored  = visible.where((e) => e.isIgnored).toList();
    final pending  = visible.where((e) => e.pendingReview).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Case Timeline',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 24),
            tooltip: 'Add event',
            onPressed: () => _showAddSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          tabs: [
            const Tab(text: 'Timeline'),
            Tab(text: 'Full Log${pending > 0 ? '  •$pending' : ''}'),
            Tab(text: 'Ignored${ignored.isNotEmpty ? '  ${ignored.length}' : ''}'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // Tab 1 — curated condensed timeline (non-ignored)
                _CondensedTab(caseId: caseId, entries: active),
                // Tab 2 — full event log with relevance + chronology curation
                _FullEventLogTab(caseId: caseId, entries: visible),
                // Tab 3 — ignored review (mirrors the cue "review" pattern)
                _IgnoredTab(caseId: caseId, entries: ignored),
              ],
            ),
          ),
          ContextCuesPanel(caseId: caseId, section: CaseSection.timeline),
        ],
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTimelineEventSheet(
        onSave: (model) async {
          final m = TimelineEventModel(
            eventId:     '',
            caseId:      caseId,
            eventType:   model.eventType,
            eventDate:   model.eventDate,
            title:       model.title,
            location:    model.location,
            description: model.description,
          );
          await ref.read(timelineProvider(caseId).notifier).add(m);
        },
      ),
    );
  }
}

// ── Tab 1: condensed curated timeline ─────────────────────────────────────

class _CondensedTab extends StatelessWidget {
  const _CondensedTab({required this.caseId, required this.entries});
  final String caseId;
  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _emptyState(
        icon: Icons.timeline,
        title: 'No timeline events yet',
        body: 'Events are added automatically from occurrences, attendances '
            'and completed repairs.\n\nTap + to add vessel movements, drydock '
            'entries, repair milestones and custom notes.\n\nSee the Full Log '
            'tab to rate every event and pick which appear in the report '
            'Chronology.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: entries.length,
      itemBuilder: (ctx, i) => _TimelineItem(
        entry:   entries[i],
        isFirst: i == 0,
        isLast:  i == entries.length - 1,
      ),
    );
  }
}

// ── Tab 2: full event log ─────────────────────────────────────────────────

class _FullEventLogTab extends ConsumerStatefulWidget {
  const _FullEventLogTab({required this.caseId, required this.entries});
  final String caseId;
  final List<TimelineEntry> entries;

  @override
  ConsumerState<_FullEventLogTab> createState() => _FullEventLogTabState();
}

class _FullEventLogTabState extends ConsumerState<_FullEventLogTab> {
  bool _rating = false;

  Future<void> _suggest() async {
    final notifier = ref.read(timelineRatingsProvider(widget.caseId).notifier);
    final unrated = widget.entries
        .where((e) => e.rating == null && e.date != null)
        .toList();
    if (unrated.isEmpty) {
      _snack('Every dated event already has a relevance rating.');
      return;
    }
    setState(() => _rating = true);
    try {
      final raw = await ClaudeApi.rateTimelineEvents(
        caseId: widget.caseId,
        events: unrated
            .map((e) => {
                  'event_key':   e.eventKey,
                  'date':        e.date?.toIso8601String(),
                  'title':       e.title,
                  'description': e.description,
                })
            .toList(),
      );
      final suggestions = <TimelineAiSuggestion>[];
      for (final r in raw) {
        final key = r['event_key'] as String?;
        if (key == null) continue;
        suggestions.add(TimelineAiSuggestion(
          eventKey:  key,
          relevance: EventRelevance.fromValue(r['relevance'] as String?),
          reason:    r['reason'] as String?,
        ));
      }
      await notifier.applyAiSuggestions(suggestions);
      _snack('AI suggested relevance for ${suggestions.length} event(s) — '
          'review and confirm below.');
    } catch (e) {
      _snack('Could not get AI suggestions: $e');
    } finally {
      if (mounted) setState(() => _rating = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    return Column(
      children: [
        _actionBar(),
        Expanded(
          child: entries.isEmpty
              ? _emptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'Nothing to log yet',
                  body: 'Once occurrences, attendances, repairs or manual '
                      'events exist, every dated item appears here to be rated '
                      'and selected for the report Chronology.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) =>
                      _FullLogItem(caseId: widget.caseId, entry: entries[i]),
                ),
        ),
      ],
    );
  }

  Widget _actionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Rate each event, then select which appear in the report '
              'Chronology.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _rating ? null : _suggest,
            style: FilledButton.styleFrom(
              backgroundColor: _kColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: _rating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome, size: 15),
            label: Text(_rating ? 'Rating…' : 'Suggest (AI)',
                style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

// ── Tab 3: ignored ──────────────────────────────────────────────────────────

class _IgnoredTab extends StatelessWidget {
  const _IgnoredTab({required this.caseId, required this.entries});
  final String caseId;
  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _emptyState(
        icon: Icons.visibility_off_outlined,
        title: 'Nothing ignored',
        body: 'Events you (or the AI) mark as "Ignore" move here. They stay '
            'out of the timeline and report Chronology, but you can restore '
            'any of them if it was hidden by mistake.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: entries.length,
      itemBuilder: (ctx, i) =>
          _FullLogItem(caseId: caseId, entry: entries[i]),
    );
  }
}

// ── Condensed timeline item (rail card) ───────────────────────────────────

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final TimelineEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = _sourceColor(entry.sourceType);
    final dateStr = entry.date != null
        ? DateFormat('dd/MM/yyyy').format(entry.date!)
        : 'Date TBC';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Expanded(
                  child: isFirst
                      ? const SizedBox.shrink()
                      : Center(child: Container(width: 2, color: AppColors.border)),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.3), blurRadius: 4),
                    ],
                  ),
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : Center(child: Container(width: 2, color: AppColors.border)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(left: 10, bottom: isLast ? 4 : 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _pill(dateStr, _kColor),
                      if (entry.badge != null) ...[
                        const SizedBox(width: 6),
                        _pill(entry.badge!, color),
                      ],
                      const Spacer(),
                      if (entry.relevance == EventRelevance.important)
                        const Icon(Icons.star, size: 14, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Icon(_sourceIcon(entry.sourceType),
                          size: 14, color: color.withValues(alpha: 0.7)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(entry.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  if (entry.subtitle != null && entry.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(entry.subtitle!,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ),
                    ]),
                  ],
                  if (entry.description != null &&
                      entry.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.description!.length > 160
                          ? '${entry.description!.substring(0, 160)}…'
                          : entry.description!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full-log item (relevance + chronology controls) ───────────────────────

class _FullLogItem extends ConsumerWidget {
  const _FullLogItem({required this.caseId, required this.entry});
  final String caseId;
  final TimelineEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _sourceColor(entry.sourceType);
    final ignored = entry.isIgnored;
    final dateStr = entry.date != null
        ? DateFormat('dd/MM/yyyy').format(entry.date!)
        : 'Date TBC';
    final ratings = ref.read(timelineRatingsProvider(caseId).notifier);

    return Opacity(
      opacity: ignored ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: entry.includedInChronology
                ? _kColor.withValues(alpha: 0.55)
                : AppColors.border,
            width: entry.includedInChronology ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _pill(dateStr, _kColor),
                if (entry.badge != null) ...[
                  const SizedBox(width: 6),
                  _pill(entry.badge!, color),
                ],
                const Spacer(),
                if (entry.pendingReview)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _pill('Suggested', AppColors.midBlue),
                  ),
                _relevanceMenu(context, ratings),
              ],
            ),
            const SizedBox(height: 8),
            Text(entry.title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            if (entry.subtitle != null && entry.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(entry.subtitle!,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
            if (entry.description != null &&
                entry.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.description!.length > 200
                    ? '${entry.description!.substring(0, 200)}…'
                    : entry.description!,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.45),
              ),
            ],
            if (entry.aiReason != null && entry.aiReason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.auto_awesome,
                    size: 11, color: AppColors.midBlue),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('AI: ${entry.aiReason!}',
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontStyle: FontStyle.italic,
                          color: AppColors.midBlue)),
                ),
              ]),
            ],
            const SizedBox(height: 10),
            _controlRow(context, ref, ratings),
          ],
        ),
      ),
    );
  }

  Widget _relevanceMenu(BuildContext context, TimelineRatingsNotifier ratings) {
    final rel = entry.relevance;
    final (label, c) = switch (rel) {
      EventRelevance.important => ('Important', AppColors.warning),
      EventRelevance.normal    => ('Normal', AppColors.textSecondary),
      EventRelevance.ignore    => ('Ignore', AppColors.error),
    };
    return PopupMenuButton<EventRelevance>(
      tooltip: 'Set relevance',
      onSelected: (v) => ratings.setRelevance(entry.eventKey, v),
      itemBuilder: (_) => [
        for (final r in EventRelevance.values)
          PopupMenuItem(value: r, child: Text(r.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (rel == EventRelevance.important)
            const Icon(Icons.star, size: 12, color: AppColors.warning),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w600, color: c)),
          Icon(Icons.arrow_drop_down, size: 16, color: c),
        ]),
      ),
    );
  }

  Widget _controlRow(
      BuildContext context, WidgetRef ref, TimelineRatingsNotifier ratings) {
    final timeline = ref.read(timelineProvider(caseId).notifier);

    // Confirm an AI suggestion.
    final confirm = entry.pendingReview
        ? TextButton.icon(
            onPressed: () => ratings.confirmSuggestion(entry.eventKey),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32)),
            icon: const Icon(Icons.check_circle_outline, size: 15),
            label: const Text('Confirm', style: TextStyle(fontSize: 12)),
          )
        : const SizedBox.shrink();

    // Chronology inclusion control.
    Widget chrono;
    if (entry.isIgnored) {
      chrono = TextButton.icon(
        onPressed: () =>
            ratings.setRelevance(entry.eventKey, EventRelevance.normal),
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32)),
        icon: const Icon(Icons.undo, size: 15),
        label: const Text('Restore', style: TextStyle(fontSize: 12)),
      );
    } else if (entry.sourceType == TimelineSourceType.manual) {
      final included = entry.includedInChronology;
      chrono = TextButton.icon(
        onPressed: () => ratings.setIncluded(entry.eventKey, !included),
        style: TextButton.styleFrom(
            foregroundColor: included ? _kColor : AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32)),
        icon: Icon(included ? Icons.playlist_add_check : Icons.playlist_add,
            size: 16),
        label: Text(included ? 'In Chronology' : 'Add to Chronology',
            style: const TextStyle(fontSize: 12)),
      );
    } else if (entry.promoted) {
      chrono = TextButton.icon(
        onPressed: () => timeline.unpromoteByKey(entry.eventKey),
        style: TextButton.styleFrom(
            foregroundColor: _kColor,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32)),
        icon: const Icon(Icons.playlist_add_check, size: 16),
        label: const Text('In Chronology', style: TextStyle(fontSize: 12)),
      );
    } else {
      chrono = TextButton.icon(
        onPressed: () => timeline.promote(entry),
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32)),
        icon: const Icon(Icons.playlist_add, size: 16),
        label: const Text('Add to Chronology', style: TextStyle(fontSize: 12)),
      );
    }

    return Row(
      children: [
        chrono,
        const Spacer(),
        confirm,
        if (entry.manualEventId != null)
          IconButton(
            tooltip: 'Delete event',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline,
                size: 16, color: AppColors.textTertiary.withValues(alpha: 0.7)),
            onPressed: () => _confirmDelete(context, ref, entry.manualEventId!),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String eventId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove event?'),
        content: const Text('This timeline entry will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(timelineProvider(caseId).notifier).delete(eventId);
    }
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────

Widget _pill(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );

Widget _emptyState({
  required IconData icon,
  required String title,
  required String body,
}) {
  return LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _kColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _kColor, size: 36),
          ),
          const SizedBox(height: 18),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5)),
        ],
      ),
    ),
        ),
      ),
    ),
  );
}

Color _sourceColor(TimelineSourceType t) => switch (t) {
      TimelineSourceType.occurrence => AppColors.coral,
      TimelineSourceType.attendance => const Color(0xFFBF7E3A),
      TimelineSourceType.repair     => AppColors.success,
      TimelineSourceType.manual     => _kColor,
    };

IconData _sourceIcon(TimelineSourceType t) => switch (t) {
      TimelineSourceType.occurrence => Icons.warning_amber_outlined,
      TimelineSourceType.attendance => Icons.calendar_today_outlined,
      TimelineSourceType.repair     => Icons.verified_outlined,
      TimelineSourceType.manual     => Icons.event_note_outlined,
    };
