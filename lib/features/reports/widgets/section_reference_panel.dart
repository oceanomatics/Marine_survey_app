// lib/features/reports/widgets/section_reference_panel.dart
//
// Read-only structured reference panels shown in the Editor tab above the
// free-text box, for sections whose spec layout (docs/report_builder_editor_
// notes.md, line 486 onward) is a table/register/block rather than plain
// prose. Reuses the same data builders as report_preview.dart/
// docx_export_service.dart (section_table_rows.dart) so all three renderers
// agree on content — the Editor's styling is the plain admin-chrome
// AppColors palette (not document branding) since this panel is reference
// context for the surveyor, not part of the WYSIWYG document.
//
// Returns SizedBox.shrink() for section types with no structured layout —
// callers can always insert this widget unconditionally.

import 'package:flutter/material.dart';
import '../providers/report_provider.dart';
import '../utils/section_table_rows.dart';
import '../../../shared/theme/app_theme.dart';

class SectionReferencePanel extends StatelessWidget {
  const SectionReferencePanel({
    super.key,
    required this.type,
    required this.assembled,
  });

  final SectionType type;
  final AssembledReportData assembled;

  @override
  Widget build(BuildContext context) {
    final content = _build(context);
    if (content == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: content,
      ),
    );
  }

  Widget? _build(BuildContext context) {
    switch (type) {
      // Deliberately no reference panel for SectionType.opening — this
      // section's content is fixed, surveyor-approved legal wording (see
      // _fillOpeningClause), not composed from the occurrence register the
      // way e.g. Attending Representatives is literally built from
      // attendance blocks. An occurrence table underneath read as unrelated
      // clutter next to a "read only" legal clause (14 July 2026 live bug
      // report — surveyor circled both this and the class-status sentence
      // below as "wrong place for these items").

      case SectionType.vesselParticulars:
        final rows = buildVesselParticularsRows(assembled.vessel ?? {});
        if (rows.isEmpty) return null;
        return _panel("Vessel's particulars on file", _KeyValueTable(rows: rows));

      case SectionType.attendees:
        final blocks =
            buildAttendanceBlocks(assembled.attendances, assembled.attendees);
        if (blocks.isEmpty) return null;
        return _panel('Attendance blocks on file',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < blocks.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                if (blocks[i].label.isNotEmpty)
                  Text(blocks[i].label,
                      style: const TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w700)),
                _RegisterTable(rows: blocks[i].rows),
              ],
            ]));

      case SectionType.classStatutory:
        final certRows = buildCertificateRows(assembled.certificates);
        final ccRows = buildClassConditionRows(assembled.classConditions);
        if (certRows.isEmpty && ccRows.isEmpty) return null;
        return _panel('Certificates & conditions of class on file',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (certRows.isNotEmpty) _RegisterTable(rows: certRows),
              if (certRows.isNotEmpty && ccRows.isNotEmpty)
                const SizedBox(height: 10),
              if (ccRows.isNotEmpty) _RegisterTable(rows: ccRows),
            ]));

      case SectionType.machineryParticulars:
        final blocks = buildMachineryBlocks(assembled.machinery);
        if (blocks.isEmpty) return null;
        return _panel('Claim object technical detail on file',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < blocks.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Text(blocks[i].label,
                    style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                _KeyValueTable(rows: blocks[i].rows),
              ],
            ]));

      case SectionType.causation:
        final tpRows = buildThirdPartyFindingRows(assembled.occurrences);
        final certainty = buildCertaintyLevelLabel(assembled.occurrences);
        if (tpRows.isEmpty && certainty == null) return null;
        return _panel('Cause consideration — structured voices on file',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (tpRows.isNotEmpty) _RegisterTable(rows: tpRows),
              if (certainty != null) ...[
                if (tpRows.isNotEmpty) const SizedBox(height: 8),
                Text('Certainty Level: $certainty',
                    style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w600)),
              ],
            ]));

      case SectionType.accounts:
        final summaries = buildAccountSummaries(assembled);
        final totals = buildAccountTotalsRows(assembled);
        if (summaries.isEmpty) return null;
        return _panel('Repair cost summary on file',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < summaries.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Text(summaries[i].docLabel,
                    style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700)),
                if (summaries[i].lineRows.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _RegisterTable(rows: summaries[i].lineRows),
                ],
                if (summaries[i].sumApprovedWp != null) ...[
                  const SizedBox(height: 4),
                  Text(summaries[i].sumApprovedWp!,
                      style: const TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w700)),
                ],
              ],
              if (totals.isNotEmpty) ...[
                const SizedBox(height: 8),
                _KeyValueTable(rows: totals),
              ],
            ]));

      case SectionType.informationSources:
        final rows = buildAvailableInformationRows(
            assembled.caseDocuments, assembled.requestedDocuments);
        final chronoRows = buildChronologyRows(assembled.timelineEvents);
        if (rows.isEmpty && chronoRows.isEmpty) return null;
        return _panel('Available information & chronology on file',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (rows.isNotEmpty) _RegisterTable(rows: rows),
              if (rows.isNotEmpty && chronoRows.isNotEmpty)
                const SizedBox(height: 10),
              if (chronoRows.isNotEmpty) ...[
                const Text('Chronology of Events',
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                _RegisterTable(rows: chronoRows),
              ],
            ]));

      case SectionType.repairs:
        final items = buildWncaItems(assembled.surveyorNotes);
        if (items.isEmpty) return null;
        return _panel('Work Not Concerning Average (locked opening clause)',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(wncaOpeningClause,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                      height: 1.4)),
              const SizedBox(height: 4),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2, left: 6),
                  child: Text('•  $item',
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.textPrimary)),
                ),
            ]));

      case SectionType.closing:
        final signOff = buildReportSignOff(assembled.organisation);
        return _panel('Sign-off block preview',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(signOff.name,
                  style: const TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700)),
              if ((signOff.title ?? '').isNotEmpty)
                Text(signOff.title!, style: _refStyle),
              if ((signOff.company ?? '').isNotEmpty)
                Text(signOff.company!, style: _refStyle),
              if ((signOff.mobile ?? '').isNotEmpty)
                Text('Mob: ${signOff.mobile}', style: _refStyle),
              if ((signOff.email ?? '').isNotEmpty)
                Text('E: ${signOff.email}', style: _refStyle),
              Text(
                signOff.signatureStoragePath != null
                    ? '[Signature on file]'
                    : '[Signature not yet uploaded]',
                style: const TextStyle(
                    fontSize: 9.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textTertiary),
              ),
            ]));

      // §1.9 (9 July 2026): structured hard-field summaries for the three
      // narrative sections that previously had no reference panel at all
      // (repairs already had one, above, for WNCA — a different concept).
      case SectionType.occurrence:
        if (assembled.occurrences.isEmpty) return null;
        final occ = assembled.occurrences.first;
        final rows = [
          if ((occ['brief_description'] as String?)?.isNotEmpty == true)
            ['Brief description', occ['brief_description'] as String],
          if ((occ['vessel_status_at_casualty'] as String?)?.isNotEmpty == true)
            ['Vessel status at casualty', occ['vessel_status_at_casualty'] as String],
          if ((occ['aftermath_status'] as String?)?.isNotEmpty == true)
            ['Aftermath', occ['aftermath_status'] as String],
        ];
        if (rows.isEmpty) return null;
        return _panel('Occurrence data on file', _KeyValueTable(rows: rows));

      case SectionType.damageDescription:
        final rows = buildDamageScheduleRows(assembled.damageItems);
        if (rows.isEmpty) return null;
        return _panel('Damage schedule on file', _RegisterTable(rows: rows));

      case SectionType.natureOfRepairs:
        final n = assembled.natureOfRepairs;
        if (n == null) return null;
        const flagLabels = {
          'drydocking_required': 'Drydocking anticipated',
          'assured_plan_formulated': "Assured's plan formulated",
          'further_inspections_planned': 'Further inspections planned',
          'parts_long_lead_time': 'Long-lead-time parts required',
          'foreseeable_difficulties': 'Foreseeable difficulties identified',
        };
        final flags = flagLabels.entries
            .where((e) => n[e.key] == true)
            .map((e) => e.value)
            .toList();
        if (flags.isEmpty) return null;
        return _panel('Flagged considerations on file',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final f in flags)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('•  $f',
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.textPrimary)),
                ),
            ]));

      // §2.18 (10 July 2026): repairTimes and documentsOnFile previously had
      // no reference-panel case (fell to `default: return null`) even
      // though both already render as pure tables — not `content` — in the
      // real docx export (docx_export_service.dart:959-991, :1006-1028).
      // Mirrors that table-building logic exactly so the Editor tab shows
      // what actually ships.
      case SectionType.repairTimes:
        final rows = buildRepairTimesRows(assembled.repairPeriods);
        if (rows.isEmpty) return null;
        return _panel('Repair times on file', _RegisterTable(rows: rows));

      case SectionType.documentsOnFile:
        final rows = buildDocumentsOnFileRows(assembled.caseDocuments);
        if (rows.isEmpty) return null;
        return _panel('Documents retained on file', _RegisterTable(rows: rows));

      default:
        return null;
    }
  }

  static const _refStyle =
      TextStyle(fontSize: 10.5, color: AppColors.textSecondary);

  Widget _panel(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.table_chart_outlined,
              size: 12, color: AppColors.midBlue),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.midBlue)),
        ]),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

// ── Available context cues (§1.9, 9 July 2026) ─────────────────────────────
//
// "List the available context cues for that section" — shown separately
// from SectionReferencePanel above (which is hard-field structured data;
// this is the cue register) so both can appear together in the section
// header per the spec. Covers every SectionType that has a direct
// CaseSection cue tag; returns nothing for types that don't (e.g.
// natureOfRepairs — no CaseSection value exists for it).
const _sectionCueTags = {
  SectionType.background: 'background',
  SectionType.occurrence: 'occurrence',
  SectionType.damageDescription: 'damage',
  SectionType.causation: 'causation',
  SectionType.repairs: 'repairs',
  SectionType.generalServices: 'general_expenses',
  SectionType.previousWorks: 'previous_works',
  SectionType.extraExpenses: 'extra_expenses',
  SectionType.contractualHire: 'contractual_hire',
  SectionType.otherMatters: 'other_matters',
};

class SectionCuesPanel extends StatelessWidget {
  const SectionCuesPanel({
    super.key,
    required this.type,
    required this.assembled,
  });

  final SectionType type;
  final AssembledReportData assembled;

  @override
  Widget build(BuildContext context) {
    final tag = _sectionCueTags[type];
    if (tag == null) return const SizedBox.shrink();
    final cues = assembled.surveyorNotes
        .where((n) =>
            n['case_section'] == tag && n['pending_review'] != true)
        .map((n) => n['content'] as String? ?? '')
        .where((c) => c.isNotEmpty)
        .toList();
    if (cues.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.lightAmber.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.label_outline, size: 12, color: AppColors.amber),
              const SizedBox(width: 5),
              Text('Available context cues (${cues.length})',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amber)),
            ]),
            const SizedBox(height: 8),
            for (final c in cues)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('•  $c',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.textPrimary)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Plain admin-styled table primitives (distinct from report_preview.dart's
// brand-coloured versions — this panel is editor chrome, not the WYSIWYG
// document) ─────────────────────────────────────────────────────────────

class _KeyValueTable extends StatelessWidget {
  const _KeyValueTable({required this.rows});
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2.2)},
      children: rows
          .map((r) => TableRow(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(r[0],
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(r[1],
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.textPrimary)),
                ),
              ]))
          .toList(),
    );
  }
}

class _RegisterTable extends StatelessWidget {
  const _RegisterTable({required this.rows});
  /// First row is the header row.
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final header = rows.first;
    final body = rows.skip(1).toList();
    return Table(
      border: TableBorder.all(color: AppColors.border, width: 0.6),
      columnWidths: {
        for (var i = 0; i < header.length; i++) i: const FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.lightBlue),
          children: header
              .map((h) => Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(h,
                        style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.midBlue)),
                  ))
              .toList(),
        ),
        ...body.map((r) => TableRow(children: [
              for (final cell in r)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(cell,
                      style: const TextStyle(
                          fontSize: 9.5, color: AppColors.textPrimary)),
                ),
            ])),
      ],
    );
  }
}
