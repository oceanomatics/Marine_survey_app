// lib/features/correspondence/widgets/correspondence_review_sheet.dart
//
// Per-item selector review sheet for correspondence AI-extraction — parity with
// the document review sheet. Shows every extractable item grouped by type with
// an import switch, so the surveyor imports only the relevant data. Collects the
// selection and hands it to CorrespondenceNotifier.importExtraction, which fans
// out the write-back to the right records/tables.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/corr_extraction_result.dart';
import '../providers/correspondence_provider.dart';

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
    useSafeArea: true,
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

  bool _importing = false;

  CorrExtractionResult get r => widget.result;

  @override
  void initState() {
    super.initState();
    // Default ON for informational items; the consequential record-creating
    // ones (occurrences, damage, repairs) default OFF so they're a deliberate
    // opt-in. Damage/repairs also require a parent occurrence to be selected.
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

  void _toggle(Set<int> set, int i) =>
      setState(() => set.contains(i) ? set.remove(i) : set.add(i));

  CorrImportSelection _selection() => CorrImportSelection(
        headerRefs: _headerRefs,
        background: _background,
        parties: _parties,
        keyDates: _keyDates,
        findings: _findings,
        incidents: _incidents,
        // Damage/repairs only import when at least one occurrence is imported
        // (they need a parent occurrence_id).
        damage: _incidents.isEmpty ? <int>{} : _damage,
        repairs: _incidents.isEmpty ? <int>{} : _repairs,
        costs: _costs,
        actionItems: _actionItems,
      );

  Future<void> _import() async {
    setState(() => _importing = true);
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
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sel = _selection();
    if (r.isEmpty) {
      return _wrap(
        theme,
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Nothing was extracted from this correspondence.')),
        ),
      );
    }

    return _wrap(
      theme,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                if (r.summary != null) ...[
                  Text('Summary', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(r.summary!, style: theme.textTheme.bodyMedium),
                  const Divider(height: 24),
                ],
                if (r.hasHeaderRefs)
                  _section('Case details', [
                    SwitchListTile(
                      dense: true,
                      value: _headerRefs,
                      onChanged: (v) => setState(() => _headerRefs = v),
                      title: const Text('Apply case header fields'),
                      subtitle: Text([
                        if (r.technicalFileNo != null) 'File ${r.technicalFileNo}',
                        if (r.claimReference != null) 'Claim ${r.claimReference}',
                        if (r.vesselName != null) 'Vessel ${r.vesselName}',
                        if (r.instructionDate != null) 'Instructed ${r.instructionDate}',
                      ].join(' · ')),
                    ),
                  ]),
                if (r.backgroundText != null)
                  _section('Background', [
                    SwitchListTile(
                      dense: true,
                      value: _background,
                      onChanged: (v) => setState(() => _background = v),
                      title: const Text('Append to case background'),
                      subtitle: Text(r.backgroundText!,
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                _listSection<CorrParty>('Parties / contacts', r.parties, _parties,
                    (p) => p.name, (p) => [p.role, p.company].whereType<String>().join(' · ')),
                _listSection<CorrKeyDate>('Key dates', r.keyDates, _keyDates,
                    (k) => [k.date, k.description].whereType<String>().join(' — '),
                    (k) => k.isAttendance ? 'ATTENDANCE${k.location != null ? ' · ${k.location}' : ''}' : 'timeline (full log)'),
                _listSection<CorrFinding>('Context notes', r.findings, _findings,
                    (f) => f.text, (f) => f.caseSection ?? ''),
                _listSection<CorrIncident>('Occurrences', r.incidents, _incidents,
                    (i) => i.title, (i) => [i.date, i.location].whereType<String>().join(' · '),
                    caption: 'Off by default — creates an occurrence record'),
                if (r.damage.isNotEmpty)
                  _listSection<CorrDamage>('Damage', r.damage, _damage,
                      (d) => d.description, (d) => d.component ?? '',
                      caption: _incidents.isEmpty
                          ? 'Select an occurrence above to enable damage import'
                          : null,
                      enabled: _incidents.isNotEmpty),
                if (r.repairs.isNotEmpty)
                  _listSection<CorrRepair>('Repairs', r.repairs, _repairs,
                      (rp) => rp.description, (rp) => rp.status ?? '',
                      caption: _incidents.isEmpty
                          ? 'Select an occurrence above to enable repair import'
                          : null,
                      enabled: _incidents.isNotEmpty),
                _listSection<CorrCost>('Cost estimates', r.costs, _costs,
                    (c) => c.description,
                    (c) => [if (c.amount != null) '${c.amount}${c.currency != null ? ' ${c.currency}' : ''}', c.category].whereType<String>().join(' · ')),
                _listSection<String>('Action items', r.actionItems, _actionItems,
                    (a) => a, (_) => ''),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _importing ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: (_importing || sel.count == 0) ? null : _import,
                    icon: _importing
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_done),
                    label: Text(_importing ? 'Importing…' : 'Import ${sel.count} selected'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrap(ThemeData theme, {required Widget child}) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, __) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 20),
                  const SizedBox(width: 8),
                  Text('Import extracted data', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      );

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(title, style: Theme.of(context).textTheme.labelLarge),
          ),
          ...children,
          const Divider(height: 16),
        ],
      );

  Widget _listSection<T>(
    String title,
    List<T> items,
    Set<int> selected,
    String Function(T) titleOf,
    String Function(T) subtitleOf, {
    String? caption,
    bool enabled = true,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return _section(
      '$title (${selected.length}/${items.length})',
      [
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(caption,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic)),
          ),
        for (var i = 0; i < items.length; i++)
          SwitchListTile(
            dense: true,
            value: selected.contains(i),
            onChanged: enabled ? (_) => _toggle(selected, i) : null,
            title: Text(titleOf(items[i]),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: subtitleOf(items[i]).isEmpty
                ? null
                : Text(subtitleOf(items[i]),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }
}
