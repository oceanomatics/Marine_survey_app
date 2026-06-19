// lib/features/surveyor_notes/screens/surveyor_notes_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/surveyor_note_model.dart';
import '../providers/surveyor_notes_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

const _kColor = Color(0xFF4A7A5A);

class SurveyorNotesScreen extends ConsumerWidget {
  const SurveyorNotesScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(surveyorNotesProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Surveyor Notes'),
        actions: [
          PopupMenuButton<NoteCategory>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by category',
            onSelected: (_) {},
            itemBuilder: (_) => NoteCategory.values
                .map((c) => PopupMenuItem(
                      value: c,
                      child: Row(children: [
                        _CategoryDot(category: c),
                        const SizedBox(width: 8),
                        Text(c.label,
                            style: const TextStyle(fontSize: 13)),
                      ]),
                    ))
                .toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteEditor(context, ref),
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Note',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: notesAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading notes…'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notes) => notes.isEmpty
            ? _EmptyState(onAdd: () => _showNoteEditor(context, ref))
            : _NotesList(
                notes: notes,
                onEdit: (note) => _showNoteEditor(context, ref, note: note),
                onDelete: (noteId) => ref
                    .read(surveyorNotesProvider(caseId).notifier)
                    .delete(noteId),
              ),
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
        caseId: caseId,
        existing: note,
        onSave: (content, category) async {
          final notifier =
              ref.read(surveyorNotesProvider(caseId).notifier);
          if (note == null) {
            await notifier.add(
              caseId: caseId,
              content: content,
              category: category,
            );
          } else {
            await notifier.editNote(
              note.id,
              content: content,
              category: category,
            );
          }
        },
      ),
    );
  }
}

// ── Notes list ─────────────────────────────────────────────────────────────

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
    final grouped = <NoteCategory, List<SurveyorNote>>{};
    for (final n in notes) {
      grouped.putIfAbsent(n.category, () => []).add(n);
    }

    final categories = NoteCategory.values
        .where((c) => grouped.containsKey(c))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final cat = categories[i];
        final catNotes = grouped[cat]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 0) const SizedBox(height: 18),
            _CategoryHeader(category: cat, count: catNotes.length),
            const SizedBox(height: 8),
            ...catNotes.map((note) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _NoteCard(
                    note: note,
                    onEdit: () => onEdit(note),
                    onDelete: () => onDelete(note.id),
                  ),
                )),
          ],
        );
      },
    );
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
    final catColor = _categoryColor(note.category);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: catColor, width: 3),
          top: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
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

  String _formatDateTime(DateTime dt) {
    final d = dt;
    return '${d.day.toString().padLeft(2, '0')} '
        '${_months[d.month - 1]} ${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

// ── Category header ────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category, required this.count});
  final NoteCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Row(children: [
      _CategoryDot(category: category),
      const SizedBox(width: 7),
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
        child: Text(
          '$count',
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    ]);
  }
}

// ── Category dot ───────────────────────────────────────────────────────────

class _CategoryDot extends StatelessWidget {
  const _CategoryDot({required this.category});
  final NoteCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _categoryColor(category),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ── Note editor sheet ──────────────────────────────────────────────────────

class _NoteEditorSheet extends StatefulWidget {
  const _NoteEditorSheet({
    required this.caseId,
    required this.onSave,
    this.existing,
  });

  final String caseId;
  final SurveyorNote? existing;
  final Future<void> Function(String content, NoteCategory category) onSave;

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late final TextEditingController _ctrl;
  late NoteCategory _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.existing?.content ?? '');
    _category = widget.existing?.category ?? NoteCategory.general;
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ────────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // ── Title ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  widget.existing == null ? 'New Note' : 'Edit Note',
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
          const SizedBox(height: 12),

          // ── Category chips ─────────────────────────────────────────
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? color
                            : color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: color.withValues(
                              alpha: selected ? 1.0 : 0.25),
                        ),
                      ),
                      child: Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 12,
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
          const SizedBox(height: 12),

          // ── Text input ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 8,
              minLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter your note…',
                hintStyle: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 14),

          // ── Save button ────────────────────────────────────────────
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
                        widget.existing == null ? 'Save Note' : 'Update Note',
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
      await widget.onSave(content, _category);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
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
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit_note, color: _kColor, size: 30),
          ),
          const SizedBox(height: 16),
          const Text('No notes yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text(
              'Capture observations, measurements,\nfollow-ups and interview notes',
              textAlign: TextAlign.center,
              style: TextStyle(
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

// ── Helpers ────────────────────────────────────────────────────────────────

Color _categoryColor(NoteCategory cat) => switch (cat) {
      NoteCategory.observation => const Color(0xFF2A6099),
      NoteCategory.measurement => const Color(0xFF7B5EA7),
      NoteCategory.followUp    => const Color(0xFFD97706),
      NoteCategory.interview   => const Color(0xFF0891B2),
      NoteCategory.technical   => const Color(0xFFDC2626),
      NoteCategory.general     => const Color(0xFF4A7A5A),
    };
