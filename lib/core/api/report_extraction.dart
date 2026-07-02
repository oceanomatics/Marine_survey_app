// lib/core/api/report_extraction.dart
//
// Extracts rich case data from a previously issued survey report.
// Called from the Document Vault when a Word/PDF report is imported.

import 'dart:async';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'usage_tracker.dart';

class ReportExtraction {
  static final _dio = () {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.anthropic.com/v1',
      headers: {
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      // sendTimeout covers the upload of the (potentially large) base64 payload.
      sendTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 300),
    ));
    // Read the key fresh on every request — see claude_api.dart for why.
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['x-api-key'] = AppConfig.anthropicApiKey;
        handler.next(options);
      },
    ));
    return dio;
  }();

  /// Extract full case data from a previous survey report (PDF or image).
  /// Returns a structured map covering vessel, occurrence, damage,
  /// attendees, certificates and machinery.
  static Future<FullReportExtraction> extractFromReport({
    required String base64Content,
    required String mediaType,
    String? documentHint,
    String? caseId,
    String? contextNotes,
  }) async {
    final hint = documentHint != null
        ? 'This is a $documentHint. '
        : 'This appears to be a marine survey report. ';

    final contextSection = (contextNotes != null && contextNotes.trim().isNotEmpty)
        ? '\nSurveyor context note: ${contextNotes.trim()}\nTake this note into account when interpreting the document.\n'
        : '';

    const extractionTemplate = '''
{
  "report_meta": {
    "report_number": "",
    "technical_file_no": "",
    "report_date": "",
    "report_type": "preliminary|advice|final",
    "claim_reference": "",
    "output_format": "nordic|abl|other"
  },
  "vessel": {
    "name": "",
    "imo_number": "",
    "vessel_type": "",
    "flag": "",
    "port_of_registry": "",
    "gross_tonnage": null,
    "net_tonnage": null,
    "deadweight": null,
    "length_oa": null,
    "length_bp": null,
    "breadth": null,
    "depth": null,
    "max_draft": null,
    "year_built": null,
    "build_yard": "",
    "build_country": "",
    "owners": "",
    "operators": "",
    "class_society": "",
    "class_notation": "",
    "service_speed": null
  },
  "machinery": [
    {
      "role": "main_engine|diesel_generator|thruster|turbocharger|other",
      "make": "",
      "model": "",
      "quantity": 1,
      "mcr_kw": null,
      "mcr_rpm": null,
      "fuel_type": "",
      "cylinder_count": null,
      "configuration": "",
      "serial_number": ""
    }
  ],
  "occurrences": [
    {
      "occurrence_no": 1,
      "date_time": "",
      "location": "",
      "title": "",
      "brief_description": "",
      "background_narrative": "Copy verbatim from the report — do not summarise or truncate",
      "ism_reported": null,
      "cause_type": "grounding|collision|contact|fire|explosion|flooding|heavy_weather|machinery_failure|structural_failure|crew_error|port_damage|ice_damage|lightning|malicious|other",
      "allegation_type": "formal_allegation|no_formal_allegation|tbc",
      "cause_narrative": "Copy verbatim from causation/allegation section — do not summarise"
    }
  ],
  "damage_items": [
    {
      "item_no": 1,
      "occurrence_no": 1,
      "component_name": "",
      "location_on_vessel": "",
      "damage_description": "",
      "condition_found": "",
      "repair_status": "not_repaired|temporary_repair|permanently_repaired|deferred",
      "is_concerning_average": true
    }
  ],
  "repairs_performed": [
    {
      "repair_no": 1,
      "repair_type": "temporary|permanent",
      "description": "What was done — e.g. 'Steel doubling plate 8mm welded over breach afloat'",
      "item_nos": [1, 2],
      "contractor": "",
      "location": "",
      "date_completed": "",
      "status": "completed|in_progress|deferred"
    }
  ],
  "attendees": [
    {
      "full_name": "",
      "rank_position": "",
      "company": "",
      "representing": "",
      "role_type": "master|chief_engineer|superintendent|class_surveyor|service_engineer|surveyor|other"
    }
  ],
  "certificates": [
    {
      "cert_type": "class_certificate|doc|smc|load_line|marpol|psc_inspection|other",
      "cert_name": "",
      "issuing_authority": "",
      "issue_date": "",
      "expiry_date": "",
      "cert_number": ""
    }
  ],
  "repairs": {
    "yard_contractor": "",
    "location": "",
    "start_date": "",
    "end_date": "",
    "drydock_required": null,
    "drydock_days": null,
    "afloat_days": null
  },
  "cause_narrative": "Copy verbatim — do not summarise",
  "allegation_type": "formal_allegation|no_formal_allegation|tbc",
  "context_cues": [
    {
      "content": "Concise statement of a key finding, adjuster instruction, policy position, coverage constraint, follow-up item or observation worth tracking by the surveyor",
      "category": "observation|measurement|follow_up|interview|technical|policy|general",
      "report_section": "background|occurrence|attendance|timeline|causation|damage|repairs|repair_times|extra_expenses|general_expenses|not_average|other_matters",
      "priority": "important|normal"
    }
  ]
}

Return null for missing numeric fields. Return empty string for missing text fields. Dates in ISO format YYYY-MM-DD. Copy all narrative text verbatim — never summarise or truncate. In context_cues, include every key finding, adjuster instruction, policy position, coverage constraint, follow-up action or noteworthy observation — especially anything that could affect how invoices, repairs or liabilities are treated.''';

    // Build content blocks — DOCX is extracted as text; PDF/images use native blocks.
    final List<Map<String, dynamic>> contentBlocks;
    if (mediaType.contains('wordprocessingml') || mediaType.contains('msword')) {
      final rawBytes = base64Decode(base64Content);
      final docxText = _extractDocxText(rawBytes);
      contentBlocks = [
        {
          'type': 'text',
          'text': '$hint$contextSection\nExtract ALL structured data from this marine survey report and return ONLY a JSON object with no preamble or markdown. Extract every field you can identify. Copy all narrative text verbatim.\n\n<document_text>\n$docxText\n</document_text>\n\n$extractionTemplate',
        }
      ];
    } else {
      final mediaBlock = mediaType == 'application/pdf'
          ? {
              'type': 'document',
              'source': {
                'type': 'base64',
                'media_type': 'application/pdf',
                'data': base64Content,
              },
            }
          : {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': base64Content,
              },
            };
      contentBlocks = [
        mediaBlock,
        {
          'type': 'text',
          'text': '$hint$contextSection\nExtract ALL structured data from this marine survey report and return ONLY a JSON object with no preamble or markdown. Extract every field you can identify. Copy all narrative text verbatim.\n\n$extractionTemplate',
        },
      ];
    }

    final payload = {
      'model': AppConfig.claudeModel,
      'max_tokens': 8096,
      'messages': [
        {
          'role': 'user',
          'content': contentBlocks,
        },
      ],
    };

    // Use SSE streaming so the connection receives regular token chunks instead
    // of sitting silent for 30-120 s. Intermediate proxies and satellite modems
    // often kill connections they consider "idle", even if they're legitimately
    // waiting. Streaming keeps them alive.
    final streamPayload = {...payload, 'stream': true};

    const maxAttempts = 4;
    Object? lastErr;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await _dio.post<ResponseBody>(
          '/messages',
          data: streamPayload,
          options: Options(
            responseType: ResponseType.stream,
            // Per-chunk timeout: abort only if no data arrives for 3 min.
            receiveTimeout: const Duration(minutes: 3),
          ),
        );
        final result = await _collectStream(response.data!);
        if (result.text.isEmpty) throw Exception('Empty response from API');
        UsageTracker.log(
          caseId: caseId,
          feature: 'report_extraction',
          model: AppConfig.claudeModel,
          inputTokens: result.inputTokens,
          outputTokens: result.outputTokens,
        );
        final parsed = _parseJson(result.text);
        debugPrint('[Extract] raw chars: ${result.text.length}, '
            'parsed keys: ${parsed.keys.toList()}');
        // If the stream was truncated, parsed will be empty — treat it as a
        // transient failure so the retry loop can try again.
        if (parsed.isEmpty) {
          debugPrint('[Extract] parse failed — truncated stream? '
              'First 600 chars: ${result.text.substring(0, result.text.length.clamp(0, 600))}');
          throw Exception(
              'Response received (${result.text.length} chars) but '
              'could not be parsed as JSON — retrying');
        }
        return FullReportExtraction.fromJson(parsed,
            rawText: result.text);
      } on DioException catch (e) {
        lastErr = e;
        final code = e.response?.statusCode;
        if (code != null && code >= 400 && code < 500 &&
            code != 408 && code != 429) {
          rethrow;
        }
      } catch (e) {
        // Catches stream-level drops (SocketException, "connection closed", etc.)
        lastErr = e;
      }
      if (attempt < maxAttempts - 1) {
        await Future.delayed(Duration(seconds: 5 * (attempt + 1)));
      }
    }
    Error.throwWithStackTrace(lastErr!, StackTrace.current);
  }

  /// Reads an Anthropic SSE stream and concatenates all text deltas.
  /// Also captures input/output token counts from the usage events.
  static Future<({String text, int inputTokens, int outputTokens})>
      _collectStream(ResponseBody body) async {
    final buffer = StringBuffer();
    var inputTokens  = 0;
    var outputTokens = 0;

    await body.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      if (!line.startsWith('data: ')) return;
      final data = line.substring(6).trim();
      if (data == '[DONE]' || data.isEmpty) return;
      try {
        final event = jsonDecode(data) as Map<String, dynamic>;
        switch (event['type'] as String?) {
          case 'message_start':
            final u =
                (event['message'] as Map?)?['usage'] as Map?;
            if (u != null) {
              inputTokens = (u['input_tokens'] as num?)?.toInt() ?? 0;
            }
          case 'content_block_delta':
            final delta = event['delta'] as Map<String, dynamic>?;
            if (delta?['type'] == 'text_delta') {
              buffer.write(delta!['text'] as String? ?? '');
            }
          case 'message_delta':
            final u = event['usage'] as Map?;
            if (u != null) {
              outputTokens =
                  (u['output_tokens'] as num?)?.toInt() ?? 0;
            }
        }
      } catch (_) {
        // Skip malformed SSE events.
      }
    });

    return (
      text:         buffer.toString(),
      inputTokens:  inputTokens,
      outputTokens: outputTokens,
    );
  }

  static Map<String, dynamic> _parseJson(String text) {
    try {
      var clean = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      // Claude sometimes adds a prose preamble before the JSON object.
      // Find the outermost { … } and parse just that.
      final start = clean.indexOf('{');
      final end   = clean.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        clean = clean.substring(start, end + 1);
      }
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// Extracts plain text from a DOCX file (which is a ZIP of XML).
  /// Reads word/document.xml and pulls text from <w:t> elements,
  /// preserving paragraph breaks.
  static String _extractDocxText(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? docFile;
    for (final file in archive) {
      if (file.name == 'word/document.xml') {
        docFile = file;
        break;
      }
    }
    if (docFile == null) {
      throw UnsupportedError('Invalid DOCX: word/document.xml not found');
    }
    final xmlStr = utf8.decode(docFile.content as List<int>);

    final buf      = StringBuffer();
    final paraRe   = RegExp(r'<w:p[ />].*?</w:p>', dotAll: true);
    final textRe   = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);

    for (final para in paraRe.allMatches(xmlStr)) {
      final paraBuf = StringBuffer();
      for (final t in textRe.allMatches(para.group(0)!)) {
        paraBuf.write((t.group(1) ?? '')
            .replaceAll('&amp;',  '&')
            .replaceAll('&lt;',   '<')
            .replaceAll('&gt;',   '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&apos;', "'"));
      }
      final line = paraBuf.toString().trim();
      if (line.isNotEmpty) buf.writeln(line);
    }
    return buf.toString().trim();
  }
}

// ── Extraction result model ────────────────────────────────────────────────

class FullReportExtraction {
  const FullReportExtraction({
    required this.reportMeta,
    required this.vessel,
    required this.machinery,
    required this.occurrences,
    required this.damageItems,
    required this.repairsPerformed,
    required this.attendees,
    required this.certificates,
    required this.yardRepairs,
    required this.causeNarrative,
    required this.allegationType,
    required this.contextCues,
    required this.raw,
    this.rawText = '',
  });

  final Map<String, dynamic> reportMeta;
  final Map<String, dynamic> vessel;
  final List<Map<String, dynamic>> machinery;
  final List<Map<String, dynamic>> occurrences;
  final List<Map<String, dynamic>> damageItems;
  /// Individual repair actions, each potentially covering multiple damage items.
  final List<Map<String, dynamic>> repairsPerformed;
  final List<Map<String, dynamic>> attendees;
  final List<Map<String, dynamic>> certificates;
  /// Yard / drydock repair specification (dates, contractor, drydock days).
  final Map<String, dynamic> yardRepairs;
  final String causeNarrative;
  final String allegationType;
  /// Key findings, adjuster instructions, policy positions and follow-up items
  /// extracted by Claude to pre-populate the Context Cues screen.
  final List<Map<String, dynamic>> contextCues;
  final Map<String, dynamic> raw;
  /// The raw text Claude returned before JSON parsing — for diagnostics.
  final String rawText;

  int get totalFields {
    int count = 0;
    vessel.forEach((k, v) { if (v != null && v != '') count++; });
    count += machinery.length;
    count += occurrences.length;
    count += damageItems.length;
    count += repairsPerformed.length;
    count += attendees.length;
    count += certificates.length;
    if (causeNarrative.isNotEmpty) count++;
    return count;
  }

  bool get hasVesselData =>
      vessel.values.any((v) => v != null && v != '');
  bool get hasMachinery        => machinery.isNotEmpty;
  bool get hasOccurrences      => occurrences.isNotEmpty;
  bool get hasDamageItems      => damageItems.isNotEmpty;
  bool get hasRepairsPerformed => repairsPerformed.isNotEmpty;
  bool get hasAttendees        => attendees.isNotEmpty;
  bool get hasCertificates     => certificates.isNotEmpty;
  bool get hasContextCues      => contextCues.isNotEmpty;

  factory FullReportExtraction.fromJson(Map<String, dynamic> j,
      {String rawText = ''}) {
    List<Map<String, dynamic>> list(String key) {
      final v = j[key];
      if (v == null) return [];
      if (v is List) return v.whereType<Map<String, dynamic>>().toList();
      return [];
    }

    Map<String, dynamic> map(String key) {
      final v = j[key];
      if (v is Map<String, dynamic>) return v;
      return {};
    }

    return FullReportExtraction(
      reportMeta:       map('report_meta'),
      vessel:           map('vessel'),
      machinery:        list('machinery'),
      occurrences:      list('occurrences'),
      damageItems:      list('damage_items'),
      repairsPerformed: list('repairs_performed'),
      attendees:        list('attendees'),
      certificates:     list('certificates'),
      yardRepairs:      map('repairs'),
      causeNarrative:   j['cause_narrative'] as String? ?? '',
      allegationType:   j['allegation_type'] as String? ?? 'tbc',
      contextCues:      list('context_cues'),
      raw:              j,
      rawText:          rawText,
    );
  }
}
