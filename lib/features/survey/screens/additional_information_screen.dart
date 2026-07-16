// lib/features/survey/screens/additional_information_screen.dart
//
// "Additional Information" — consolidated case-screen section per surveyor
// direction (4 July 2026): "General expenses section, extra expense... can
// [be] one section in the case screen, which collects the context cues
// (and allow to input some manually)... we could include the Other
// matters of relevance in the Expenses... section (maybe rename this
// section in the front end as 'Additional Information' for clarity)."
//
// Four cue-register subsections — Previous Work on the Damaged Item,
// Extra Expenses to Reduce Delay, Contractual / Hire, and Other Matters of
// Relevance — each present the shared `ContextCuesPanel` (the same
// register used by the global Context Cues screen and by
// Background/Causation/Repairs), and each is AI-drafted from its tagged
// cues into its own report section (report_provider.dart).
//
// Work Not Concerning Average was originally a subsection here (as a flat
// case-level context-cue register), but was pulled back out per surveyor
// direction (5 July 2026) into its own standalone screen (wnca_screen.dart)
// — WNCA needs to stay split by repair period, which a flat case-level
// register can't express.
//
// General Services & Access (the original 1st subsection) was retired the
// same day: its content largely overlaps the services/hot-work checklist
// already captured per repair period (auto-built into the Repairs section
// — see `_buildServicesAndHotWorkText` in report_provider.dart), making a
// second manual cue-entry point redundant. `SectionType.generalServices`
// itself is left as-is in the report pipeline rather than retired, in
// case any already-tagged cues exist.
//
// Advice to Assured — the legal-clause ticklist — is presented last, per
// surveyor direction (5 July 2026) splitting it out from "Other Matters of
// Relevance": "A section just like above for other matters of relevance,
// managed as above, mainly as context cue holder, the tick box as the
// last section - name it 'Advice to Assured'." Other Matters of Relevance
// is now a plain cue-register subsection like the other three (previously
// it doubled as both the clause ticklist AND a cue register). The ticklist
// (docs/migrations/018_other_matters_clauses.sql) plus its free-text
// additional-notes field (docs/migrations/019_other_matters_notes.sql,
// `CasesNotifier.updateOtherMattersNotes()`) still feed the
// `SectionType.surveyorNotes` report section (Dart enum name kept for
// DB/historical continuity), just retitled "Advice to Assured" — the
// underlying data model/columns are unchanged, only the front-end
// presentation and report heading moved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../../cases/providers/cases_provider.dart';
import '../../cases/models/case_model.dart';
import '../../reports/providers/report_provider.dart' show ClauseModel;
import '../providers/other_matters_clauses_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/context_cues_panel.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../vessel/widgets/machinery_equipment_section.dart';

class AdditionalInformationScreen extends ConsumerWidget {
  const AdditionalInformationScreen({super.key, required this.caseId});
  final String caseId;

  static const _cueSections = [
    (CaseSection.previousWorks, 'Previous Work on the Damaged Item',
        'Prior repairs, surveys, or interventions carried out on the damaged item before this incident…'),
    (CaseSection.extraExpenses, 'Extra Expenses to Reduce Delay',
        'Yard selection premium, overtime, express freight of spare parts…'),
    (CaseSection.contractualHire, 'Contractual / Hire',
        'Charter party terms, off-hire periods, contractual notices to owners/charterers…'),
    (CaseSection.otherMatters, 'Other Matters of Relevance',
        'Any other matter relevant to the case not captured in another section…'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseModel = ref.watch(caseProvider(caseId)).value;
    final format = caseModel?.outputFormat?.value ?? 'abl';
    final clausesAsync = ref.watch(otherMattersClausesProvider(format));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: Text('Additional Information')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final s in _cueSections) ...[
            CueSectionCard(
              title: s.$2,
              hint: s.$3,
              child: ContextCuesPanel(caseId: caseId, section: s.$1),
            ),
            const SizedBox(height: 16),
            // Repeat the vessel's Machinery & Equipment entry right under
            // Previous Work — a clear entry point for capturing units while
            // documenting prior works, instead of digging into
            // Vessel → Machinery three menus away (16 July 2026 report).
            if (s.$1 == CaseSection.previousWorks) ...[
              MachineryEquipmentSection(caseId: caseId),
              const SizedBox(height: 16),
            ],
          ],
          _AdviceToAssuredSection(
            caseId: caseId,
            caseModel: caseModel,
            clauses: clausesAsync.value ?? const [],
          ),
        ],
      ),
    );
  }
}

// ── Advice to Assured — clause ticklist + additional notes (last) ────────

class _AdviceToAssuredSection extends ConsumerStatefulWidget {
  const _AdviceToAssuredSection({
    required this.caseId,
    required this.caseModel,
    required this.clauses,
  });

  final String caseId;
  final CaseModel? caseModel;
  final List<ClauseModel> clauses;

  @override
  ConsumerState<_AdviceToAssuredSection> createState() =>
      _AdviceToAssuredSectionState();
}

class _AdviceToAssuredSectionState
    extends ConsumerState<_AdviceToAssuredSection> {
  late final TextEditingController _notesCtrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onNotesChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), () {
      ref
          .read(caseProvider(widget.caseId).notifier)
          .updateOtherMattersNotes(_notesCtrl.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tickedIds = widget.caseModel?.otherMattersClauseIds ?? const [];
    final storedNotes = widget.caseModel?.otherMattersNotes ?? '';
    if (_notesCtrl.text.isEmpty && storedNotes.isNotEmpty) {
      _notesCtrl.text = storedNotes;
      _notesCtrl.selection =
          TextSelection.collapsed(offset: _notesCtrl.text.length);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Advice to Assured',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const Text(
              'Standard legal statements — tick to include in the report.',
              style:
                  TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
          const SizedBox(height: 8),
          if (widget.clauses.isEmpty)
            const Text('No candidate clauses configured.',
                style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textTertiary))
          else
            ...widget.clauses.map((c) {
              final ticked = tickedIds.contains(c.clauseId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => _toggle(tickedIds, c.clauseId, !ticked),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: ticked,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) =>
                            _toggle(tickedIds, c.clauseId, v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.clauseLabel,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                              Text(c.clauseText,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      height: 1.4)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const Divider(height: 24),
          const Text('Additional Notes / Clarifications',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const Text(
              'Free text, appended after the ticked clauses above — '
              'contractual points or clarifications not covered by the '
              'standard clauses.',
              style:
                  TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            onChanged: _onNotesChanged,
            maxLines: null,
            minLines: 3,
            style: const TextStyle(fontSize: 13, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Enter additional notes…',
              hintStyle: const TextStyle(
                  color: AppColors.textTertiary, fontSize: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.midBlue, width: 1.5)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(
      List<String> current, String clauseId, bool include) async {
    final updated = List<String>.from(current);
    if (include) {
      if (!updated.contains(clauseId)) updated.add(clauseId);
    } else {
      updated.remove(clauseId);
    }
    await ref
        .read(caseProvider(widget.caseId).notifier)
        .updateOtherMattersClauses(updated);
  }
}
