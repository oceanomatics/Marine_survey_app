// lib/features/reports/services/docx_export_service.dart
//
// Builds a properly structured .docx from assembled case data using the
// in-house OOXML builder (lib/core/docx/docx_builder.dart).
// Replaces the previous docx_template approach.
//
// On web:    downloads via dart:html
// On native: saves to getApplicationDocumentsDirectory()

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show debugPrint;
import '../providers/report_provider.dart';
import '../utils/section_text.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/docx/docx_builder.dart';
import '../../survey/models/repair_period_model.dart';
import '../../survey/providers/damage_provider.dart'
    show ConditionStatus, ConfirmedByRole;
import 'report_delivery.dart';

/// A photo's decoded bytes + file extension, resolved by the caller
/// (ExportButton) before export — the service itself has no filesystem
/// dependency, same convention as coverPhotoBytes.
typedef ResolvedPhoto = ({Uint8List bytes, String ext});

class DocxExportService {
  static const String _docxMime =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  /// Generate and deliver a .docx report. Returns the filename.
  /// [coverPhotoBytes] comes from the caller (read from local photo storage)
  /// so the export service itself has no filesystem or Supabase Storage
  /// dependency for the cover image.
  static Future<String> export({
    required ReportOutput output,
    required AssembledReportData assembled,
    required Map<SectionType, ReportSection> sections,
    Uint8List? coverPhotoBytes,
    String coverPhotoExt = 'jpg',
    Map<String, List<ResolvedPhoto>>? damagePhotosByItemId,
  }) async {
    // Fetch org logo from Supabase Storage (non-fatal)
    Uint8List? logoBytes;
    String logoExt = 'png';
    final logoPath = assembled.organisation?['logo_path'] as String?;
    if (logoPath != null && logoPath.isNotEmpty) {
      try {
        final parts = logoPath.split('.');
        if (parts.length > 1) logoExt = parts.last.toLowerCase();
        logoBytes = await SupabaseService.client.storage
            .from('organisation_assets')
            .download(logoPath);
      } catch (e) {
        debugPrint('Logo fetch skipped: $e');
      }
    }

    // Compute an aspect-ratio-preserving box for the cover photo so it's
    // scaled to fit, not cropped or stretched — cropping is a deliberate
    // step done in the photo editor, not something export should do.
    int? coverPhotoWidthEmu;
    int? coverPhotoHeightEmu;
    if (coverPhotoBytes != null) {
      try {
        final codec = await ui.instantiateImageCodec(coverPhotoBytes);
        final frame = await codec.getNextFrame();
        final imgW = frame.image.width;
        final imgH = frame.image.height;
        frame.image.dispose();
        const maxW = DocxBuilder.kPageWidthEmu;
        const maxH = DocxBuilder.kPageWidthEmu * 9 ~/ 16;
        final scale = (maxW / imgW < maxH / imgH) ? maxW / imgW : maxH / imgH;
        coverPhotoWidthEmu  = (imgW * scale).round();
        coverPhotoHeightEmu = (imgH * scale).round();
      } catch (e) {
        debugPrint('Cover photo dimension decode skipped: $e');
      }
    }

    final bytes = _buildDocx(output, assembled, sections,
        coverPhotoBytes: coverPhotoBytes, coverPhotoExt: coverPhotoExt,
        coverPhotoWidthEmu: coverPhotoWidthEmu,
        coverPhotoHeightEmu: coverPhotoHeightEmu,
        logoBytes: logoBytes, logoExt: logoExt,
        damagePhotosByItemId: damagePhotosByItemId);
    final filename = _filename(output, assembled);

    // Snapshot AI log + upload to Supabase Storage (non-fatal)
    try {
      final path = '${assembled.caseData['case_id']}/exports/$filename';
      await SupabaseService.uploadFile(
        bucket: 'exports',
        path: path,
        bytes: bytes,
        mimeType: _docxMime,
      );
      final aiSnapshot = assembled.aiGenerationLog.isEmpty
          ? null
          : assembled.aiGenerationLog.map((l) => l.toJson()).toList();
      await SupabaseService.client
          .from('report_outputs')
          .update({
            'file_path': path,
            if (aiSnapshot != null) 'ai_log_snapshot': aiSnapshot,
          })
          .eq('output_id', output.outputId);
    } catch (e) {
      debugPrint('Storage upload/snapshot skipped: $e');
    }

    return _deliver(bytes: bytes, filename: filename);
  }

  // ── Document builder ──────────────────────────────────────────────────────

  static Uint8List _buildDocx(
    ReportOutput output,
    AssembledReportData assembled,
    Map<SectionType, ReportSection> sections, {
    Uint8List? coverPhotoBytes,
    String? coverPhotoExt,
    int? coverPhotoWidthEmu,
    int? coverPhotoHeightEmu,
    Uint8List? logoBytes,
    String logoExt = 'png',
    Map<String, List<ResolvedPhoto>>? damagePhotosByItemId,
  }) {
    final doc = DocxBuilder();
    final v     = assembled.vessel ?? {};
    final case_ = assembled.caseData;
    final org   = assembled.organisation;

    // Resolve branding colours (strip '#' prefix if present)
    String hex(String? raw, String fallback) =>
        (raw ?? fallback).replaceAll('#', '');
    final primaryHex   = hex(org?['primary_colour']   as String?, '1F3A5F');
    final secondaryHex = hex(org?['secondary_colour'] as String?, '2C5282');
    final accentHex    = hex(org?['accent_colour']    as String?, 'EBF4FF');
    final firmName     = org?['name'] as String?;

    doc.setBranding(
      primaryHex:   primaryHex,
      secondaryHex: secondaryHex,
      accentHex:    accentHex,
    );

    // ── WP footer on every page (location 4) ──────────────────────────
    final wpFooterNotice = org?['wp_footer_text'] as String?
        ?? 'This report is supplied without prejudice to any or all parties '
           'involved and shall not be copied or passed on to third parties '
           'without the express permission of'
           '${firmName != null && firmName.isNotEmpty ? ' $firmName' : ' the issuing firm'}.';
    doc.setFooter(wpFooterNotice);

    // ── Running header on body pages (page 2+) ────────────────────────
    final vesselName  = v['name'] as String? ?? '';
    final claimRef    = case_['claim_reference'] as String? ?? '';
    final jobNo       = case_['technical_file_no'] as String? ?? '';
    final reportTypeLabel = switch (output.outputType) {
      OutputType.advice => 'Advice No ${output.sequenceNo}',
      OutputType.preliminary => 'Preliminary Report',
      OutputType.final_ => 'Final Report',
    };
    final headerRight = [
      if (jobNo.isNotEmpty) jobNo,
      if (vesselName.isNotEmpty) vesselName,
      reportTypeLabel,
    ].join(' — ');
    doc.setBodyHeader(
      leftText:  firmName ?? '',
      rightText: headerRight,
      logoBytes: logoBytes,
      logoExt:   logoExt,
    );

    // ═══════════════════════════════════════════════════════════════════
    // COVER PAGE (page 1 — no running header via w:titlePg)
    // ═══════════════════════════════════════════════════════════════════

    // WP notice (location 1 — top of cover)
    final wpHeader = org?['wp_header_text'] as String? ??
        'WITHOUT PREJUDICE AND SUBJECT TO SURVEY';
    doc.addParagraph(wpHeader,
        bold: true, align: WAlignment.center,
        colorHex: '6B7280', halfPtSize: 18);
    doc.addSpacer();

    // Firm name
    if (firmName != null && firmName.isNotEmpty) {
      doc.addParagraph(firmName,
          bold: true, align: WAlignment.center,
          halfPtSize: 22, colorHex: '374151');
    }
    doc.addSpacer();

    // Vessel name — large primary-colour band
    if (vesselName.isNotEmpty) {
      doc.addShadedBlock(
        'M.V.  "$vesselName"',
        bgHex: primaryHex,
        halfPtSize: 52,
        paddingTwips: 200,
      );
    }

    // Report type + version — status-colour band
    final statusHex = switch (output.outputType) {
      OutputType.final_      => '059669',  // green
      OutputType.advice      => '0284C7',  // sky blue
      OutputType.preliminary => 'B45309',  // amber
    };
    doc.addShadedBlock(
      '${output.outputType.label.toUpperCase()}  ·  ${output.versionCode}',
      bgHex: statusHex,
      halfPtSize: 26,
      paddingTwips: 100,
    );

    // WP cover block (location 2)
    final wpCover = org?['wp_cover_text'] as String?;
    if (wpCover != null && wpCover.isNotEmpty) {
      doc.addSpacer();
      doc.addParagraph(wpCover,
          italic: true, halfPtSize: 18,
          colorHex: '6B7280', align: WAlignment.center);
    }

    doc.addSpacer();

    // Vessel cover photo (if available) — scaled to fit within the page
    // width / a 16:9-ish max height, preserving aspect ratio (no crop or
    // stretch). Falls back to the old fixed 16:9 box only if dimensions
    // couldn't be decoded.
    if (coverPhotoBytes != null) {
      const fallbackH = (DocxBuilder.kPageWidthEmu * 9 ~/ 16);
      doc.addImage(coverPhotoBytes, coverPhotoExt ?? 'jpg',
          widthEmu: coverPhotoWidthEmu ?? DocxBuilder.kPageWidthEmu,
          heightEmu: coverPhotoHeightEmu ?? fallbackH);
      doc.addSpacer();
    }

    // Cover info table
    final occFirst = assembled.occurrences.isNotEmpty
        ? assembled.occurrences.first
        : <String, dynamic>{};
    final occDate   = _formatDate(occFirst['occurrence_date'] as String? ?? '');
    final occTitle  = occFirst['title']    as String? ?? '';
    final occLoc    = occFirst['location'] as String? ?? '';
    final infoRows  = <List<String>>[
      if (occDate.isNotEmpty)  ['Date of Casualty',    occDate],
      if (occTitle.isNotEmpty) ['Nature of Casualty',  occTitle],
      if (occLoc.isNotEmpty)   ['Location',            occLoc],
      if (claimRef.isNotEmpty) ['Claim Reference',     claimRef],
      if (jobNo.isNotEmpty)    ['File No.',             jobNo],
                               ['Report Version',      output.versionCode],
                               ['Date Issued',         _today()],
    ];
    doc.addTable(infoRows, colWidths: [3000, 6355]);

    doc.addPageBreak();

    // ═══════════════════════════════════════════════════════════════════
    // BODY PAGES (page 2+) — running header active from here
    // ═══════════════════════════════════════════════════════════════════

    // Helper to render a text section if it has content
    void renderTextSection(SectionType type, String heading) {
      final section = sections[type];
      if (section == null || section.content.trim().isEmpty) return;
      doc.addHeading(heading, 2);
      for (final para in splitSectionParagraphs(section.content)) {
        doc.addParagraph(para);
      }
      doc.addSpacer();
    }

    // ── Page 2: AI Disclosure → Executive Summary → Document Control ────

    // AI usage disclosure (page 2, before Executive Summary — spec §3.5)
    if (assembled.aiGenerationLog.isNotEmpty) {
      doc.addHeading('AI USAGE DISCLOSURE', 2);
      final aiDisclosure = org?['ai_disclosure_text'] as String?
          ?? 'In preparing this report, artificial intelligence tools were '
             'used to assist with the drafting of certain sections. All '
             'AI-generated content was reviewed, verified, and approved by '
             'the attending surveyor prior to issue. This report complies with '
             'the Federal Court of Australia Practice Note GPN-AI (2026).';
      doc.addParagraph(aiDisclosure,
          italic: true, halfPtSize: 18, colorHex: '374151');
      doc.addSpacer();
    }

    // Executive Summary (page 2 — editable)
    final executiveSummarySection = sections[SectionType.executiveSummary];
    if (executiveSummarySection != null &&
        executiveSummarySection.content.trim().isNotEmpty) {
      doc.addHeading('EXECUTIVE SUMMARY', 2);
      for (final para in splitSectionParagraphs(executiveSummarySection.content)) {
        doc.addParagraph(para);
      }
      doc.addSpacer();
    }

    // Document Control — version history table
    final allOutputs = assembled.allReportOutputs;
    if (allOutputs.isNotEmpty) {
      doc.addHeading('DOCUMENT CONTROL', 2);
      final vRows = <List<String>>[
        ['Version', 'Date', 'Type', 'Supersedes', 'Changes'],
        ...allOutputs.map((o) {
          final seqNo = o['sequence_no'] as int? ?? 1;
          final vCode = () {
            final rn = o['report_number'] as String?;
            if (rn != null) {
              final m = RegExp(r'R\d{3,}$').firstMatch(rn);
              if (m != null) return m.group(0)!;
            }
            return 'R${seqNo.toString().padLeft(3, '0')}';
          }();
          final typeStr  = o['output_type'] as String? ?? '';
          final typeLabel = OutputType.values
              .firstWhere((e) => e.value == typeStr,
                  orElse: () => OutputType.preliminary)
              .label;
          final rawDate = (o['issued_date'] ?? o['created_at']) as String?;
          final dateStr = rawDate != null ? _formatDate(rawDate) : '—';
          return [vCode, dateStr, typeLabel,
            o['supersedes_version'] as String? ?? '—',
            o['changes_summary']   as String? ?? '—'];
        }),
      ];
      doc.addTable(vRows, boldFirstRow: true,
          colWidths: [800, 1000, 1400, 900, 5255]);
      doc.addSpacer();
    }

    // ── Section 1: Introduction / Scope of Work ───────────────────────
    // Clause B-1 ("THIS IS TO CERTIFY") is already the opening words of the
    // seeded opening_certification clause text — confirmed via clause_library
    // discovery query, 2026-07-02. Do not add it again here.
    renderTextSection(SectionType.opening, 'INTRODUCTION');

    // ── Section 2: Attending Representatives ─────────────────────────
    if (assembled.attendees.isNotEmpty) {
      doc.addHeading('ATTENDANCE & REPRESENTATIVES', 2);
      final attRows = [
        ['Name / Rank', 'Representing'],
        ...assembled.attendees.map((a) => [
              '${a['rank_position'] ?? ''} ${a['full_name'] ?? ''}'.trim(),
              a['representing'] as String? ?? a['company'] as String? ?? '',
            ]),
      ];
      doc.addTable(attRows, boldFirstRow: true, colWidths: [4677, 4678]);
      doc.addSpacer();
    }

    // ── Section 3: Vessel Particulars ────────────────────────────────
    if (v.isNotEmpty) {
      doc.addHeading('VESSEL PARTICULARS', 2);
      final vpRows = [
        ['Vessel Name',         v['name']             ?? ''],
        ['IMO Number',          v['imo_number']        ?? ''],
        ['Type',                v['vessel_type']       ?? ''],
        ['Flag',                v['flag']              ?? ''],
        ['Port of Registry',    v['port_of_registry']  ?? ''],
        ['Gross Tonnage',       v['gross_tonnage']?.toString() ?? ''],
        ['Net Tonnage',         v['net_tonnage']?.toString()  ?? ''],
        ['Deadweight',          v['deadweight']?.toString()   ?? ''],
        ['LOA',                 v['length_oa']?.toString()    ?? ''],
        // Clauses C-2/C-3: the row label itself is the qualifier the
        // surveyor picked on the vessel screen (e.g. "Moulded Breadth"),
        // so no separate phrase lookup is needed.
        [v['breadth_qualifier'] as String? ?? 'Breadth',
         v['breadth'] != null ? '${v['breadth']} m' : ''],
        [v['draft_qualifier'] as String? ?? 'Draft',
         v['max_draft'] != null ? '${v['max_draft']} m' : ''],
        // Clauses C-4/C-5: propeller/drive type
        ['Propeller Type',      v['propeller_type']       ?? ''],
        ['Propulsion Drive',    v['propulsion_drive_type'] ?? ''],
        ['Year Built',          v['year_built']?.toString()   ?? ''],
        ['Build Yard',          v['build_yard']        ?? ''],
        ['Owners',              v['owners']            ?? ''],
        ['Operators',           v['operators']         ?? ''],
        ['Class Society',       v['class_society']     ?? ''],
        ['Class Notation',      v['class_notation']    ?? ''],
        ['P&I Club',            v['pi_club']           ?? ''],
        ['ISPS Status',         v['isps_status']       ?? ''],
        ['Last Drydock',        _formatDate(v['last_drydock_date'] as String? ?? '')],
        ['PSC Last Inspection', _formatDate(v['psc_last_inspection'] as String? ?? '')],
        // DCV — National Law only (empty-row filter below hides these for
        // Convention vessels automatically).
        ['Hull Material',            v['hull_material']            ?? ''],
        ['Unique Vessel Identifier', v['unique_vessel_identifier'] ?? ''],
        ['Survey Certificate No.',   v['survey_certificate_no']    ?? ''],
        ['AMSA Class',
         (v['amsa_vessel_use_class'] != null && v['amsa_service_category'] != null)
             ? 'Class ${v['amsa_vessel_use_class']}${(v['amsa_service_category'] as String).toUpperCase()}'
             : ''],
        ['Equipment Due',  _formatDate(v['equipment_survey_due']  as String? ?? '')],
        ['Hull Due',       _formatDate(v['hull_survey_due']       as String? ?? '')],
        ['Tail Shaft Due', _formatDate(v['tail_shaft_survey_due'] as String? ?? '')],
      ].where((r) => (r[1] as String).isNotEmpty)
       .map((r) => [r[0] as String, r[1] as String])
       .toList();
      if (vpRows.isNotEmpty) {
        doc.addTable(vpRows, colWidths: [3000, 6355]);
      }
      doc.addSpacer();
    }

    // ── Section 4: Machinery & Equipment Particulars (if applicable) ──
    if (assembled.machinery.isNotEmpty) {
      doc.addHeading('MACHINERY & EQUIPMENT PARTICULARS', 2);
      final mRows = [
        ['Item', 'Make / Model', 'Serial No.', 'MCR'],
        ...assembled.machinery.map((m) {
          final kw  = (m['mcr_kw']  as num?)?.toStringAsFixed(0);
          final rpm = (m['mcr_rpm'] as num?)?.toStringAsFixed(0);
          final mcr = [if (kw != null) '$kw kW', if (rpm != null) '$rpm rpm']
              .join(' / ');
          return [
            '${m['machinery_type'] ?? ''}${m['role'] != null ? '\n${m['role']}' : ''}',
            '${m['make'] ?? ''} ${m['model'] ?? ''}'.trim(),
            m['serial_number'] as String? ?? '',
            mcr,
          ];
        }),
      ];
      doc.addTable(mRows, boldFirstRow: true, colWidths: [2500, 3000, 2000, 1855]);
      doc.addSpacer();
    }

    // ── Section 5: Class & Statutory Certification ────────────────────
    if (assembled.certificates.isNotEmpty) {
      doc.addHeading('CLASS & STATUTORY CERTIFICATES', 2);
      final certRows = [
        ['Certificate', 'Issuing Authority', 'Issue Date', 'Expiry'],
        ...assembled.certificates.map((c) => [
              c['cert_name'] as String? ?? c['cert_type'] as String? ?? '',
              c['issuing_authority'] as String? ?? '',
              _formatDate(c['issue_date']  as String? ?? ''),
              _formatDate(c['expiry_date'] as String? ?? ''),
            ]),
      ];
      doc.addTable(certRows, boldFirstRow: true,
          colWidths: [3000, 3000, 1500, 1855]);
      doc.addSpacer();
    }
    if (assembled.classConditions.isNotEmpty) {
      doc.addHeading('CONDITIONS OF CLASS', 2);
      final ccRows = [
        ['Reference', 'Description', 'Due Date'],
        ...assembled.classConditions.map((cc) => [
              cc['reference']   as String? ?? '',
              cc['description'] as String? ?? '',
              _formatDate(cc['expiry_date'] as String? ?? ''),
            ]),
      ];
      doc.addTable(ccRows, boldFirstRow: true, colWidths: [1800, 5700, 1855]);
      doc.addSpacer();
    }

    // ── Section 6: Available Information Sources ──────────────────────
    renderTextSection(SectionType.informationSources, 'AVAILABLE INFORMATION SOURCES');

    // ── Section 7: Chronology of Events ──────────────────────────────
    final timeline = assembled.timelineEvents;
    if (timeline.isNotEmpty) {
      doc.addHeading('CHRONOLOGY OF EVENTS', 2);
      final chronoRows = [
        ['Date', 'Event'],
        ...timeline.map((e) => [
              _formatDate(e['event_date'] as String? ?? ''),
              e['description'] as String? ?? e['title'] as String? ?? '',
            ]),
      ];
      doc.addTable(chronoRows, boldFirstRow: true, colWidths: [2000, 7355]);
      doc.addSpacer();
    }

    // ── Section 8: Background ─────────────────────────────────────────
    renderTextSection(SectionType.background, 'BACKGROUND');

    // ── Section 9: Damage Description ────────────────────────────────
    renderTextSection(SectionType.occurrence, 'OCCURRENCE');

    // Structured render (not the plain pre-built section text) so inline
    // photos can be embedded directly under the right claim object's
    // narrative — grouping mirrors report_provider.dart._buildDamageText.
    if (assembled.damageItems.isNotEmpty) {
      doc.addHeading('EXTENT OF DAMAGE', 2);
      final groups = <String, List<Map<String, dynamic>>>{};
      final groupLabels = <String, String>{};
      for (final d in assembled.damageItems) {
        final machineryId = d['machinery_id'] as String?;
        final componentName = d['component_name'] as String? ?? '';
        final key = machineryId ?? 'unlinked:$componentName';
        groups.putIfAbsent(key, () => []).add(d);
        groupLabels.putIfAbsent(key, () {
          if (machineryId == null) return componentName;
          final match = assembled.machinery
              .where((row) => row['machinery_id'] == machineryId)
              .firstOrNull;
          if (match == null) return componentName;
          final type = match['machinery_type'] as String? ?? '';
          final role = match['role'] as String? ?? '';
          return role.isNotEmpty ? '$type — $role' : type;
        });
      }

      for (final entry in groups.entries) {
        final label = groupLabels[entry.key] ?? '';
        if (label.isNotEmpty) {
          doc.addParagraph(
              'The $label was inspected. The following damage was observed:');
        }
        for (final d in entry.value) {
          final description = d['damage_description'] as String? ?? '';
          final conditionStatusRaw = d['condition_status'] as String?;
          final conditionFound = d['condition_found'] as String? ?? '';
          final line = StringBuffer('• ');
          line.write(description.isNotEmpty
              ? description
              : (d['component_name'] as String? ?? ''));
          if (conditionStatusRaw != null) {
            line.write(' (${ConditionStatus.fromValue(conditionStatusRaw).label})');
          } else if (conditionFound.isNotEmpty) {
            line.write(' ($conditionFound)');
          }
          doc.addParagraph(line.toString());

          final confirmedByRaw =
              (d['confirmed_by'] as List?)?.cast<String>() ?? const [];
          final nonSurveyorConfirmers = confirmedByRaw
              .map(ConfirmedByRole.fromValue)
              .where((r) => r != ConfirmedByRole.undersignedSurveyor)
              .toList();
          if (nonSurveyorConfirmers.isNotEmpty) {
            final who = nonSurveyorConfirmers.map((r) => r.label).join(', ');
            final componentName = d['component_name'] as String? ?? 'this item';
            final method = d['confirmation_method'] as String?;
            final date = d['confirmation_date'] as String?;
            final methodClause =
                method != null && method.isNotEmpty ? ' following $method' : '';
            final dateClause =
                date != null ? ' on ${_formatDate(date)}' : '';
            doc.addParagraph(
                'Damage to the $componentName was confirmed by '
                '$who$methodClause$dateClause.');
          }

          // Inline photos for this damage item (spec §7 placement mode).
          final damageId = d['damage_id'] as String?;
          final photos = <ResolvedPhoto>[
            if (damageId != null) ...?damagePhotosByItemId?[damageId],
          ];
          for (final photo in photos) {
            doc.addImage(photo.bytes, photo.ext,
                widthEmu: DocxBuilder.kPageWidthEmu ~/ 2);
          }
        }
        doc.addSpacer();
      }
    }

    if (assembled.damageItems.isNotEmpty) {
      doc.addHeading('DAMAGE SCHEDULE', 2);
      final dmgRows = [
        ['Component', 'Description', 'Condition', 'Average'],
        ...assembled.damageItems.map((d) {
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
            d['component_name']     as String? ?? '',
            d['damage_description'] as String? ?? '',
            conditionStatusRaw != null
                ? ConditionStatus.fromValue(conditionStatusRaw).label
                : '',
            averageLabel,
          ];
        }),
      ];
      doc.addTable(dmgRows, boldFirstRow: true,
          colWidths: [2500, 3200, 1700, 1455]);
      doc.addSpacer();
    }

    // ── Section 10: Cause Consideration ──────────────────────────────
    renderTextSection(SectionType.allegation, "OWNER'S ALLEGATION");
    renderTextSection(SectionType.causation,  'CAUSE CONSIDERATION');

    // ── Section 11: Repairs ───────────────────────────────────────────
    renderTextSection(SectionType.repairs, 'REPAIRS');
    final repairPeriodModels =
        assembled.repairPeriods.map(RepairPeriodModel.fromJson).toList();
    if (repairPeriodModels.isNotEmpty) {
      final repairRows = [
        ['Period', 'Location', 'Start', 'End', 'Drydock Days', 'Afloat Days'],
        ...repairPeriodModels.map((p) => [
              p.displayTitle,
              p.location ?? '',
              p.startDate != null ? _formatDate(p.startDate!.toIso8601String()) : '',
              p.endDate   != null ? _formatDate(p.endDate!.toIso8601String())   : '',
              p.drydockDaysTotal   > 0 ? p.drydockDaysTotal.toStringAsFixed(1)   : '',
              p.alongsideDaysTotal > 0 ? p.alongsideDaysTotal.toStringAsFixed(1) : '',
            ]),
      ];
      doc.addTable(repairRows, boldFirstRow: true,
          colWidths: [2500, 1900, 1000, 1000, 1200, 1455]);
      doc.addSpacer();
    }

    // ── Section 12: General Services & Access (optional) ─────────────
    renderTextSection(SectionType.generalServices, 'GENERAL SERVICES & ACCESS');

    // ── Section 13: Repair Costs ──────────────────────────────────────
    final docs = assembled.repairDocuments;

    // Clause G-1: cost estimate status — computed once, may render even
    // with no repair documents yet (e.g. "no invoices obtained" is
    // precisely the no-docs case).
    String? costText;
    final costStatus = assembled.caseData['cost_estimate_status'] as String?;
    if (costStatus != null) {
      final currency = assembled.caseData['base_currency'] as String? ?? '';
      final estimate =
          (assembled.caseData['estimated_repair_cost'] as num?)?.toString();
      String? fillCost(String clauseType) => assembled
          .clauseByType(clauseType)
          ?.clauseText
          .replaceAll('{CURRENCY_CODE}', currency)
          .replaceAll('{ESTIMATED_COST}', estimate ?? '');
      costText = switch (costStatus) {
        'no_invoices_yet' => estimate != null
            ? fillCost('cost_status_estimate_obtained')
            : fillCost('cost_status_estimate_not_obtained'),
        'ongoing_partial_invoices' => fillCost('cost_status_ongoing'),
        'completed_all_invoices'   => fillCost('cost_status_completed'),
        _ => null,
      };
    }

    if (docs.isNotEmpty) {
      doc.addHeading('REPAIR COSTS', 2);
      final wpCost = org?['wp_cost_section_text'] as String?
          ?? 'The following costs are presented without prejudice to '
             "Underwriters' rights and without admission of liability.";
      doc.addParagraph(wpCost,
          italic: true, halfPtSize: 18, colorHex: '6B7280');
      doc.addSpacer();

      if (costText != null && costText.isNotEmpty) {
        doc.addParagraph(costText);
        doc.addSpacer();
      }

      // Clause H-1: fixed approval statement, once for the whole section.
      final approvalIntro =
          assembled.clauseByType('account_approval_intro')?.clauseText;
      if (approvalIntro != null && approvalIntro.isNotEmpty) {
        doc.addParagraph(approvalIntro);
        doc.addSpacer();
      }

      final baseCurrency = assembled.caseData['base_currency'] as String? ?? '';
      double grandTotalBase  = 0;
      double grandTotalUw    = 0;
      double grandTotalOwner = 0;

      bool isOwnersLine(Map<String, dynamic> l) =>
          l['cost_nature'] == 'owners_maintenance' ||
          l['cost_nature'] == 'class_statutory';

      for (final repDoc in docs) {
        final docName   = repDoc['display_name']    as String?
            ?? repDoc['supplier_name'] as String? ?? 'Invoice';
        final docNumber = repDoc['document_number'] as String? ?? '';
        final docDate   = _formatDate(repDoc['document_date'] as String? ?? '');
        final currency  = repDoc['currency'] as String? ?? '';

        doc.addParagraph(
          [docName, if (docNumber.isNotEmpty) '#$docNumber',
                    if (docDate.isNotEmpty)   docDate].join('  ·  '),
          bold: true, halfPtSize: 22,
        );

        // Clause H-2: per-invoice intro, using the AI-extracted description
        // already captured in presentation_statement during account import.
        final invoiceDescription = repDoc['presentation_statement'] as String?;
        if (invoiceDescription != null && invoiceDescription.isNotEmpty) {
          final h2Template =
              assembled.clauseByType('account_line_intro')?.clauseText;
          final h2Text = h2Template
              ?.replaceAll('{INVOICE_DESCRIPTION}', invoiceDescription);
          if (h2Text != null && h2Text.isNotEmpty) {
            doc.addParagraph(h2Text, italic: true,
                halfPtSize: 18, colorHex: '374151');
            doc.addSpacer();
          }
        }

        final lines = (repDoc['account_lines'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        double docTotalUw = 0;
        if (lines.isNotEmpty) {
          final lineRows = [
            ['#', 'Description', 'Nature', 'Amount ($currency)', 'Allocation'],
            ...lines.asMap().entries.map((e) {
              final l       = e.value;
              final gross   = (l['gross_amount']         as num?)?.toDouble() ?? 0;
              final uwPart  = (l['underwriters_portion'] as num?)?.toDouble() ?? gross;
              final ownPart = (l['owners_portion']       as num?)?.toDouble() ?? 0;
              final fxRate  = (l['fx_rate_to_base']      as num?)?.toDouble() ?? 1.0;
              grandTotalUw    += uwPart  * fxRate;
              grandTotalOwner += ownPart * fxRate;
              grandTotalBase  += gross   * fxRate;
              docTotalUw      += uwPart;
              return [
                '${l['item_number'] as int? ?? e.key + 1}',
                l['description']      as String? ?? '',
                l['cost_nature']      as String? ?? '',
                _fmtAmt(gross),
                l['apportionment_type'] as String? ?? "Underwriters'",
              ];
            }),
          ];
          doc.addTable(lineRows, boldFirstRow: true,
              colWidths: [400, 3600, 1500, 1500, 1855]);
          doc.addSpacer();
        }

        // Clause H-3: account assessment outcome (mutually exclusive).
        final allOwners  = lines.isNotEmpty && lines.every(isOwnersLine);
        final someOwners = !allOwners && lines.any(isOwnersLine);
        final docStatus  = repDoc['surveyor_status'] as String?;
        String? h3ClauseType;
        if (allOwners) {
          h3ClauseType = 'account_owners_only';
        } else if (docStatus == 'approved') {
          h3ClauseType = 'account_approved_full';
        } else if (docStatus == 'partly_approved') {
          h3ClauseType = someOwners
              ? 'account_split_partial'
              : 'account_approved_subject_to_deductions';
        } else if (docStatus == 'queried') {
          h3ClauseType = 'account_queried';
        }
        if (h3ClauseType != null) {
          final h3Text = assembled.clauseByType(h3ClauseType)?.clauseText;
          if (h3Text != null && h3Text.isNotEmpty) {
            doc.addParagraph(h3Text, italic: true,
                halfPtSize: 18, colorHex: '374151');
            doc.addSpacer();
          }
        }

        // Clause H-4: owner's-maintenance deduction lines called out
        // separately, for accounts that mix casualty and owner's-account
        // items (not the fully-owner's-account case, handled by H-3 above).
        if (someOwners) {
          final deductionIntro =
              assembled.clauseByType('owners_maintenance_deduction_intro')
                  ?.clauseText;
          if (deductionIntro != null && deductionIntro.isNotEmpty) {
            doc.addParagraph(deductionIntro, italic: true,
                halfPtSize: 18, colorHex: '374151');
            final deductionRows = [
              ['Item', 'Description', 'Amount'],
              ...lines.where(isOwnersLine).map((l) => [
                    '${l['item_number'] ?? ''}',
                    l['description'] as String? ?? '',
                    _fmtAmt((l['gross_amount'] as num?)?.toDouble() ?? 0),
                  ]),
            ];
            doc.addTable(deductionRows, boldFirstRow: true,
                colWidths: [800, 5555, 3000]);
            doc.addSpacer();
          }
        }

        // Clause H-6: general services / dry-docking cost attribution note.
        if (repDoc['supplier_category'] == 'dry_dock_operator') {
          final h6Text =
              assembled.clauseByType('general_services_attribution')
                  ?.clauseText;
          if (h6Text != null && h6Text.isNotEmpty) {
            doc.addParagraph(h6Text, italic: true,
                halfPtSize: 18, colorHex: '374151');
            doc.addSpacer();
          }
        }

        // Clause H-5: Sum Approved Without Prejudice — mandatory per
        // approval block unless the document is explicitly marked
        // otherwise (without_prejudice defaults true).
        if ((repDoc['without_prejudice'] as bool? ?? true) &&
            lines.isNotEmpty && docTotalUw > 0.005) {
          doc.addParagraph(
              'Sum Approved Without Prejudice: $currency ${_fmtAmt(docTotalUw)}',
              bold: true, halfPtSize: 20);
          doc.addSpacer();
        }
      }

      final totalsRows = <List<String>>[
        ['', ''],
        if (grandTotalUw > 0.005)
          ["Underwriters' account", _fmtAmt(grandTotalUw)],
        if (grandTotalOwner > 0.005)
          ["Owner's account",       _fmtAmt(grandTotalOwner)],
        if (grandTotalBase > 0.005 && baseCurrency.isNotEmpty)
          ['Grand total ($baseCurrency)', _fmtAmt(grandTotalBase)],
      ].where((r) => r[0].isNotEmpty).toList();
      if (totalsRows.isNotEmpty) {
        doc.addTable(totalsRows, colWidths: [6355, 3000]);
      }
      doc.addSpacer();
    } else {
      final wpCost = org?['wp_cost_section_text'] as String?;
      if ((wpCost != null && wpCost.isNotEmpty) ||
          (costText != null && costText.isNotEmpty)) {
        doc.addHeading('REPAIR COSTS', 2);
      }
      if (wpCost != null && wpCost.isNotEmpty) {
        doc.addParagraph(wpCost,
            italic: true, halfPtSize: 18, colorHex: '6B7280');
        doc.addSpacer();
      }
      if (costText != null && costText.isNotEmpty) {
        doc.addParagraph(costText);
        doc.addSpacer();
      }
    }

    // ── Section 14: Repair Times ──────────────────────────────────────
    if (repairPeriodModels.isNotEmpty) {
      final hasTime = repairPeriodModels.any((p) =>
          p.drydockDaysTotal > 0 || p.alongsideDaysTotal > 0 || p.ownerDaysTotal > 0);
      if (hasTime) {
        doc.addHeading('REPAIR TIMES', 2);
        // Clause I-1: fixed guidance statement ahead of the times table.
        final guidance =
            assembled.clauseByType('repair_times_guidance')?.clauseText;
        if (guidance != null && guidance.isNotEmpty) {
          doc.addParagraph(guidance);
          doc.addSpacer();
        }
        final rtRows = [
          ['Repair', 'Drydock Days', 'Afloat Days', "Owner's Days", 'Total'],
          ...repairPeriodModels.map((p) {
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
        doc.addTable(rtRows, boldFirstRow: true,
            colWidths: [3200, 1200, 1200, 1200, 1555]);
        doc.addSpacer();
      }
    }

    // ── Section 15: Surveyor's Notes (optional) ───────────────────────
    if (assembled.surveyorNotes.isNotEmpty) {
      doc.addHeading("SURVEYOR'S NOTES", 2);
      for (final note in assembled.surveyorNotes) {
        final tag     = note['section_tag'] as String?;
        final content = note['content']     as String? ?? '';
        if (tag != null && tag.isNotEmpty) {
          doc.addParagraph(tag.toUpperCase(),
              bold: true, halfPtSize: 18, colorHex: '374151');
        }
        doc.addParagraph(content);
      }
      doc.addSpacer();
    }

    // ── Section 16: Documents Retained on File ────────────────────────
    if (assembled.caseDocuments.isNotEmpty) {
      doc.addHeading('DOCUMENTS RETAINED ON FILE', 2);
      // Clause K-1: fixed lead-in sentence ahead of the documents table.
      final docsHeader =
          assembled.clauseByType('documents_on_file_header')?.clauseText;
      if (docsHeader != null && docsHeader.isNotEmpty) {
        doc.addParagraph(docsHeader);
        doc.addSpacer();
      }
      final docRows = [
        ['#', 'Document', 'Category', 'Date'],
        ...assembled.caseDocuments.asMap().entries.map((e) => [
              '${e.key + 1}',
              e.value['title']        as String? ?? '',
              (e.value['doc_category'] as String? ?? '').replaceAll('_', ' '),
              _formatDate(e.value['doc_date'] as String? ?? ''),
            ]),
      ];
      doc.addTable(docRows, boldFirstRow: true,
          colWidths: [400, 5200, 2000, 1755]);
      doc.addSpacer();
    }

    // ── Section 17: Documents Requested / Outstanding ─────────────────
    renderTextSection(SectionType.documentsRequested, 'DOCUMENTS REQUESTED');

    // ── Section 19: Waiver / Limitation of Liability ──────────────────
    final waiverSection = sections[SectionType.waiver];
    final waiverContent = waiverSection?.content
        ?? org?['waiver_text'] as String? ?? '';
    if (waiverContent.isNotEmpty) {
      doc.addHeading('WAIVER', 2);
      doc.addParagraph(waiverContent,
          italic: true, halfPtSize: 18, colorHex: '374151');
      doc.addSpacer();
    }

    // Closing disclaimer (Clause J-1) — content already resolves org
    // override → clause_library → hardcoded fallback in report_provider.dart.
    renderTextSection(SectionType.closing, 'DISCLAIMER');

    // ── Sign-off authentication block (Final reports only) ───────────
    if (output.outputType == OutputType.final_) {
      final caseData = assembled.caseData;
      String? fmtSignDate(String? iso) {
        if (iso == null) return null;
        final dt = DateTime.tryParse(iso);
        if (dt == null) return null;
        const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${dt.day.toString().padLeft(2, '0')} '
            '${months[dt.month]} ${dt.year}';
      }
      doc.addSpacer();
      doc.addHeading('AUTHENTICATION', 2);
      doc.addSignOffBlock(
        attendingName: caseData['signed_off_attending_name'] as String?,
        attendingDate: fmtSignDate(caseData['signed_off_attending_at'] as String?),
        reviewingName: caseData['signed_off_reviewing_name'] as String?,
        reviewingDate: fmtSignDate(caseData['signed_off_reviewing_at'] as String?),
      );
      doc.addSpacer();
    }

    // ── Annexures A–H (documents grouped by annexure_assignment) ─────
    final annexured = assembled.caseDocuments.where((d) {
      final a = d['annexure_assignment'] as String?;
      return a != null && a.isNotEmpty;
    }).toList();
    if (annexured.isNotEmpty) {
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final d in annexured) {
        final letter = (d['annexure_assignment'] as String).toUpperCase().trim();
        grouped.putIfAbsent(letter, () => []).add(d);
      }
      for (final letter in (grouped.keys.toList()..sort())) {
        if (letter == 'I') continue; // Reserved for AI generation record
        doc.addPageBreak();
        doc.addHeading('ANNEXURE $letter', 1);
        for (final d in grouped[letter]!) {
          final title = d['title'] as String? ?? 'Untitled';
          final date  = _formatDate(d['doc_date'] as String? ?? '');
          doc.addParagraph(date.isNotEmpty ? '$title  —  $date' : title);
        }
        doc.addSpacer();
        doc.addParagraph('[See attached document(s)]',
            italic: true, colorHex: '9CA3AF', halfPtSize: 18);
      }
    }

    // ── Annexure I — AI Generation Record ────────────────────────────
    if (assembled.aiGenerationLog.isNotEmpty) {
      doc.addPageBreak();
      doc.addHeading('ANNEXURE I — AI GENERATION RECORD', 1);
      doc.addParagraph(
        'The following table records all artificial intelligence model calls '
        'made in the preparation of this report, in compliance with the '
        'Federal Court of Australia Practice Note GPN-AI (2026).',
        halfPtSize: 18, colorHex: '374151',
      );
      doc.addSpacer();
      final aiRows = <List<String>>[
        ['#', 'Date', 'Type', 'Section', 'Model', 'Tokens', 'Reviewed'],
        ...assembled.aiGenerationLog.asMap().entries.map((e) {
          final log     = e.value;
          final date    = log.createdAt != null
              ? _formatDate(log.createdAt!.toIso8601String()) : '—';
          final tokens  = (log.inputTokens != null && log.outputTokens != null)
              ? '${log.inputTokens}/${log.outputTokens}' : '—';
          final reviewed = log.humanReviewed
              ? (log.humanEdited ? 'Amended' : 'Accepted') : 'Pending';
          return [
            '${e.key + 1}', date,
            log.callType.replaceAll('_', ' '),
            log.sectionLabel?.replaceAll('_', ' ') ?? '—',
            log.model, tokens, reviewed,
          ];
        }),
      ];
      doc.addTable(aiRows, boldFirstRow: true,
          colWidths: [300, 900, 1200, 1500, 1500, 800, 1155]);
    }

    return doc.build();

  }

  // ── Delivery ──────────────────────────────────────────────────────────────

  static Future<String> _deliver({
    required Uint8List bytes,
    required String filename,
  }) async {
    await deliverDocx(bytes, filename);
    return filename;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _filename(ReportOutput output, AssembledReportData assembled) {
    final jobNo  = assembled.caseData['technical_file_no'] as String? ?? 'UNKNOWN';
    final vessel = (assembled.vessel?['name'] as String? ?? 'VESSEL')
        .replaceAll(' ', '_')
        .toUpperCase();
    final type = switch (output.outputType) {
      OutputType.preliminary => 'Prelim',
      OutputType.advice      => 'Advice${output.sequenceNo}',
      OutputType.final_      => 'Final',
    };
    final d = DateTime.now();
    final ds = '${d.day.toString().padLeft(2, '0')}'
        '${d.month.toString().padLeft(2, '0')}${d.year}';
    return '${jobNo}_${vessel}_${type}_$ds.docx';
  }

  static String _today() {
    final d = DateTime.now();
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day.toString().padLeft(2, '0')}-${m[d.month]}-${d.year}';
  }

  static String _fmtAmt(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final integral = parts[0].replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '$integral.${parts[1]}';
  }

  static String _costNatureLabel(String? value) => switch (value) {
        'repair'              => 'Repair',
        'owners_maintenance'  => "Owner's",
        'class_statutory'     => 'Class/Stat.',
        'betterment'          => 'Betterment',
        'sue_labour'          => 'Sue & Labour',
        'general_average'     => 'GA',
        _                     => value ?? '',
      };

  static String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day.toString().padLeft(2, '0')}-${m[d.month]}-${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
