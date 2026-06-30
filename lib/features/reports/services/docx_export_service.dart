// lib/features/reports/services/docx_export_service.dart
//
// Builds a properly structured .docx from assembled case data using the
// in-house OOXML builder (lib/core/docx/docx_builder.dart).
// Replaces the previous docx_template approach.
//
// On web:    downloads via dart:html
// On native: saves to getApplicationDocumentsDirectory()

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import '../providers/report_provider.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/docx/docx_builder.dart';
import 'report_delivery.dart';

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
  }) async {
    final bytes = _buildDocx(output, assembled, sections,
        coverPhotoBytes: coverPhotoBytes, coverPhotoExt: coverPhotoExt);
    final filename = _filename(output, assembled);

    // Upload to Supabase Storage (non-fatal)
    try {
      final path = '${assembled.caseData['case_id']}/exports/$filename';
      await SupabaseService.uploadFile(
        bucket: 'exports',
        path: path,
        bytes: bytes,
        mimeType: _docxMime,
      );
      await SupabaseService.client
          .from('report_outputs')
          .update({'file_path': path})
          .eq('output_id', output.outputId);
    } catch (e) {
      debugPrint('Storage upload skipped: $e');
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
  }) {
    final doc = DocxBuilder();
    final v     = assembled.vessel ?? {};
    final case_ = assembled.caseData;
    final org   = assembled.organisation;

    // Resolve branding colours (strip '#' prefix if present)
    String hex(String? raw, String fallback) =>
        (raw ?? fallback).replaceAll('#', '');
    final primaryHex = hex(org?['primary_colour'] as String?, '1F3A5F');
    final firmName   = org?['name'] as String?;

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
    final headerRight = [
      if (vesselName.isNotEmpty) vesselName,
      output.outputType.label,
      if (claimRef.isNotEmpty) claimRef,
    ].join(' — ');
    doc.setBodyHeader(
      leftText:  firmName ?? '',
      rightText: headerRight,
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

    // Vessel cover photo (if available)
    if (coverPhotoBytes != null) {
      const photoH = (DocxBuilder.kPageWidthEmu * 9 ~/ 16);
      doc.addImage(coverPhotoBytes, coverPhotoExt ?? 'jpg',
          widthEmu: DocxBuilder.kPageWidthEmu, heightEmu: photoH);
      doc.addSpacer();
    }

    // Cover info table
    final occFirst = assembled.occurrences.isNotEmpty
        ? assembled.occurrences.first
        : <String, dynamic>{};
    final occDate   = _formatDate(occFirst['occurrence_date'] as String? ?? '');
    final occTitle  = occFirst['title']    as String? ?? '';
    final occLoc    = occFirst['location'] as String? ?? '';
    final jobNo     = case_['technical_file_no']  as String? ?? '';
    final policyUcr = case_['policy_ucr']  as String? ?? '';
    final infoRows  = <List<String>>[
      if (occDate.isNotEmpty)  ['Date of Casualty',    occDate],
      if (occTitle.isNotEmpty) ['Nature of Casualty',  occTitle],
      if (occLoc.isNotEmpty)   ['Location',            occLoc],
      if (claimRef.isNotEmpty) ['Claim Reference',     claimRef],
      if (policyUcr.isNotEmpty)['Policy UCR',          policyUcr],
      if (jobNo.isNotEmpty)    ['File No.',             jobNo],
                               ['Report Version',      output.versionCode],
                               ['Date Issued',         _today()],
    ];
    doc.addTable(infoRows, colWidths: [3000, 6355]);

    doc.addPageBreak();

    // ═══════════════════════════════════════════════════════════════════
    // BODY PAGES (page 2+) — running header active from here
    // ═══════════════════════════════════════════════════════════════════

    // ── Vessel Particulars & Machinery ───────────────────────────────
    if (v.isNotEmpty) {
      doc.addHeading('VESSEL PARTICULARS', 2);
      final vpRows = [
        ['Vessel Name',      v['name']             ?? ''],
        ['IMO Number',       v['imo_number']        ?? ''],
        ['Type',             v['vessel_type']       ?? ''],
        ['Flag',             v['flag']              ?? ''],
        ['Port of Registry', v['port_of_registry']  ?? ''],
        ['Gross Tonnage',    v['gross_tonnage']?.toString() ?? ''],
        ['Net Tonnage',      v['net_tonnage']?.toString()  ?? ''],
        ['Deadweight',       v['deadweight']?.toString()   ?? ''],
        ['LOA',              v['length_oa']?.toString()    ?? ''],
        ['Year Built',       v['year_built']?.toString()   ?? ''],
        ['Build Yard',       v['build_yard']        ?? ''],
        ['Owners',           v['owners']            ?? ''],
        ['Operators',        v['operators']         ?? ''],
        ['Class Society',    v['class_society']     ?? ''],
        ['Class Notation',   v['class_notation']    ?? ''],
      ].where((r) => (r[1] as String).isNotEmpty)
       .map((r) => [r[0] as String, r[1] as String])
       .toList();
      if (vpRows.isNotEmpty) {
        doc.addTable(vpRows, colWidths: [3000, 6355]);
      }
      doc.addSpacer();
    }

    // ── Machinery ─────────────────────────────────────────────────────
    if (assembled.machinery.isNotEmpty) {
      doc.addHeading('MACHINERY & EQUIPMENT PARTICULARS', 2);
      final mRows = [
        ['Item', 'Make / Model', 'Serial No.', 'MCR'],
        ...assembled.machinery.map((m) {
          final kw  = (m['mcr_kw'] as num?)?.toStringAsFixed(0);
          final rpm = (m['mcr_rpm'] as num?)?.toStringAsFixed(0);
          final mcrLabel = [
            if (kw != null) '$kw kW',
            if (rpm != null) '$rpm rpm',
          ].join(' / ');
          return [
            '${m['machinery_type'] ?? ''}${m['role'] != null ? '\n${m['role']}' : ''}',
            '${m['make'] ?? ''} ${m['model'] ?? ''}'.trim(),
            m['serial_number'] as String? ?? '',
            mcrLabel,
          ];
        }),
      ];
      doc.addTable(mRows, boldFirstRow: true, colWidths: [2500, 3000, 2000, 1855]);
      doc.addSpacer();
    }

    // ── Certificates & Class Conditions ───────────────────────────────
    if (assembled.certificates.isNotEmpty) {
      doc.addHeading('CLASS & STATUTORY CERTIFICATES', 2);
      final certRows = [
        ['Certificate', 'Issuing Authority', 'Issue Date', 'Expiry'],
        ...assembled.certificates.map((c) => [
              c['cert_name'] as String? ?? c['cert_type'] as String? ?? '',
              c['issuing_authority'] as String? ?? '',
              _formatDate(c['issue_date'] as String? ?? ''),
              _formatDate(c['expiry_date'] as String? ?? ''),
            ]),
      ];
      doc.addTable(certRows, boldFirstRow: true, colWidths: [3000, 3000, 1500, 1855]);
      doc.addSpacer();
    }

    if (assembled.classConditions.isNotEmpty) {
      doc.addHeading('CONDITIONS OF CLASS', 2);
      final ccRows = [
        ['Reference', 'Description', 'Due Date'],
        ...assembled.classConditions.map((cc) => [
              cc['reference'] as String? ?? '',
              cc['description'] as String? ?? '',
              _formatDate(cc['expiry_date'] as String? ?? ''),
            ]),
      ];
      doc.addTable(ccRows, boldFirstRow: true, colWidths: [1800, 5700, 1855]);
      doc.addSpacer();
    }

    // ── Attendance & Representatives ──────────────────────────────────
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

    // ── Narrative sections (ordered) ──────────────────────────────────
    const orderedSections = [
      SectionType.opening,
      SectionType.background,
      SectionType.occurrence,
      SectionType.damageDescription,
      SectionType.repairs,
      SectionType.causation,
      SectionType.allegation,
      SectionType.closing,
    ];

    for (final type in orderedSections) {
      final section = sections[type];
      if (section == null || section.content.trim().isEmpty) continue;
      doc.addHeading(section.title.toUpperCase(), 2);
      // Split on double-newlines for paragraph breaks
      for (final para in section.content.split('\n\n')) {
        final trimmed = para.trim();
        if (trimmed.isNotEmpty) doc.addParagraph(trimmed);
      }
      doc.addSpacer();
    }

    // ── Chronology ────────────────────────────────────────────────────
    final timeline = assembled.timelineEvents;
    if (timeline.isNotEmpty) {
      doc.addHeading('CHRONOLOGY', 2);
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

    // ── Accounts / Cost Section ───────────────────────────────────────
    final docs = assembled.repairDocuments;
    if (docs.isNotEmpty) {
      doc.addHeading('ACCOUNTS', 2);

      // ── WP cost note (location 3) ─────────────────────────────────
      final wpCost = org?['wp_cost_section_text'] as String?
          ?? 'The following costs are presented without prejudice to '
             "Underwriters' rights and without admission of liability.";
      doc.addParagraph(wpCost,
          italic: true, halfPtSize: 18, colorHex: '6B7280');
      doc.addSpacer();

      final baseCurrency =
          assembled.caseData['base_currency'] as String? ?? '';

      double grandTotalBase = 0;
      double grandTotalUw   = 0;
      double grandTotalOwner = 0;

      for (final repDoc in docs) {
        final supplierName = repDoc['supplier_name'] as String? ?? '—';
        final docRef       = repDoc['document_number'] as String? ?? '';
        final docDate      = _formatDate(repDoc['document_date'] as String? ?? '');
        final docCurrency  = repDoc['currency'] as String? ?? '';
        final docTotal     = (repDoc['total_inc_tax'] as num?)?.toDouble();

        // Document header row
        final docLabel = [
          supplierName,
          if (docRef.isNotEmpty) 'Ref: $docRef',
          if (docDate.isNotEmpty) docDate,
        ].join(' — ');
        doc.addParagraph(docLabel,
            bold: true, halfPtSize: 20, colorHex: '1F3A5F');

        // Line items
        final lines =
            (repDoc['account_lines'] as List? ?? [])
                .cast<Map<String, dynamic>>();

        if (lines.isNotEmpty) {
          final lineRows = <List<String>>[
            ['#', 'Description', 'Nature', 'Gross ($docCurrency)',
             if (baseCurrency.isNotEmpty && baseCurrency != docCurrency)
               'Base ($baseCurrency)',
            ],
          ];
          for (final ln in lines) {
            final gross = (ln['gross_amount'] as num?)?.toDouble() ?? 0;
            final uw    = (ln['underwriters_portion'] as num?)?.toDouble() ?? 0;
            final own   = (ln['owners_portion'] as num?)?.toDouble() ?? 0;
            final baseAmt = (ln['base_currency_amount'] as num?)?.toDouble();
            grandTotalUw    += uw;
            grandTotalOwner += own;
            if (baseAmt != null) grandTotalBase += baseAmt;

            lineRows.add([
              '${ln['item_number'] ?? ln['line_order'] ?? ''}',
              ln['description'] as String? ?? '',
              _costNatureLabel(ln['cost_nature'] as String?),
              _fmtAmt(gross),
              if (baseCurrency.isNotEmpty && baseCurrency != docCurrency)
                baseAmt != null ? _fmtAmt(baseAmt) : '—',
            ]);
          }
          final hasFx = baseCurrency.isNotEmpty && baseCurrency != docCurrency;
          doc.addTable(lineRows,
              boldFirstRow: true,
              colWidths: hasFx
                  ? [400, 4300, 1500, 1800, 1355]
                  : [400, 5800, 1500, 1655]);
        } else if (docTotal != null) {
          doc.addParagraph(
              'Total: $docCurrency ${_fmtAmt(docTotal)}',
              halfPtSize: 18);
        }
        doc.addSpacer();
      }

      // ── Grand totals ──────────────────────────────────────────────
      final totalsRows = <List<String>>[
        ['', ''],
        if (grandTotalUw > 0.005)
          ["Underwriters' account",  _fmtAmt(grandTotalUw)],
        if (grandTotalOwner > 0.005)
          ["Owner's account",        _fmtAmt(grandTotalOwner)],
        if (grandTotalBase > 0.005 && baseCurrency.isNotEmpty)
          ['Grand total ($baseCurrency)', _fmtAmt(grandTotalBase)],
      ].where((r) => r[0].isNotEmpty).toList();

      if (totalsRows.isNotEmpty) {
        doc.addTable(totalsRows, colWidths: [6355, 3000]);
      }
      doc.addSpacer();
    }

    // ── WP cost note fallback (location 3) — only when no account docs ──
    if (docs.isEmpty) {
      final wpCost = org?['wp_cost_section_text'] as String?;
      if (wpCost != null && wpCost.isNotEmpty) {
        doc.addParagraph(wpCost, italic: true, halfPtSize: 18, colorHex: '6B7280');
        doc.addSpacer();
      }
    }

    // ── Damage items ──────────────────────────────────────────────────
    if (assembled.damageItems.isNotEmpty) {
      doc.addHeading('DAMAGE SCHEDULE', 2);
      final dmgRows = [
        ['Component', 'Description', 'Repair Type', 'Average'],
        ...assembled.damageItems.map((d) => [
              d['component_name'] as String? ?? '',
              d['damage_description'] as String? ?? '',
              d['repair_type'] as String? ?? '',
              (d['is_concerning_average'] as bool? ?? true) ? 'Average' : "Owner's",
            ]),
      ];
      doc.addTable(dmgRows, boldFirstRow: true,
          colWidths: [2500, 3500, 1700, 1655]);
      doc.addSpacer();
    }

    // ── Surveyor's Notes ─────────────────────────────────────────────
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

    // ── Documents on File ─────────────────────────────────────────────
    if (assembled.caseDocuments.isNotEmpty) {
      doc.addHeading('DOCUMENTS RETAINED ON FILE', 2);
      final docRows = [
        ['#', 'Document', 'Category', 'Date'],
        ...assembled.caseDocuments.asMap().entries.map((e) => [
              '${e.key + 1}',
              e.value['title'] as String? ?? '',
              (e.value['doc_category'] as String? ?? '')
                  .replaceAll('_', ' '),
              _formatDate(e.value['doc_date'] as String? ?? ''),
            ]),
      ];
      doc.addTable(docRows, boldFirstRow: true,
          colWidths: [400, 5200, 2000, 1755]);
      doc.addSpacer();
    }

    // ── Waiver / Limitation of Liability ─────────────────────────────
    final waiverSection = sections[SectionType.waiver];
    final waiverContent = waiverSection?.content ?? '';
    if (waiverContent.isNotEmpty) {
      doc.addHeading('LIMITATION OF LIABILITY', 2);
      doc.addParagraph(waiverContent,
          italic: true, halfPtSize: 18, colorHex: '374151');
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
        attendingDate: fmtSignDate(
            caseData['signed_off_attending_at'] as String?),
        reviewingName: caseData['signed_off_reviewing_name'] as String?,
        reviewingDate: fmtSignDate(
            caseData['signed_off_reviewing_at'] as String?),
      );
      doc.addSpacer();
    }

    // ── WP footer (location 4: end of report) ─────────────────────────
    final wpFooter = org?['wp_footer_text'] as String?;
    if (wpFooter != null && wpFooter.isNotEmpty) {
      doc.addPageBreak();
      doc.addParagraph(wpFooter,
          italic: true, halfPtSize: 18, colorHex: '6B7280',
          align: WAlignment.center);
    }

    // Disclaimer
    final disclaimer = org?['disclaimer_text'] as String?;
    if (disclaimer != null && disclaimer.isNotEmpty) {
      doc.addSpacer();
      doc.addParagraph(disclaimer,
          halfPtSize: 16, colorHex: '9CA3AF', align: WAlignment.justify);
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
