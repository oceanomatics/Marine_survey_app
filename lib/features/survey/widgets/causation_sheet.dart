// lib/features/survey/widgets/causation_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/damage_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../vessel/widgets/survey_field.dart';
import '../../../core/api/claude_api.dart';
import '../../surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';

// ── Standard formulation generator ────────────────────────────────────────

String? buildAllegationFormulation(
  HMCauseType? causeType,
  String? allegationType,
  String? agreement,
) {
  if (allegationType == null || allegationType == 'tbc') return null;

  if (allegationType == 'no_formal_allegation') {
    return 'We are not aware of any formal allegation of cause having been '
        'raised by any party in connection with this casualty.';
  }

  final causeLabel = causeType != null
      ? causeType.label.toLowerCase()
      : 'the casualty';

  switch (agreement) {
    case 'agree':
      return 'We note that a formal allegation of $causeLabel has been raised '
          'in connection with this casualty. Having carefully reviewed the '
          'available documentation and circumstances, we are in agreement '
          'with the allegation of cause.';
    case 'disagree':
      return 'We note that a formal allegation of $causeLabel has been raised '
          'in connection with this casualty. Having carefully reviewed the '
          'available documentation and circumstances, we are not in a position '
          'to concur with the allegation of cause as presented.';
    default:
      return 'We note that a formal allegation of $causeLabel has been raised '
          'in connection with this casualty. Our position with regard to the '
          'allegation of cause will be advised in due course upon completion '
          'of our technical review.';
  }
}

// ── Sheet ──────────────────────────────────────────────────────────────────

class CausationSheet extends ConsumerStatefulWidget {
  const CausationSheet({
    super.key,
    required this.occurrence,
    required this.onSave,
  });

  final OccurrenceModel occurrence;
  final Future<void> Function(OccurrenceModel updated) onSave;

  @override
  ConsumerState<CausationSheet> createState() => _CausationSheetState();
}

class _CausationSheetState extends ConsumerState<CausationSheet> {
  HMCauseType? _causeType;
  String _allegationType = 'tbc';
  String _causeAgreement = 'tbc';
  final _commentCtrl = TextEditingController();
  bool _saving = false;
  bool _generating = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final occ = widget.occurrence;
    _causeType = HMCauseType.fromValue(occ.causeType);
    _allegationType = occ.allegationType ?? 'tbc';
    _causeAgreement = occ.causeAgreement ?? 'tbc';
    _commentCtrl.text = occ.causeNarrative ?? '';
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateSubCausation() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final occ = widget.occurrence;
      final notes = ref
          .read(surveyorNotesProvider(occ.caseId))
          .value ?? [];
      final causationCues = notes
          .where((n) => n.reportSection == ReportSection.causation)
          .map((n) => n.content)
          .toList();

      final text = await ClaudeApi.draftSubCausation(
        occurrenceTitle:    occ.title ?? 'Occurrence ${occ.occurrenceNo}',
        causeTypeLabel:     _causeType?.label ?? 'Unknown cause',
        allegationType:     _allegationType,
        briefDescription:   occ.briefDescription,
        backgroundNarrative: occ.backgroundNarrative,
        contextCues:        causationCues,
      );
      if (mounted) {
        _commentCtrl.text = text;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI draft failed: $e'),
            backgroundColor: AppColors.coral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    debugPrint('[CausationSheet._save] START occ=${widget.occurrence.occurrenceId}');
    setState(() { _saving = true; _saveError = null; });
    try {
      final occ = widget.occurrence;
      final updated = OccurrenceModel(
        occurrenceId:        occ.occurrenceId,
        caseId:              occ.caseId,
        occurrenceNo:        occ.occurrenceNo,
        isPrimary:           occ.isPrimary,
        dateTime:            occ.dateTime,
        location:            occ.location,
        title:               occ.title,
        briefDescription:    occ.briefDescription,
        backgroundNarrative: occ.backgroundNarrative,
        chronology:          occ.chronology,
        causeType:           _causeType?.value,
        allegationType:      _allegationType,
        causeAgreement:      _allegationType == 'formal_allegation'
            ? _causeAgreement
            : null,
        causeNarrative:      _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
        ismReported:         occ.ismReported,
        createdAt:           occ.createdAt,
      );
      debugPrint('[CausationSheet._save] calling onSave, causeType=${updated.causeType} allegationType=${updated.allegationType}');
      await widget.onSave(updated);
      debugPrint('[CausationSheet._save] onSave completed OK, popping');
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      debugPrint('[CausationSheet._save] ERROR: $e\n$st');
      if (mounted) setState(() => _saveError = '[${e.runtimeType}] $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formulation = buildAllegationFormulation(
      _causeType, _allegationType, _causeAgreement,
    );

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header: occurrence number + title
              Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.occurrence.occurrenceNo}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.occurrence.title ??
                          'Occurrence ${widget.occurrence.occurrenceNo}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── ALLEGATION OF CAUSE ─────────────────────────────────
              const _SectionLabel('ALLEGATION OF CAUSE'),
              const SizedBox(height: 4),
              const Text(
                'Select the primary H&M cause type',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HMCauseType.values
                    .map((t) => _CauseChip(
                          label: t.label,
                          selected: _causeType == t,
                          onTap: () => setState(
                              () => _causeType = _causeType == t ? null : t),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 22),

              // ── FORMAL ALLEGATION ───────────────────────────────────
              const _SectionLabel('FORMAL ALLEGATION OR STATEMENT OF CAUSE'),
              const SizedBox(height: 10),
              _TriSegment(
                options: const [
                  ('formal_allegation', 'Formal Allegation'),
                  ('no_formal_allegation', 'No Allegation'),
                  ('tbc', 'TBC'),
                ],
                selected: _allegationType,
                onSelected: (v) => setState(() => _allegationType = v),
                activeColor: AppColors.amber,
              ),

              // ── OUR POSITION (only when formal allegation) ──────────
              if (_allegationType == 'formal_allegation') ...[
                const SizedBox(height: 22),
                const _SectionLabel('OUR POSITION ON THE ALLEGATION'),
                const SizedBox(height: 10),
                _TriSegment(
                  options: const [
                    ('agree', 'We Agree'),
                    ('disagree', 'We Disagree'),
                    ('tbc', 'TBC'),
                  ],
                  selected: _causeAgreement,
                  onSelected: (v) => setState(() => _causeAgreement = v),
                  activeColor: AppColors.midBlue,
                ),
              ],

              const SizedBox(height: 22),

              // ── SUB-CAUSATION ───────────────────────────────────────
              Row(
                children: [
                  const _SectionLabel('SUB-CAUSATION / COMMENTS'),
                  const Spacer(),
                  GestureDetector(
                    onTap: _generating ? null : _generateSubCausation,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.amber.withValues(alpha: 0.3)),
                      ),
                      child: _generating
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.amber),
                            )
                          : const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.auto_awesome_outlined,
                                  size: 11, color: AppColors.amber),
                              SizedBox(width: 4),
                              Text('AI Draft',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.amber)),
                            ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Explain the factors or sequence of events that led to this cause',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 8),
              SurveyField(
                label: '',
                controller: _commentCtrl,
                hint: 'e.g. The vessel was navigating at reduced speed in poor '
                    'visibility when the anchor watch failed to detect the '
                    'reef on the radar…',
                maxLines: 5,
              ),

              // ── STANDARD FORMULATION PREVIEW ────────────────────────
              if (formulation != null) ...[
                const SizedBox(height: 22),
                const _SectionLabel('STANDARD FORMULATION (PREVIEW)'),
                const SizedBox(height: 4),
                const Text(
                  'Auto-generated from selections above — used in the Allegation / '
                  'Causation section of the report',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightAmber,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    formulation,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                      height: 1.55,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              if (_saveError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.coral.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.coral, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _saveError!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.coral),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save Causation',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Local widgets ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
          letterSpacing: 0.6,
        ),
      );
}

class _CauseChip extends StatelessWidget {
  const _CauseChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.amber : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.amber
                : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TriSegment extends StatelessWidget {
  const _TriSegment({
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.activeColor,
  });

  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.asMap().entries.map((entry) {
        final i = entry.key;
        final (value, label) = entry.value;
        final isSelected = selected == value;
        final isFirst = i == 0;
        final isLast = i == options.length - 1;

        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.white,
                borderRadius: BorderRadius.horizontal(
                  left: isFirst ? const Radius.circular(8) : Radius.zero,
                  right: isLast ? const Radius.circular(8) : Radius.zero,
                ),
                border: Border.all(
                  color: isSelected ? activeColor : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color:
                        isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
