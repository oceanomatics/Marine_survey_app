// lib/features/background/screens/background_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../../surveyor_notes/providers/surveyor_notes_provider.dart';
import '../providers/background_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/save_bar.dart';

const _kAccent = Color(0xFF2A6B9E);

class BackgroundScreen extends ConsumerStatefulWidget {
  const BackgroundScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<BackgroundScreen> createState() => _BackgroundScreenState();
}

class _BackgroundScreenState extends ConsumerState<BackgroundScreen> {
  late final TextEditingController _ctrl;
  Timer? _debounce;
  bool _dirty = false;
  bool _saving = false;
  bool _cuesExpanded = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged(String _) {
    if (!_dirty) setState(() => _dirty = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), _autosave);
  }

  Future<void> _autosave() async {
    if (!mounted) return;
    await _doSave();
  }

  Future<void> _doSave() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(backgroundProvider(widget.caseId).notifier)
          .save(_ctrl.text);
      if (mounted) setState(() => _dirty = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundAsync = ref.watch(backgroundProvider(widget.caseId));

    return backgroundAsync.when(
      loading: () => const Scaffold(body: AppLoadingWidget()),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (bg) {
        if (_ctrl.text.isEmpty && bg.content.isNotEmpty) {
          _ctrl.text = bg.content;
          _ctrl.selection =
              TextSelection.collapsed(offset: _ctrl.text.length);
        }

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: _BackgroundAppBar(
            dirty: _dirty,
            saving: _saving,
          ),
          bottomNavigationBar: SaveBar(
            visible: _dirty,
            saving: _saving,
            onSave: _doSave,
          ),
          body: Column(
            children: [
              // ── Narrative text editor ─────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: TextField(
                    controller: _ctrl,
                    onChanged: _onTextChanged,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Enter the background narrative for this case…\n\n'
                          'Describe the vessel\'s history, circumstances '
                          'leading to the incident, instruction details, '
                          'and any relevant pre-existing conditions.',
                      hintStyle: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                          height: 1.6),
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
                          borderSide: const BorderSide(
                              color: _kAccent, width: 1.5)),
                      contentPadding: const EdgeInsets.all(14),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── Context cues panel (background-tagged notes) ───────
              _ContextCuesPanel(
                caseId: widget.caseId,
                expanded: _cuesExpanded,
                onToggle: () =>
                    setState(() => _cuesExpanded = !_cuesExpanded),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────

class _BackgroundAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _BackgroundAppBar({
    required this.dirty,
    required this.saving,
  });

  final bool dirty;
  final bool saving;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.navy,
      title: Row(
        children: [
          const Text('Background',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          if (saving)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Colors.white54),
            )
          else if (!dirty)
            const Icon(Icons.cloud_done_outlined,
                color: Colors.white38, size: 15),
        ],
      ),
    );
  }
}

// ── Context cues panel ────────────────────────────────────────────────────
//
// Shows surveyor notes tagged as ReportSection.background.

class _ContextCuesPanel extends ConsumerWidget {
  const _ContextCuesPanel({
    required this.caseId,
    required this.expanded,
    required this.onToggle,
  });

  final String caseId;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(surveyorNotesProvider(caseId));
    final bgNotes = notesAsync.value
            ?.where((n) => n.reportSection == ReportSection.background)
            .toList() ??
        [];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      height: expanded ? 230 : 44,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border:
            Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.auto_awesome_outlined,
                        color: _kAccent, size: 14),
                  ),
                  const SizedBox(width: 9),
                  const Text('Context Cues',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  if (bgNotes.isNotEmpty) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${bgNotes.length}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _kAccent)),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _addNote(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _kAccent.withValues(alpha: 0.2)),
                      ),
                      child: const Text('+ Add',
                          style: TextStyle(
                              color: _kAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_up,
                        color: AppColors.textTertiary, size: 18),
                  ),
                ],
              ),
            ),
          ),

          // ── Notes list ─────────────────────────────────────────────
          if (expanded)
            Expanded(
              child: notesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) =>
                    Center(child: Text('Error: $e')),
                data: (_) => bgNotes.isEmpty
                    ? const _CuesEmpty()
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        itemCount: bgNotes.length,
                        itemBuilder: (_, i) => _CueTile(
                          note: bgNotes[i],
                          onEdit: () =>
                              _editNote(context, ref, bgNotes[i]),
                          onDelete: () => ref
                              .read(surveyorNotesProvider(caseId)
                                  .notifier)
                              .delete(bgNotes[i].id),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  void _addNote(BuildContext context, WidgetRef ref) {
    _openSheet(context, ref, existing: null);
  }

  void _editNote(
      BuildContext context, WidgetRef ref, SurveyorNote note) {
    _openSheet(context, ref, existing: note);
  }

  void _openSheet(BuildContext context, WidgetRef ref,
      {SurveyorNote? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CueSheet(
        existing: existing,
        onSave: (content, category) async {
          final notifier =
              ref.read(surveyorNotesProvider(caseId).notifier);
          if (existing == null) {
            await notifier.add(
              caseId:        caseId,
              content:       content,
              category:      category,
              reportSection: ReportSection.background,
            );
          } else {
            await notifier.editNote(
              existing.id,
              content:       content,
              category:      category,
              reportSection: ReportSection.background,
            );
          }
        },
      ),
    );
  }
}

// ── Cue tile ──────────────────────────────────────────────────────────────

class _CueTile extends StatelessWidget {
  const _CueTile({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            color: _kAccent.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kAccent.withValues(alpha: 0.15)),
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
                        child: Text(note.category.label,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: catColor)),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          note.content,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary),
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
    );
  }
}

// ── Quick add / edit sheet (section fixed to background) ─────────────────

class _CueSheet extends StatefulWidget {
  const _CueSheet({required this.onSave, this.existing});
  final SurveyorNote? existing;
  final Future<void> Function(String content, NoteCategory category) onSave;

  @override
  State<_CueSheet> createState() => _CueSheetState();
}

class _CueSheetState extends State<_CueSheet> {
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
                    const Text('Tagged: Background',
                        style: TextStyle(
                            fontSize: 11, color: _kAccent)),
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

          // ── Category chips ───────────────────────────────────────
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
                    child: Text(cat.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : color)),
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
                hintText: 'Enter context cue or background note…',
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
                    borderSide: const BorderSide(
                        color: _kAccent, width: 1.5)),
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
                backgroundColor: _kAccent,
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

// ── Empty state ───────────────────────────────────────────────────────────

class _CuesEmpty extends StatelessWidget {
  const _CuesEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Text(
        'No background context cues yet. Tap + Add to capture a cue, '
        'or they will appear automatically when you import documents '
        'and correspondence.',
        style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
            fontStyle: FontStyle.italic),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

Color _categoryColor(NoteCategory cat) => _catColor(cat);

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
