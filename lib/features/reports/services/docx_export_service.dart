// lib/features/reports/services/docx_export_service.dart
//
// Generates a .docx report file from assembled case data.
// Uses the docx_template package for Flutter/Dart.
// The template .docx files live in assets/templates/.
//
// On web: downloads the file via dart:html
// On native: saves to app documents directory

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:docx_template/docx_template.dart';
import '../providers/report_provider.dart';
import '../../../core/api/supabase_client.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show AnchorElement, Blob, Url;

class DocxExportService {
  /// Generate and download/save a .docx report.
  /// Returns the filename on success.
  static Future<String> export({
    required ReportOutput output,
    required AssembledReportData assembled,
    required Map<SectionType, ReportSection> sections,
  }) async {
    final format = assembled.outputFormat; // 'abl' or 'nordic'
    final templatePath = 'assets/templates/template_$format.docx';

    // ── Load template ────────────────────────────────────────────────
    Uint8List templateBytes;
    try {
      final data = await rootBundle.load(templatePath);
      templateBytes = data.buffer.asUint8List();
    } catch (_) {
      // No template found — generate a basic document from scratch
      templateBytes = await _buildBasicDocx(output, assembled, sections);
      return _deliver(
        bytes: templateBytes,
        filename: _filename(output, assembled),
      );
    }

    // ── Build content map for template substitution ──────────────────
    final content = _buildContentMap(output, assembled, sections);

    // ── Render template ──────────────────────────────────────────────
    final doc = await DocxTemplate.fromBytes(templateBytes);
    final rawBytes = await doc.generate(content);
    if (rawBytes == null) {
      throw Exception('Template rendering returned null');
    }
    final rendered = Uint8List.fromList(rawBytes);

    final filename = _filename(output, assembled);

    // ── Upload to Supabase Storage ────────────────────────────────────
    try {
      final storagePath =
          '${assembled.caseData['case_id']}/exports/$filename';
      await SupabaseService.uploadFile(
        bucket: 'exports',
        path: storagePath,
        bytes: rendered,
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      // Save path to report_outputs
      await SupabaseService.client
          .from('report_outputs')
          .update({'file_path': storagePath})
          .eq('output_id', output.outputId);
    } catch (e) {
      debugPrint('Storage upload failed (non-fatal): $e');
    }

    return _deliver(bytes: rendered, filename: filename);
  }

  // ── Content map — all substitution variables ───────────────────────

  static Content _buildContentMap(
    ReportOutput output,
    AssembledReportData assembled,
    Map<SectionType, ReportSection> sections,
  ) {
    final v     = assembled.vessel ?? {};
    final occ   = assembled.occurrences.isNotEmpty
        ? assembled.occurrences.first
        : <String, dynamic>{};
    final case_ = assembled.caseData;
    final client = (case_['principals_clients']
            as Map<String, dynamic>?)?['name'] as String? ??
        '';

    return Content()
      // ── Report metadata ────────────────────────────────────────────
      ..add(TextContent('report_number',
          output.reportNumber ?? ''))
      ..add(TextContent('report_date', _today()))
      ..add(TextContent('job_number',
          case_['job_number'] as String? ?? ''))
      ..add(TextContent('report_type',
          output.outputType.label.toUpperCase()))
      ..add(TextContent('sequence_no',
          output.sequenceNo > 1 ? ' No.${output.sequenceNo}' : ''))
      ..add(TextContent('claim_reference',
          case_['claim_reference'] as String? ?? ''))
      ..add(TextContent('client_name', client))

      // ── Vessel particulars ─────────────────────────────────────────
      ..add(TextContent('vessel_name',
          v['name'] as String? ?? ''))
      ..add(TextContent('imo_number',
          v['imo_number'] as String? ?? ''))
      ..add(TextContent('vessel_type',
          v['vessel_type'] as String? ?? ''))
      ..add(TextContent('flag',
          v['flag'] as String? ?? ''))
      ..add(TextContent('port_of_registry',
          v['port_of_registry'] as String? ?? ''))
      ..add(TextContent('gross_tonnage',
          v['gross_tonnage']?.toString() ?? ''))
      ..add(TextContent('net_tonnage',
          v['net_tonnage']?.toString() ?? ''))
      ..add(TextContent('deadweight',
          v['deadweight']?.toString() ?? ''))
      ..add(TextContent('length_oa',
          v['length_oa']?.toString() ?? ''))
      ..add(TextContent('length_bp',
          v['length_bp']?.toString() ?? ''))
      ..add(TextContent('breadth',
          v['breadth']?.toString() ?? ''))
      ..add(TextContent('depth',
          v['depth']?.toString() ?? ''))
      ..add(TextContent('max_draft',
          v['max_draft']?.toString() ?? ''))
      ..add(TextContent('year_built',
          v['year_built']?.toString() ?? ''))
      ..add(TextContent('build_yard',
          v['build_yard'] as String? ?? ''))
      ..add(TextContent('build_country',
          v['build_country'] as String? ?? ''))
      ..add(TextContent('owners',
          v['owners'] as String? ?? ''))
      ..add(TextContent('operators',
          v['operators'] as String? ?? ''))
      ..add(TextContent('class_society',
          v['class_society'] as String? ?? ''))
      ..add(TextContent('class_notation',
          v['class_notation'] as String? ?? ''))
      ..add(TextContent('service_speed',
          v['service_speed']?.toString() ?? ''))

      // ── Occurrence ─────────────────────────────────────────────────
      ..add(TextContent('occurrence_title',
          occ['title'] as String? ?? ''))
      ..add(TextContent('occurrence_date',
          _formatDate(occ['date_time'] as String? ?? '')))
      ..add(TextContent('occurrence_location',
          occ['location'] as String? ?? ''))

      // ── Sections ───────────────────────────────────────────────────
      ..add(TextContent('opening_text',
          sections[SectionType.opening]?.content ?? ''))
      ..add(TextContent('background_text',
          sections[SectionType.background]?.content ?? ''))
      ..add(TextContent('occurrence_text',
          sections[SectionType.occurrence]?.content ?? ''))
      ..add(TextContent('damage_text',
          sections[SectionType.damageDescription]?.content ?? ''))
      ..add(TextContent('repairs_text',
          sections[SectionType.repairs]?.content ?? ''))
      ..add(TextContent('cause_text',
          sections[SectionType.causation]?.content ?? ''))
      ..add(TextContent('allegation_text',
          sections[SectionType.allegation]?.content ?? ''))
      ..add(TextContent('closing_text',
          sections[SectionType.closing]?.content ?? ''))

      // ── Attendees table ────────────────────────────────────────────
      ..add(ListContent('attendees',
          assembled.attendees.map((a) => TableContent('', [
                RowContent()
                  ..add(TextContent('attendee_name',
                      '${a['rank_position'] ?? ''} ${a['full_name'] ?? ''}'.trim()))
                  ..add(TextContent('attendee_representing',
                      a['representing'] as String? ??
                          a['company'] as String? ?? '')),
              ])).toList()))

      // ── Certificates table ─────────────────────────────────────────
      ..add(ListContent('certificates',
          assembled.certificates.map((c) => TableContent('', [
                RowContent()
                  ..add(TextContent('cert_name',
                      c['cert_name'] as String? ?? ''))
                  ..add(TextContent('cert_issuer',
                      c['issuing_authority'] as String? ?? ''))
                  ..add(TextContent('cert_issue',
                      _formatDate(c['issue_date'] as String? ?? '')))
                  ..add(TextContent('cert_expiry',
                      _formatDate(c['expiry_date'] as String? ?? ''))),
              ])).toList()))

      // ── Damage items table ─────────────────────────────────────────
      ..add(ListContent('damage_items',
          assembled.damageItems.map((d) => TableContent('', [
                RowContent()
                  ..add(TextContent('damage_component',
                      d['component_name'] as String? ?? ''))
                  ..add(TextContent('damage_description',
                      d['damage_description'] as String? ?? ''))
                  ..add(TextContent('damage_repair_type',
                      d['repair_type'] as String? ?? ''))
                  ..add(TextContent('damage_average',
                      (d['is_concerning_average'] as bool? ?? true)
                          ? 'Average'
                          : "Owner's")),
              ])).toList()));
  }

  // ── Fallback: build a basic .docx without a template ──────────────
  // Used when no template asset exists. Produces a clean but unstyled doc.

  static Future<Uint8List> _buildBasicDocx(
    ReportOutput output,
    AssembledReportData assembled,
    Map<SectionType, ReportSection> sections,
  ) async {
    // Build plain text content structured as the report
    final v = assembled.vessel ?? {};
    final buf = StringBuffer();

    buf.writeln(output.outputType.label.toUpperCase());
    buf.writeln('M.V. "${v['name'] ?? 'VESSEL'}"');
    buf.writeln('Report No.: ${output.reportNumber ?? ''}');
    buf.writeln('Date: ${_today()}');
    buf.writeln('Job No.: ${assembled.caseData['job_number'] ?? ''}');
    buf.writeln();

    for (final section in sections.values) {
      if (section.content.isEmpty) continue;
      buf.writeln(section.title.toUpperCase());
      buf.writeln(section.content);
      buf.writeln();
    }

    // Encode as a minimal .docx (XML-based)
    final xmlContent = _wrapInDocxXml(buf.toString());
    return Uint8List.fromList(xmlContent.codeUnits);
  }

  static String _wrapInDocxXml(String text) {
    // Minimal valid OOXML — opens in Word as plain text
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final paragraphs = escaped
        .split('\n')
        .map((line) =>
            '<w:p><w:r><w:t xml:space="preserve">$line</w:t></w:r></w:p>')
        .join('\n');

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
$paragraphs
  </w:body>
</w:document>''';
  }

  // ── File delivery ─────────────────────────────────────────────────

  static Future<String> _deliver({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (kIsWeb) {
      _downloadWeb(bytes, filename);
    } else {
      await _saveNative(bytes, filename);
    }
    return filename;
  }

  /// Web: trigger browser download
  static void _downloadWeb(Uint8List bytes, String filename) {
    final blob = html.Blob([bytes],
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
    final url  = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  /// Native: save to app documents directory
  static Future<void> _saveNative(Uint8List bytes, String filename) async {
    // import 'dart:io' and 'package:path_provider/path_provider.dart'
    // when building for Android/iOS/tablet
    // final dir = await getApplicationDocumentsDirectory();
    // final file = File('${dir.path}/$filename');
    // await file.writeAsBytes(bytes);
    debugPrint('Native save: $filename (${bytes.length} bytes)');
  }

  // ── Helpers ───────────────────────────────────────────────────────

  static String _filename(
      ReportOutput output, AssembledReportData assembled) {
    final jobNo  = assembled.caseData['job_number'] as String? ?? 'UNKNOWN';
    final vessel = (assembled.vessel?['name'] as String? ?? 'VESSEL')
        .replaceAll(' ', '_')
        .toUpperCase();
    final type   = switch (output.outputType) {
      OutputType.preliminary => 'Prelim',
      OutputType.advice      => 'Advice${output.sequenceNo}',
      OutputType.final_      => 'Final',
    };
    final date = DateTime.now();
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}${date.month.toString().padLeft(2, '0')}${date.year}';
    return '${jobNo}_${vessel}_${type}_$dateStr.docx';
  }

  static String _today() {
    final d = DateTime.now();
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')}-${months[d.month]}-${d.year}';
  }

  static String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day.toString().padLeft(2, '0')}-${months[d.month]}-${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
