// lib/features/surveyor_notes/screens/surveyor_notes_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/surveyor_note_model.dart';
import '../providers/surveyor_notes_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

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
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(surveyorNotesProvider(widget.caseId));

    return notesAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('Context Cues')),
        body: const AppLoadingWidget(message: 'Loading cues…'),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('Context Cues')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (notes) {
        final retained    = notes.where((n) =>
            n.priority != CuePriority.ignored &&
            n.reportSection != null).toList();
        final unallocated = notes.where((n) =>
            n.priority != CuePriority.ignored &&
            n.reportSection == null).toList();
        final ignored     = notes.where((n) =>
            n.priority == CuePriority.ignored).toList();

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: const Text('Context Cues'),
            bottom: TabBar(
              controller: _tabCtrl,
              labelColor: _kColor,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: _kColor,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              tabs: [
                const Tab(text: 'Retained'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Unallocated',
                          style: TextStyle(fontSize: 12)),
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
                      const Text('Ignored',
                          style: TextStyle(fontSize: 12)),
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
            label: const Text('Add Cue',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              // ── Retained ──────────────────────────────────────────────
              retained.isEmpty
                  ? _EmptyState(
                      message: 'No retained cues yet',
                      sub: 'Assign a report section to a cue to retain it here',
                      onAdd: () => _showNoteEditor(context, ref),
                    )
                  : _RetainedList(
                      notes: retained,
                      onEdit: (n) => _showNoteEditor(context, ref, note: n),
                      onDelete: (id) => ref
                          .read(surveyorNotesProvider(widget.caseId).notifier)
                          .delete(id),
                    ),

              // ── Unallocated ───────────────────────────────────────────
              unallocated.isEmpty
                  ? _EmptyState(
                      message: 'No unallocated cues',
                      sub: 'New cues without a report section appear here',
                      onAdd: () => _showNoteEditor(context, ref),
                    )
                  : _FlatList(
                      notes: unallocated,
                      onEdit: (n) => _showNoteEditor(context, ref, note: n),
                      onDelete: (id) => ref
                          .read(surveyorNotesProvider(widget.caseId).notifier)
                          .delete(id),
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
        onSave: (content, category, section, priority,
            updateResolvedAt, resolvedAt) async {
          final notifier =
              ref.read(surveyorNotesProvider(widget.caseId).notifier);
          if (note == null) {
            await notifier.add(
              caseId:        widget.caseId,
              content:       content,
              category:      category,
              reportSection: section,
              priority:      priority,
              resolvedAt:    resolvedAt,
            );
          } else {
            await notifier.editNote(
              note.id,
              content:          content,
              category:         category,
              reportSection:    section,
              priority:         priority,
              updateResolvedAt: updateResolvedAt,
              resolvedAt:       resolvedAt,
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

// ── Retained list (grouped by report section) ─────────────────────────────

class _RetainedList extends StatelessWidget {
  const _RetainedList(
      {required this.notes, required this.onEdit, required this.onDelete});
  final List<SurveyorNote> notes;
  final void Function(SurveyorNote) onEdit;
  final void Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    final grouped = <ReportSection, List<SurveyorNote>>{};
    for (final n in notes) {
      grouped.putIfAbsent(n.reportSection!, () => []).add(n);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    }

    final sections = ReportSection.ordered.where(grouped.containsKey).toList();

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
              onDelete: () => onDelete(note.id)),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: items,
    );
  }
}

// ── Flat list (unallocated + ignored) ────────────────────────────────────

class _FlatList extends StatelessWidget {
  const _FlatList(
      {required this.notes, required this.onEdit, required this.onDelete});
  final List<SurveyorNote> notes;
  final void Function(SurveyorNote) onEdit;
  final void Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    // Group by category for unallocated; flat for ignored
    final grouped = <NoteCategory, List<SurveyorNote>>{};
    for (final n in notes) {
      grouped.putIfAbsent(n.category, () => []).add(n);
    }

    final items = <Widget>[];
    var first = true;
    for (final cat in NoteCategory.values) {
      final list = grouped[cat];
      if (list == null) continue;
      if (!first) items.add(const SizedBox(height: 18));
      first = false;
      items.add(_CategoryHeader(category: cat, count: list.length));
      items.add(const SizedBox(height: 8));
      for (final note in list) {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _NoteCard(
              note: note,
              onEdit: () => onEdit(note),
              onDelete: () => onDelete(note.id)),
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
  final ReportSection section;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = _sectionColor(section);
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

// ── Category header ───────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category, required this.count});
  final NoteCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Row(children: [
      Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 7),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      Text(
        category.label.toUpperCase(),
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

// ── Note card ─────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final SurveyorNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final sectionColor = note.reportSection != null
        ? _sectionColor(note.reportSection!)
        : const Color(0xFFD97706);
    final catColor = _categoryColor(note.category);
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
                Container(width: 4, color: sectionColor),
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
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    note.category.label,
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: catColor),
                                  ),
                                ),
                                if (note.priority != CuePriority.normal) ...[
                                  const SizedBox(width: 5),
                                  _PriorityBadge(priority: note.priority),
                                ],
                              ]),
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
                                  _formatDate(note.updatedAt),
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
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ]),
                                    ),
                                  ),
                                ],
                                if (note.isResolved) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '✓ Resolved ${_formatDate(note.resolvedAt!)}',
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ]),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              size: 16, color: AppColors.textTertiary),
                          onSelected: (v) {
                            if (v == 'edit') onEdit();
                            if (v == 'delete') onDelete();
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit_outlined, size: 15),
                                  SizedBox(width: 8),
                                  Text('Edit',
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
                                          fontSize: 13,
                                          color: Colors.red)),
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

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')} '
      '${_months[dt.month - 1]} ${dt.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
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
  NoteCategory category,
  ReportSection? section,
  CuePriority priority,
  bool updateResolvedAt,
  DateTime? resolvedAt,
);

class _NoteEditorSheet extends StatefulWidget {
  const _NoteEditorSheet({
    required this.caseId,
    required this.onSave,
    this.existing,
  });

  final String caseId;
  final SurveyorNote? existing;
  final _OnSave onSave;

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late final TextEditingController _ctrl;
  late NoteCategory _category;
  late CuePriority _priority;
  ReportSection? _section;
  bool _updateResolvedAt = false;
  DateTime? _resolvedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.existing?.content ?? '');
    _category = widget.existing?.category ?? NoteCategory.general;
    _priority = widget.existing?.priority ?? CuePriority.normal;
    _resolvedAt = widget.existing?.resolvedAt;
    _section = widget.existing?.reportSection;
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

            // Report section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('REPORT SECTION',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.7)),
                  const SizedBox(height: 6),
                  _SectionChips(
                    value: _section,
                    onChanged: (s) => setState(() => _section = s),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Category
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NOTE TYPE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.7)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: NoteCategory.values.map((cat) {
                      final selected = _category == cat;
                      final color = _categoryColor(cat);
                      return GestureDetector(
                        onTap: () => setState(() => _category = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? color
                                : color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: color.withValues(
                                    alpha: selected ? 1.0 : 0.25)),
                          ),
                          child: Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : color,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Priority
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? color.withValues(alpha: 0.12)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: selected
                                        ? color
                                        : AppColors.border,
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
            const SizedBox(height: 10),

            // Text input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                maxLines: 6,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter context cue…',
                  hintStyle: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _kColor, width: 1.5)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 10),

            // Resolved date
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('RESOLVED',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.7)),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _resolvedAt ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _resolvedAt = picked;
                          _updateResolvedAt = true;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _resolvedAt != null
                            ? AppColors.success.withValues(alpha: 0.08)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _resolvedAt != null
                              ? AppColors.success.withValues(alpha: 0.4)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        _resolvedAt != null
                            ? '${_resolvedAt!.day.toString().padLeft(2, '0')} '
                                '${_months[_resolvedAt!.month - 1]} ${_resolvedAt!.year}'
                            : 'Set date…',
                        style: TextStyle(
                          fontSize: 12,
                          color: _resolvedAt != null
                              ? AppColors.success
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  if (_resolvedAt != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() {
                        _resolvedAt = null;
                        _updateResolvedAt = true;
                      }),
                      child: const Icon(Icons.close,
                          size: 16, color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
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
    final content = _ctrl.text.trim();
    if (content.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
          content, _category, _section, _priority, _updateResolvedAt, _resolvedAt);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

// ── Section quick-pick chips ──────────────────────────────────────────────

class _SectionChips extends StatelessWidget {
  const _SectionChips({required this.value, required this.onChanged});
  final ReportSection? value;
  final void Function(ReportSection?) onChanged;

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
                fontWeight:
                    value == null ? FontWeight.w700 : FontWeight.w400,
                color: value == null
                    ? AppColors.textSecondary
                    : AppColors.textTertiary,
              ),
            ),
          ),
        ),
        ...ReportSection.ordered.map((s) {
          final selected = value == s;
          final color = _sectionColor(s);
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
                color: _kColor.withValues(alpha: 0.1),
                shape: BoxShape.circle),
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
            label: const Text('Add Cue'),
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

// ── Helpers ───────────────────────────────────────────────────────────────

Color _sectionColor(ReportSection s) => switch (s) {
      ReportSection.background      => const Color(0xFF2A6B9E),
      ReportSection.occurrence      => const Color(0xFFDC2626),
      ReportSection.attendance      => const Color(0xFFBF7E3A),
      ReportSection.timeline        => const Color(0xFF2E7CB7),
      ReportSection.causation       => const Color(0xFFD97706),
      ReportSection.damage          => const Color(0xFFE05C2A),
      ReportSection.repairs         => const Color(0xFF1A6B9E),
      ReportSection.repairTimes     => const Color(0xFF0F766E),
      ReportSection.extraExpenses   => const Color(0xFF059669),
      ReportSection.generalExpenses => const Color(0xFF4A7A5A),
      ReportSection.notAverage      => const Color(0xFF6B7280),
      ReportSection.otherMatters    => const Color(0xFF7B5EA7),
    };

Color _categoryColor(NoteCategory cat) => switch (cat) {
      NoteCategory.observation   => const Color(0xFF2A6099),
      NoteCategory.measurement   => const Color(0xFF7B5EA7),
      NoteCategory.followUp      => const Color(0xFFD97706),
      NoteCategory.interview     => const Color(0xFF0891B2),
      NoteCategory.technical     => const Color(0xFFDC2626),
      NoteCategory.operations    => const Color(0xFF0F766E),
      NoteCategory.previousWorks => const Color(0xFF6B7280),
      NoteCategory.policy        => const Color(0xFF4338CA),
      NoteCategory.invoicing     => const Color(0xFF0284C7),
      NoteCategory.general       => const Color(0xFF4A7A5A),
    };

Color _priorityColor(CuePriority p) => switch (p) {
      CuePriority.important => const Color(0xFFDC2626),
      CuePriority.normal    => AppColors.textSecondary,
      CuePriority.ignored   => AppColors.textTertiary,
    };
