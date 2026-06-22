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

class _SurveyorNotesScreenState extends ConsumerState<SurveyorNotesScreen> {
  ReportSection? _sectionFilter; // null = show all

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(surveyorNotesProvider(widget.caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Context Cues'),
        actions: [
          _SectionFilterButton(
            current: _sectionFilter,
            onSelected: (s) => setState(() => _sectionFilter = s),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteEditor(context, ref),
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Cue',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: notesAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading notes…'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notes) {
          final filtered = _sectionFilter == null
              ? notes
              : notes
                  .where((n) => n.reportSection == _sectionFilter)
                  .toList();

          if (filtered.isEmpty) {
            return _EmptyState(
              onAdd: () => _showNoteEditor(context, ref),
              filtered: _sectionFilter != null,
            );
          }
          return _NotesList(
            notes: filtered,
            onEdit: (note) => _showNoteEditor(context, ref, note: note),
            onDelete: (id) =>
                ref.read(surveyorNotesProvider(widget.caseId).notifier).delete(id),
          );
        },
      ),
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
        initialSection: note?.reportSection ?? _sectionFilter,
        onSave: (content, category, section) async {
          final notifier =
              ref.read(surveyorNotesProvider(widget.caseId).notifier);
          if (note == null) {
            await notifier.add(
              caseId:        widget.caseId,
              content:       content,
              category:      category,
              reportSection: section,
            );
          } else {
            await notifier.editNote(
              note.id,
              content:       content,
              category:      category,
              reportSection: section,
            );
          }
        },
      ),
    );
  }
}

// ── Section filter button ──────────────────────────────────────────────────

class _SectionFilterButton extends StatelessWidget {
  const _SectionFilterButton({
    required this.current,
    required this.onSelected,
  });

  final ReportSection? current;
  final void Function(ReportSection?) onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ReportSection?>(
      icon: Icon(
        Icons.filter_list,
        color: current != null ? AppColors.midBlue : null,
      ),
      tooltip: 'Filter by section',
      initialValue: current,
      onSelected: onSelected,
      itemBuilder: (_) => [
        const PopupMenuItem<ReportSection?>(
          value: null,
          child: Text('All sections',
              style: TextStyle(fontStyle: FontStyle.italic)),
        ),
        const PopupMenuDivider(),
        ...ReportSection.ordered.map(
          (s) => PopupMenuItem<ReportSection?>(
            value: s,
            child: Row(children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _sectionColor(s),
                  shape: BoxShape.circle,
                ),
              ),
              Text(s.label, style: const TextStyle(fontSize: 13)),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Cues list grouped by section ──────────────────────────────────────────

class _NotesList extends StatelessWidget {
  const _NotesList({
    required this.notes,
    required this.onEdit,
    required this.onDelete,
  });

  final List<SurveyorNote> notes;
  final void Function(SurveyorNote) onEdit;
  final void Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    final grouped = <ReportSection?, List<SurveyorNote>>{};
    for (final n in notes) {
      grouped.putIfAbsent(n.reportSection, () => []).add(n);
    }

    final sections = [
      ...ReportSection.ordered.where(grouped.containsKey),
      if (grouped.containsKey(null)) null,
    ];

    // Flat list: section header + note cards interleaved as individual items.
    // Avoids nested Column-inside-ListView which causes unreliable rendering.
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
          ),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: items,
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section, required this.count});
  final ReportSection? section;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = section != null ? _sectionColor(section!) : AppColors.textTertiary;
    final label = section?.label ?? 'Untagged';
    return Row(children: [
      Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 7),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      Text(
        label.toUpperCase(),
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
        child: Text(
          '$count',
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    ]);
  }
}

// ── Note card ──────────────────────────────────────────────────────────────

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
        : AppColors.textTertiary;
    final catColor = _categoryColor(note.category);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: sectionColor, width: 3),
          top: const BorderSide(color: AppColors.border),
          right: const BorderSide(color: AppColors.border),
          bottom: const BorderSide(color: AppColors.border),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category chip
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
                      const SizedBox(height: 5),
                      Text(
                        note.content,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.45),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDateTime(note.updatedAt),
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary),
                      ),
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
                          Text('Edit', style: TextStyle(fontSize: 13)),
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
      ),
    );
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')} '
      '${_months[dt.month - 1]} ${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

// ── Note editor sheet ──────────────────────────────────────────────────────

class _NoteEditorSheet extends StatefulWidget {
  const _NoteEditorSheet({
    required this.caseId,
    required this.onSave,
    this.existing,
    this.initialSection,
  });

  final String caseId;
  final SurveyorNote? existing;
  final ReportSection? initialSection;
  final Future<void> Function(
      String content, NoteCategory category, ReportSection? section) onSave;

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late final TextEditingController _ctrl;
  late NoteCategory _category;
  ReportSection? _section;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.existing?.content ?? '');
    _category = widget.existing?.category ?? NoteCategory.general;
    _section = widget.existing?.reportSection ?? widget.initialSection;
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

          // ── Report section picker ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REPORT SECTION',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.7),
                ),
                const SizedBox(height: 6),
                _SectionDropdown(
                  value: _section,
                  onChanged: (s) => setState(() => _section = s),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Category chips ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NOTE TYPE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.7),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: NoteCategory.values.map((cat) {
                      final selected = _category == cat;
                      final color = _categoryColor(cat);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _category = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
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
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Text input ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 7,
              minLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter note or context cue…',
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
              style:
                  const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 14),

          // ── Save button ──────────────────────────────────────────
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
                        widget.existing == null
                            ? 'Save Cue'
                            : 'Update Cue',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final content = _ctrl.text.trim();
    if (content.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(content, _category, _section);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Section dropdown ───────────────────────────────────────────────────────

class _SectionDropdown extends StatelessWidget {
  const _SectionDropdown({required this.value, required this.onChanged});
  final ReportSection? value;
  final void Function(ReportSection?) onChanged;

  @override
  Widget build(BuildContext context) {
    final color =
        value != null ? _sectionColor(value!) : AppColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<ReportSection?>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        hint: const Text('No section — general note',
            style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
                fontStyle: FontStyle.italic)),
        items: [
          const DropdownMenuItem<ReportSection?>(
            value: null,
            child: Text('No section — general note',
                style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic)),
          ),
          ...ReportSection.ordered.map((s) => DropdownMenuItem<ReportSection?>(
                value: s,
                child: Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: _sectionColor(s), shape: BoxShape.circle),
                  ),
                  Text(s.label, style: const TextStyle(fontSize: 13)),
                ]),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.filtered});
  final VoidCallback onAdd;
  final bool filtered;

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
          Text(
            filtered ? 'No cues for this section' : 'No context cues yet',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            filtered
                ? 'Add a context cue tagged to this report section'
                : 'Capture observations, measurements, interview notes\n'
                    'and tag them to a report section',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
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

// ── Helpers ────────────────────────────────────────────────────────────────

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
      NoteCategory.observation => const Color(0xFF2A6099),
      NoteCategory.measurement => const Color(0xFF7B5EA7),
      NoteCategory.followUp    => const Color(0xFFD97706),
      NoteCategory.interview   => const Color(0xFF0891B2),
      NoteCategory.technical   => const Color(0xFFDC2626),
      NoteCategory.general     => const Color(0xFF4A7A5A),
    };
