// lib/features/reports/widgets/section_editor.dart

import 'package:flutter/material.dart';
import '../providers/report_provider.dart';
import '../../../shared/theme/app_theme.dart';

class SectionEditor extends StatefulWidget {
  const SectionEditor({
    super.key,
    required this.section,
    required this.isLocked,
    required this.onContentChanged,
    required this.onSurveyorReviewChanged,
    this.sectionNumber,
    this.onDraftWithAi,
  });

  final ReportSection section;
  final bool isLocked;          // report-level lock (issued/locked status)
  final ValueChanged<String> onContentChanged;
  final ValueChanged<SurveyorReview> onSurveyorReviewChanged;
  final int? sectionNumber;     // e.g. 1 for §1 Opening; null for unnumbered sections
  /// When non-null, shows a "Draft with AI" button in the header — offered
  /// only for empty, unlocked, AI-draftable sections (background/causation).
  final VoidCallback? onDraftWithAi;

  @override
  State<SectionEditor> createState() => _SectionEditorState();
}

class _SectionEditorState extends State<SectionEditor> {
  late TextEditingController _ctrl;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.section.content);
  }

  @override
  void didUpdateWidget(SectionEditor old) {
    super.didUpdateWidget(old);
    if (old.section.content != widget.section.content &&
        _ctrl.text != widget.section.content) {
      _ctrl.text = widget.section.content;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section  = widget.section;
    final approved = section.approved;
    final locked   = section.isLocked || widget.isLocked;

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
            Padding(
              padding: const EdgeInsets.all(12),
              child: section.isLocked || widget.isLocked
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

            // ── Surveyor review chips ─────────────────────────────
            if (!locked)
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
