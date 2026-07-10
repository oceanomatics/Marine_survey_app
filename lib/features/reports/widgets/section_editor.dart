// lib/features/reports/widgets/section_editor.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/report_provider.dart';
import '../utils/writing_style_lint.dart';
import 'section_reference_panel.dart';
import '../../../shared/theme/app_theme.dart';

class SectionEditor extends StatefulWidget {
  const SectionEditor({
    super.key,
    required this.section,
    required this.isLocked,
    required this.onContentChanged,
    required this.onSurveyorReviewChanged,
    required this.caseId,
    required this.onRemarksChanged,
    this.sectionNumber,
    this.onDraftWithAi,
    this.assembled,
  });

  final ReportSection section;
  final bool isLocked;          // report-level lock (issued/locked status)
  final ValueChanged<String> onContentChanged;
  final ValueChanged<SurveyorReview> onSurveyorReviewChanged;
  final int? sectionNumber;     // e.g. 1 for §1 Opening; null for unnumbered sections
  /// When non-null, shows a "Draft with AI" button in the header — offered
  /// only for empty, unlocked, AI-draftable sections (background/causation).
  final VoidCallback? onDraftWithAi;
  /// When provided, shows a read-only structured reference panel (tables/
  /// blocks matching the spec's suggested layout — see
  /// docs/report_builder_editor_notes.md line 486 onward) above the
  /// free-text box, for section types that have one.
  final AssembledReportData? assembled;
  /// Needed for §2.18's "Edit in case screen" deep-link on auto-populated
  /// sections — `context.go('/cases/$caseId/<segment>')`.
  final String caseId;
  /// §2.18: the Remarks field's own change callback, separate from
  /// [onContentChanged] — only used for [autoPopulatedSectionTypes].
  final ValueChanged<String> onRemarksChanged;

  @override
  State<SectionEditor> createState() => _SectionEditorState();
}

class _SectionEditorState extends State<SectionEditor> {
  late TextEditingController _ctrl;
  late TextEditingController _remarksCtrl;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.section.content);
    _remarksCtrl = TextEditingController(text: widget.section.remarks ?? '');
  }

  @override
  void didUpdateWidget(SectionEditor old) {
    super.didUpdateWidget(old);
    if (old.section.content != widget.section.content &&
        _ctrl.text != widget.section.content) {
      _ctrl.text = widget.section.content;
    }
    final remarks = widget.section.remarks ?? '';
    if (old.section.remarks != widget.section.remarks &&
        _remarksCtrl.text != remarks) {
      _remarksCtrl.text = remarks;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section  = widget.section;
    final approved = section.approved;
    final locked   = section.isLocked || widget.isLocked;
    final isAutoPopulated = autoPopulatedSectionTypes.contains(section.type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: approved
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.border,
          width: approved ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────
          InkWell(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Row(children: [
                // Review status indicator
                _ReviewDot(review: section.surveyorReview),
                const SizedBox(width: 10),

                // Section title
                Expanded(
                  child: Row(children: [
                    Text(
                      widget.sectionNumber != null
                          ? '${widget.sectionNumber}.  ${section.title}'
                          : section.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: approved
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (section.isLocked)
                      const _Badge('LOCKED', AppColors.purple,
                          AppColors.lightPurple),
                    if (section.aiDrafted && !section.isLocked)
                      const _Badge('AI DRAFT', AppColors.midBlue,
                          AppColors.lightBlue),
                  ]),
                ),

                // AI draft trigger (background/causation only, empty content)
                if (widget.onDraftWithAi != null)
                  TextButton.icon(
                    onPressed: widget.onDraftWithAi,
                    icon: const Icon(Icons.auto_awesome, size: 13),
                    label: const Text('Draft with AI',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.midBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),

                // Expand/collapse
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more,
                      color: AppColors.textTertiary, size: 18),
                ),
              ]),
            ),
          ),

          // ── Content editor ────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1),

            // Carried-forward text from the prior report in this case's
            // successive chain (spec gap #10) — frozen, read-only, shown
            // above the new-content box below so the two are visually
            // distinguished per spec ("visually distinguished from
            // carried-forward content in the editor"); rendered
            // seamlessly with no marker in the exported docx/Preview via
            // ReportSection.fullContent.
            if ((section.carriedForwardContent ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.history, size: 11, color: AppColors.textTertiary),
                        SizedBox(width: 4),
                        Text('Carried forward from prior report — read only',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        section.carriedForwardContent!,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.5),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add what\'s new since the above below — it will '
                        'appear as a seamless continuation in the report.',
                        style: TextStyle(
                            fontSize: 9,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: isAutoPopulated
                  // §2.18 — auto-populated from case data; content is no
                  // longer surveyor-editable (see buildSections()'s overlay
                  // logic). Show the same structured table the real report
                  // renders, plus a deep-link to the case screen that owns
                  // the underlying data.
                  ? _AutoPopulatedSectionContent(
                      type: section.type,
                      caseId: widget.caseId,
                      assembled: widget.assembled,
                      fallbackText: section.content,
                      // Table-mode types (§2.18 Slice 1) show
                      // SectionReferencePanel's table as the content itself
                      // — it's what Preview/docx actually render, `content`
                      // is dead weight. Prose-mode types (Slice 2) show the
                      // full computed text instead — that IS what Preview/
                      // docx render, no table exists — with the reference
                      // panel kept as separate supplementary context below
                      // (unchanged from how it already behaved).
                      preferReferencePanel:
                          autoPopulatedTableModeTypes.contains(section.type),
                    )
                  : section.isLocked || widget.isLocked
                  // Locked — read-only display
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            AppColors.lightPurple.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.lock_outline,
                                size: 11, color: AppColors.purple),
                            SizedBox(width: 4),
                            Text('Approved legal wording — read only',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.purple,
                                    fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 6),
                          Text(
                            section.content,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary,
                                height: 1.5),
                          ),
                        ],
                      ),
                    )
                  // Editable
                  : TextField(
                      controller: _ctrl,
                      maxLines: null,
                      minLines: 3,
                      onChanged: widget.onContentChanged,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          height: 1.5),
                      decoration: InputDecoration(
                        hintText:
                            'Enter ${section.title.toLowerCase()}...',
                        hintStyle: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                              color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                              color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                              color: AppColors.midBlue, width: 1.5),
                        ),
                      ),
                    ),
            ),

            // ── Remarks (§2.18) — the only free-text field for
            // auto-populated sections; content itself is shown above.
            if (isAutoPopulated)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: TextField(
                  controller: _remarksCtrl,
                  maxLines: null,
                  minLines: 2,
                  onChanged: widget.onRemarksChanged,
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textPrimary,
                      height: 1.4),
                  decoration: InputDecoration(
                    labelText: 'Remarks (optional)',
                    labelStyle: const TextStyle(
                        fontSize: 10.5, color: AppColors.textTertiary),
                    hintText:
                        'Anything worth noting about this section that '
                        "isn't part of the case data above...",
                    hintStyle: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                          color: AppColors.midBlue, width: 1.5),
                    ),
                  ),
                ),
              ),

            // ── Structured reference panel (tables/blocks matching the
            // spec's suggested layout) — table-mode auto-populated sections
            // (§2.18 Slice 1) already show this as their primary content
            // above, so it isn't repeated here for them. Prose-mode
            // auto-populated sections (Slice 2) keep it as supplementary
            // context below the read-only text, same as narrative
            // sections always have. ────────────────────────────
            if (widget.assembled != null &&
                !autoPopulatedTableModeTypes.contains(section.type))
              SectionReferencePanel(
                  type: section.type, assembled: widget.assembled!),

            // ── Available context cues (§1.9, 9 July 2026) ─────────
            if (widget.assembled != null &&
                !autoPopulatedTableModeTypes.contains(section.type))
              SectionCuesPanel(
                  type: section.type, assembled: widget.assembled!),

            // ── Writing style rulebook advisory — doesn't apply once
            // content isn't surveyor-authored prose (§2.18). ────────
            if (!locked && !isAutoPopulated)
              _StyleFlagsBanner(type: section.type, text: section.content),

            // ── Surveyor review chips — doesn't apply once content isn't
            // surveyor-authored/AI-drafted prose (§2.18). ─────────────
            if (!locked && !isAutoPopulated)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _ReviewChips(
                  current: section.surveyorReview,
                  onChanged: widget.onSurveyorReviewChanged,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Review chips ──────────────────────────────────────────────────────────

class _ReviewChips extends StatelessWidget {
  const _ReviewChips({required this.current, required this.onChanged});

  final SurveyorReview? current;
  final ValueChanged<SurveyorReview> onChanged;

  static const _chips = [
    (SurveyorReview.reviewedAccepted, 'ACCEPTED',       Icons.check_circle_outline, AppColors.success),
    (SurveyorReview.reviewedAmended,  'AMENDED',        Icons.edit_outlined,        Color(0xFFD97706)),
    (SurveyorReview.surveyorAuthored, 'MY OWN',         Icons.person_outline,       AppColors.midBlue),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _chips.map((chip) {
        final (review, label, icon, color) = chip;
        final selected = current == review;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => onChanged(review),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
                border: Border.all(
                  color: selected ? color : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 11,
                    color: selected ? color : AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : AppColors.textTertiary,
                    )),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Review status dot in header ───────────────────────────────────────────

class _ReviewDot extends StatelessWidget {
  const _ReviewDot({required this.review});
  final SurveyorReview? review;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (review) {
      SurveyorReview.reviewedAccepted => (AppColors.success,   Icons.check),
      SurveyorReview.reviewedAmended  => (const Color(0xFFD97706), Icons.edit),
      SurveyorReview.surveyorAuthored => (AppColors.midBlue,   Icons.person),
      null                            => (AppColors.border,    Icons.radio_button_unchecked),
    };
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: review != null ? color.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(color: color, width: review != null ? 0 : 1.5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Icon(icon, size: 13, color: color),
    );
  }
}

// ── Writing style rulebook advisory banner ──────────────────────────────────

class _StyleFlagsBanner extends StatelessWidget {
  const _StyleFlagsBanner({required this.type, required this.text});

  final SectionType type;
  final String text;

  @override
  Widget build(BuildContext context) {
    final flags = lintSection(type, text);
    if (flags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFD97706).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: const Color(0xFFD97706).withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.flag_outlined, size: 12, color: Color(0xFFD97706)),
              SizedBox(width: 5),
              Text('Writing style check',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706))),
            ]),
            const SizedBox(height: 6),
            ...flags.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.4,
                          color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: '"${f.phrase}" — ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: f.reason),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Auto-populated section content (§2.18) ──────────────────────────────────
//
// Replaces the free-text box for autoPopulatedSectionTypes with a deep-link
// to the case screen that owns the underlying data, plus one of two
// read-only content presentations:
// - table-mode (preferReferencePanel: true, Slice 1) — the same structured
//   table SectionReferencePanel already builds from case data, matching
//   what Preview/docx actually render (content is dead weight for these).
// - prose-mode (preferReferencePanel: false, Slice 2) — the full computed
//   `content` text, since that IS what Preview/docx render for these types
//   (no table exists) — SectionReferencePanel is kept as separate
//   supplementary context below instead (see section_editor.dart's trailing
//   panels), not shown here.
// Falls back to plain read-only fallbackText whenever assembled is null or
// (table-mode) the panel has nothing to show, so this never renders a dead
// end.
class _AutoPopulatedSectionContent extends StatelessWidget {
  const _AutoPopulatedSectionContent({
    required this.type,
    required this.caseId,
    required this.assembled,
    required this.fallbackText,
    required this.preferReferencePanel,
  });

  final SectionType type;
  final String caseId;
  final AssembledReportData? assembled;
  final String fallbackText;
  final bool preferReferencePanel;

  @override
  Widget build(BuildContext context) {
    final route = autoPopulatedEditRoute[type];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: preferReferencePanel && assembled != null
              ? SectionReferencePanel(type: type, assembled: assembled!)
              : Text(
                  fallbackText.isNotEmpty
                      ? fallbackText
                      : 'No data on file yet.',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textPrimary,
                      height: 1.5),
                ),
        ),
        if (route != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.go('/cases/$caseId/${route.$1}'),
            icon: const Icon(Icons.open_in_new, size: 13),
            label: Text('Edit in ${route.$2} →',
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.midBlue,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color, this.bgColor);
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.w700)),
    );
  }
}
