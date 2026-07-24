// lib/features/surveyor_notes/screens/surveyor_notes_screen.dart
//
// Cue metadata rework (docs/context_cue_system_review.md §3.4, §3.6, 5 July
// 2026): `ReportSection` renamed `CaseSection`; `NoteCategory` retired,
// replaced by `NatureOfContent`/`EvidentiaryWeight` axes plus a new
// `origin` field; Priority moved to the top of the editor sheet; the manual
// "Resolved" date picker removed — lostRelevanceAt is now auto-set by the
// provider when a cue's priority flips to Ignored, not a separately
// toggled state. Colour helpers and chip-row widgets now reused from
// context_cues_panel.dart instead of duplicated here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/surveyor_note_model.dart';
import '../providers/surveyor_notes_provider.dart';
import '../../timeline/providers/timeline_provider.dart';
import '../../timeline/utils/cue_to_event.dart';
import '../../survey/models/repair_period_model.dart';
import '../../survey/providers/repair_period_provider.dart';
import '../../survey/widgets/quick_create_repair_period.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/context_cues_panel.dart';
import '../../../shared/widgets/back_app_bar.dart';

const _kColor = Color(0xFF4A7A5A);

class SurveyorNotesScreen extends ConsumerStatefulWidget {
  const SurveyorNotesScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<SurveyorNotesScreen> createState() =>
      _SurveyorNotesScreenState();
}

class _SurveyorNotesScreenState extends ConsumerState<SurveyorNotesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(surveyorNotesProvider(widget.caseId));
    final timelineAsync = ref.watch(timelineProvider(widget.caseId));
    final eventSourceKeys = timelineAsync.valueOrNull
            ?.map((e) => e.sourceKey)
            .whereType<String>()
            .toSet() ??
        <String>{};
    bool hasEvent(SurveyorNote n) =>
        eventSourceKeys.contains(cueEventSourceKey(n.id));
    void onCreateEvent(SurveyorNote n) => convertCueToTimelineEvent(
          context,
          ref,
          caseId: widget.caseId,
          note: n,
        );

    return notesAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.surface,
        appBar: BackAppBar(title: Text('Notes')),
        body: AppLoadingWidget(message: 'Loading cues…'),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const BackAppBar(title: Text('Notes')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (notes) {
        final suggested = notes
            .where((n) => n.priority != CuePriority.ignored && n.pendingReview)
            .toList();
        final retained = notes
            .where((n) =>
                n.priority != CuePriority.ignored &&
                !n.pendingReview &&
                n.caseSection != null)
            .toList();
        final unallocated = notes
            .where((n) =>
                n.priority != CuePriority.ignored &&
                !n.pendingReview &&
                n.caseSection == null)
            .toList();
        final ignored =
            notes.where((n) => n.priority == CuePriority.ignored).toList();

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: BackAppBar(
            title: const Text('Notes'),
            bottom: TabBar(
              controller: _tabCtrl,
              labelColor: _kColor,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: _kColor,
              labelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: [
                const Tab(text: 'Retained'),
                // 4 tabs sharing a non-scrollable TabBar squeeze to ~68dp
                // each on a ~400dp phone — "Suggested"/"Unallocated" plus
                // their badge overflowed that on real narrow devices
                // (caught by a widget test, same class of bug as the
                // Accounts/Causation overflow fixes earlier tonight).
                // Flexible + ellipsis lets the label shrink instead.
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Flexible(
                        child: Text('Suggested',
                            style: TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (suggested.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        _Badge(
                            count: suggested.length, color: AppColors.midBlue),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Flexible(
                        child: Text('Unallocated',
                            style: TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (unallocated.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        _Badge(count: unallocated.length),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Flexible(
                        child: Text('Ignored',
                            style: TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (ignored.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        _Badge(
                            count: ignored.length,
                            color: AppColors.textTertiary),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showNoteEditor(context, ref),
            backgroundColor: _kColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Note',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              // ── Retained ──────────────────────────────────────────────
              retained.isEmpty
                  ? _EmptyState(
                      message: 'No retained cues yet',
                      sub: 'Assign a case section to a cue to retain it here',
                      onAdd: () => _showNoteEditor(context, ref),
                    )
                  : _RetainedList(
                      notes: retained,
                      onEdit: (n) => _showNoteEditor(context, ref, note: n),
                      onDelete: (id) => ref
                          .read(surveyorNotesProvider(widget.caseId).notifier)
                          .delete(id),
                      hasEvent: hasEvent,
                      onCreateEvent: onCreateEvent,
                    ),

              // ── Suggested (AI-extracted, awaiting review) ────────────────
              suggested.isEmpty
                  ? _EmptyState(
                      message: 'No suggested cues',
                      sub:
                          'AI-extracted cues awaiting your confirmation appear here',
                      onAdd: () => _showNoteEditor(context, ref),
                    )
                  : _FlatList(
                      notes: suggested,
                      onEdit: (n) => _showNoteEditor(context, ref, note: n),
                      onDelete: (id) => ref
                          .read(surveyorNotesProvider(widget.caseId).notifier)
                          .delete(id),
                      onConfirm: (id) => ref
                          .read(surveyorNotesProvider(widget.caseId).notifier)
                          .confirmAllocation(id),
                      hasEvent: hasEvent,
                      onCreateEvent: onCreateEvent,
                    ),

              // ── Unallocated ───────────────────────────────────────────
              unallocated.isEmpty
                  ? _EmptyState(
                      message: 'No unallocated cues',
                      sub: 'New cues without a case section appear here',
                      onAdd: () => _showNoteEditor(context, ref),
                    )
                  : _FlatList(
                      notes: unallocated,
                      onEdit: (n) => _showNoteEditor(context, ref, note: n),
                      onDelete: (id) => ref
                          .read(surveyorNotesProvider(widget.caseId).notifier)
                          .delete(id),
                      hasEvent: hasEvent,
                      onCreateEvent: onCreateEvent,
                    ),

              // ── Ignored ───────────────────────────────────────────────
              ignored.isEmpty
                  ? _EmptyState(
                      message: 'No ignored cues',
                      sub: 'Cues marked as ignored appear here',
                      onAdd: () => _showNoteEditor(context, ref),
                    )
                  : _FlatList(
                      notes: ignored,
                      onEdit: (n) => _showNoteEditor(context, ref, note: n),
                      onDelete: (id) => ref
                          .read(surveyorNotesProvider(widget.caseId).notifier)
                          .delete(id),
                    ),
            ],
          ),
        );
      },
    );
  }

  void _showNoteEditor(BuildContext context, WidgetRef ref,
      {SurveyorNote? note}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoteEditorSheet(
        caseId: widget.caseId,
        existing: note,
        onSave: (content, section, phase, priority, weight, origin,
            linkedPeriodId) async {
          final notifier =
              ref.read(surveyorNotesProvider(widget.caseId).notifier);
          final linkedToType =
              section?.isRepairPeriodScoped == true && linkedPeriodId != null
                  ? repairPeriodLinkType
                  : null;
          if (note == null) {
            await notifier.add(
              caseId: widget.caseId,
              content: content,
              caseSection: section,
              occurrencePhase: phase,
              priority: priority,
              evidentiaryWeight: weight,
              origin: origin,
              linkedToType: linkedToType,
              linkedToId: linkedToType != null ? linkedPeriodId : null,
            );
          } else {
            await notifier.editNote(
              note.id,
              content: content,
              caseSection: section,
              occurrencePhase: phase,
              priority: priority,
              evidentiaryWeight: weight,
              origin: origin,
              linkedToType: linkedToType,
              linkedToId: linkedToType != null ? linkedPeriodId : null,
            );
          }
        },
      ),
    );
  }
}

// ── Tab badge ──────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.count, this.color = _kColor});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

// ── Retained list (grouped by case section) ────────────────────────────────

class _RetainedList extends StatelessWidget {
  const _RetainedList({
    required this.notes,
    required this.onEdit,
    required this.onDelete,
    this.hasEvent,
    this.onCreateEvent,
  });
  final List<SurveyorNote> notes;
  final void Function(SurveyorNote) onEdit;
  final void Function(String) onDelete;
  final bool Function(SurveyorNote)? hasEvent;
  final void Function(SurveyorNote)? onCreateEvent;

  @override
  Widget build(BuildContext context) {
    final grouped = <CaseSection, List<SurveyorNote>>{};
    for (final n in notes) {
      grouped.putIfAbsent(n.caseSection!, () => []).add(n);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    }

    final sections = CaseSection.ordered.where(grouped.containsKey).toList();

    final items = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final sectionNotes = grouped[section]!;
      if (i > 0) items.add(const SizedBox(height: 18));
      items.add(_SectionHeader(section: section, count: sectionNotes.length));
      items.add(const SizedBox(height: 8));
      for (final note in sectionNotes) {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _NoteCard(
              note: note,
              onEdit: () => onEdit(note),
              onDelete: () => onDelete(note.id),
              hasEvent: hasEvent?.call(note) ?? false,
              onCreateEvent:
                  onCreateEvent == null ? null : () => onCreateEvent!(note)),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: items,
    );
  }
}

// ── Flat list (unallocated + ignored) — grouped by nature of content ──────

class _FlatList extends StatelessWidget {
  const _FlatList({
    required this.notes,
    required this.onEdit,
    required this.onDelete,
    this.onConfirm,
    this.hasEvent,
    this.onCreateEvent,
  });
  final List<SurveyorNote> notes;
  final void Function(SurveyorNote) onEdit;
  final void Function(String) onDelete;
  final void Function(String)? onConfirm;
  final bool Function(SurveyorNote)? hasEvent;
  final void Function(SurveyorNote)? onCreateEvent;

  @override
  Widget build(BuildContext context) {
    // Grouped by case section (the cue's routing destination) — the
    // Nature-of-content axis was dropped as unhelpful (23 July 2026).
    final grouped = <CaseSection?, List<SurveyorNote>>{};
    for (final n in notes) {
      grouped.putIfAbsent(n.caseSection, () => []).add(n);
    }

    final items = <Widget>[];
    var first = true;
    for (final section in [...CaseSection.ordered, null]) {
      final list = grouped[section];
      if (list == null) continue;
      if (!first) items.add(const SizedBox(height: 18));
      first = false;
      items.add(section != null
          ? _SectionHeader(section: section, count: list.length)
          : _UnsortedHeader(count: list.length));
      items.add(const SizedBox(height: 8));
      for (final note in list) {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _NoteCard(
              note: note,
              onEdit: () => onEdit(note),
              onDelete: () => onDelete(note.id),
              onConfirm: onConfirm != null ? () => onConfirm!(note.id) : null,
              hasEvent: hasEvent?.call(note) ?? false,
              onCreateEvent:
                  onCreateEvent == null ? null : () => onCreateEvent!(note)),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: items,
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section, required this.count});
  final CaseSection section;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = sectionColor(section);
    return Row(children: [
      Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 7),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      Text(
        section.label.toUpperCase(),
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.8),
      ),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$count',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }
}

// ── Unsorted header (cues with no case section yet) ────────────────────────

class _UnsortedHeader extends StatelessWidget {
  const _UnsortedHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.textTertiary;
    return Row(children: [
      Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 7),
        decoration: const BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const Text(
        'UNSORTED',
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.8),
      ),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$count',
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }
}

// ── Note card ─────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
    this.onConfirm,
    this.hasEvent = false,
    this.onCreateEvent,
  });

  final SurveyorNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onConfirm;
  /// Whether a Timeline event already links back to this cue via
  /// `sourceKey` (15 July 2026 walkthrough §16 — "Event created" pill).
  final bool hasEvent;
  final VoidCallback? onCreateEvent;

  @override
  Widget build(BuildContext context) {
    final secColor = note.caseSection != null
        ? sectionColor(note.caseSection!)
        : const Color(0xFFD97706);
    final isIgnored = note.priority == CuePriority.ignored;

    return Opacity(
      opacity: isIgnored ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: secColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (note.evidentiaryWeight != null)
                                    _MetaChip(
                                      label: note.evidentiaryWeight!.label,
                                      color: evidentiaryWeightColor(
                                          note.evidentiaryWeight!),
                                    ),
                                  if (note.origin != null)
                                    _MetaChip(
                                      label: note.origin!.label,
                                      color: cueOriginColor(note.origin!),
                                    ),
                                  if (note.priority != CuePriority.normal)
                                    _PriorityBadge(priority: note.priority),
                                  if (note.pendingReview)
                                    const _MetaChip(
                                      label: 'Suggested',
                                      color: AppColors.midBlue,
                                    ),
                                  if (hasEvent)
                                    const _MetaChip(
                                      label: 'Event',
                                      color: AppColors.midBlue,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                note.content,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isIgnored
                                        ? AppColors.textTertiary
                                        : AppColors.textPrimary,
                                    height: 1.45),
                              ),
                              const SizedBox(height: 6),
                              Row(children: [
                                Text(
                                  // Document's own date when the cue came from
                                  // one (email/report date), else the edit time.
                                  _formatDate(
                                      note.contentDate ?? note.updatedAt),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textTertiary),
                                ),
                                if (note.source != null) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.midBlue
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                                Icons.description_outlined,
                                                size: 9,
                                                color: AppColors.midBlue),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                note.source!,
                                                style: const TextStyle(
                                                    fontSize: 9,
                                                    color: AppColors.midBlue,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ]),
                                    ),
                                  ),
                                ],
                                if (note.hasLostRelevance) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.textTertiary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Lost relevance ${_formatDate(note.lostRelevanceAt!)}',
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ]),
                            ],
                          ),
                        ),
                        if (onConfirm != null) ...[
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline,
                                size: 18, color: AppColors.midBlue),
                            tooltip: 'Confirm allocation',
                            onPressed: onConfirm,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 6),
                        ],
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              size: 16, color: AppColors.textTertiary),
                          onSelected: (v) {
                            if (v == 'edit') onEdit();
                            if (v == 'delete') onDelete();
                            if (v == 'event') onCreateEvent?.call();
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit_outlined, size: 15),
                                  SizedBox(width: 8),
                                  Text('Edit', style: TextStyle(fontSize: 13)),
                                ])),
                            if (!hasEvent && onCreateEvent != null)
                              const PopupMenuItem(
                                  value: 'event',
                                  child: Row(children: [
                                    Icon(Icons.event_outlined,
                                        size: 15, color: AppColors.midBlue),
                                    SizedBox(width: 8),
                                    Text('Create event',
                                        style: TextStyle(fontSize: 13)),
                                  ])),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete_outline,
                                      size: 15, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(
                                          fontSize: 13, color: Colors.red)),
                                ])),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')} '
      '${_months[dt.month - 1]} ${dt.year}';

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

// ── Small metadata chip (nature / weight / origin) ─────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ── Priority badge ────────────────────────────────────────────────────────

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final CuePriority priority;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (priority) {
      CuePriority.important => (
          const Color(0xFFDC2626),
          Icons.priority_high,
          'Important',
        ),
      CuePriority.ignored => (
          AppColors.textTertiary,
          Icons.do_not_disturb_outlined,
          'Ignored',
        ),
      CuePriority.normal => (AppColors.textTertiary, Icons.circle, 'Normal'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 9, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ── Note editor sheet ─────────────────────────────────────────────────────

typedef _OnSave = Future<void> Function(
  String content,
  CaseSection? section,
  OccurrencePhase? phase,
  CuePriority priority,
  EvidentiaryWeight? weight,
  CueOrigin? origin,
  String? linkedPeriodId,
);

class _NoteEditorSheet extends ConsumerStatefulWidget {
  const _NoteEditorSheet({
    required this.caseId,
    required this.onSave,
    this.existing,
  });

  final String caseId;
  final SurveyorNote? existing;
  final _OnSave onSave;

  @override
  ConsumerState<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<_NoteEditorSheet> {
  late final TextEditingController _ctrl;
  late CuePriority _priority;
  CaseSection? _section;
  OccurrencePhase? _phase;
  EvidentiaryWeight? _weight;
  CueOrigin? _origin;
  String? _periodId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.existing?.content ?? '');
    _priority = widget.existing?.priority ?? CuePriority.normal;
    _section = widget.existing?.caseSection;
    _phase = widget.existing?.occurrencePhase;
    _weight = widget.existing?.evidentiaryWeight;
    _origin = widget.existing?.origin;
    _periodId = widget.existing?.linkedToType == repairPeriodLinkType
        ? widget.existing?.linkedToId
        : null;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    widget.existing == null ? 'New Context Cue' : 'Edit Cue',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Priority — first decision, positioned at the top ────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PRIORITY',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.7)),
                  const SizedBox(height: 6),
                  Row(
                    children: CuePriority.values.map((p) {
                      final selected = _priority == p;
                      final color = _priorityColor(p);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _priority = p),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? color.withValues(alpha: 0.12)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: selected ? color : AppColors.border,
                                    width: selected ? 1.5 : 1.0),
                              ),
                              child: Text(
                                p.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: selected
                                      ? color
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Cue text + its origin, moved up here (right after Priority,
            // ahead of the classification chips below) so both are visible
            // while classifying instead of buried further down — this is
            // what actually informs the classification decision (14 July
            // 2026 walkthrough).
            if (widget.existing?.source != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.midBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    const Icon(Icons.description_outlined,
                        size: 12, color: AppColors.midBlue),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        widget.existing!.source!,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.midBlue,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                maxLines: 6,
                minLines: 3,
                // Prompt the keyboard / voice dictation to capitalise the
                // first character; _save() also hard-capitalises it so a cue
                // reads correctly even when the STT transcript omits it
                // (16 July 2026 occurrence/cue UX sweep, item 3).
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Enter context cue…',
                  hintStyle: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kColor, width: 1.5)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 12),

            // Case section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CASE SECTION',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.7)),
                  const SizedBox(height: 6),
                  _SectionChips(
                    value: _section,
                    onChanged: (s) => setState(() {
                      _section = s;
                      if (s != CaseSection.occurrence) _phase = null;
                    }),
                  ),
                ],
              ),
            ),
            // Occurrence-phase sub-route — mirrors the extraction sheet so a
            // cue can be sorted into Before/Incident/Aftermath from the editor
            // too (24 July 2026 report: "works during extraction, not in the
            // editor").
            if (_section == CaseSection.occurrence) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LabeledCueChipRow<OccurrencePhase>(
                  label: 'Occurrence phase',
                  values: OccurrencePhase.ordered,
                  selected: _phase,
                  labelOf: (p) => p.label,
                  colorOf: (_) => const Color(0xFFE05C2A),
                  onTap: (p) =>
                      setState(() => _phase = _phase == p ? null : p),
                ),
              ),
            ],
            if (_section?.isRepairPeriodScoped == true) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('REPAIR PERIOD',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.7)),
                    const SizedBox(height: 6),
                    _RepairPeriodChips(
                      caseId: widget.caseId,
                      value: _periodId,
                      onChanged: (id) => setState(() => _periodId = id),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),

            // ── Further classification skipped once Ignored (14 July 2026
            // walkthrough): an ignored cue isn't going to be allocated
            // further, so these menus were pointless to fill in regardless.
            if (_priority != CuePriority.ignored) ...[
              LabeledCueChipRow<EvidentiaryWeight>(
                label: 'Evidentiary weight',
                values: EvidentiaryWeight.values,
                selected: _weight,
                labelOf: (w) => w.label,
                colorOf: evidentiaryWeightColor,
                onTap: (w) =>
                    setState(() => _weight = _weight == w ? null : w),
              ),
              const SizedBox(height: 10),
              LabeledCueChipRow<CueOrigin>(
                label: 'Origin',
                values: CueOrigin.values,
                selected: _origin,
                labelOf: (o) => o.label,
                colorOf: cueOriginColor,
                onTap: (o) =>
                    setState(() => _origin = _origin == o ? null : o),
              ),
            ],
            const SizedBox(height: 14),

            // Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          widget.existing == null ? 'Save Cue' : 'Update Cue',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final content = capitalizeCueContent(_ctrl.text.trim());
    if (content.isEmpty) return;
    setState(() => _saving = true);
    try {
      final linkedPeriodId =
          _section?.isRepairPeriodScoped == true ? _periodId : null;
      final phase = _section == CaseSection.occurrence ? _phase : null;
      await widget.onSave(content, _section, phase, _priority, _weight,
          _origin, linkedPeriodId);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

Color _priorityColor(CuePriority p) => switch (p) {
      CuePriority.important => const Color(0xFFDC2626),
      CuePriority.normal => AppColors.textSecondary,
      CuePriority.ignored => AppColors.textTertiary,
    };

// ── Repair-period quick-pick chips (WNCA / General Services & Access) ─────
//
// Cascading second choice for CaseSection.isRepairPeriodScoped sections —
// docs/context_cue_system_review.md §3.1. "Unassigned" is always available
// and is the default (a cue in one of these sections doesn't have to be
// tied to a period). Includes an inline quick-create shortcut so the
// surveyor never has to leave this sheet to record against a period that
// doesn't exist yet.

class _RepairPeriodChips extends ConsumerWidget {
  const _RepairPeriodChips({
    required this.caseId,
    required this.value,
    required this.onChanged,
  });

  final String caseId;
  final String? value;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodsAsync = ref.watch(repairPeriodsProvider(caseId));
    final periods = periodsAsync.value ?? const <RepairPeriodModel>[];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        GestureDetector(
          onTap: () => onChanged(null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: value == null
                  ? AppColors.warning.withValues(alpha: 0.18)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.warning
                    .withValues(alpha: value == null ? 0.6 : 0.2),
                width: value == null ? 1.5 : 1.0,
              ),
            ),
            child: Text(
              'Unassigned',
              style: TextStyle(
                fontSize: 11,
                fontWeight: value == null ? FontWeight.w700 : FontWeight.w400,
                color:
                    value == null ? AppColors.warning : AppColors.textTertiary,
              ),
            ),
          ),
        ),
        ...periods.map((p) {
          final selected = value == p.periodId;
          return GestureDetector(
            onTap: () => onChanged(p.periodId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.midBlue
                    : AppColors.midBlue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.midBlue
                      .withValues(alpha: selected ? 1.0 : 0.25),
                  width: selected ? 1.5 : 1.0,
                ),
              ),
              child: Text(
                p.displayTitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? Colors.white : AppColors.midBlue,
                ),
              ),
            ),
          );
        }),
        GestureDetector(
          onTap: () async {
            final nextNo = periods.isEmpty
                ? 1
                : periods
                        .map((p) => p.periodNo)
                        .reduce((a, b) => a > b ? a : b) +
                    1;
            final createdId = await showQuickCreateRepairPeriodDialog(
              context,
              ref,
              caseId: caseId,
              nextPeriodNo: nextNo,
            );
            if (createdId != null) onChanged(createdId);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 12, color: AppColors.textSecondary),
                SizedBox(width: 3),
                Text('New Period',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section quick-pick chips ──────────────────────────────────────────────

class _SectionChips extends StatelessWidget {
  const _SectionChips({required this.value, required this.onChanged});
  final CaseSection? value;
  final void Function(CaseSection?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        GestureDetector(
          onTap: () => onChanged(null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: value == null
                  ? AppColors.textTertiary.withValues(alpha: 0.18)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.textTertiary
                    .withValues(alpha: value == null ? 0.5 : 0.2),
                width: value == null ? 1.5 : 1.0,
              ),
            ),
            child: Text(
              'None',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                fontWeight: value == null ? FontWeight.w700 : FontWeight.w400,
                color: value == null
                    ? AppColors.textSecondary
                    : AppColors.textTertiary,
              ),
            ),
          ),
        ),
        ...CaseSection.ordered.map((s) {
          final selected = value == s;
          final color = sectionColor(s);
          return GestureDetector(
            onTap: () => onChanged(selected ? null : s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? color : color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: selected ? 1.0 : 0.25),
                  width: selected ? 1.5 : 1.0,
                ),
              ),
              child: Text(
                s.shortLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.message, required this.sub, required this.onAdd});
  final String message;
  final String sub;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: _kColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.edit_note, color: _kColor, size: 30),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Note'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
