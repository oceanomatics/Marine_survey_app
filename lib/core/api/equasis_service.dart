// lib/core/api/equasis_service.dart
//
// Logs in to equasis.org, fetches the ship folder for a given IMO,
// parses the response HTML and generates a PDF matching the Equasis
// "Ship folder" format. The PDF bytes are returned for upload to the
// document vault.

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ── Data model ─────────────────────────────────────────────────────────────

class EquasisShipData {
  const EquasisShipData({
    required this.imo,
    required this.name,
    required this.particulars,
    required this.management,
    required this.classStatus,
    required this.classSurveys,
    required this.pni,
    required this.psc,
    required this.nameHistory,
    required this.flagHistory,
    required this.classHistory,
    required this.companyHistory,
    required this.fetchDate,
  });

  final String imo;
  final String name;

  // Each inner list is a table row (list of cell strings).
  final List<List<String>> particulars;   // [label, value, since?]
  final List<List<String>> management;
  final List<List<String>> classStatus;
  final List<List<String>> classSurveys;
  final List<List<String>> pni;
  final List<List<String>> psc;
  final List<List<String>> nameHistory;
  final List<List<String>> flagHistory;
  final List<List<String>> classHistory;
  final List<List<String>> companyHistory;
  final String fetchDate;
}

// ── Service ────────────────────────────────────────────────────────────────

class EquasisService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://www.equasis.org',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*',
      'Accept-Language': 'en-US,en;q=0.9',
    },
  ));

  /// Full flow: login → fetch ship page → parse → generate PDF.
  /// Returns PDF bytes ready for upload to the document vault.
  static Future<Uint8List> fetchVesselReport({
    required String imo,
    required String username,
    required String password,
    String? vesselName,
  }) async {
    final cookie = await _login(username, password);
    final html   = await _fetchShipInfo(imo, cookie);
    final data   = _parseHtml(imo: imo, fallbackName: vesselName ?? '', html: html);
    return _buildPdf(data);
  }

  // ── Login ──────────────────────────────────────────────────────────────

  static Future<String> _login(String username, String password) async {
    // POST the login form. Equasis uses JavaServer Faces; the action
    // URL and field names come from their public login page.
    final resp = await _dio.post(
      '/EquasisWeb/public/Login',
      data: 'fs=Login&pageName=Login'
          '&j_email=${Uri.encodeComponent(username)}'
          '&j_password=${Uri.encodeComponent(password)}',
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        followRedirects: false,
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    final allCookies = <String>[];
    for (final header in (resp.headers.map['set-cookie'] ?? [])) {
      final kv = header.split(';').first.trim();
      if (kv.isNotEmpty) allCookies.add(kv);
    }

    // Follow the redirect manually so we collect cookies from each hop.
    String cookieStr = allCookies.join('; ');
    if ((resp.statusCode == 302 || resp.statusCode == 301)) {
      final location = resp.headers.map['location']?.first ?? '';
      if (location.isNotEmpty) {
        final redir = await _dio.get(
          location.startsWith('http') ? location : location,
          options: Options(
            followRedirects: false,
            validateStatus: (s) => s != null && s < 500,
            headers: {'Cookie': cookieStr},
          ),
        );
        for (final h in (redir.headers.map['set-cookie'] ?? [])) {
          final kv = h.split(';').first.trim();
          if (kv.isNotEmpty && !cookieStr.contains(kv.split('=').first)) {
            allCookies.add(kv);
          }
        }
        cookieStr = allCookies.join('; ');
      }
    }

    if (cookieStr.isEmpty) {
      throw Exception(
          'Equasis login failed: no session cookie. Check credentials.');
    }

    // A successful Equasis login puts JSESSIONID in the cookie jar.
    // If we only got a generic pre-session cookie, login probably failed.
    final lowerHtml = ((resp.data ?? '') as String).toLowerCase();
    if (lowerHtml.contains('invalid') || lowerHtml.contains('incorrect')) {
      throw Exception('Equasis login failed: invalid username or password.');
    }

    debugPrint('[Equasis] login OK — cookies: ${cookieStr.length} chars');
    return cookieStr;
  }

  // ── Fetch ship info HTML ───────────────────────────────────────────────

  static Future<String> _fetchShipInfo(String imo, String cookie) async {
    final resp = await _dio.get(
      '/EquasisWeb/restricted/ShipInfo',
      queryParameters: {'fs': 'Search', 'P_IMO': imo},
      options: Options(
        followRedirects: true,
        validateStatus: (s) => s != null && s < 500,
        headers: {'Cookie': cookie},
      ),
    );
    final html = (resp.data ?? '') as String;
    if (html.toLowerCase().contains('please login') ||
        resp.statusCode == 403) {
      throw Exception('Equasis session expired or IMO $imo not found.');
    }
    return html;
  }

  // ── HTML parsing ───────────────────────────────────────────────────────

  static String _strip(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Extract all <table> blocks as rows of cells.
  static List<List<List<String>>> _tables(String html) {
    final tRe  = RegExp(r'<table[^>]*>(.*?)</table>', dotAll: true, caseSensitive: false);
    final rRe  = RegExp(r'<tr[^>]*>(.*?)</tr>',        dotAll: true, caseSensitive: false);
    final cRe  = RegExp(r'<t[hd][^>]*>(.*?)</t[hd]>',  dotAll: true, caseSensitive: false);

    return [
      for (final t in tRe.allMatches(html))
        [
          for (final r in rRe.allMatches(t.group(1)!))
            [for (final c in cRe.allMatches(r.group(1)!)) _strip(c.group(1)!)]
                .where((s) => true)
                .toList()
        ].where((row) => row.isNotEmpty).toList()
    ].where((t) => t.isNotEmpty).toList();
  }

  // Split HTML into sections by <h2> / <h3> headings.
  static Map<String, String> _sections(String html) {
    final hRe = RegExp(
      r'<h[23][^>]*>(.*?)</h[23]>(.*?)(?=<h[23]|$)',
      dotAll: true, caseSensitive: false,
    );
    return {
      for (final m in hRe.allMatches(html))
        _strip(m.group(1)!).toLowerCase(): m.group(2)!,
    };
  }

  static EquasisShipData _parseHtml({
    required String imo,
    required String fallbackName,
    required String html,
  }) {
    // Ship name — look in <title> or a header near the IMO.
    final titleM = RegExp(
      r'<h1[^>]*>(.*?)</h1>',
      dotAll: true, caseSensitive: false,
    ).firstMatch(html);
    final name = titleM != null
        ? _strip(titleM.group(1)!)
        : fallbackName;

    final sections = _sections(html);

    List<List<String>> fromSection(String key) {
      final body = sections.entries
          .where((e) => e.key.contains(key))
          .map((e) => e.value)
          .firstOrNull ?? '';
      final tbls = _tables(body);
      // Skip header row (first row is usually th labels).
      if (tbls.isEmpty) return [];
      final rows = tbls.first;
      return rows.length > 1 ? rows.sublist(1) : rows;
    }

    // Ship particulars are in the first big table on the page.
    // It has two columns: "Information" and "Since".
    final allTables = _tables(html);
    final particulars = allTables.isNotEmpty && allTables.first.length > 1
        ? allTables.first.sublist(1) // skip header row
        : <List<String>>[];

    final now = DateTime.now();
    final fetchDate =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';

    return EquasisShipData(
      imo: imo,
      name: name.isNotEmpty ? name : 'IMO $imo',
      particulars: particulars,
      management:     fromSection('management'),
      classStatus:    fromSection('classification status'),
      classSurveys:   fromSection('classification survey'),
      pni:            fromSection('p&i'),
      psc:            fromSection('port state control'),
      nameHistory:    fromSection('name'),
      flagHistory:    fromSection('flag'),
      classHistory:   fromSection('classification'),
      companyHistory: fromSection('company'),
      fetchDate: fetchDate,
    );
  }

  // ── PDF generation ─────────────────────────────────────────────────────

  static const _navy   = PdfColor.fromInt(0xFF0C2340);
  static const _blue   = PdfColor.fromInt(0xFF185FA5);
  static const _teal   = PdfColor.fromInt(0xFF0F6E56);
  static const _row0   = PdfColor.fromInt(0xFFF8F7F3);
  static const _border = PdfColor.fromInt(0xFFD3D1C7);
  static const _grey   = PdfColor.fromInt(0xFF5F5E5A);
  static const _white  = PdfColors.white;

  static Future<Uint8List> _buildPdf(EquasisShipData d) async {
    final pdf = pw.Document(
      author: 'Marine Survey App — Equasis fetch',
      title: 'Equasis Ship Folder — ${d.name}',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _header(d, ctx),
        footer: (ctx) => _footer(d, ctx),
        build: (ctx) => [
          _disclaimer(),
          pw.SizedBox(height: 14),
          _sectionTitle('Ship Particulars'),
          _twoColTable(d.particulars, ['Information', 'Since']),
          if (d.management.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionTitle('Management Detail'),
            _multiColTable(d.management,
                ['IMO', 'Role', 'Name of Company', 'Address', 'Date of Effect']),
          ],
          if (d.classStatus.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionTitle('Classification Status'),
            _multiColTable(d.classStatus,
                ['Classification Society', 'Date Change Status', 'Status', 'Reason']),
          ],
          if (d.classSurveys.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionTitle('Classification Surveys'),
            _multiColTable(d.classSurveys,
                ['Classification Society', 'Date Survey', 'Date Next Survey']),
          ],
          if (d.pni.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionTitle('P&I Information'),
            _multiColTable(d.pni, ['Name of P&I Insurer', 'Recorded On']),
          ],
          if (d.psc.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionTitle('Port State Control'),
            _multiColTable(d.psc, [
              'Authority', 'Port', 'Date', 'Detention',
              'PSC Org', 'Type', 'Duration', 'Deficiencies',
            ]),
          ],
          if (d.nameHistory.isNotEmpty || d.flagHistory.isNotEmpty ||
              d.classHistory.isNotEmpty || d.companyHistory.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _historyTitle(),
            if (d.nameHistory.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              _sectionTitle('Current and Former Names'),
              _multiColTable(d.nameHistory, ['Name of Ship', 'Date of Effect', 'Source']),
            ],
            if (d.flagHistory.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              _sectionTitle('Current and Former Flags'),
              _multiColTable(d.flagHistory, ['Flag', 'Date of Effect', 'Source']),
            ],
            if (d.classHistory.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              _sectionTitle('Classification History'),
              _multiColTable(d.classHistory,
                  ['Classification Society', 'Date of Survey', 'Sources']),
            ],
            if (d.companyHistory.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              _sectionTitle('Company History'),
              _multiColTable(d.companyHistory,
                  ['Company', 'Role', 'Date of Effect', 'Sources']),
            ],
          ],
        ],
      ),
    );

    return pdf.save();
  }

  // ── PDF sub-widgets ────────────────────────────────────────────────────

  static pw.Widget _header(EquasisShipData d, pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const pw.BoxDecoration(color: _navy),
      child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Equasis — Ship Folder',
                    style: pw.TextStyle(
                        color: _white,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(d.name,
                    style: pw.TextStyle(
                        color: _white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('IMO: ${d.imo}',
                    style: pw.TextStyle(color: _white, fontSize: 9,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Data source: equasis.org',
                    style: const pw.TextStyle(color: _white, fontSize: 7)),
              ],
            ),
          ]),
    );
  }

  static pw.Widget _footer(EquasisShipData d, pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.5)),
      ),
      child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Equasis — Ship folder — ${d.name} (imo:${d.imo})'
              ' — Fetched ${d.fetchDate}',
              style: const pw.TextStyle(fontSize: 7, color: _grey),
            ),
            pw.Text(
              'Page ${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: _grey),
            ),
          ]),
    );
  }

  static pw.Widget _disclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _row0,
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        'Disclaimer: Neither Equasis nor its officers or employees shall be under any liability or '
        'responsibility regarding data displayed on equasis.org. Whilst Equasis will make every '
        'effort to provide accurate information, it does not rule out the possibility of inadvertent '
        'omissions or inaccuracies. This PDF was automatically generated by Marine Survey App '
        'from the live Equasis database on ${DateTime.now().toUtc().toString().substring(0, 10)} UTC.',
        style: const pw.TextStyle(fontSize: 7, color: _grey),
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      color: _blue,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Text(
        '• $title',
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _white,
        ),
      ),
    );
  }

  static pw.Widget _historyTitle() {
    return pw.Container(
      color: _teal,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(
        'Ship History',
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: _white,
        ),
      ),
    );
  }

  // Two-column table used for ship particulars (label | value | since?).
  static pw.Widget _twoColTable(
      List<List<String>> rows, List<String> headers) {
    if (rows.isEmpty) {
      return pw.Text('No data', style: const pw.TextStyle(fontSize: 8, color: _grey));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _navy),
          children: headers
              .map((h) => _cell(h, isHeader: true))
              .toList(),
        ),
        // Data rows
        for (int i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration:
                pw.BoxDecoration(color: i.isEven ? _white : _row0),
            children: List.generate(
              headers.length,
              (j) => _cell(j < rows[i].length ? rows[i][j] : ''),
            ),
          ),
      ],
    );
  }

  // Generic multi-column table.
  static pw.Widget _multiColTable(
      List<List<String>> rows, List<String> headers) {
    if (rows.isEmpty) {
      return pw.Text('No data', style: const pw.TextStyle(fontSize: 8, color: _grey));
    }
    final colCount = headers.length;
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _navy),
          children: headers.map((h) => _cell(h, isHeader: true)).toList(),
        ),
        for (int i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration:
                pw.BoxDecoration(color: i.isEven ? _white : _row0),
            children: List.generate(
              colCount,
              (j) => _cell(j < rows[i].length ? rows[i][j] : ''),
            ),
          ),
      ],
    );
  }

  static pw.Widget _cell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight:
              isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? _white : PdfColors.black,
        ),
      ),
    );
  }
}
