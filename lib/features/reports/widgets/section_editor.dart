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
    required this.onToggleApproved,
  });

  final ReportSection section;
  final bool isLocked;          // report-level lock (issued/locked status)
  final ValueChanged<String> onContentChanged;
  final VoidCallback onToggleApproved;

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
    final section   = widget.section;
    final approved  = section.approved;
    final locked    = section.isLocked || widget.isLocked;

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
                // Approve checkbox
                GestureDetector(
                  onTap: locked ? null : widget.onToggleApproved,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: approved
                          ? AppColors.success
                          : Colors.transparent,
                      border: Border.all(
                        color: approved
                            ? AppColors.success
                            : AppColors.textTertiary,
                        width: approved ? 0 : 1.5,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: approved
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 13)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),

                // Section title
                Expanded(
                  child: Row(children: [
                    Text(
                      section.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: approved
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Badges
                    if (section.isLocked)
                      const _Badge('LOCKED', AppColors.purple,
                          AppColors.lightPurple),
                    if (section.aiDrafted && !section.isLocked)
                      const _Badge('AI DRAFT', AppColors.midBlue,
                          AppColors.lightBlue),
                  ]),
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
            // Approve button (only when not locked and not yet approved)
            if (!section.isLocked && !widget.isLocked && !approved)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onToggleApproved,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side:
                          const BorderSide(color: AppColors.success),
                      padding:
                          const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Approve section ✓',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

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
