// lib/features/reports/utils/section_table_rows.dart
//
// Shared table-row builders for sections whose docx layout is a structured
// table or set of blocks (two-column key:value, a formal register, or
// per-attendance blocks) rather than free prose — Vessel's Particulars,
// Class & Statutory Certification, Attending Representatives. Used by both
// report_preview.dart and
// docx_export_service.dart so the two independent renderers agree on
// content and layout — same convention as advice_summary_rows.dart (see
// gap #5 / gap #11 in docs/report_builder_editor_notes.md re: renderer
// drift). Before this file existed, the Preview tab rendered these three
// sections as flat paragraph text (from the section's free-text content)
// while the docx export already built them as tables directly from the
// underlying data — the two had quietly diverged.

import '../providers/report_provider.dart';
import '../../survey/providers/damage_provider.dart'
    show CertaintyLevel, ConditionStatus;
import '../../survey/models/repair_period_model.dart';

String formatSectionDate(String iso) {
  if (iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso);
    const m = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')}-${m[d.month]}-${d.year}';
  } catch (_) {
    return iso;
  }
}

/// Vessel's Particulars — spec §3 two-column key:value layout, no header
/// row. Rows with no data are omitted so Convention-only or DCV-only
/// fields don't show up as blank for the other vessel type.
List<List<String>> buildVesselParticularsRows(Map<String, dynamic> v) {
  // Breadth/draft — TODO.md §2.17: the old model forced one value + a
  // qualifier dropdown; replaced with independent per-variant fields
  // (populated as collected) so more than one can be on record at once.
  // Prefer those; fall back to the legacy single value+qualifier pair for
  // vessels never re-saved since the split, so old data stays visible.
  // This was wired into the vessel-particulars editor at the split but
  // never into the report table until now (found + fixed 10 July 2026).
  final hasNewBreadth = v['breadth_moulded'] != null ||
      v['breadth_extreme'] != null ||
      v['beam_oa'] != null;
  final breadthRows = hasNewBreadth
      ? [
          if (v['breadth_moulded'] != null)
            ['Breadth (Moulded)', '${v['breadth_moulded']} m'],
          if (v['breadth_extreme'] != null)
            ['Breadth (Extreme)', '${v['breadth_extreme']} m'],
          if (v['beam_oa'] != null) ['Beam (OA)', '${v['beam_oa']} m'],
        ]
      : [
          [v['breadth_qualifier'] as String? ?? 'Breadth',
           v['breadth'] != null ? '${v['breadth']} m' : ''],
        ];
  final hasNewDraft = v['draft_load_line'] != null || v['draft_max'] != null;
  final draftRows = hasNewDraft
      ? [
          if (v['draft_load_line'] != null)
            ['Draft (Load Line)', '${v['draft_load_line']} m'],
          if (v['draft_max'] != null) ['Draft (Max)', '${v['draft_max']} m'],
        ]
      : [
          [v['draft_qualifier'] as String? ?? 'Draft',
           v['max_draft'] != null ? '${v['max_draft']} m' : ''],
        ];

  return [
    ['Vessel Name', v['name'] ?? ''],
    ['IMO Number', v['imo_number'] ?? ''],
    ['Type', v['vessel_type'] ?? ''],
    ['Flag', v['flag'] ?? ''],
    ['Port of Registry', v['port_of_registry'] ?? ''],
    ['Gross Tonnage', v['gross_tonnage']?.toString() ?? ''],
    ['Net Tonnage', v['net_tonnage']?.toString() ?? ''],
    ['Deadweight', v['deadweight']?.toString() ?? ''],
    ['LOA', v['length_oa']?.toString() ?? ''],
    ...breadthRows,
    ...draftRows,
    ['Propeller Type', v['propeller_type'] ?? ''],
    ['Propulsion Drive', v['propulsion_drive_type'] ?? ''],
    ['Year Built', v['year_built']?.toString() ?? ''],
    ['Build Yard', v['build_yard'] ?? ''],
    ['Owners', v['owners'] ?? ''],
    ['Registered Owner', v['registered_owner'] ?? ''],
    ['Operators', v['operators'] ?? ''],
    ['Class Society', v['class_society'] ?? ''],
    ['Class Notation', v['class_notation'] ?? ''],
    ['P&I Club', v['pi_club'] ?? ''],
    ['ISPS Status', v['isps_status'] ?? ''],
    ['Last Drydock', formatSectionDate(v['last_drydock_date'] as String? ?? '')],
    ['PSC Last Inspection', formatSectionDate(v['psc_last_inspection'] as String? ?? '')],
    // DCV — National Law only (empty-row filter below hides these for
    // Convention vessels automatically).
    ['Hull Material', v['hull_material'] ?? ''],
    ['Unique Vessel Identifier', v['unique_vessel_identifier'] ?? ''],
    ['Survey Certificate No.', v['survey_certificate_no'] ?? ''],
    ['AMSA Class',
     (v['amsa_vessel_use_class'] != null && v['amsa_service_category'] != null)
         ? 'Class ${v['amsa_vessel_use_class']}${(v['amsa_service_category'] as String).toUpperCase()}'
         : ''],
    ['Equipment Due', formatSectionDate(v['equipment_survey_due'] as String? ?? '')],
    ['Hull Due', formatSectionDate(v['hull_survey_due'] as String? ?? '')],
    ['Tail Shaft Due', formatSectionDate(v['tail_shaft_survey_due'] as String? ?? '')],
  ].where((r) => (r[1] as String).isNotEmpty)
   .map((r) => [r[0] as String, r[1] as String])
   .toList();
}

/// Class & Statutory Certification — certificates register (spec §5),
/// with header row.
List<List<String>> buildCertificateRows(List<Map<String, dynamic>> certificates) {
  if (certificates.isEmpty) return const [];
  return [
    ['Certificate', 'Issuing Authority', 'Issue Date', 'Expiry'],
    ...certificates.map((c) => [
          c['cert_name'] as String? ?? c['cert_type'] as String? ?? '',
          c['issuing_authority'] as String? ?? '',
          formatSectionDate(c['issue_date'] as String? ?? ''),
          formatSectionDate(c['expiry_date'] as String? ?? ''),
        ]),
  ];
}

/// Conditions of Class register (spec §5), with header row.
List<List<String>> buildClassConditionRows(List<Map<String, dynamic>> classConditions) {
  if (classConditions.isEmpty) return const [];
  return [
    ['Reference', 'Description', 'Due Date'],
    ...classConditions.map((cc) => [
          cc['reference'] as String? ?? '',
          cc['description'] as String? ?? '',
          formatSectionDate(cc['expiry_date'] as String? ?? ''),
        ]),
  ];
}

// ── Attending Representatives (spec §2 — per-attendance blocks) ────────────

const _titleLabels = {
  'mr': 'Mr.', 'mrs': 'Mrs.', 'ms': 'Ms.', 'miss': 'Miss',
  'dr': 'Dr.', 'capt': 'Capt.', 'prof': 'Prof.',
};

const _roleLabels = {
  'master': 'Master',
  'port_captain': 'Port Captain',
  'chief_engineer': 'Chief Engineer',
  'first_engineer': 'First Engineer',
  'superintendent': 'Superintendent',
  'owner_rep': "Owner's Representative",
  'service_engineer': 'Service Engineer',
  'other': 'Other',
  'class_surveyor': 'Class Surveyor',
  'adjuster': 'Adjuster / Average Adjuster',
  'broker': 'Broker',
  'solicitor': 'Solicitor',
  'surveyor': 'Surveyor',
};

// This is the table actually rendered in both the docx export and the
// Preview tab (see buildAttendanceBlocks below) — previously silently
// dropped the title prefix entirely when unset, rather than falling back
// to a guess (TODO.md §1.8 S2). 'Mr./Ms.' hedge instead of a bare 'Mr.'
// default (as literally asked) to avoid misgendering — mirrors
// AttendeeModel.prefix in attendees_provider.dart, which only runs on the
// in-app Attendees screen, not this raw-map path.
String _attendeeName(Map<String, dynamic> a) {
  final title = a['title'] as String?;
  final name = a['full_name'] as String? ?? '';
  if (title != null) return '${_titleLabels[title] ?? ''} $name'.trim();
  final role = a['role_type'] as String?;
  final prefix = (role == 'master' || role == 'port_captain')
      ? 'Capt.'
      : 'Mr./Ms.';
  return '$prefix $name'.trim();
}

String _attendeeFunction(Map<String, dynamic> a) {
  final rank = a['rank_position'] as String?;
  if (rank != null && rank.isNotEmpty) return rank;
  final roleValue = a['role_type'] as String?;
  if (roleValue == null) return '';
  return _roleLabels[roleValue] ?? roleValue;
}

List<List<String>> _attendeeRows(List<Map<String, dynamic>> group) {
  return [
    ['Name', 'Company', 'Function'],
    ...group.map((a) => [
          _attendeeName(a),
          a['company'] as String? ?? a['representing'] as String? ?? '',
          _attendeeFunction(a),
        ]),
  ];
}

String _attendanceIntroLine(Map<String, dynamic> attendance) {
  final hasLocation = (attendance['location'] as String?)?.isNotEmpty == true;
  return hasLocation
      ? 'The following persons were also present during the survey / meetings:'
      : 'The following persons were in attendance, or provided information:';
}

/// One "Attendance No. N" block (spec §2 suggested layout): an intro line,
/// optional date/location/purpose, and an attendee register (with header
/// row) for the people linked to that attendance.
class AttendanceBlock {
  const AttendanceBlock({
    required this.label,
    required this.introLine,
    required this.rows,
    this.date,
    this.location,
    this.purpose,
  });

  /// e.g. "Attendance No. 1" / "Other Attendees" — blank when this is the
  /// only block (legacy cases with no survey_attendances records at all).
  final String label;
  final String introLine;
  final String? date;
  final String? location;
  /// Reuses the attendance's free-text "Brief summary" field as the
  /// closest existing match to the spec's "Purpose" field (no dedicated
  /// purpose/attendance-type column exists in the schema).
  final String? purpose;
  /// Header row + one row per attendee: ['Name', 'Company', 'Function'].
  final List<List<String>> rows;
}

/// Groups attendees by `attendance_id` into per-attendance blocks, ordered
/// to match [attendances] (expected oldest-first). Attendees with no
/// `attendance_id` (legacy rows, or cases with no survey_attendances
/// records at all) are collected into a trailing block — labelled "Other
/// Attendees" if there are other blocks, or left as the sole, unlabelled
/// block otherwise (matching the app's pre-grouping flat-register look for
/// cases that predate per-attendance linkage).
List<AttendanceBlock> buildAttendanceBlocks(
  List<Map<String, dynamic>> attendances,
  List<Map<String, dynamic>> attendees,
) {
  final byAttendance = <String, List<Map<String, dynamic>>>{};
  final unlinked = <Map<String, dynamic>>[];
  for (final a in attendees) {
    final id = a['attendance_id'] as String?;
    if (id == null) {
      unlinked.add(a);
    } else {
      byAttendance.putIfAbsent(id, () => []).add(a);
    }
  }

  final blocks = <AttendanceBlock>[];
  var blockNo = 0;
  for (final att in attendances) {
    final id = att['attendance_id'] as String?;
    final group = id != null ? byAttendance[id] : null;
    if (group == null || group.isEmpty) continue;
    blockNo++;
    blocks.add(AttendanceBlock(
      label: 'Attendance No. $blockNo',
      introLine: _attendanceIntroLine(att),
      date: formatSectionDate(att['attendance_date'] as String? ?? ''),
      location: att['location'] as String?,
      purpose: att['summary'] as String?,
      rows: _attendeeRows(group),
    ));
  }

  if (unlinked.isNotEmpty) {
    blocks.add(AttendanceBlock(
      label: blocks.isEmpty ? '' : 'Other Attendees',
      introLine: 'The following persons were in attendance, or provided information:',
      rows: _attendeeRows(unlinked),
    ));
  }

  return blocks;
}

// ── Section 1: Introduction — Occurrence table (spec suggested layout) ────
//
// Spec shows a single "Occurrence No. 1" row; extended here to list every
// occurrence on the case (multi-occurrence cases previously only ever
// looked at `occurrences.first` throughout the codebase).
List<List<String>> buildOccurrenceRows(List<Map<String, dynamic>> occurrences) {
  if (occurrences.isEmpty) return const [];
  return [
    ['Occurrence No.', 'Date', 'Title'],
    ...occurrences.map((o) => [
          'Occurrence No. ${o['occurrence_no'] ?? ''}',
          formatSectionDate(o['date_time'] as String? ?? ''),
          (o['title'] as String?)?.isNotEmpty == true
              ? o['title'] as String
              : '[occurrence title not yet recorded]',
        ]),
  ];
}

// ── Section 4: Movements & Events — Chronology of Events table ────────────
//
// Not a `SectionType` (auto-table straight from `timeline_events`, no text
// section — see the enum comment in report_provider.dart), which meant it
// was previously rendered only in docx_export_service.dart and never shown
// in the Preview tab at all, since Preview iterates `sections` map entries
// only. Shared here so both renderers build the identical table.
List<List<String>> buildChronologyRows(List<Map<String, dynamic>> timelineEvents) {
  if (timelineEvents.isEmpty) return const [];
  return [
    ['Date', 'Event'],
    ...timelineEvents.map((e) => [
          formatSectionDate(e['event_date'] as String? ?? ''),
          e['description'] as String? ?? e['title'] as String? ?? '',
        ]),
  ];
}

// ── Section 5: Brief Technical Description — claim-object blocks ──────────

const kNotConfirmed = 'Not Confirmed';

String _mval(dynamic v) =>
    (v is String && v.trim().isNotEmpty) ? v : kNotConfirmed;

/// One machinery / claim-object block (spec suggested layout: bordered box,
/// key:value pairs). "Not Confirmed" placeholder is used for any field not
/// yet captured — per spec: "never leave blank in the rendered output".
class MachineryBlock {
  const MachineryBlock({required this.label, required this.rows});
  final String label;
  final List<List<String>> rows; // key:value pairs, no header row
}

List<MachineryBlock> buildMachineryBlocks(List<Map<String, dynamic>> machinery) {
  return machinery.map((m) {
    final type = m['machinery_type'] as String? ?? '';
    final role = m['role'] as String? ?? '';
    final label = role.isNotEmpty
        ? '$type — $role'
        : (type.isNotEmpty ? type : 'Machinery Item');

    final kw = (m['mcr_kw'] as num?)?.toStringAsFixed(0);
    final rpm = (m['mcr_rpm'] as num?)?.toStringAsFixed(0);
    final quantity = (m['quantity'] as num?)?.toInt();
    final runHrsNew = m['run_hrs_new'] as num?;
    final runHrsOverhaul = m['run_hrs_overhaul'] as num?;

    return MachineryBlock(label: label, rows: [
      ['Manufacturer', _mval(m['make'])],
      ['Model', _mval(m['model'])],
      ['Serial Number', _mval(m['serial_number'])],
      if (kw != null || rpm != null)
        [
          'Power / Speed',
          [if (kw != null) '$kw kW', if (rpm != null) '$rpm rpm'].join(' @ '),
        ],
      if (_mval(m['fuel_type']) != kNotConfirmed) ['Fuel Type', m['fuel_type'] as String],
      if (m['cylinder_count'] != null) ['Cylinders', '${m['cylinder_count']}'],
      if (_mval(m['configuration']) != kNotConfirmed)
        ['Configuration', m['configuration'] as String],
      if (quantity != null && quantity > 1)
        [
          'Quantity',
          '$quantity${m['unit_number'] != null ? ' (Unit ${m['unit_number']})' : ''}',
        ],
      ['Total Running Hours', runHrsNew != null ? '$runHrsNew' : kNotConfirmed],
      ['Hours Since Last Overhaul',
       runHrsOverhaul != null ? '$runHrsOverhaul' : kNotConfirmed],
    ]);
  }).toList();
}

// ── Section 8: Repairs — Work Not Concerning Average (WNCA) ───────────────
//
// Fixed, locked opening clause (spec verbatim) — not AI-generated, not
// editable. Populated from context cues tagged CaseSection.notAverage
// (docs/context_cue_system_review.md §3.1) — reintegrated 5 July 2026 from
// the earlier `repair_periods.not_average_items` bespoke per-period list,
// which is retired. Includes cues regardless of whether they're linked to
// a specific repair period, same as the old flattened-across-all-periods
// behaviour.
const wncaOpeningClause =
    'Concurrently with the average repairs, the Owners / Managers of the '
    'vessel instructed repairs to be carried out to their own account. '
    'These included, but were not limited to, the following works:';

List<String> buildWncaItems(List<Map<String, dynamic>> surveyorNotes) =>
    surveyorNotes
        .where((n) => n['case_section'] == 'not_average')
        .map((n) => n['content'] as String? ?? '')
        .where((c) => c.isNotEmpty)
        .toList();

// ── Section 10: Cause Consideration — third-party findings register ──────

List<List<String>> buildThirdPartyFindingRows(
    List<Map<String, dynamic>> occurrences) {
  final findings = <Map<String, dynamic>>[];
  for (final occ in occurrences) {
    final raw = (occ['third_party_findings'] as List?) ?? const [];
    findings.addAll(raw.cast<Map<String, dynamic>>());
  }
  if (findings.isEmpty) return const [];
  return [
    ['Source', 'Document Reference', 'Finding'],
    ...findings.map((f) => [
          f['source_name'] as String? ?? '',
          (f['document_reference'] as String?)?.isNotEmpty == true
              ? f['document_reference'] as String
              : '—',
          f['finding'] as String? ?? '',
        ]),
  ];
}

/// Certainty level label (spec §10 item 4 — drives the hedging language of
/// the surveyor's assessment). Read from the primary occurrence.
String? buildCertaintyLevelLabel(List<Map<String, dynamic>> occurrences) {
  if (occurrences.isEmpty) return null;
  final raw = occurrences.first['certainty_level'] as String?;
  return CertaintyLevel.fromValue(raw)?.label;
}

// ── Section 11: Repair Costs — per-invoice line tables + WP totals ────────

String fmtAmount(double v) {
  final parts = v.toStringAsFixed(2).split('.');
  final integral =
      parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$integral.${parts[1]}';
}

/// One repair-document's cost summary (spec §11 — line-item table +
/// mandatory "Sum Approved Without Prejudice" phrase). Narrative clauses
/// (H-2/H-3/H-4/H-6 in docx_export_service.dart) are docx-only trims on top
/// of this shared core — the Preview tab shows the same figures without the
/// clause-library prose.
class AccountLineSummary {
  const AccountLineSummary({
    required this.docLabel,
    required this.currency,
    required this.lineRows,
    this.sumApprovedWp,
  });
  final String docLabel;
  final String currency;
  /// Header + rows: ['#','Description','Nature','Amount','Allocation'].
  /// Empty when the document has no account lines.
  final List<List<String>> lineRows;
  final String? sumApprovedWp;
}

List<AccountLineSummary> buildAccountSummaries(AssembledReportData assembled) {
  return assembled.repairDocuments.map((repDoc) {
    final docName = repDoc['display_name'] as String? ??
        repDoc['supplier_name'] as String? ?? 'Invoice';
    final docNumber = repDoc['document_number'] as String? ?? '';
    final docDate = formatSectionDate(repDoc['document_date'] as String? ?? '');
    final currency = repDoc['currency'] as String? ?? '';
    final docLabel = [
      docName,
      if (docNumber.isNotEmpty) '#$docNumber',
      if (docDate.isNotEmpty) docDate,
    ].join('  ·  ');

    final lines =
        (repDoc['account_lines'] as List? ?? []).cast<Map<String, dynamic>>();
    double docTotalUw = 0;
    final lineRows = <List<String>>[
      ['#', 'Description', 'Nature', 'Amount ($currency)', 'Allocation'],
    ];
    for (final e in lines.asMap().entries) {
      final l = e.value;
      final gross = (l['gross_amount'] as num?)?.toDouble() ?? 0;
      final uwPart = (l['underwriters_portion'] as num?)?.toDouble() ?? gross;
      docTotalUw += uwPart;
      lineRows.add([
        '${l['item_number'] as int? ?? e.key + 1}',
        l['description'] as String? ?? '',
        l['cost_nature'] as String? ?? '',
        fmtAmount(gross),
        l['apportionment_type'] as String? ?? "Underwriters'",
      ]);
    }

    final wp = (repDoc['without_prejudice'] as bool? ?? true) &&
            lines.isNotEmpty &&
            docTotalUw > 0.005
        ? 'Sum Approved Without Prejudice: $currency ${fmtAmount(docTotalUw)}'
        : null;

    return AccountLineSummary(
      docLabel: docLabel,
      currency: currency,
      lineRows: lineRows.length > 1 ? lineRows : const [],
      sumApprovedWp: wp,
    );
  }).toList();
}

/// Grand totals row set (Underwriters' / Owner's / base-currency grand
/// total) — spec §11 headline figures.
List<List<String>> buildAccountTotalsRows(AssembledReportData assembled) {
  final baseCurrency = assembled.caseData['base_currency'] as String? ?? '';
  double grandTotalUw = 0, grandTotalOwner = 0, grandTotalBase = 0;
  for (final repDoc in assembled.repairDocuments) {
    final lines =
        (repDoc['account_lines'] as List? ?? []).cast<Map<String, dynamic>>();
    for (final l in lines) {
      final gross = (l['gross_amount'] as num?)?.toDouble() ?? 0;
      final uwPart = (l['underwriters_portion'] as num?)?.toDouble() ?? gross;
      final ownPart = (l['owners_portion'] as num?)?.toDouble() ?? 0;
      final fx = (l['fx_rate_to_base'] as num?)?.toDouble() ?? 1.0;
      grandTotalUw += uwPart * fx;
      grandTotalOwner += ownPart * fx;
      grandTotalBase += gross * fx;
    }
  }
  return [
    if (grandTotalUw > 0.005) ["Underwriters' account", fmtAmount(grandTotalUw)],
    if (grandTotalOwner > 0.005) ["Owner's account", fmtAmount(grandTotalOwner)],
    if (grandTotalBase > 0.005 && baseCurrency.isNotEmpty)
      ['Grand total ($baseCurrency)', fmtAmount(grandTotalBase)],
  ];
}

// ── Section 12: Available Information — MINRES BALDER table format ───────

/// Document | Status table (spec's preferred default over the two flat
/// bullet lists) — built from the same `caseDocuments`/`requestedDocuments`
/// split already used for Clause K-1/K-2. No "Not provided" status exists
/// in the schema yet (`documents.availability` is a two-way enclosed/
/// requested split) so only Available/Requested are ever produced.
List<List<String>> buildAvailableInformationRows(
  List<Map<String, dynamic>> caseDocuments,
  List<Map<String, dynamic>> requestedDocuments,
) {
  if (caseDocuments.isEmpty && requestedDocuments.isEmpty) return const [];
  String label(Map<String, dynamic> d) {
    final title = d['title'] as String? ?? 'Untitled document';
    final date = formatSectionDate(d['doc_date'] as String? ?? '');
    return date.isNotEmpty ? '$title — $date' : title;
  }

  return [
    ['Document', 'Status'],
    ...caseDocuments.map((d) => [label(d), 'Available']),
    ...requestedDocuments.map((d) => [label(d), 'Requested']),
  ];
}

// ── Section 14: Repair Times — §2.18 (10 July 2026) ───────────────────────
//
// Extracted from docx_export_service.dart's previously-inline table
// construction so report_preview.dart / section_reference_panel.dart can
// share it too — before this, Preview rendered the section's free-text
// `content` (AI-generated prose) while docx built this table directly from
// `repairPeriods`, and the two had quietly diverged (whatever the surveyor
// typed into the Editor's free-text box never actually reached the export).
List<List<String>> buildRepairTimesRows(
    List<Map<String, dynamic>> repairPeriods) {
  final periods = repairPeriods.map(RepairPeriodModel.fromJson).toList();
  final hasTime = periods.any((p) =>
      p.drydockDaysTotal > 0 || p.alongsideDaysTotal > 0 || p.ownerDaysTotal > 0);
  if (!hasTime) return const [];
  return [
    ['Repair', 'Drydock Days', 'Afloat Days', "Owner's Days", 'Total'],
    ...periods.map((p) {
      final dd = p.drydockDaysTotal;
      final ad = p.alongsideDaysTotal;
      final od = p.ownerDaysTotal;
      return [
        p.displayTitle,
        dd > 0 ? dd.toStringAsFixed(1) : '—',
        ad > 0 ? ad.toStringAsFixed(1) : '—',
        od > 0 ? od.toStringAsFixed(1) : '—',
        (dd + ad).toStringAsFixed(1),
      ];
    }),
  ];
}

// ── Section 16: Documents Retained on File — §2.18 (10 July 2026) ────────
//
// Same extraction as [buildRepairTimesRows], same reason — this table was
// previously only built inline in docx_export_service.dart.
List<List<String>> buildDocumentsOnFileRows(
    List<Map<String, dynamic>> caseDocuments) {
  if (caseDocuments.isEmpty) return const [];
  return [
    ['#', 'Document', 'Category', 'Date'],
    ...caseDocuments.asMap().entries.map((e) => [
          '${e.key + 1}',
          e.value['title'] as String? ?? '',
          (e.value['doc_category'] as String? ?? '').replaceAll('_', ' '),
          formatSectionDate(e.value['doc_date'] as String? ?? ''),
        ]),
  ];
}

// ── Section 9: Damage Description — "DAMAGE SCHEDULE" table (§2.18,
// 10 July 2026) ────────────────────────────────────────────────────────
//
// Extracted from docx_export_service.dart's previously-inline table
// construction, same reason as buildRepairTimesRows/buildDocumentsOnFileRows.
// This covers only the docx export's "DAMAGE SCHEDULE" table — the
// separate "EXTENT OF DAMAGE" block (grouped by machinery, with inline
// photos and confirmation-clause prose) is genuinely richer than a table
// and isn't reproduced here; this is still a faithful, useful summary of
// the same underlying damageItems, and — like the other auto-populated
// types — strictly better than the disconnected free-text `content` this
// replaces (which had no relationship to either exported block at all).
List<List<String>> buildDamageScheduleRows(
    List<Map<String, dynamic>> damageItems) {
  if (damageItems.isEmpty) return const [];
  return [
    ['Component', 'Description', 'Condition', 'Average'],
    ...damageItems.map((d) {
      final averageStatusRaw = d['average_status'] as String?;
      final averageLabel = switch (averageStatusRaw) {
        'no' => "Owner's",
        'partial' => 'Partial',
        'yes' => 'Average',
        _ => (d['is_concerning_average'] as bool? ?? true)
            ? 'Average'
            : "Owner's",
      };
      final conditionStatusRaw = d['condition_status'] as String?;
      return [
        d['component_name'] as String? ?? '',
        d['damage_description'] as String? ?? '',
        conditionStatusRaw != null
            ? ConditionStatus.fromValue(conditionStatusRaw).label
            : '',
        averageLabel,
      ];
    }),
  ];
}

// ── Section 13: Waiver — sign-off block ───────────────────────────────────

/// Report sign-off identity (spec's "Yours faithfully" block) — distinct
/// from the internal attending/reviewing QC authentication block already
/// implemented in docx_export_service.dart. Falls back to bracketed
/// placeholders when no surveyor profile has been configured yet.
class ReportSignOff {
  const ReportSignOff({
    required this.name,
    this.title,
    this.company,
    this.mobile,
    this.email,
    this.website,
    this.signatureStoragePath,
  });
  final String name;
  final String? title;
  final String? company;
  final String? mobile;
  final String? email;
  final String? website;
  final String? signatureStoragePath;
}

/// Picks the first surveyor profile on the organisation — this app's
/// current target market is single-surveyor firms, so there is no
/// multi-surveyor disambiguation to do yet.
ReportSignOff buildReportSignOff(Map<String, dynamic>? organisation) {
  final profiles = (organisation?['surveyor_profiles'] as List?)
          ?.cast<Map<String, dynamic>>() ??
      const [];
  final profile = profiles.isNotEmpty ? profiles.first : null;
  return ReportSignOff(
    name: (profile?['full_name'] as String?)?.isNotEmpty == true
        ? profile!['full_name'] as String
        : '[Surveyor Name]',
    title: profile?['title'] as String?,
    company: organisation?['name'] as String?,
    mobile: profile?['phone'] as String?,
    email: profile?['email'] as String?,
    website: organisation?['website'] as String?,
    signatureStoragePath: profile?['signature_storage_path'] as String?,
  );
}
