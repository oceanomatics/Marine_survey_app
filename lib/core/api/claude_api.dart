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
  "vessel_type": "",
  "flag": "",
  "port_of_registry": "",
  "gross_tonnage": null,
  "net_tonnage": null,
  "deadweight": null,
  "holds_count": null,
  "tanks_count": null,
  "length_oa": null,
  "length_bp": null,
  "breadth": null,
  "breadth_qualifier": "",
  "depth": null,
  "max_draft": null,
  "draft_qualifier": "",
  "year_built": null,
  "build_yard": "",
  "build_country": "",
  "owners": "",
  "operators": "",
  "class_society": "",
  "class_notation": "",
  "service_speed": null,
  "propulsion_type": "",
  "propeller_type": "",
  "propulsion_drive_type": "",
  "mcr_power_value": null,
  "mcr_rpm": null,
  "mcr_power_unit": "kW",
  "issuing_authority": "",
  "issue_date": "",
  "expiry_date": "",
  "annual_survey_date": "",
  "cert_number": "",
  "language": "en",
  "additional_fields": {}
}

Return null for fields not found. Dates in ISO format YYYY-MM-DD.
If build_country is not explicitly stated, infer it from the build_yard address.
For qualifiers: breadth_qualifier from "Moulded Breadth|Extreme Breadth|Beam (OA)|Breadth|Beam"; draft_qualifier from "Load Line Draft|Max Draft|Draft".''',
            },
          ],
        },
      ],
    });

    final text = _extractText(response.data);
    return _parseJson(text);
  }

  // ── Nameplate Extraction ──────────────────────────────────────────────────

  /// Extract structured data from a machinery or equipment nameplate photo.
  static Future<Map<String, dynamic>> extractNameplate({
    required String base64Image,
    required String mediaType,
  }) async {
    final response = await _dio.post('/messages',
      options: Options(extra: {'feature': 'nameplate_extraction'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 600,
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
                'text': '''This is a machinery or equipment nameplate from a marine vessel. Extract every readable field and return ONLY a JSON object with no preamble or markdown:

{
  "manufacturer": "",
  "model": "",
  "part_number": "",
  "serial_number": "",
  "date_of_manufacture": "",
  "rated_power_kw": null,
  "rated_rpm": null,
  "voltage_v": null,
  "frequency_hz": null,
  "current_a": null,
  "weight_kg": null,
  "additional_info": ""
}

Rules:
- Return null for numeric fields not found, "" for text fields not found.
- date_of_manufacture: year only is fine (e.g. "2009"), or ISO date if full date visible.
- rated_power_kw: convert from kW, bhp, or hp — store in kW (1 hp = 0.7457 kW, 1 bhp = 0.7457 kW).
- additional_info: any other text on the nameplate not captured above (certifications, standards, class marks, etc.) as a single readable string.
- If a value is partially legible, include what you can read.''',
              },
            ],
          },
        ],
      },
    );

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

Return ONLY valid JSON, no preamble:
{
  "vessel_name": "",
  "imo_number": "",
  "vessel_type": "",
  "flag": "",
  "port_of_registry": "",
  "gross_tonnage": null,
  "net_tonnage": null,
  "deadweight": null,
  "holds_count": null,
  "tanks_count": null,
  "length_oa": null,
  "length_bp": null,
  "breadth": null,
  "breadth_qualifier": "",
  "depth": null,
  "max_draft": null,
  "draft_qualifier": "",
  "year_built": null,
  "build_yard": "",
  "build_country": "",
  "owners": "",
  "operators": "",
  "class_society": "",
  "class_notation": "",
  "service_speed": null,
  "propulsion_type": "",
  "propeller_type": "",
  "propulsion_drive_type": "",
  "mcr_power_value": null,
  "mcr_rpm": null,
  "mcr_power_unit": "kW",
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

Field guidance:
- breadth_qualifier: choose from "Moulded Breadth", "Extreme Breadth", "Beam (OA)", "Breadth", "Beam"
- draft_qualifier: choose from "Load Line Draft", "Max Draft", "Draft"
- propulsion_type: choose from "single screw, motor driven", "twin screw, motor driven", "single screw, steam turbine driven"
- propeller_type: choose from "Single screw fixed pitch", "Twin screw fixed pitch", "Single Azipod", "Twin Azipods", "Single screw variable pitch", "Twin screw variable pitch", "Water Jet"
- propulsion_drive_type: choose from "Direct drive", "Via reduction gearbox", "Via double reduction gearbox", "Electric Motor"
- mcr_power_value: numeric MCR value; set mcr_power_unit to "kW" or "bhp"
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

  // ── Sub-causation narrative draft ─────────────────────────────────────────

  /// Draft a concise sub-causation / contributing factors narrative for the
  /// Allegation / Causation section of a marine survey report.
  static Future<String> draftSubCausation({
    required String occurrenceTitle,
    required String causeTypeLabel,
    required String? allegationType,
    required String? briefDescription,
    required String? backgroundNarrative,
    required List<String> contextCues,
  }) async {
    final cuesText = contextCues.isNotEmpty
        ? '\n\nSURVEYOR CONTEXT CUES:\n${contextCues.map((c) => '• $c').join('\n')}'
        : '';
    final bgText = backgroundNarrative != null && backgroundNarrative.isNotEmpty
        ? '\n\nBACKGROUND:\n$backgroundNarrative'
        : '';
    final descText = briefDescription != null && briefDescription.isNotEmpty
        ? '\n\nBRIEF DESCRIPTION:\n$briefDescription'
        : '';
    final allegLabel = switch (allegationType) {
      'formal_allegation'    => 'Formal allegation raised',
      'no_formal_allegation' => 'No formal allegation raised',
      _                      => 'Allegation status TBC',
    };

    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'sub_causation_draft'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 600,
        'messages': [
          {
            'role': 'user',
            'content': '''Draft a concise SUB-CAUSATION / CONTRIBUTING FACTORS paragraph (2–4 sentences) for a marine survey report.
Write in precise technical prose. Explain the sequence of events or contributing factors that led to this casualty. Do not speculate beyond the information provided.

OCCURRENCE: $occurrenceTitle
CAUSE TYPE: $causeTypeLabel
ALLEGATION STATUS: $allegLabel$descText$bgText$cuesText

Draft the sub-causation paragraph now (plain text, no headers or markdown):''',
          },
        ],
      },
    );
    return _extractText(response.data);
  }

  // ── Generalized Document Extraction ──────────────────────────────────────

  /// Extract hard structured data + soft context findings from any marine doc.
  /// Works with PDFs (via the Anthropic PDF beta) and images.
  static Future<Map<String, dynamic>> extractDocument({
    required String base64Content,
    required String mediaType,
    required String categoryHint,
  }) async {
    final isPdf = mediaType == 'application/pdf';
    final contentBlock = isPdf
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

    final response = await _dio.post(
      '/messages',
      options: Options(
        extra: {'feature': 'document_extraction'},
        headers: isPdf ? {'anthropic-beta': 'pdfs-2024-09-25'} : null,
      ),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 2000,
        'messages': [
          {
            'role': 'user',
            'content': [
              contentBlock,
              {
                'type': 'text',
                'text': '''You are extracting data from a marine survey document (category hint: $categoryHint).

IMPORTANT: All text in the output MUST be in English. Translate any non-English content.

Extract ALL information and return ONLY valid JSON with no preamble or markdown:

{
  "document_type": "specific type of this document",
  "suggested_category": "certificate|class_survey_report|condition_of_class|previous_survey_report|service_report|logbook_extract|maintenance_record|statement_of_facts|incident_report|oil_analysis|invoice|intelligence_report|other",
  "hard_fields": {
    "vessel_name": "",
    "imo_number": "",
    "document_date": "",
    "document_number": "",
    "issuing_authority": "",
    "expiry_date": "",
    "next_due_date": "",
    "survey_date": "",
    "port_of_survey": "",
    "class_society": "",
    "class_notation": "",
    "surveyor_name": "",
    "component": "",
    "serial_number": "",
    "manufacturer": "",
    "model_ref": "",
    "hours_run": null,
    "next_service_hours": null,
    "invoice_number": "",
    "supplier": "",
    "amount": null,
    "currency": ""
  },
  "context_findings": [
    {
      "text": "Brief factual statement in English about a finding, condition, observation, or recommendation",
      "note_category": "observation|measurement|technical|operations|previous_works|follow_up|interview|policy|general"
    }
  ],
  "detected_incidents": [
    {
      "title": "Short title for the incident or occurrence",
      "date": "YYYY-MM-DD or null",
      "location": "place or null",
      "description": "1-2 sentence description in English"
    }
  ],
  "detected_machinery": [
    {
      "machinery_type": "descriptive name e.g. Main Engine, Turbocharger",
      "role": "main_engine|diesel_generator|turbocharger|gearbox|thruster|pump|compressor|crane|other",
      "make": "",
      "model": "",
      "serial_number": "",
      "mcr_kw": null,
      "mcr_rpm": null,
      "fuel_type": ""
    }
  ],
  "vessel_data": {
    "vessel_name": "",
    "imo_number": "",
    "call_sign": "",
    "mmsi": "",
    "vessel_type": "",
    "flag": "",
    "port_of_registry": "",
    "gross_tonnage": null,
    "net_tonnage": null,
    "deadweight": null,
    "holds_count": null,
    "tanks_count": null,
    "length_oa": null,
    "length_bp": null,
    "breadth": null,
    "breadth_qualifier": "",
    "depth": null,
    "max_draft": null,
    "draft_qualifier": "",
    "year_built": null,
    "build_yard": "",
    "build_country": "",
    "owners": "",
    "operators": "",
    "class_society": "",
    "class_notation": "",
    "service_speed": null,
    "propulsion_type": "",
    "propeller_type": "",
    "propulsion_drive_type": "",
    "mcr_power_value": null,
    "mcr_rpm": null,
    "mcr_power_unit": "kW"
  }
}

Rules:
- hard_fields: include ONLY fields actually present in the document; omit absent fields entirely; dates MUST be YYYY-MM-DD; numeric values must be numbers not strings
- context_findings: each item must have a "text" and a "note_category"; choose the most fitting category; translate text to English
- detected_incidents: only populate if the document describes a specific physical incident, casualty, accident, or occurrence event; PSC inspections, detentions, and port state deficiencies are NOT incidents — add them as context_findings with note_category "operations"; leave detected_incidents as [] if none
- detected_machinery: list each distinct machinery item mentioned with technical data; leave as [] if none or if only named in passing without any technical detail
- vessel_data: populate for intelligence/registration documents (Equasis, Lloyd's Register, flag state registry, class certificates, vessel particulars sheets, etc.); omit fields not present; numeric values must be numbers; leave as {} if not applicable
- vessel_data field guidance:
  · breadth_qualifier: if stated, choose closest from: "Moulded Breadth", "Extreme Breadth", "Beam (OA)", "Breadth", "Beam"
  · draft_qualifier: if stated, choose closest from: "Load Line Draft", "Max Draft", "Draft"
  · propulsion_type: if stated, choose closest from: "single screw, motor driven", "twin screw, motor driven", "single screw, steam turbine driven"
  · propeller_type: if stated, choose closest from: "Single screw fixed pitch", "Twin screw fixed pitch", "Single Azipod", "Twin Azipods", "Single screw variable pitch", "Twin screw variable pitch", "Water Jet"
  · propulsion_drive_type: if stated, choose closest from: "Direct drive", "Via reduction gearbox", "Via double reduction gearbox", "Electric Motor"
  · mcr_power_value: the numeric MCR power value; set mcr_power_unit to "kW" or "bhp" accordingly
  · holds_count: integer number of cargo holds (cargo ships, bulk carriers)
  · tanks_count: integer number of cargo tanks (tankers, chemical carriers)
- Return ONLY the JSON object, no other text''',
              },
            ],
          },
        ],
      },
    );

    final text = _extractText(response.data);
    return _parseJson(text);
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
    {"name": "", "company": "", "role": "e.g. Adjuster, Owner, Broker, Surveyor, Underwriter", "email": "", "phone": ""}
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
  "claim_reference": "underwriter or P&I claim / file reference, or null",
  "vessel_name": "name of the vessel, or null",
  "job_number": "surveyor's job or file number if mentioned, or null",
  "instruction_date": "YYYY-MM-DD date when surveyors are formally instructed to attend, or null if not explicitly stated"
}

Return null or empty array for fields not found. Dates in ISO format. For parties, include email and phone only when explicitly present in the document.''',
              },
            ],
          },
        ],
      },
    );

    final text = _extractText(response.data);
    return _parseJson(text);
  }

  /// Extract parties, summary, action items and key dates from plain-text email.
  static Future<Map<String, dynamic>> extractCorrespondenceFromText({
    required String subject,
    required String bodyText,
    String? from,
    String? to,
  }) async {
    final emailContent = [
      if (from != null && from.isNotEmpty) 'From: $from',
      if (to != null && to.isNotEmpty) 'To: $to',
      'Subject: $subject',
      '',
      bodyText,
    ].join('\n');

    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'correspondence_extraction'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 1500,
        'messages': [
          {
            'role': 'user',
            'content':
                '''This is a marine insurance / survey email. Extract the following and return ONLY a JSON object with no preamble or markdown:

$emailContent

{
  "summary": "2-3 sentence summary of the overall correspondence",
  "sender": "primary sender name and organisation",
  "recipient": "primary recipient name and organisation",
  "corr_date": "date of the email in YYYY-MM-DD format, or null",
  "parties": [
    {"name": "", "company": "", "role": "e.g. Adjuster, Owner, Broker, Surveyor, Underwriter", "email": "", "phone": ""}
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
  "claim_reference": "underwriter or P&I claim / file reference, or null",
  "vessel_name": "name of the vessel, or null",
  "job_number": "surveyor's job or file number if mentioned, or null",
  "instruction_date": "YYYY-MM-DD date when surveyors are formally instructed to attend, or null if not explicitly stated"
}

Return null or empty array for fields not found. Dates in ISO format. For parties, include email and phone only when explicitly present in the document.''',
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
