// lib/core/api/claude_api.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../services/ai_log_service.dart';
import 'usage_tracker.dart';

class ClaudeApi {
  static final _dio = () {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.anthropic.com/v1',
      headers: {
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
    ));
    // Read the key fresh on every request — it can change at runtime once
    // loaded from / edited in the account profile, without needing a
    // rebuild or app restart.
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['x-api-key'] = AppConfig.anthropicApiKey;
        handler.next(options);
      },
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        try {
          final data = response.data as Map<String, dynamic>?;
          final usage = data?['usage'] as Map<String, dynamic>?;
          if (usage != null) {
            final extra = response.requestOptions.extra;
            final feature = extra['feature'] as String? ?? 'api_call';
            final model   = data?['model'] as String? ?? AppConfig.claudeModel;
            final inputTokens  = (usage['input_tokens']  as num?)?.toInt() ?? 0;
            final outputTokens = (usage['output_tokens'] as num?)?.toInt() ?? 0;

            // ignore: discarded_futures
            UsageTracker.log(
              feature: feature,
              model: model,
              inputTokens:  inputTokens,
              outputTokens: outputTokens,
            );

            // GPN-AI audit log — only for calls tagged with a case_id
            final caseId   = extra['case_id']   as String?;
            final callType = extra['call_type']  as String?;
            if (caseId != null && callType != null) {
              // Extract prompt text from the last user message in the request
              final reqData  = response.requestOptions.data as Map<String, dynamic>?;
              final messages = reqData?['messages'] as List<dynamic>?;
              final lastMsg  = messages?.lastWhere(
                (m) => (m as Map<String, dynamic>)['role'] == 'user',
                orElse: () => null,
              ) as Map<String, dynamic>?;
              final content = lastMsg?['content'];
              final promptText = switch (content) {
                String s => s,
                List l => l
                    .whereType<Map<String, dynamic>>()
                    .where((c) => c['type'] == 'text')
                    .map((c) => c['text'] as String? ?? '')
                    .join('\n'),
                _ => '',
              };

              // Extract response text
              final respContent = data?['content'] as List<dynamic>?;
              final responseText = respContent
                      ?.whereType<Map<String, dynamic>>()
                      .where((c) => c['type'] == 'text')
                      .map((c) => c['text'] as String? ?? '')
                      .join('\n') ??
                  '';

              // ignore: discarded_futures
              AiLogService.log(
                caseId:       caseId,
                callType:     callType,
                model:        model,
                promptText:   promptText,
                responseText: responseText,
                sectionLabel: extra['section_label'] as String?,
                documentId:   extra['document_id']   as String?,
                inputTokens:  inputTokens,
                outputTokens: outputTokens,
              );
            }
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
    String? caseId,
    String? documentId,
  }) async {
    final hint = documentHint != null
        ? 'This appears to be a $documentHint. '
        : '';

    final response = await _dio.post('/messages',
      options: Options(extra: {
        'feature':  'certificate_extraction',
        if (caseId != null) 'case_id':    caseId,
        if (caseId != null) 'call_type':  'extraction',
        if (documentId != null) 'document_id': documentId,
      }),
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
    String? caseId,
    String? documentId,
  }) async {
    final response = await _dio.post('/messages',
      options: Options(extra: {
        'feature': 'nameplate_extraction',
        if (caseId != null) 'case_id':    caseId,
        if (caseId != null) 'call_type':  'extraction',
        if (documentId != null) 'document_id': documentId,
      }),
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
    String pdfText, {
    String? caseId,
    String? documentId,
  }) async {
    final response = await _dio.post('/messages',
      options: Options(extra: {
        'feature': 'vessel_particulars',
        if (caseId != null) 'case_id':    caseId,
        if (caseId != null) 'call_type':  'extraction',
        if (documentId != null) 'document_id': documentId,
      }),
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
    String? caseId,
  }) async {
    final damages = damageItems.join('\n- ');
    final transcriptSection = interviewTranscript != null
        ? '\n\nINTERVIEW TRANSCRIPT EXTRACT:\n$interviewTranscript'
        : '';

    final response = await _dio.post('/messages',
      options: Options(extra: {
        'feature':  'occurrence_narrative',
        if (caseId != null) 'case_id':   caseId,
        if (caseId != null) 'call_type': 'report_section',
        if (caseId != null) 'section_label': 'occurrence_narrative',
      }),
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

  /// Draft the cause consideration section. [ownersAllegation] is the
  /// owner's own stated cause (if any) — passed for context only; the
  /// model must never adopt or restate it as the surveyor's own view
  /// (spec §10 "Voice separation enforcement").
  static Future<String> draftCauseConsideration({
    required String vesselName,
    required String occurrenceTitle,
    required List<String> damageItems,
    required String? serviceEngineerFindings,
    required String reportFormat,
    String? ownersAllegation,
  }) async {
    final damages = damageItems.join('\n- ');
    final findings = serviceEngineerFindings != null
        ? '\n\nSERVICE ENGINEER / TECHNICAL FINDINGS:\n$serviceEngineerFindings'
        : '';
    final allegation = ownersAllegation != null && ownersAllegation.isNotEmpty
        ? '\n\nOWNERS\' STATED CAUSE (their words, provided for context only — '
          'do not adopt or restate this as your own finding):\n$ownersAllegation'
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
              '''Draft the surveyor's assessment for the CAUSE CONSIDERATION section of a marine H&M survey report ($reportFormat format). Write in precise, semi-legalistic technical prose. One or two paragraphs. Do not speculate beyond the evidence provided.

This must be written entirely in the surveyor's own voice — introduce it with a phrase such as "It is the view of the Undersigned Surveyor that…" or "In the opinion of the Undersigned…". If owner's stated cause context is provided below, do not restate it as fact or blend it into your own sentence — your text is the surveyor's independent assessment, not a summary of the owner's account.

VESSEL: $vesselName
OCCURRENCE: $occurrenceTitle
DAMAGE:
- $damages$findings$allegation

Draft the surveyor's assessment now:''',
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
    String? caseId,
    String? documentId,
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
        extra: {
          'feature': 'document_extraction',
          if (caseId != null) 'case_id':    caseId,
          if (caseId != null) 'call_type':  'extraction',
          if (documentId != null) 'document_id': documentId,
        },
        headers: isPdf ? {'anthropic-beta': 'pdfs-2024-09-25'} : null,
      ),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 4000,
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
  "detected_class_conditions": [
    {
      "reference": "condition reference number e.g. CC-2024-001 or Recommendation 2024-001",
      "description": "brief 1-2 sentence description of what the condition requires",
      "expiry_date": "YYYY-MM-DD or null"
    }
  ],
  "vessel_data": {
    "vessel_name": "",
    "previous_name": "",
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
- detected_machinery: list each distinct machinery item that is a subject of the document (surveyed, serviced, inspected, or described with any technical detail); include make/model/serial when present but do not require them; leave as [] only for items mentioned purely in passing with no context
- detected_class_conditions: for class survey reports, condition-of-class documents, and class survey certificates, extract EVERY Condition of Class and Recommendation listed — include reference number, description, and expiry/due date; leave as [] for all other document types
- vessel_data: populate for ANY document that contains vessel identification data — this includes intelligence/registration documents (Equasis, Lloyd's Register, flag state registry, class certificates, vessel particulars sheets) AND class survey reports, condition-of-class documents, PSC inspection reports, and service reports that carry vessel name, IMO, flag, or class notation; omit fields not present in the document; numeric values must be numbers; leave as {} only if the document contains no vessel identification at all
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
    String? caseId,
    String? documentId,
  }) async {
    final isImage = mediaType.startsWith('image/');
    final contentBlock = isImage
        ? {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': mediaType,
              'data': base64Content,
            },
          }
        : {
            'type': 'document',
            'source': {
              'type': 'base64',
              'media_type': mediaType,
              'data': base64Content,
            },
          };

    final response = await _dio.post('/messages',
      options: Options(extra: {
        'feature': 'invoice_extraction',
        if (caseId != null) 'case_id':    caseId,
        if (caseId != null) 'call_type':  'invoice_extraction',
        if (documentId != null) 'document_id': documentId,
      }),
      data: {
      'model': AppConfig.claudeModel,
      'max_tokens': AppConfig.claudeMaxTokens,
      'messages': [
        {
          'role': 'user',
          'content': [
            contentBlock,
            {
              'type': 'text',
              'text': '''You are a marine insurance claims assistant. Extract all data from this invoice/document for a marine survey case account and return ONLY a JSON object.

{
  "document_type": "invoice|estimate|credit_note|proforma|quotation|purchase_order|delivery_note",
  "document_number": "invoice or document reference number, or null",
  "document_date": "YYYY-MM-DD or null",
  "due_date": "YYYY-MM-DD or null",
  "contract_ref": "any PO, contract, or work-order reference, or null",
  "supplier_name": "company name issuing the document, or null",
  "supplier_category": "oem_dealer|oem_direct|independent_workshop|electrical_specialist|hydraulic_specialist|ndt_specialist|diving_services|dry_dock_operator|port_authority|port_services_co|shipping_agency|freight_domestic|freight_international|tool_hire_co|industrial_supply|class_society|naval_architect|legal_professional|other",
  "currency": "3-letter ISO code, default AUD",
  "subtotal_ex_tax": null,
  "tax_total": null,
  "total_inc_tax": null,
  "mixed_nature_flag": false,
  "account_lines": [
    {
      "item_number": 1,
      "description": "exact verbatim text from the invoice line item as it appears on the document — do not paraphrase",
      "cost_nature": "service_technician|specialist_engineer|repairer_workshop|dry_dock_slipway|diving_contractor|inspection_survey|superintendency|access_staging|mobilisation|demobilisation|surface_treatment|testing_commissioning|tool_hire|spare_parts|equipment|freight_domestic|freight_international|port_services|waste_disposal|accommodation|catering|crew_expenses|professional_fees|owners_maintenance|class_statutory|other",
      "gross_amount": 0.0,
      "owners_note": "brief reason if this line might be owner's maintenance, or null"
    }
  ],
  "raw_lines": [
    {"description": "exact line item text", "amount": null}
  ],
  "ai_presentation_draft": "Start with 'This invoice appears to be' then describe in 1–2 sentences what this document covers in general terms; plain factual prose; do NOT include monetary amounts, currencies, or numeric figures",
  "confidence": 0.9
}

Rules:
- account_lines: list items in the SAME ORDER they appear in the invoice from top to bottom; item_number matches the printed line number or sequential order as on document
- description: copy the EXACT text from each line item — verbatim, not summarized
- cost_nature: classify by the TYPE of service/work (who/what is doing it), not whether repair is permanent or temporary
- mixed_nature_flag: true when line items span both U/W damage repair and owner maintenance
- confidence: 0.0-1.0 reflecting extraction certainty
- Dates in ISO format. Null for missing fields.''',
            },
          ],
        },
      ],
    });

    final text = _extractText(response.data);
    return _parseJson(text);
  }

  // ── Multi-invoice PDF analysis ────────────────────────────────────────────

  /// Analyse a PDF that may contain multiple individual invoices/documents.
  /// Returns a JSON array of invoice segments with page ranges and relevance.
  static Future<List<Map<String, dynamic>>> analyzeMultiInvoicePdf({
    required String base64Content,
    required String mediaType,
  }) async {
    final response = await _dio.post('/messages',
      options: Options(extra: {'feature': 'batch_invoice_analysis'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': AppConfig.claudeMaxTokens,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'document',
                'source': {
                  'type': 'base64',
                  'media_type': mediaType,
                  'data': base64Content,
                },
              },
              {
                'type': 'text',
                'text': '''You are a marine insurance claims assistant. This PDF may contain multiple individual invoices or documents bundled together.

Identify each distinct invoice or document and return ONLY a JSON array. Each element:

[
  {
    "page_start": 1,
    "page_end": 2,
    "supplier_name": "Acme Marine Pty Ltd",
    "invoice_number": "INV-2024-001",
    "date": "2024-03-15",
    "currency": "AUD",
    "total_amount": 12500.00,
    "submitted_to_insurance": true,
    "reason": "Direct damage repair — plating and welding work on hull",
    "confidence": 0.92
  }
]

Rules:
- page_start / page_end: 1-based page numbers for this document
- submitted_to_insurance: true if the document appears to have been submitted as part of a claim (look for claim references, highlighting, cover letter inclusions, damage-related descriptions). false if it appears to be context only (routine maintenance, unrelated work, owner's expense items explicitly marked as such)
- reason: one sentence explaining the submitted_to_insurance decision
- confidence: 0.0–1.0 for your overall extraction certainty
- If the entire PDF is a single invoice, return an array with one element
- Do not merge separate invoices even if from the same supplier
- Return ONLY the JSON array, no other text''',
              },
            ],
          },
        ],
      },
    );

    final text = _extractText(response.data);
    try {
      var clean = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final start = clean.indexOf('[');
      final end   = clean.lastIndexOf(']');
      if (start != -1 && end != -1 && end > start) {
        clean = clean.substring(start, end + 1);
      }
      final list = jsonDecode(clean) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
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
    String? caseId,
    String? documentId,
  }) async {
    final hint = filename != null ? 'Filename: $filename.\n' : '';

    final response = await _dio.post(
      '/messages',
      options: Options(
        extra: {
          'feature': 'correspondence_extraction',
          if (caseId != null) 'case_id':    caseId,
          if (caseId != null) 'call_type':  'extraction',
          if (documentId != null) 'document_id': documentId,
        },
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
  "technical_file_no": "surveyor's job or file number if mentioned, or null",
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
  "technical_file_no": "surveyor's job or file number if mentioned, or null",
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
  "technical_file_no": "",
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

  // ── Image Orientation Detection ──────────────────────────────────────────

  /// Returns the number of clockwise quarter-turns (0–3) needed to make a
  /// document image upright and readable. Downloads the image from [signedUrl],
  /// sends it to Claude Haiku (cheap/fast), and parses the result.
  static Future<int> detectImageOrientation({
    required String signedUrl,
    required String mediaType,
  }) async {
    final fetchDio = Dio();
    final fetchResp = await fetchDio.get<List<int>>(
      signedUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final b64 = base64Encode(fetchResp.data!);

    final aiResp = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'image_orientation'}),
      data: {
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 10,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': mediaType,
                  'data': b64,
                },
              },
              {
                'type': 'text',
                'text': 'This is a document image (invoice, letter, or form). '
                    'Reply with ONLY a single integer — the number of degrees '
                    'clockwise this image must be rotated to appear upright '
                    'and readable. Choose from: 0, 90, 180, 270.',
              },
            ],
          },
        ],
      },
    );

    final text = _extractText(aiResp.data).trim();
    final match = RegExp(r'\d+').firstMatch(text);
    final angle = int.tryParse(match?.group(0) ?? '0') ?? 0;
    return switch (angle) {
      90  => 1,
      180 => 2,
      270 => 3,
      _   => 0,
    };
  }

  // ── Document Corner Detection ─────────────────────────────────────────────

  /// Detects the four corners of a document / paper visible in a photo.
  ///
  /// [base64Image] – already-encoded image bytes.
  /// [mediaType]   – e.g. 'image/jpeg'.
  ///
  /// Returns [TL, TR, BR, BL] as `[x, y]` pairs (normalized 0–1) or null if
  /// the document could not be reliably detected.
  static Future<List<List<double>>?> detectDocumentCorners({
    required String base64Image,
    required String mediaType,
  }) async {
    final aiResp = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'document_corner_detection'}),
      data: {
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 60,
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
                'text': 'Find the four corners of the flat document, paper, '
                    'invoice, or form photographed here. '
                    'Reply with ONLY the corner coordinates as decimal '
                    'fractions of image width (x) and height (y), '
                    'in this exact order: top-left, top-right, bottom-right, '
                    'bottom-left. Format: x1,y1 x2,y2 x3,y3 x4,y4\n'
                    'Values must be between 0.0 and 1.0. '
                    'If a corner is off-screen or unclear, estimate its '
                    'position rather than omitting it. '
                    'If no document is visible at all, reply with: none',
              },
            ],
          },
        ],
      },
    );

    final text = _extractText(aiResp.data).trim().toLowerCase();
    if (text == 'none' || text.isEmpty) return null;

    try {
      final parts = text.trim().split(RegExp(r'\s+'));
      if (parts.length < 3) return null;

      List<double> parseXY(String s) {
        final xy = s.split(',');
        return [double.parse(xy[0]), double.parse(xy[1])];
      }

      final corners = parts.take(4).map(parseXY).toList();

      // If only 3 corners came back, recover BL via parallelogram:
      // BL = TL + BR − TR  (works well for near-rectangular documents)
      if (corners.length == 3) {
        final tl = corners[0], tr = corners[1], br = corners[2];
        final blX = (tl[0] + br[0] - tr[0]).clamp(0.0, 1.0);
        final blY = (tl[1] + br[1] - tr[1]).clamp(0.0, 1.0);
        corners.add([blX, blY]);
      }

      return corners;
    } catch (_) {
      return null;
    }
  }

  // ── Surveyor Note Polish ──────────────────────────────────────────────────

  /// Clean up a dictated or rough surveyor note into polished professional prose.
  /// Reads an invoice/document and extracts non-accounting observations
  /// (timesheets, hours, scope descriptions, certifications, etc.)
  /// Returns a list of maps: {content, priority ('important'|'normal')}
  static Future<List<Map<String, dynamic>>> extractInvoiceContextCues({
    required String base64Content,
    required String mediaType,
  }) async {
    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'invoice_context_cues'}),
      data: {
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 1200,
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
                'text': '''You are assisting a marine insurance surveyor reviewing a repair invoice or document.

Your task: identify any NON-ACCOUNTING information present in this document that would be useful context for the survey. Focus on:
- Hours worked / timesheets / labour breakdown
- Scope of work descriptions or repair narratives
- Certification numbers, class approvals, or warranty references
- Delivery dates, mobilisation/demobilisation details
- Specialist equipment or techniques mentioned
- Any notes from the repairer about findings or conditions
- Anomalies, additional observations, or qualifications

Do NOT extract financial figures, totals, invoice numbers, supplier names, or dates — those are already captured.

If you find relevant context cues, return them as a JSON array. Each item must have:
- "content": the cue text (concise, factual, professional)
- "priority": "important" if it has significant claim implications, otherwise "normal"

If there is nothing non-accounting to extract, return an empty array.

Return ONLY valid JSON — no preamble, no explanation. Example:
[{"content": "Labour breakdown: 8 hours at standard rate, 4 hours overtime.", "priority": "normal"}]''',
              },
            ],
          },
        ],
      },
    );

    final text = _extractText(response.data).trim();
    try {
      var clean = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final start = clean.indexOf('[');
      final end   = clean.lastIndexOf(']');
      if (start < 0 || end < 0) return [];
      clean = clean.substring(start, end + 1);
      final list = jsonDecode(clean) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<String> polishSurveyorNote(String rawText) async {
    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'surveyor_note_polish'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 600,
        'messages': [
          {
            'role': 'user',
            'content':
                '''You are assisting a marine surveyor. Clean up the following dictated or rough note into polished, professional prose suitable for a marine insurance survey report. Preserve all factual content and meaning. Correct grammar, punctuation, and sentence structure. Do not add information not present. Do not use bullet points — write flowing prose. Return ONLY the cleaned-up text, no preamble or explanation.

NOTE TO POLISH:
$rawText''',
          },
        ],
      },
    );
    return _extractText(response.data).trim();
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
