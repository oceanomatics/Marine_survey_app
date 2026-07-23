// lib/features/correspondence/widgets/correspondence_review_sheet.dart
//
// Per-item selector review sheet for correspondence AI-extraction. Presentation
// deliberately mirrors the document-vault extraction sheet
// (_ExtractionResultSheet in document_vault_screen.dart) for a consistent
// "review & import" experience across the app: rounded modal, drag handle,
// auto_awesome header, _SectionHeader groups, leading-checkbox rows, and a
// counted Apply button. Collects the selection and hands it to
// CorrespondenceNotifier.importExtraction, which fans out the write-back.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../models/corr_extraction_result.dart';
import '../providers/correspondence_provider.dart';

const _kColor = AppColors.amber;

/// Opens the review sheet. Returns true if the surveyor imported something.
Future<bool> showCorrespondenceReviewSheet(
  BuildContext context, {
  required String caseId,
  required String corrId,
  required CorrExtractionResult result,
}) async {
  final imported = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CorrespondenceReviewSheet(
      caseId: caseId,
      corrId: corrId,
      result: result,
    ),
  );
  return imported ?? false;
}

class _CorrespondenceReviewSheet extends ConsumerStatefulWidget {
  const _CorrespondenceReviewSheet({
    required this.caseId,
    required this.corrId,
    required this.result,
  });

  final String caseId;
  final String corrId;
  final CorrExtractionResult result;

  @override
  ConsumerState<_CorrespondenceReviewSheet> createState() =>
      _CorrespondenceReviewSheetState();
}

class _CorrespondenceReviewSheetState
    extends ConsumerState<_CorrespondenceReviewSheet> {
  late bool _headerRefs;
  late bool _background;
  late final Set<int> _parties;
  late final Set<int> _keyDates;
  late final Set<int> _findings;
  late final Set<int> _incidents;
  late final Set<int> _damage;
  late final Set<int> _repairs;
  late final Set<int> _costs;
  late final Set<int> _actionItems;

  bool _saving = false;

  CorrExtractionResult get r => widget.result;

  @override
  void initState() {
    super.initState();
    // Informational items default ON; the record-creating occurrences/damage/
    // repairs default OFF (deliberate opt-in). Damage/repairs also require a
    // parent occurrence to be selected.
    _headerRefs = r.hasHeaderRefs;
    _background = r.backgroundText != null;
    _parties = _all(r.parties.length);
    _keyDates = _all(r.keyDates.length);
    _findings = _all(r.findings.length);
    _incidents = <int>{};
    _damage = <int>{};
    _repairs = <int>{};
    _costs = _all(r.costs.length);
    _actionItems = _all(r.actionItems.length);
  }

  Set<int> _all(int n) => {for (var i = 0; i < n; i++) i};

  void _toggle(Set<int> set, int i, bool v) =>
      setState(() => v ? set.add(i) : set.remove(i));

  CorrImportSelection _selection() => CorrImportSelection(
        headerRefs: _headerRefs,
        background: _background,
        parties: _parties,
        keyDates: _keyDates,
        findings: _findings,
        incidents: _incidents,
        // Damage/repairs only import alongside a parent occurrence.
        damage: _incidents.isEmpty ? <int>{} : _damage,
        repairs: _incidents.isEmpty ? <int>{} : _repairs,
        costs: _costs,
        actionItems: _actionItems,
      );

  Future<void> _import() async {
    setState(() => _saving = true);
    try {
      final n = await ref
          .read(correspondenceProvider(widget.caseId).notifier)
          .importExtraction(widget.corrId, r, _selection());
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $n item${n == 1 ? '' : 's'} into the case')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sel = _selection();

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header (mirrors the document extraction sheet)
              Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _kColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome_outlined,
                      color: _kColor, size: 17),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Extraction Results',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        Text('Correspondence',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ]),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context, false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              const SizedBox(height: 14),

              if (r.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                      child: Text('Nothing was extracted from this correspondence.',
                          style: TextStyle(color: AppColors.textSecondary))),
                )
              else ...[
                if (r.summary != null) ...[
                  Text(r.summary!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                ],

                if (r.hasHeaderRefs) ...[
                  const _SectionHeader('CASE DETAILS', Icons.badge_outlined),
                  _check(
                    value: _headerRefs,
                    onChanged: (v) => setState(() => _headerRefs = v ?? false),
                    title: 'Apply case header fields',
                    subtitle: [
                      if (r.technicalFileNo != null) 'File ${r.technicalFileNo}',
                      if (r.claimReference != null) 'Claim ${r.claimReference}',
                      if (r.vesselName != null) 'Vessel ${r.vesselName}',
                      if (r.instructionDate != null) 'Instructed ${r.instructionDate}',
                    ].join(' · '),
                  ),
                  const SizedBox(height: 10),
                ],

                _group<CorrParty>(
                  'PARTIES / CONTACTS', Icons.people_outline, r.parties, _parties,
                  subtitle: 'added to stakeholders',
                  titleOf: (p) => p.name,
                  subOf: (p) => [p.role, p.company].whereType<String>().join(' · '),
                ),
                _group<CorrKeyDate>(
                  'KEY DATES', Icons.event_outlined, r.keyDates, _keyDates,
                  subtitle: 'timeline events / surveyor attendances',
                  titleOf: (k) => [k.date, k.description].whereType<String>().join(' — '),
                  subOf: (k) => k.isAttendance
                      ? 'SURVEYOR ATTENDANCE${k.location != null ? ' · ${k.location}' : ''}'
                      : 'timeline event (full log)',
                ),
                _group<CorrFinding>(
                  'CONTEXT NOTES', Icons.label_outline, r.findings, _findings,
                  subtitle: 'added as context cues',
                  titleOf: (f) => f.text,
                  subOf: (f) => f.caseSection ?? '',
                ),
                _group<CorrIncident>(
                  'OCCURRENCES', Icons.warning_amber_outlined, r.incidents, _incidents,
                  subtitle: 'off by default — creates an occurrence',
                  titleOf: (i) => i.title,
                  subOf: (i) => [i.date, i.location].whereType<String>().join(' · '),
                ),
                _group<CorrDamage>(
                  'DAMAGE', Icons.build_outlined, r.damage, _damage,
                  enabled: _incidents.isNotEmpty,
                  subtitle: _incidents.isEmpty
                      ? 'select an occurrence to enable'
                      : null,
                  titleOf: (d) => d.description,
                  subOf: (d) => d.component ?? '',
                ),
                _group<CorrRepair>(
                  'REPAIRS', Icons.handyman_outlined, r.repairs, _repairs,
                  enabled: _incidents.isNotEmpty,
                  subtitle: _incidents.isEmpty
                      ? 'select an occurrence to enable'
                      : null,
                  titleOf: (rp) => rp.description,
                  subOf: (rp) => rp.status ?? '',
                ),
                _group<CorrCost>(
                  'COST ESTIMATES', Icons.attach_money, r.costs, _costs,
                  titleOf: (c) => c.description,
                  subOf: (c) => [
                    if (c.amount != null)
                      '${c.amount}${c.currency != null ? ' ${c.currency}' : ''}',
                    c.category,
                  ].whereType<String>().join(' · '),
                ),
                _group<String>(
                  'ACTION ITEMS', Icons.checklist_outlined, r.actionItems, _actionItems,
                  titleOf: (a) => a,
                  subOf: (_) => '',
                ),

                if (r.backgroundText != null) ...[
                  const _SectionHeader('BACKGROUND', Icons.notes_outlined),
                  _check(
                    value: _background,
                    onChanged: (v) => setState(() => _background = v ?? false),
                    title: 'Append to case background',
                    subtitle: r.backgroundText!,
                  ),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_saving || sel.count == 0) ? null : _import,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Import ${sel.count} selected',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _group<T>(
    String label,
    IconData icon,
    List<T> items,
    Set<int> selected, {
    required String Function(T) titleOf,
    required String Function(T) subOf,
    String? subtitle,
    bool enabled = true,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader('$label (${selected.length}/${items.length})', icon,
            subtitle: subtitle),
        for (var i = 0; i < items.length; i++)
          _check(
            value: selected.contains(i),
            onChanged: enabled ? (v) => _toggle(selected, i, v ?? false) : null,
            title: titleOf(items[i]),
            subtitle: subOf(items[i]),
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _check({
    required bool value,
    required ValueChanged<bool?>? onChanged,
    required String title,
    String? subtitle,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.teal,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      tileColor: Colors.transparent,
      dense: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          if (subtitle != null && subtitle.isNotEmpty)
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Section header — same style as the document extraction sheet.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, this.icon, {this.subtitle});
  final String label;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        Icon(icon, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.6)),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text('— $subtitle',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textTertiary),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ]),
    );
  }
}
