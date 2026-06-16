// lib/core/api/report_extraction.dart
//
// Extracts rich case data from a previously issued survey report.
// Called from the Document Vault when a Word/PDF report is imported.

import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ReportExtraction {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://api.anthropic.com/v1',
    headers: {
      'x-api-key': AppConfig.anthropicApiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    receiveTimeout: const Duration(seconds: 180),
  ));

  /// Extract full case data from a previous survey report (PDF or image).
  /// Returns a structured map covering vessel, occurrence, damage,
  /// attendees, certificates and machinery.
  static Future<FullReportExtraction> extractFromReport({
    required String base64Content,
    required String mediaType,
    String? documentHint,
  }) async {
    final hint = documentHint != null
        ? 'This is a $documentHint. '
        : 'This appears to be a marine survey report. ';

    final response = await _dio.post('/messages', data: {
      'model': AppConfig.claudeModel,
      'max_tokens': 4096,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': base64Content,
              },
            },
            {
              'type': 'text',
              'text': '''${hint}Extract ALL structured data from this marine survey report and return ONLY a JSON object with no preamble or markdown. Extract every field you can identify.

{
  "report_meta": {
    "report_number": "",
    "job_number": "",
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
      "background_narrative": "",
      "ism_reported": null
    }
  ],
  "damage_items": [
    {
      "component_name": "",
      "location_on_vessel": "",
      "damage_description": "",
      "condition_found": "",
      "repair_type": "temporary|permanent|part_permanent|deferred",
      "repair_status": "completed|in_progress|not_started|deferred",
      "is_concerning_average": true
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
  "cause_narrative": "",
  "allegation_type": "formal_allegation|no_formal_allegation|tbc"
}

Return null for missing numeric fields. Return empty string for missing text fields. Dates in ISO format YYYY-MM-DD.''',
            },
          ],
        },
      ],
    });

    final content = response.data['content'] as List;
    final text = content
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join('\n');

    return FullReportExtraction.fromJson(_parseJson(text));
  }

  static Map<String, dynamic> _parseJson(String text) {
    try {
      var clean = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
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
    required this.attendees,
    required this.certificates,
    required this.repairs,
    required this.causeNarrative,
    required this.allegationType,
    required this.raw,
  });

  final Map<String, dynamic> reportMeta;
  final Map<String, dynamic> vessel;
  final List<Map<String, dynamic>> machinery;
  final List<Map<String, dynamic>> occurrences;
  final List<Map<String, dynamic>> damageItems;
  final List<Map<String, dynamic>> attendees;
  final List<Map<String, dynamic>> certificates;
  final Map<String, dynamic> repairs;
  final String causeNarrative;
  final String allegationType;
  final Map<String, dynamic> raw;

  // Summary of what was found
  int get totalFields {
    int count = 0;
    vessel.forEach((k, v) { if (v != null && v != '') count++; });
    count += machinery.length;
    count += occurrences.length;
    count += damageItems.length;
    count += attendees.length;
    count += certificates.length;
    if (causeNarrative.isNotEmpty) count++;
    return count;
  }

  bool get hasVesselData =>
      vessel.values.any((v) => v != null && v != '');
  bool get hasMachinery => machinery.isNotEmpty;
  bool get hasOccurrences => occurrences.isNotEmpty;
  bool get hasDamageItems => damageItems.isNotEmpty;
  bool get hasAttendees => attendees.isNotEmpty;
  bool get hasCertificates => certificates.isNotEmpty;

  factory FullReportExtraction.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String key) {
      final v = j[key];
      if (v == null) return [];
      if (v is List) {
        return v
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      return [];
    }

    Map<String, dynamic> map(String key) {
      final v = j[key];
      if (v is Map<String, dynamic>) return v;
      return {};
    }

    return FullReportExtraction(
      reportMeta:     map('report_meta'),
      vessel:         map('vessel'),
      machinery:      list('machinery'),
      occurrences:    list('occurrences'),
      damageItems:    list('damage_items'),
      attendees:      list('attendees'),
      certificates:   list('certificates'),
      repairs:        map('repairs'),
      causeNarrative: j['cause_narrative'] as String? ?? '',
      allegationType: j['allegation_type'] as String? ?? 'tbc',
      raw:            j,
    );
  }
}
