// lib/core/api/claude_api.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'usage_tracker.dart';

class ClaudeApi {
  static final _dio = () {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.anthropic.com/v1',
      headers: {
        'x-api-key': AppConfig.anthropicApiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        try {
          final data = response.data as Map<String, dynamic>?;
          final usage = data?['usage'] as Map<String, dynamic>?;
          if (usage != null) {
            final feature =
                response.requestOptions.extra['feature'] as String? ??
                    'api_call';
            final model =
                data?['model'] as String? ?? AppConfig.claudeModel;
            // ignore: discarded_futures
            UsageTracker.log(
              feature: feature,
              model: model,
              inputTokens:
                  (usage['input_tokens'] as num?)?.toInt() ?? 0,
              outputTokens:
                  (usage['output_tokens'] as num?)?.toInt() ?? 0,
            );
          }
        } catch (_) {}
        handler.next(response);
      },
    ));
    return dio;
  }();

  // ── Document / Certificate Extraction ─────────────────────────────────────

  /// Extract structured vessel data from a certificate image or PDF text
  static Future<Map<String, dynamic>> extractCertificateData({
    required String base64Image,
    required String mediaType, // 'image/jpeg', 'image/png', 'application/pdf'
    String? documentHint, // e.g. 'class certificate', 'SMC'
  }) async {
    final hint = documentHint != null
        ? 'This appears to be a $documentHint. '
        : '';

    final response = await _dio.post('/messages',
      options: Options(extra: {'feature': 'certificate_extraction'}),
      data: {
      'model': AppConfig.claudeModel,
      'max_tokens': AppConfig.claudeMaxTokens,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': base64Image,
              },
            },
            {
              'type': 'text',
              'text': '''${hint}Extract all data from this marine document and return ONLY a JSON object with no preamble or markdown. Include every field you can identify. Use these keys where applicable:

{
  "document_type": "",
  "cert_name": "",
  "vessel_name": "",
  "imo_number": "",
  "flag": "",
  "gross_tonnage": null,
  "net_tonnage": null,
  "deadweight": null,
  "length_oa": null,
  "breadth": null,
  "draft": null,
  "year_built": null,
  "build_yard": "",
  "build_country": "",
  "owners": "",
  "operators": "",
  "class_society": "",
  "class_notation": "",
  "issuing_authority": "",
  "issue_date": "",
  "expiry_date": "",
  "annual_survey_date": "",
  "cert_number": "",
  "port_of_registry": "",
  "language": "en",
  "additional_fields": {}
}

Return null for fields not found. Dates in ISO format YYYY-MM-DD.
If build_country is not explicitly stated, infer it from the build_yard address (e.g. "Hyundai, Ulsan, South Korea" → build_country = "South Korea").''',
            },
          ],
        },
      ],
    });

    final text = _extractText(response.data);
    return _parseJson(text);
  }

  // ── Vessel Particulars from PDF (DNV / Class reports) ─────────────────────

  /// Extract vessel particulars from a class society or DNV PDF report
  static Future<Map<String, dynamic>> extractVesselParticulars(
      String pdfText) async {
    final response = await _dio.post('/messages',
      options: Options(extra: {'feature': 'vessel_particulars'}),
      data: {
      'model': AppConfig.claudeModel,
      'max_tokens': AppConfig.claudeMaxTokens,
      'messages': [
        {
          'role': 'user',
          'content':
              '''Extract vessel particulars from this class society / DNV report text and return ONLY a JSON object:

$pdfText

Return:
{
  "vessel_name": "",
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
  "service_speed": null,
  "machinery": [
    {
      "machinery_type": "",
      "role": "",
      "make": "",
      "model": "",
      "quantity": 1,
      "mcr_kw": null,
      "mcr_rpm": null,
      "fuel_type": ""
    }
  ]
}

Dates in ISO format. Return null for missing fields.''',
        },
      ],
    });

    final text = _extractText(response.data);
    return _parseJson(text);
  }

  // ── Narrative Drafting ────────────────────────────────────────────────────

  /// Draft the occurrence background narrative from structured case data
  static Future<String> draftOccurrenceNarrative({
    required String vesselName,
    required String occurrenceDate,
    required String occurrenceLocation,
    required String occurrenceTitle,
    required List<String> damageItems,
    required String? interviewTranscript,
    required String reportFormat, // 'nordic' or 'abl'
  }) async {
    final damages = damageItems.join('\n- ');
    final transcriptSection = interviewTranscript != null
        ? '\n\nINTERVIEW TRANSCRIPT EXTRACT:\n$interviewTranscript'
        : '';

    final response = await _dio.post('/messages',
      options: Options(extra: {'feature': 'occurrence_narrative'}),
      data: {
      'model': AppConfig.claudeModel,
      'max_tokens': 1500,
      'messages': [
        {
          'role': 'user',
          'content':
              '''You are a marine surveyor drafting a Hull & Machinery survey report section in the $reportFormat format.

Draft the BACKGROUND / OCCURRENCE section (the owners' description of events leading up to the casualty) using the following information. Write in a precise, semi-legalistic technical register appropriate for a marine insurance report. Do not use bullet points — write flowing prose. Do not include headings. Do not add information not provided. 

VESSEL: $vesselName
DATE: $occurrenceDate
LOCATION: $occurrenceLocation
OCCURRENCE: $occurrenceTitle
DAMAGE ITEMS:
- $damages$transcriptSection

Draft the background narrative paragraph now:''',
        },
      ],
    });

    return _extractText(response.data);
  }

  /// Draft the cause consideration section
  static Future<String> draftCauseConsideration({
    required String vesselName,
    required String occurrenceTitle,
    required List<String> damageItems,
    required String? serviceEngineerFindings,
    required String reportFormat,
  }) async {
    final damages = damageItems.join('\n- ');
    final findings = serviceEngineerFindings != null
        ? '\n\nSERVICE ENGINEER / TECHNICAL FINDINGS:\n$serviceEngineerFindings'
        : '';

    final response = await _dio.post('/messages',
      options: Options(extra: {'feature': 'cause_consideration'}),
      data: {
      'model': AppConfig.claudeModel,
      'max_tokens': 1000,
      'messages': [
        {
          'role': 'user',
          'content':
              '''Draft the CAUSE CONSIDERATION section of a marine H&M survey report ($reportFormat format). Write in precise, semi-legalistic technical prose. One or two paragraphs. Do not speculate beyond the evidence provided.

VESSEL: $vesselName
OCCURRENCE: $occurrenceTitle
DAMAGE:
- $damages$findings

Draft the cause consideration now:''',
        },
      ],
    });

    return _extractText(response.data);
  }

  // ── Invoice Extraction ────────────────────────────────────────────────────

  /// Extract invoice data from a PDF or image
  static Future<Map<String, dynamic>> extractInvoiceData({
    required String base64Content,
    required String mediaType,
  }) async {
    final response = await _dio.post('/messages',
      options: Options(extra: {'feature': 'invoice_extraction'}),
      data: {
      'model': AppConfig.claudeModel,
      'max_tokens': AppConfig.claudeMaxTokens,
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
              'text': '''Extract all invoice data and return ONLY a JSON object:

{
  "supplier_name": "",
  "invoice_number": "",
  "invoice_date": "",
  "currency": "AUD",
  "total_amount": null,
  "gst_amount": null,
  "gst_excluded_amount": null,
  "description": "",
  "line_items": [
    {
      "item_ref": "",
      "description": "",
      "amount": null
    }
  ]
}

Dates in ISO format. Return null for missing fields.''',
            },
          ],
        },
      ],
    });

    final text = _extractText(response.data);
    return _parseJson(text);
  }

  // ── Photo Classification ──────────────────────────────────────────────────

  /// Suggest tags for a photo
  static Future<Map<String, dynamic>> classifyPhoto({
    required String base64Image,
    required String mediaType,
    String? context, // e.g. "engine room damage"
  }) async {
    final ctx = context != null ? ' Context: $context.' : '';

    final response = await _dio.post('/messages',
      options: Options(extra: {'feature': 'photo_classification'}),
      data: {
      'model': AppConfig.claudeModel,
      'max_tokens': 500,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': base64Image,
              },
            },
            {
              'type': 'text',
              'text':
                  '''Classify this marine survey photo and return ONLY a JSON object.$ctx

{
  "tag_category": "general_view|vessel_exterior|nameplate|certificate|damage|repair_in_progress|repair_completed|component_detail|logbook|other",
  "tag_subject": "",
  "tag_location": "",
  "tag_component": "",
  "tag_condition": "as_found|pre_repair|during_repair|post_repair|unknown",
  "suggested_caption": "",
  "report_section": "cover|vessel_particulars|occurrence|damage_description|repairs|appendix|other"
}''',
            },
          ],
        },
      ],
    });

    final text = _extractText(response.data);
    return _parseJson(text);
  }

  // ── Voice Note Routing ────────────────────────────────────────────────────

  /// Classify a transcribed voice note and suggest where to route it
  static Future<Map<String, dynamic>> routeVoiceNote(
      String transcript) async {
    final response = await _dio.post('/messages',
      options: Options(extra: {'feature': 'voice_routing'}),
      data: {
      'model': AppConfig.claudeModel,
      'max_tokens': 300,
      'messages': [
        {
          'role': 'user',
          'content':
              '''A marine surveyor recorded this voice note during a vessel survey. Classify it and return ONLY a JSON object:

"$transcript"

{
  "routed_to": "damage_item|checklist|doc_request|interview_question|occurrence_note|general_note",
  "summary": "",
  "action": ""
}''',
        },
      ],
    });

    final text = _extractText(response.data);
    return _parseJson(text);
  }

  // ── Correspondence Extraction ─────────────────────────────────────────────

  /// Extract parties, summary, action items and key dates from a PDF email trail.
  static Future<Map<String, dynamic>> extractCorrespondence({
    required String base64Pdf,
    String? filename,
  }) async {
    final hint = filename != null ? 'Filename: $filename.\n' : '';

    final response = await _dio.post(
      '/messages',
      options: Options(
        extra: {'feature': 'correspondence_extraction'},
        headers: {'anthropic-beta': 'pdfs-2024-09-25'},
      ),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 1500,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'document',
                'source': {
                  'type': 'base64',
                  'media_type': 'application/pdf',
                  'data': base64Pdf,
                },
              },
              {
                'type': 'text',
                'text': '''${hint}This is a marine insurance / survey correspondence document (email trail, letter, or report). Extract the following and return ONLY a JSON object with no preamble or markdown:

{
  "summary": "2-3 sentence summary of the overall correspondence",
  "sender": "primary sender name and organisation",
  "recipient": "primary recipient name and organisation",
  "corr_date": "date of most recent or primary communication in YYYY-MM-DD format, or null",
  "parties": [
    {"name": "", "company": "", "role": "e.g. Adjuster, Owner, Broker, Surveyor, Underwriter"}
  ],
  "key_dates": [
    "YYYY-MM-DD — description of the event"
  ],
  "action_items": [
    "action item or outstanding request"
  ],
  "decisions": [
    "key decision or agreement reached"
  ],
  "claim_reference": "",
  "vessel_name": "",
  "job_number": ""
}

Return null or empty array for fields not found. Dates in ISO format.''',
              },
            ],
          },
        ],
      },
    );

    final text = _extractText(response.data);
    return _parseJson(text);
  }

  // ── Email Classification ──────────────────────────────────────────────────

  /// Classify an incoming email and extract job number if present
  static Future<Map<String, dynamic>> classifyEmail({
    required String subject,
    required String bodyText,
  }) async {
    final response = await _dio.post('/messages',
      options: Options(extra: {'feature': 'email_classification'}),
      data: {
      'model': AppConfig.claudeModel,
      'max_tokens': 300,
      'messages': [
        {
          'role': 'user',
          'content':
              '''Classify this marine survey case email and return ONLY a JSON object:

SUBJECT: $subject
BODY: ${bodyText.length > 500 ? bodyText.substring(0, 500) : bodyText}

{
  "email_type": "instruction|claim_correspondence|info_request|info_provided|invoice_submission|report_distribution|adjuster_correspondence|broker_correspondence|owner_manager|other",
  "job_number": "",
  "case_reference": "",
  "vessel_name": "",
  "summary": ""
}

Return empty string if field not found.''',
        },
      ],
    });

    final text = _extractText(response.data);
    return _parseJson(text);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _extractText(dynamic responseData) {
    final content = responseData['content'] as List;
    return content
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join('\n');
  }

  static Map<String, dynamic> _parseJson(String text) {
    try {
      var clean = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final start = clean.indexOf('{');
      final end   = clean.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        clean = clean.substring(start, end + 1);
      }
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (e) {
      return {'error': 'Failed to parse response', 'raw': text};
    }
  }
}
