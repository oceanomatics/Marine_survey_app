// lib/shared/widgets/context_cues_panel.dart
//
// Reusable collapsible context-cues panel shown at the bottom of any report
// section screen. Filters cues by the given [section] and provides add/edit/
// delete actions. Mirrors the pattern established in background_screen.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/surveyor_notes/models/surveyor_note_model.dart';
import '../../features/surveyor_notes/providers/surveyor_notes_provider.dart';
import '../theme/app_theme.dart';

// ── Category colour helper (matches surveyor_notes_screen.dart) ─────────────

Color _catColor(NoteCategory cat) => switch (cat) {
      NoteCategory.observation   => const Color(0xFF2A6099),
      NoteCategory.measurement   => const Color(0xFF7B5EA7),
      NoteCategory.followUp      => const Color(0xFFD97706),
      NoteCategory.interview     => const Color(0xFF0891B2),
      NoteCategory.technical     => const Color(0xFFDC2626),
      NoteCategory.operations    => const Color(0xFF0F766E),
      NoteCategory.previousWorks => const Color(0xFF6B7280),
      NoteCategory.policy        => const Color(0xFF4338CA),
      NoteCategory.general       => const Color(0xFF4A7A5A),
    };

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

// ── Public panel widget ───────────────────────────────────────────────────────

class ContextCuesPanel extends ConsumerStatefulWidget {
  const ContextCuesPanel({
    super.key,
    required this.caseId,
    required this.section,
  });

  final String caseId;
  final ReportSection section;

  @override
  ConsumerState<ContextCuesPanel> createState() => _ContextCuesPanelState();
}

class _ContextCuesPanelState extends ConsumerState<ContextCuesPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final accent = _sectionColor(widget.section);
    final notesAsync = ref.watch(surveyorNotesProvider(widget.caseId));
    final sectionNotes = notesAsync.value
            ?.where((n) => n.reportSection == widget.section)
            .toList() ??
        [];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      height: _expanded ? 230 : 44,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.label_outline, color: accent, size: 14),
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    'Context Cues',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  if (sectionNotes.isNotEmpty) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${sectionNotes.length}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accent),
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _addNote(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '+ Add',
                        style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_up,
                        color: AppColors.textTertiary, size: 18),
                  ),
                ],
              ),
            ),
          ),

          // ── Notes list ───────────────────────────────────────────────
          if (_expanded)
            Expanded(
              child: notesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (_) => sectionNotes.isEmpty
                    ? _CuesPanelEmpty(section: widget.section)
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        itemCount: sectionNotes.length,
                        itemBuilder: (_, i) => _CuePanelTile(
                          note: sectionNotes[i],
                          accent: accent,
                          onEdit: () => _editNote(context, sectionNotes[i]),
                          onDelete: () => ref
                              .read(surveyorNotesProvider(widget.caseId)
                                  .notifier)
                              .delete(sectionNotes[i].id),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  void _addNote(BuildContext context) =>
      _openSheet(context, existing: null);

  void _editNote(BuildContext context, SurveyorNote note) =>
      _openSheet(context, existing: note);

  void _openSheet(BuildContext context, {SurveyorNote? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CuePanelSheet(
        section: widget.section,
        existing: existing,
        onSave: (content, category) async {
          final notifier =
              ref.read(surveyorNotesProvider(widget.caseId).notifier);
          if (existing == null) {
            await notifier.add(
              caseId:        widget.caseId,
              content:       content,
              category:      category,
              reportSection: widget.section,
            );
          } else {
            await notifier.editNote(
              existing.id,
              content:       content,
              category:      category,
              reportSection: widget.section,
            );
          }
        },
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _CuePanelTile extends StatelessWidget {
  const _CuePanelTile({
    required this.note,
    required this.accent,
    required this.onEdit,
    required this.onDelete,
  });

  final SurveyorNote note;
  final Color accent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final catColor = _catColor(note.category);
    final isIgnored = note.priority == CuePriority.ignored;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Opacity(
        opacity: isIgnored ? 0.45 : 1.0,
        child: GestureDetector(
          onTap: onEdit,
          child: Container(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: accent.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: catColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.12),
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
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            note.content,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: isIgnored
                                    ? AppColors.textTertiary
                                    : AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close,
                        size: 13, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Quick add/edit sheet ──────────────────────────────────────────────────────

class _CuePanelSheet extends StatefulWidget {
  const _CuePanelSheet({
    required this.section,
    required this.onSave,
    this.existing,
  });

  final ReportSection section;
  final SurveyorNote? existing;
  final Future<void> Function(String content, NoteCategory category) onSave;

  @override
  State<_CuePanelSheet> createState() => _CuePanelSheetState();
}

class _CuePanelSheetState extends State<_CuePanelSheet> {
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
    final accent = _sectionColor(widget.section);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.existing == null
                          ? 'Add Context Cue'
                          : 'Edit Context Cue',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      'Tagged: ${widget.section.label}',
                      style: TextStyle(fontSize: 11, color: accent),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style:
                          TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Category chips (Wrap — all visible) ──────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: NoteCategory.values.map((cat) {
                final selected = _category == cat;
                final color = _catColor(cat);
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 6),
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
                          color: selected ? Colors.white : color),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 5,
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
                        BorderSide(color: accent, width: 1.5)),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
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
                          fontWeight: FontWeight.w700, fontSize: 14)),
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

// ── Empty state ───────────────────────────────────────────────────────────────

class _CuesPanelEmpty extends StatelessWidget {
  const _CuesPanelEmpty({required this.section});
  final ReportSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Text(
        'No context cues for ${section.label} yet. Tap + Add to capture a cue.',
        style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
            fontStyle: FontStyle.italic),
      ),
    );
  }
}
