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
import '../utils/advice_summary_rows.dart';
import '../utils/annexure_groups.dart';
import '../utils/section_table_rows.dart';
import '../utils/page2_legal_text.dart';
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
    Map<String, List<ResolvedPhoto>>? machineryPhotosByItemId,
    Map<String, ResolvedPhoto>? annexurePhotosById,
  }) async {
    // Fetch org logo from Supabase Storage (non-fatal). The primary (element 0)
    // of the multi-logo array is embedded, falling back to the legacy single
    // `logo_storage_path` column. NB: the DB column is `logo_storage_path(s)`,
    // not `logo_path` — reading the wrong key here previously meant the logo
    // never actually embedded.
    Uint8List? logoBytes;
    String logoExt = 'png';
    final logoPaths = (assembled.organisation?['logo_storage_paths'] as List?)
        ?.cast<String>();
    final logoPath = (logoPaths != null && logoPaths.isNotEmpty)
        ? logoPaths.first
        : assembled.organisation?['logo_storage_path'] as String?;
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

    // Fetch surveyor signature image from Supabase Storage (non-fatal — the
    // signature upload flow isn't built yet, so this path is null on every
    // case today; the sign-off block falls back to a text placeholder).
    Uint8List? signatureBytes;
    String signatureExt = 'png';
    final signOff = buildReportSignOff(assembled.organisation);
    final signaturePath = signOff.signatureStoragePath;
    if (signaturePath != null && signaturePath.isNotEmpty) {
      try {
        final parts = signaturePath.split('.');
        if (parts.length > 1) signatureExt = parts.last.toLowerCase();
        signatureBytes = await SupabaseService.client.storage
            .from('organisation_assets')
            .download(signaturePath);
      } catch (e) {
        debugPrint('Signature fetch skipped: $e');
      }
    }

    final bytes = _buildDocx(output, assembled, sections,
        coverPhotoBytes: coverPhotoBytes, coverPhotoExt: coverPhotoExt,
        coverPhotoWidthEmu: coverPhotoWidthEmu,
        coverPhotoHeightEmu: coverPhotoHeightEmu,
        logoBytes: logoBytes, logoExt: logoExt,
        signatureBytes: signatureBytes, signatureExt: signatureExt,
        damagePhotosByItemId: damagePhotosByItemId,
        machineryPhotosByItemId: machineryPhotosByItemId,
        annexurePhotosById: annexurePhotosById);
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
    Uint8List? signatureBytes,
    String signatureExt = 'png',
    Map<String, List<ResolvedPhoto>>? damagePhotosByItemId,
    Map<String, List<ResolvedPhoto>>? machineryPhotosByItemId,
    Map<String, ResolvedPhoto>? annexurePhotosById,
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
    final occDate   = _formatDate(occFirst['date_time'] as String? ?? '');
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
      // fullContent seamlessly joins any carried-forward prior-report text
      // with this report's new delta (spec gap #10 — "no visible breaks"
      // in the rendered output); equals plain .content when there's
      // nothing carried forward.
      if (section == null || section.fullContent.trim().isEmpty) return;
      doc.addHeading(heading, 2);
      for (final para in splitSectionParagraphs(section.fullContent)) {
        doc.addParagraph(para);
      }
      doc.addSpacer();
    }

    // §2.18: Remarks is the only free-text field left on autoPopulatedSection
    // Types (Vessel Particulars, Attendees, Machinery Particulars, Accounts,
    // Repair Times, Documents on File) — rendered as a labeled paragraph
    // right after that section's table, omitted entirely when empty.
    void renderRemarks(SectionType type) {
      final remarks = sections[type]?.remarks?.trim();
      if (remarks == null || remarks.isEmpty) return;
      doc.addParagraph('Remarks: $remarks', italic: true);
      doc.addSpacer();
    }

    // ── Page 2: title block → Advice Summary → Legal Designations → AI
    // Declaration → Document Control ─────────────────────────────────
    // Per surveyor direction (4 July 2026): the title block renders as an
    // actual table (matching the spec's suggested-layout ASCII, which
    // draws it as a bordered box), and Legal Designations / AI Usage
    // Declaration sit after the Advice Summary table rather than before it
    // — still the same page, just reordered. The Advice Summary table
    // itself *is* the Executive Summary (the spec section is literally
    // titled "Section: Executive Summary (Advice Summary Table)") — there
    // is no separate free-text narrative block.

    // Title block — Vessel Name / Assured / Report Type, "continues from
    // cover" — as a single bordered, centred table cell (tabular per
    // spec's suggested-layout ASCII, which draws this as one boxed block).
    final assuredName = case_['assured'] as String?;
    final titleLines = [
      if (vesselName.isNotEmpty) 'M.V.  "$vesselName"',
      if (assuredName != null && assuredName.isNotEmpty) 'ASSURED: $assuredName',
      '${reportTypeLabel.toUpperCase()} SUMMARY',
    ];
    doc.addTable([[titleLines.join('\n')]],
        colWidths: [9355], cellAlign: WAlignment.center);
    doc.addSpacer();

    // (c) Advice Summary — structured table (spec: "Section: Executive
    // Summary (Advice Summary Table)" in docs/report_builder_editor_notes.md).
    // Row-building logic is shared with the Preview tab — see
    // advice_summary_rows.dart (avoids the renderer-drift class of bug
    // described in gap #5 of docs/report_builder_editor_notes.md).
    {
      final adviceRows = buildAdviceSummaryRows(output, assembled);
      if (adviceRows.isNotEmpty) {
        doc.addHeading('ADVICE SUMMARY', 2);
        doc.addTable(adviceRows, colWidths: [3000, 6355]);
        doc.addSpacer();
      }
    }

    // (a) Legal Designations — verbatim locked clauses.
    final legal = buildLegalDesignationLines(assembled);
    doc.addHeading('LEGAL DESIGNATIONS', 2);
    doc.addParagraph(legal.withoutPrejudice,
        bold: true, halfPtSize: 18, colorHex: '374151');
    doc.addSpacer();
    doc.addParagraph(legal.confidentiality, halfPtSize: 18, colorHex: '374151');
    doc.addSpacer();
    doc.addParagraph(legal.copyright, halfPtSize: 18, colorHex: '374151');
    doc.addSpacer();

    // (b) AI Usage Declaration — auto-generated, suppressed entirely when
    // no AI calls are on record (no surveyor toggle, per spec).
    final aiDisclosure = buildAiUsageDeclaration(assembled.aiGenerationLog);
    if (aiDisclosure != null) {
      doc.addHeading('AI USAGE DECLARATION', 2);
      doc.addParagraph(aiDisclosure,
          italic: true, halfPtSize: 18, colorHex: '374151');
      doc.addSpacer();
    }

    // Version-supersedes narrative statement (§2.5) — precedes the Document
    // Control table, since it's the prose companion to that table's
    // `Supersedes` column, not a substitute for it.
    final supersedesStatement = buildVersionSupersedesStatement(output);
    if (supersedesStatement != null) {
      doc.addParagraph(supersedesStatement, bold: true, halfPtSize: 20);
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
    // Spec §1 suggested layout — "Occurrence No. 1 | [date] | [title]"
    // table under the certifying paragraph. Supports multi-occurrence
    // cases (previously only ever `occurrences.first` was rendered
    // anywhere in this file).
    final occRows = buildOccurrenceRows(assembled.occurrences);
    if (occRows.isNotEmpty) {
      doc.addTable(occRows, boldFirstRow: true, colWidths: [2500, 2000, 4855]);
      doc.addSpacer();
    }

    // ── Section 2: Attending Representatives ─────────────────────────
    // One block per attendance (spec §2), each with its own intro line,
    // date/location/purpose, and attendee register. Block-building shared
    // with the Preview tab — see section_table_rows.dart (avoids the
    // renderer-drift class of bug described in gap #5/#11 of
    // docs/report_builder_editor_notes.md).
    final attendanceBlocks =
        buildAttendanceBlocks(assembled.attendances, assembled.attendees);
    if (attendanceBlocks.isNotEmpty) {
      doc.addHeading('ATTENDANCE & REPRESENTATIVES', 2);
      for (final block in attendanceBlocks) {
        if (block.label.isNotEmpty) {
          doc.addParagraph(block.label, bold: true);
        }
        doc.addParagraph(block.introLine, italic: true);
        final details = [
          if ((block.date ?? '').isNotEmpty) 'Date: ${block.date}',
          if ((block.location ?? '').isNotEmpty) 'Location: ${block.location}',
          if ((block.purpose ?? '').isNotEmpty) 'Purpose: ${block.purpose}',
        ];
        for (final line in details) {
          doc.addParagraph(line);
        }
        doc.addTable(block.rows, boldFirstRow: true,
            colWidths: [3100, 3100, 3155]);
        doc.addSpacer();
      }
      renderRemarks(SectionType.attendees);
    }

    // ── Section 3: Vessel Particulars ────────────────────────────────
    final vpRows = buildVesselParticularsRows(v);
    if (vpRows.isNotEmpty) {
      doc.addHeading('VESSEL PARTICULARS', 2);
      doc.addTable(vpRows, colWidths: [3000, 6355]);
      doc.addSpacer();
      renderRemarks(SectionType.vesselParticulars);
    }

    // ── Section 4: Machinery & Equipment Particulars (if applicable) ──
    // Spec §5 suggested layout — one bordered key:value block per claim
    // object, "Not Confirmed" placeholder for any field not yet captured
    // (never left blank). Shared with the Preview tab via
    // section_table_rows.dart (gap #11 convention).
    final machineryBlocks = buildMachineryBlocks(assembled.machinery);
    if (machineryBlocks.isNotEmpty) {
      doc.addHeading('MACHINERY & EQUIPMENT PARTICULARS', 2);
      for (var i = 0; i < machineryBlocks.length; i++) {
        final block = machineryBlocks[i];
        doc.addParagraph(block.label, bold: true, halfPtSize: 20);
        doc.addTable(block.rows, colWidths: [3000, 6355]);
        // Nameplate photo (TODO.md §1.8 S4), if one's been attached and
        // resolved by the caller — same convention as damagePhotosByItemId.
        final machineryId = assembled.machinery[i]['machinery_id'] as String?;
        final nameplatePhotos = <ResolvedPhoto>[
          if (machineryId != null) ...?machineryPhotosByItemId?[machineryId],
        ];
        for (final photo in nameplatePhotos) {
          doc.addImage(photo.bytes, photo.ext,
              widthEmu: DocxBuilder.kPageWidthEmu ~/ 2);
        }
        doc.addSpacer();
      }
      renderRemarks(SectionType.machineryParticulars);
    }

    // ── Section 5: Class & Statutory Certification ────────────────────
    // Narrative clause text (clauses C-6a/b/c/e/f, built in report_provider's
    // sectionDraftProvider) was previously never rendered here at all — the
    // surveyor could review/approve it in the editor but it silently never
    // reached the exported docx. Fixed: render it as the section's lead-in
    // text, ahead of the certificates/conditions-of-class tables below.
    final classStatutorySection = sections[SectionType.classStatutory];
    final hasClassStatutoryText =
        classStatutorySection != null && classStatutorySection.content.trim().isNotEmpty;
    final certRows = buildCertificateRows(assembled.certificates);
    final ccRows = buildClassConditionRows(assembled.classConditions);
    if (hasClassStatutoryText || certRows.isNotEmpty || ccRows.isNotEmpty) {
      doc.addHeading('CLASS & STATUTORY CERTIFICATION', 2);
    }
    if (hasClassStatutoryText) {
      for (final para in splitSectionParagraphs(classStatutorySection.content)) {
        doc.addParagraph(para);
      }
      doc.addSpacer();
    }
    if (certRows.isNotEmpty) {
      doc.addTable(certRows, boldFirstRow: true,
          colWidths: [3000, 3000, 1500, 1855]);
      doc.addSpacer();
    }
    if (ccRows.isNotEmpty) {
      doc.addHeading('CONDITIONS OF CLASS', 2);
      doc.addTable(ccRows, boldFirstRow: true, colWidths: [1800, 5700, 1855]);
      doc.addSpacer();
    }

    // ── Section 6: Available Information Sources ──────────────────────
    // TODO.md §1.8 S6 (8 July 2026 review): this used to render the same
    // document list twice — a free-text bullet list AND this table. Fixed
    // at the source in _buildInfoSourcesText (report_provider.dart), which
    // now returns a short intro sentence instead of the bullet dump, so
    // both this and the Preview tab (report_preview.dart, same content
    // field) show one sentence + the table, not a duplicated list.
    renderTextSection(SectionType.informationSources, 'AVAILABLE INFORMATION SOURCES');
    final availInfoRows = buildAvailableInformationRows(
        assembled.caseDocuments, assembled.requestedDocuments);
    if (availInfoRows.isNotEmpty) {
      doc.addTable(availInfoRows, boldFirstRow: true, colWidths: [6355, 3000]);
      doc.addSpacer();
    }

    // ── Section 7: Chronology of Events ──────────────────────────────
    final chronoRows = buildChronologyRows(assembled.timelineEvents);
    if (chronoRows.isNotEmpty) {
      doc.addHeading('CHRONOLOGY OF EVENTS', 2);
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

    // Row-building shared with the Preview tab / Editor reference panel —
    // see buildDamageScheduleRows (section_table_rows.dart).
    final dmgRows = buildDamageScheduleRows(assembled.damageItems);
    if (dmgRows.isNotEmpty) {
      doc.addHeading('DAMAGE SCHEDULE', 2);
      doc.addTable(dmgRows, boldFirstRow: true,
          colWidths: [2500, 3200, 1700, 1455]);
      doc.addSpacer();
    }

    // ── Section 10: Cause Consideration ──────────────────────────────
    renderTextSection(SectionType.allegation, "OWNER'S ALLEGATION");
    renderTextSection(SectionType.causation,  'CAUSE CONSIDERATION');
    // Spec §10 — third-party findings register + certainty level, shown
    // alongside (not replacing) the free-text narrative so the three-voice
    // separation is visible as structured data without constraining the
    // surveyor's ability to edit the generated prose.
    final tpRows = buildThirdPartyFindingRows(assembled.occurrences);
    if (tpRows.isNotEmpty) {
      doc.addParagraph('Third-Party Findings', bold: true, halfPtSize: 20);
      doc.addTable(tpRows, boldFirstRow: true, colWidths: [2000, 2500, 4855]);
      doc.addSpacer();
    }
    final certaintyLabel = buildCertaintyLevelLabel(assembled.occurrences);
    if (certaintyLabel != null) {
      doc.addParagraph('Certainty Level: $certaintyLabel', italic: true,
          halfPtSize: 18, colorHex: '6B7280');
      doc.addSpacer();
    }

    // ── Section 11.1: Nature of the Repairs ───────────────────────────
    renderTextSection(SectionType.natureOfRepairs, 'NATURE OF THE REPAIRS');

    // ── Section 11.2: Repairs ───────────────────────────────────────────
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

    // ── Section 8.6: Work Not Concerning Average ──────────────────────
    // Fixed, locked opening clause (spec verbatim) — not AI-generated,
    // not editable. Populated from context cues tagged
    // CaseSection.notAverage (docs/context_cue_system_review.md §3.1).
    final wncaItems = buildWncaItems(assembled.surveyorNotes);
    if (wncaItems.isNotEmpty) {
      doc.addHeading('WORK NOT CONCERNING AVERAGE', 2);
      doc.addParagraph(wncaOpeningClause);
      for (final item in wncaItems) {
        doc.addParagraph('•  $item');
      }
      doc.addSpacer();
    }

    // ── Section 12: General Services & Access (optional) ─────────────
    renderTextSection(SectionType.generalServices, 'GENERAL SERVICES & ACCESS');

    // ── Section 12.4: Previous Work on the Damaged Item (optional) ────
    renderTextSection(SectionType.previousWorks, 'PREVIOUS WORK ON THE DAMAGED ITEM');

    // ── Section 12.5: Extra Expenses to Reduce Delay (optional) ───────
    renderTextSection(SectionType.extraExpenses, 'EXTRA EXPENSES TO REDUCE DELAY');

    // ── Section 12.6: Contractual / Hire (optional) ───────────────────
    renderTextSection(SectionType.contractualHire, 'CONTRACTUAL / HIRE');

    // ── Section 12.7: Other Matters of Relevance (optional) ───────────
    renderTextSection(SectionType.otherMatters, 'OTHER MATTERS OF RELEVANCE');

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
    renderRemarks(SectionType.accounts);

    // ── Section 14: Repair Times ──────────────────────────────────────
    // Row-building shared with the Preview tab / Editor reference panel —
    // see buildRepairTimesRows (section_table_rows.dart).
    final rtRows = buildRepairTimesRows(assembled.repairPeriods);
    if (rtRows.isNotEmpty) {
      doc.addHeading('REPAIR TIMES', 2);
      // Clause I-1: fixed guidance statement ahead of the times table.
      final guidance =
          assembled.clauseByType('repair_times_guidance')?.clauseText;
      if (guidance != null && guidance.isNotEmpty) {
        doc.addParagraph(guidance);
        doc.addSpacer();
      }
      doc.addTable(rtRows, boldFirstRow: true,
          colWidths: [3200, 1200, 1200, 1200, 1555]);
      doc.addSpacer();
      renderRemarks(SectionType.repairTimes);
    }

    // ── Section 15: Advice to Assured (optional) ───────────────────────
    // Was previously an independent raw dump of every surveyor_notes row
    // regardless of tag, completely disconnected from `sections[SectionType.
    // surveyorNotes]`'s own content (which was built but never actually
    // rendered anywhere in docx — a real Preview/docx drift bug found
    // while wiring the 4 July 2026 legal-clause ticklist). Now goes
    // through the same shared renderTextSection() as every other section,
    // so it's correctly omitted when no clauses are ticked. Retitled from
    // "Other Matters of Relevance" to "Advice to Assured" (5 July 2026)
    // when that section split — see SectionType.otherMatters above for
    // the cue-drafted narrative that now carries the old name.
    renderTextSection(SectionType.surveyorNotes, 'ADVICE TO ASSURED');

    // ── Section 16: Documents Retained on File ────────────────────────
    // Row-building shared with the Preview tab / Editor reference panel —
    // see buildDocumentsOnFileRows (section_table_rows.dart).
    final docRows = buildDocumentsOnFileRows(assembled.caseDocuments);
    if (docRows.isNotEmpty) {
      doc.addHeading('DOCUMENTS RETAINED ON FILE', 2);
      // Clause K-1: fixed lead-in sentence ahead of the documents table.
      final docsHeader =
          assembled.clauseByType('documents_on_file_header')?.clauseText;
      if (docsHeader != null && docsHeader.isNotEmpty) {
        doc.addParagraph(docsHeader);
        doc.addSpacer();
      }
      doc.addTable(docRows, boldFirstRow: true,
          colWidths: [400, 5200, 2000, 1755]);
      doc.addSpacer();
      renderRemarks(SectionType.documentsOnFile);
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

    // ── Section 13 sign-off block (spec §13 — every report type) ──────
    // "Yours faithfully" + surveyor identity, distinct from the internal
    // attending/reviewing QC authentication block below. TODO.md row 73
    // (9 July 2026): moved to immediately after Waiver — the Disclaimer
    // (below) now follows the full sign-off, at the very bottom of the
    // document on the same page, rather than sitting between Waiver and
    // the signature block.
    {
      final signOff = buildReportSignOff(assembled.organisation);
      final city = org?['firm_city'] as String? ?? '[City]';
      doc.addParagraph('$city, ${_today()}');
      doc.addSpacer();
      doc.addParagraph('Yours faithfully');
      doc.addSpacer();
      if (signatureBytes != null) {
        doc.addImage(signatureBytes, signatureExt,
            widthEmu: DocxBuilder.kPageWidthEmu ~/ 3);
      } else {
        doc.addParagraph('[Signature not yet uploaded]',
            italic: true, colorHex: '9CA3AF', halfPtSize: 18);
      }
      doc.addParagraph(signOff.name, bold: true);
      if ((signOff.title ?? '').isNotEmpty) doc.addParagraph(signOff.title!);
      if ((signOff.company ?? '').isNotEmpty) doc.addParagraph(signOff.company!);
      if ((signOff.mobile ?? '').isNotEmpty) doc.addParagraph('Mob: ${signOff.mobile}');
      if ((signOff.email ?? '').isNotEmpty) doc.addParagraph('E: ${signOff.email}');
      if ((signOff.website ?? '').isNotEmpty) doc.addParagraph('W: ${signOff.website}');
      doc.addSpacer();
    }

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

    // Closing disclaimer (Clause J-1) — content already resolves org
    // override → clause_library → hardcoded fallback in report_provider.dart.
    // TODO.md row 73 (9 July 2026): moved to after the full sign-off block
    // — always the very last body content, same page as sign-off, ahead
    // of only the annexures.
    renderTextSection(SectionType.closing, 'DISCLAIMER');

    // ── Annexures A–H (documents grouped by annexure_assignment) ─────
    for (final group in buildAnnexureGroups(assembled.caseDocuments)) {
      doc.addPageBreak();
      doc.addHeading('ANNEXURE ${group.key}', 1);
      for (final d in group.value) {
        final title = d['title'] as String? ?? 'Untitled';
        final date  = _formatDate(d['doc_date'] as String? ?? '');
        doc.addParagraph(date.isNotEmpty ? '$title  —  $date' : title);
      }
      doc.addSpacer();
      doc.addParagraph('[See attached document(s)]',
          italic: true, colorHex: '9CA3AF', halfPtSize: 18);
    }

    // ── Annexure E — Photographs (§2.4, spec §4.8) ───────────────────
    // Opens with a register table (Photo No. | Location/Component |
    // Direction/Context | Date | Significance), then each photo full-size
    // with a caption composed from the same register fields. Damage-item
    // inline photos (rendered under Extent of Damage already) are excluded
    // by annexureEPhotos() so they aren't shown twice.
    final annexureEList = annexureEPhotos(assembled.photos);
    // Only photos whose local bytes actually resolved (e.g. not yet
    // downloaded from Drive, or evicted from cache) go into the register —
    // otherwise the register lists a numbered entry with no image/caption
    // ever printed for it (2026-07-13 review). Filtering before building
    // the register keeps numbering, register rows, and captions all in
    // sync, same requirement documented on buildPhotoRegisterRows.
    final resolvedAnnexureEList = annexurePhotosById == null
        ? const <Map<String, dynamic>>[]
        : annexureEList
            .where((p) => annexurePhotosById.containsKey(p['id'] as String?))
            .toList();
    if (resolvedAnnexureEList.isNotEmpty) {
      doc.addPageBreak();
      doc.addHeading('ANNEXURE E — PHOTOGRAPHS', 1);
      final registerRows = buildPhotoRegisterRows(resolvedAnnexureEList);
      if (registerRows.isNotEmpty) {
        doc.addTable(registerRows, boldFirstRow: true,
            colWidths: [900, 2400, 2400, 1300, 2355]);
        doc.addSpacer();
      }
      for (var i = 0; i < resolvedAnnexureEList.length; i++) {
        final photoId = resolvedAnnexureEList[i]['id'] as String?;
        final resolved = annexurePhotosById![photoId];
        if (resolved == null) continue;
        doc.addImage(resolved.bytes, resolved.ext,
            widthEmu: DocxBuilder.kPageWidthEmu * 2 ~/ 3);
        doc.addParagraph(
            photoRegisterCaption(resolvedAnnexureEList[i], i + 1),
            italic: true, halfPtSize: 18, colorHex: '374151');
        doc.addSpacer();
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

  // Delegates to the shared formatter in section_table_rows.dart so the
  // date format used here stays identical to the one used by the
  // buildVesselParticularsRows/buildCertificateRows/etc. helpers above.
  static String _formatDate(String iso) => formatSectionDate(iso);
}
