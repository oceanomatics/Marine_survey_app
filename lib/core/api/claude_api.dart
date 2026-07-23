// lib/core/api/claude_api.dart

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../services/ai_log_service.dart';
import 'usage_tracker.dart';

/// Zone key carrying the case a Claude call belongs to. Set by
/// AiTasksNotifier.run() (which wraps every AI call in the app and already
/// receives the caseId), read by the usage/audit interceptor below as a
/// fallback when a call site didn't thread caseId explicitly into the
/// ClaudeApi method. This is how token_usage.case_id gets populated without
/// adding a caseId parameter to ~25 call sites (14 July 2026 walkthrough §25
/// — the by-case usage grouping was empty because case_id was null on nearly
/// every row).
const aiTaskCaseIdZoneKey = #aiTaskCaseId;

/// Shared instruction block appended to every narrative report-section
/// drafting prompt. Encodes the non-negotiable parts of the Writing Style
/// Rulebook (docs/report_builder_editor_notes.md) so AI-drafted text is
/// compliant by construction rather than relying solely on the surveyor
/// catching violations at review. Kept short — this is guidance for the
/// model, not the full rulebook.
const _writingStyleGuardrails = '''

WRITING STYLE RULES (must follow):
- Refer to the surveyor only as "the Undersigned" or "the Undersigned Surveyor" — never "I", "we", "my", or "our".
- Mark any information not directly witnessed by the surveyor with an attribution phrase such as "reportedly", "according to the Master…", or "it is understood that…" — never state an unwitnessed event as if it were directly observed fact.
- Do not use unquantified qualifiers ("apparently", "seemingly", "obviously") or vague conditions ("good condition", "fair wear and tear") without stating the standard or basis for the description.
- Do not use emotive or speculative language ("unfortunately", "clearly", "as anyone can see").
- Keep a neutral, factual, third-person register throughout.
- Refer to the vessel as "the subject vessel" (name it once at most, then use "the subject vessel").''';

/// Calibrated-hedging rules (docs/house_style.md GLOBAL RULE). Appended to the
/// drafting prompts where an inference, cause, or prediction is being drawn
/// (Cause / Damage / Repairs / Nature of Repairs). The goal is calibrated
/// confidence — state firmly what was observed, hedge only what is inferred —
/// NOT blanket qualification, which is itself a fault.
const _calibratedHedging = '''

CALIBRATED HEDGING (match the verb to the evidence — do not over-hedge):
- Directly observed by the surveyor: state it as fact, no hedge.
- Reported by others / not personally witnessed: attribute it ("it was reported that", "the Master advised"), do not adopt it as your own finding.
- Inferred cause or mechanism: apply ONE calibrated qualifier ("is consistent with", "appears to", "likely", "on balance", "the evidence points to") — never a stack of them.
- Predicted / future / unverified: hedge and state the dependency ("pending inspection at docking", "would be unlikely", "could foreseeably").
Reserve "is consistent with" for the damage-to-mechanism link. One hedge per proposition — if a sentence carries two qualifiers, delete one. A run of observed facts should read cleanly; the hedge appears only at the point a conclusion is drawn from them. Where a fact could not be verified or a measurement was not taken, say so plainly ("not confirmed", "measurements were not taken").''';

/// Per-object data-capture rule (docs/house_style.md). Appended to the
/// drafting prompts whose source material is structured/object-oriented
/// (Damage, Cause, Repairs). Forces every hard field to be consumed before
/// prose is written, with an explicit "Not confirmed" for present-but-empty
/// fields rather than silent omission.
const _dataCaptureRule = '''

DATA-CAPTURE RULE: consume EVERY hard field and object below before writing prose. Do not summarise past a field or collapse a per-object record into a generic statement. Carry each named object/component with its identifier, condition/mode, and measurements exactly as recorded. Where a field is present in the source but has no value, write "Not confirmed" rather than omitting it — a reader should be able to reconstruct the full inventory from your text alone.''';

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
            final model = data?['model'] as String? ?? AppConfig.claudeModel;
            final inputTokens = (usage['input_tokens'] as num?)?.toInt() ?? 0;
            final outputTokens = (usage['output_tokens'] as num?)?.toInt() ?? 0;
            // Prefer an explicit case_id on the request; fall back to the
            // ambient one set by AiTasksNotifier.run() (see zone key above)
            // so calls that don't thread caseId still attribute correctly.
            final caseId = (extra['case_id'] as String?) ??
                (Zone.current[aiTaskCaseIdZoneKey] as String?);

            // Pass caseId so token_usage attributes cost to the case (14 July
            // 2026 walkthrough §25 — the API Usage screen's by-case grouping
            // was showing nothing because this call dropped the case_id that
            // was sitting right here in `extra`, writing every row null).
            // ignore: discarded_futures
            UsageTracker.log(
              caseId: caseId,
              feature: feature,
              model: model,
              inputTokens: inputTokens,
              outputTokens: outputTokens,
            );

            // GPN-AI audit log — only for calls tagged with a case_id
            final callType = extra['call_type'] as String?;
            if (caseId != null && callType != null) {
              // Extract prompt text from the last user message in the request
              final reqData =
                  response.requestOptions.data as Map<String, dynamic>?;
              final messages = reqData?['messages'] as List<dynamic>?;
              final lastMsg = messages?.lastWhere(
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
                caseId: caseId,
                callType: callType,
                model: model,
                promptText: promptText,
                responseText: responseText,
                sectionLabel: extra['section_label'] as String?,
                documentId: extra['document_id'] as String?,
                inputTokens: inputTokens,
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
    final hint =
        documentHint != null ? 'This appears to be a $documentHint. ' : '';

    final response = await _dio.post('/messages',
        options: Options(extra: {
          'feature': 'certificate_extraction',
          if (caseId != null) 'case_id': caseId,
          if (caseId != null) 'call_type': 'extraction',
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
                  'text':
                      '''${hint}Extract all data from this marine document and return ONLY a JSON object with no preamble or markdown. Include every field you can identify. Use these keys where applicable:

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
  "screw_count": null,
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
    final response = await _dio.post(
      '/messages',
      options: Options(extra: {
        'feature': 'nameplate_extraction',
        if (caseId != null) 'case_id': caseId,
        if (caseId != null) 'call_type': 'extraction',
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
                'text':
                    '''This is a machinery or equipment nameplate from a marine vessel. Extract every readable field and return ONLY a JSON object with no preamble or markdown:

{
  "manufacturer": "",
  "model": "",
  "part_number": "",
  "serial_number": "",
  "date_of_manufacture": "",
  "rated_power_kw": null,
  "rated_rpm": null,
  "fuel_type": "",
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
- fuel_type: only if stated/derivable from the plate — choose closest from "MGO", "MDO", "HFO", "Dual fuel", "Gas"; otherwise "".
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
          if (caseId != null) 'case_id': caseId,
          if (caseId != null) 'call_type': 'extraction',
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
  "screw_count": null,
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
- screw_count: integer number of screws/propellers, if stated
- propulsion_type: this is "type of prime mover" — choose from "Motor", "Steam", "Electric"
- propeller_type: this is "thruster type" — choose from "Fixed pitch", "Variable pitch", "Azipods", "Waterjet"
- mcr_power_value: numeric MCR value; set mcr_power_unit to "kW" or "bhp"
Dates in ISO format. Return null for missing fields.''',
            },
          ],
        });

    final text = _extractText(response.data);
    return _parseJson(text);
  }

  // ── Equasis text paste → vessel particulars ──────────────────────────────

  /// Parse pasted / imported **Equasis ship-folder text** into a vessel_data
  /// map whose keys match [VesselModel.applyExtraction] exactly, so the caller
  /// can apply it straight onto the vessel record.
  ///
  /// This is the credential-free fallback to the live Equasis fetch
  /// ([EquasisService.fetchVesselReport], which logs in and pulls the PDF by
  /// IMO): a surveyor who has the Equasis page open — but no stored Equasis
  /// login, or a blocked/failed fetch — can copy-paste the text here and still
  /// autopopulate flag / class society / build year / GT / owner & manager.
  ///
  /// TODO(equasis-live-api): if Equasis or IHS Markit ever exposes a structured
  /// data API (JSON) keyed on IMO, look the vessel up directly here instead of
  /// parsing free text — drop the [text] argument for an [imo] one and map the
  /// API fields onto the same keys returned below. The UI wiring and
  /// applyExtraction path stay unchanged.
  static Future<Map<String, dynamic>> extractEquasisText({
    required String text,
    String? imoHint,
    String? caseId,
  }) async {
    final hint = (imoHint != null && imoHint.trim().isNotEmpty)
        ? 'The vessel of interest has IMO number ${imoHint.trim()}. '
          'If the text lists several ships, use only the one matching that IMO.\n'
        : '';

    final response = await _dio.post('/messages',
        options: Options(extra: {
          'feature': 'equasis_text_extraction',
          if (caseId != null) 'case_id': caseId,
          if (caseId != null) 'call_type': 'extraction',
        }),
        data: {
          'model': AppConfig.claudeModel,
          'max_tokens': 1500,
          'messages': [
            {
              'role': 'user',
              'content':
                  '''${hint}The text below was copied from an Equasis ship record (equasis.org). Extract the vessel particulars and return ONLY a JSON object, no preamble or markdown:

<equasis_text>
$text
</equasis_text>

{
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
  "year_built": null,
  "build_yard": "",
  "build_country": "",
  "owners": "",
  "operators": "",
  "registered_owner": "",
  "class_society": "",
  "pi_club": "",
  "ism_status": "compliant|non_compliant"
}

Equasis field guidance:
- flag: the flag state (country of registry), e.g. "Panama", "Marshall Islands".
- owners / registered_owner: Equasis lists a "Registered owner" — put that in registered_owner; if a distinct beneficial/group owner is named, put it in owners.
- operators: Equasis's "ISM Manager" / "Ship manager" / "Commercial manager" — the company operating the vessel, distinct from the registered owner.
- class_society: the classification society (Equasis "Classification society" row), e.g. "DNV", "Lloyd's Register", "Bureau Veritas". Give the society name only, not the notation.
- pi_club: the P&I insurer named in the "P&I Insurer" row, if present, e.g. "Gard", "Skuld", "West of England".
- ism_status: "compliant" if a valid DOC/SMC is shown; "non_compliant" only if the record explicitly shows a withdrawn/expired ISM certificate; omit if unclear.
- gross_tonnage / net_tonnage / deadweight: numeric tonnage values only (no units).
- year_built: 4-digit year of build.
Omit any field the text does not contain (do not invent values). Numbers must be numbers, not strings.''',
            },
          ],
        });

    final result = _parseJson(_extractText(response.data));
    // Strip blank/placeholder values so applyExtraction only ever overwrites
    // with something real (mirrors the document-extraction vessel_data path).
    result.removeWhere((k, v) => v == null || v == '' || v == 0);
    return result;
  }

  // ── Narrative Drafting ────────────────────────────────────────────────────

  /// Draft the occurrence narrative from structured case data.
  ///
  /// Rewritten to the house style (docs/house_style.md, docs/
  /// occurrence_narrative_spec.md): a mandatory reported-register opening
  /// ("It was reported by the [role] that on [date], the subject vessel was
  /// …"), the three-act Before / Incident / Aftermath structure, a hard
  /// data-capture rule, and enforced concision. When the ordered phase
  /// buckets ([beforeCues]/[incidentCues]/[aftermathCues]) are supplied the
  /// narrative is drafted strictly from them in order; otherwise it falls
  /// back to the flat [damageItems] list (the report-builder Background
  /// caller, which has no phase forking).
  static Future<String> draftOccurrenceNarrative({
    required String vesselName,
    required String occurrenceDate,
    required String occurrenceLocation,
    required String occurrenceTitle,
    required List<String> damageItems,
    required String? interviewTranscript,
    required String reportFormat, // 'nordic' or 'abl'
    String? caseId,

    /// Role/rank of the person whose account this is (Master, Chief Engineer,
    /// Owner's Representative …). Fills the "[role]" slot in the opening.
    String? reporterRole,

    /// Ordered occurrence-phase cue buckets. When any is non-empty the three
    /// acts are drafted from these; the flat [damageItems] then supplies only
    /// supplementary claim-object context.
    List<String>? beforeCues,
    List<String>? incidentCues,
    List<String>? aftermathCues,

    /// Successive-report carry-forward (docs/report_builder_editor_notes.md
    /// gap #10): the prior report output's already-approved Background
    /// text for this case, when this is not the first report. When
    /// provided, the model drafts only the *incremental* narrative — new
    /// developments since that text — rather than restating it.
    String? priorApprovedText,
  }) async {
    final role = (reporterRole != null && reporterRole.trim().isNotEmpty)
        ? reporterRole.trim()
        : "vessel's Master";
    final transcriptSection = interviewTranscript != null
        ? '\n\nINTERVIEW TRANSCRIPT EXTRACT:\n$interviewTranscript'
        : '';

    String bucket(String heading, List<String>? cues) {
      if (cues == null || cues.isEmpty) {
        return '$heading:\n- (no information given — write "Not confirmed" '
            'where a fact for this phase is missing rather than inventing one)';
      }
      return '$heading:\n- ${cues.join('\n- ')}';
    }

    final hasPhases = (beforeCues?.isNotEmpty ?? false) ||
        (incidentCues?.isNotEmpty ?? false) ||
        (aftermathCues?.isNotEmpty ?? false);

    final contextBlock = hasPhases
        ? '${bucket('BEFORE THE INCIDENT (Act 1 — prelude)', beforeCues)}\n\n'
            '${bucket('THE INCIDENT (Act 2 — the event, in tick-tock order)', incidentCues)}\n\n'
            '${bucket('AFTERMATH (Act 3 — response through to a place of safety)', aftermathCues)}'
            '${damageItems.isNotEmpty ? '\n\nCLAIM OBJECTS / DAMAGE (supplementary context only):\n- ${damageItems.join('\n- ')}' : ''}'
        : 'OCCURRENCE CONTEXT:\n- ${damageItems.join('\n- ')}';

    final amendSection = priorApprovedText != null &&
            priorApprovedText.isNotEmpty
        ? '\n\nPRIOR APPROVED NARRATIVE (already issued in an earlier report '
            'on this case — do not repeat or restate any of this; it is '
            'shown only so you know what has already been said):\n'
            '"""\n$priorApprovedText\n"""\n\n'
            'Draft ONLY the new developments since the prior report above, as '
            'a continuation paragraph that reads naturally after it. If '
            'nothing in the information provided below is genuinely new '
            'compared to the prior text, return an empty string.'
        : '';

    final response = await _dio.post('/messages',
        options: Options(extra: {
          'feature': 'occurrence_narrative',
          if (caseId != null) 'case_id': caseId,
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
                  '''You are a marine surveyor drafting the OCCURRENCE NARRATIVE section of a Hull & Machinery survey report ($reportFormat format). This is the reported account of the casualty — not the surveyor's own findings.

Write flowing prose (no bullet points, no headings, no markdown).

MANDATORY OPENING — begin with exactly this shape:
"It was reported by the $role that on $occurrenceDate, the subject vessel was [pre-incident activity] …"
- Name the vessel once as "$vesselName" if natural, then refer to it only as "the subject vessel" thereafter — never repeat the name.
- Keep the WHOLE account in reported register ("it was reported", "the crew observed", "it was found"). Do not adopt any statement as the surveyor's own finding — that belongs in Damage Description.

THREE-ACT STRUCTURE, drafted strictly in this order:
1. BEFORE THE INCIDENT — the operating state immediately before: who was on watch, the operation underway, prevailing conditions, systems running normally. Anchor with time and place.
2. THE INCIDENT — in tick-tock sequence: the first sign (noise / alarm / shudder / level) with its exact time, who detected it and what they did, what was then found, each cascading failure in order with its own time, loss of function, and the point the situation was contained.
3. AFTERMATH — this act is ALWAYS INCLUDED and never dropped: notifications up the chain (managers / ERT / AMSA / P&I) with times or references, immediate mitigation, the tow or voyage to a place of safety, and any initial crew/contractor inspection, through to the endpoint that hands over to repairs.

DATA-CAPTURE RULE: consume every hard datum in the context before writing — exact dates and clock times as given (e.g. "At 1719 hours"), positions, port/berth names, named persons by rank/role, named equipment and its state, every alarm with its label/time/response, weather (actual vs forecast), cascading failures in sequence, and notifications with reference numbers. Work them all in; do not summarise past them. Where a hard fact is absent, write "Not confirmed" rather than inventing or glossing it.

CONCISION: this is a summary, not a diary — keep it tight and avoid convolution. Do NOT state or imply a cause of the casualty; causation is a separate section.

OCCURRENCE: $occurrenceTitle
LOCATION: $occurrenceLocation

$contextBlock$transcriptSection
$_writingStyleGuardrails$amendSection

Draft the occurrence narrative now:''',
            },
          ],
        });

    return _extractText(response.data);
  }

  /// Drafts the BACKGROUND section (docs/house_style.md — a distinct section
  /// from the Occurrence Narrative). Background is narrative context that
  /// stops JUST BEFORE the incident: the vessel's general employment, the
  /// specific voyage/operation in progress, and the immediate circumstances
  /// up to the point immediately preceding the occurrence. Reported register
  /// throughout ("subject vessel"); the event itself and the surveyor's own
  /// findings belong in later sections. Previously the Background draft path
  /// reused draftOccurrenceNarrative, which produced the three-act event
  /// account — semantically the wrong section (house-style item 12).
  static Future<String> draftBackgroundSection({
    required String vesselName,
    required String reportFormat,
    String? vesselType,
    String? employmentContext,
    String? occurrenceDate,
    String? occurrenceLocation,
    String? sourceReport,
    String? caseId,
    String? priorApprovedText,
  }) async {
    final srcAttribution = (sourceReport != null && sourceReport.trim().isNotEmpty)
        ? '\n\nSOURCE ATTRIBUTION: this background is drawn from "$sourceReport" '
            '(an owner/third-party account). Open with a single sentence '
            'attributing it, e.g. "The following background is a summary of the '
            'description of events in the $sourceReport."'
        : '';
    final ctx = (employmentContext != null && employmentContext.trim().isNotEmpty)
        ? '\n\nCONTEXT / RAW MATERIAL:\n${employmentContext.trim()}'
        : '';
    final amendSection = priorApprovedText != null &&
            priorApprovedText.isNotEmpty
        ? '\n\nPRIOR APPROVED BACKGROUND (already issued in an earlier report '
            'on this case — do not repeat or restate any of this; it is shown '
            'only so you know what has already been said):\n'
            '"""\n$priorApprovedText\n"""\n\n'
            'Draft ONLY the new developments since the prior text above, as a '
            'continuation that reads naturally after it. If nothing below is '
            'genuinely new, return an empty string.'
        : '';

    final response = await _dio.post('/messages',
        options: Options(extra: {
          'feature': 'background_section',
          if (caseId != null) 'case_id': caseId,
          if (caseId != null) 'call_type': 'report_section',
          if (caseId != null) 'section_label': 'background',
        }),
        data: {
          'model': AppConfig.claudeModel,
          'max_tokens': 900,
          'messages': [
            {
              'role': 'user',
              'content':
                  '''You are a marine surveyor drafting the BACKGROUND section of a Hull & Machinery survey report ($reportFormat format). This section sets the context of the claim and STOPS JUST BEFORE the incident — the occurrence itself is a separate later section and must NOT be described here.

Write flowing prose (no bullet points, no headings, no markdown), in reported register, referring to the vessel as "the subject vessel" (name it once as "$vesselName" at most).

CONTEXT BODY, strictly in this order:
1. The subject vessel's general role / employment — what it is and what it is ordinarily engaged in.${vesselType != null && vesselType.trim().isNotEmpty ? ' (Vessel type: ${vesselType.trim()}.)' : ''}
2. The specific operation or voyage in progress leading up to the incident.
3. The immediate circumstances up to (but stopping just before) the occurrence — prevailing conditions and what the vessel/crew were doing at the point immediately preceding the event.

Do NOT describe the incident, the damage, or the cause — those belong in later sections. Where a hard fact is absent, write "Not confirmed" rather than inventing it.$srcAttribution

OCCURRENCE DATE (for orientation only — do not narrate the event): ${occurrenceDate ?? 'Not confirmed'}
LOCATION: ${occurrenceLocation ?? 'Not confirmed'}$ctx
$_writingStyleGuardrails$amendSection

Draft the background now:''',
            },
          ],
        });

    return _extractText(response.data);
  }

  /// AI pre-sort for occurrence cue forking (docs/occurrence_narrative_spec.md)
  /// — classifies a single occurrence-section cue into one of the three
  /// narrative phases. "Surveyor picks, AI pre-sorts": this only *suggests*
  /// a phase; the surveyor can override it with the on-cue 3-way selector.
  /// Returns 'before', 'incident', or 'aftermath' (defaults to 'incident'
  /// when the model is unclear).
  static Future<String> classifyOccurrenceCuePhase({
    required String cueText,
    String? occurrenceTitle,
    String? caseId,
  }) async {
    final context = occurrenceTitle != null && occurrenceTitle.isNotEmpty
        ? '\nThe occurrence being described is: "$occurrenceTitle".'
        : '';
    final response = await _dio.post('/messages',
        options: Options(extra: {
          'feature': 'occurrence_cue_phase_sort',
          if (caseId != null) 'case_id': caseId,
        }),
        data: {
          'model': AppConfig.claudeModel,
          'max_tokens': 12,
          'messages': [
            {
              'role': 'user',
              'content':
                  '''Classify the following context cue into ONE phase of a marine casualty narrative:
- "before": conditions, watch, or operation in the lead-up immediately BEFORE the incident.
- "incident": the event itself — first sign, alarms, failures, loss of function, containment.
- "aftermath": AFTER the event — notifications, mitigation, tow/voyage to safety, first inspection.$context

CUE: "$cueText"

Answer with exactly one word: before, incident, or aftermath.''',
            },
          ],
        });
    final raw = _extractText(response.data).toLowerCase();
    if (raw.contains('before')) return 'before';
    if (raw.contains('aftermath')) return 'aftermath';
    return 'incident';
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

EVIDENCE-LINKAGE RULE: every causal statement must be anchored to a specific damage finding below or a cited source. Do not assert a cause that is not traceable to the damage record or a stated fact. Structure it as: (1) the damage-to-mechanism link ("The [damage] to [object] is consistent with [mechanism/load] …"); (2) the reasoning across the evidence; (3) any gaps, untaken measurements, or conflicts between sources, called out rather than smoothed over.

CERTAINTY LADDER — close on the rung the evidence supports, always framed as the surveyor's opinion:
- Preliminary: "A final conclusion cannot be reached until [condition]. On a preliminary basis, the following potential causes are considered: …".
- Qualified: "On balance, and on the basis of the evidence available, it is the opinion of the Undersigned Surveyor that [cause] is the likely cause.".
- Firm (only where evidence is strong): "It is the opinion of the Undersigned Surveyor that [cause].".

VESSEL: $vesselName
OCCURRENCE: $occurrenceTitle
DAMAGE:
- $damages$findings$allegation
$_writingStyleGuardrails$_calibratedHedging$_dataCaptureRule

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
      'formal_allegation' => 'Formal allegation raised',
      'no_formal_allegation' => 'No formal allegation raised',
      _ => 'Allegation status TBC',
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
            'content':
                '''Draft a concise SUB-CAUSATION / CONTRIBUTING FACTORS paragraph (2–4 sentences) for a marine survey report.
Write in precise technical prose. Explain the sequence of events or contributing factors that led to this casualty. Do not speculate beyond the information provided.

OCCURRENCE: $occurrenceTitle
CAUSE TYPE: $causeTypeLabel
ALLEGATION STATUS: $allegLabel$descText$bgText$cuesText
$_writingStyleGuardrails

Draft the sub-causation paragraph now (plain text, no headers or markdown):''',
          },
        ],
      },
    );
    return _extractText(response.data);
  }

  // ── General Services & Access draft (spec §8.4) ───────────────────────────

  /// Drafts the "General Services and Access" subsection from tagged
  /// context cues (surveyor_notes with case_section = 'general_expenses') —
  /// e.g. drydocking, staging, gas freeing, crane hire. Per spec output
  /// rule: states what services were provided, by whom, and when — never
  /// includes costs (those belong in the cost section).
  static Future<String> draftGeneralServices({
    required String vesselName,
    required List<String> contextCues,
    String? reportFormat,

    /// Successive-report carry-forward (docs/report_builder_editor_notes.md
    /// gap #10) — see [draftOccurrenceNarrative]'s equivalent parameter.
    String? priorApprovedText,
  }) async {
    final cuesText = contextCues.map((c) => '• $c').join('\n');
    final amendSection = priorApprovedText != null &&
            priorApprovedText.isNotEmpty
        ? '\n\nPRIOR APPROVED TEXT (already issued in an earlier report on '
            'this case — do not repeat or restate any of this; it is shown '
            'only so you know what has already been said):\n'
            '"""\n$priorApprovedText\n"""\n\n'
            'Draft ONLY the new developments since the prior report above, as '
            'a continuation that reads naturally after it. If none of the '
            'context cues above are genuinely new compared to the prior '
            'text, return an empty string.'
        : '';

    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'general_services_draft'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 500,
        'messages': [
          {
            'role': 'user',
            'content':
                '''Draft the "General Services and Access" subsection of a marine H&M survey report${reportFormat != null ? ' ($reportFormat format)' : ''}. This covers work required to access damage for inspection or repair but which is not itself a repair — e.g. drydocking, slipping, hardstanding, gas freeing, hot work certification, staging, crane hire, diving for access, tug assistance for repositioning.

Write one short prose paragraph stating what services were provided, by whom, and when, based only on the surveyor's notes below. Do NOT mention or estimate any costs — those are covered elsewhere in the report. Do not add information not provided. Do not use bullet points or headings.

VESSEL: $vesselName

SURVEYOR CONTEXT CUES:
$cuesText
$_writingStyleGuardrails$amendSection

Draft the paragraph now:''',
          },
        ],
      },
    );
    return _extractText(response.data);
  }

  // ── Previous Work on the Damaged Item draft ───────────────────────────────

  /// Drafts the "Previous Work on the Damaged Item" subsection from tagged
  /// context cues (surveyor_notes with case_section = 'previous_works')
  /// — prior repairs, surveys, or interventions carried out on the damaged
  /// item before this incident, relevant to causation. Factual only — no
  /// speculation about whether that prior work caused or contributed to
  /// the current damage; that judgement belongs in Cause Consideration.
  static Future<String> draftPreviousWorks({
    required String vesselName,
    required List<String> contextCues,
    String? reportFormat,

    /// Successive-report carry-forward (docs/report_builder_editor_notes.md
    /// gap #10) — see [draftOccurrenceNarrative]'s equivalent parameter.
    String? priorApprovedText,
  }) async {
    final cuesText = contextCues.map((c) => '• $c').join('\n');
    final amendSection = priorApprovedText != null &&
            priorApprovedText.isNotEmpty
        ? '\n\nPRIOR APPROVED TEXT (already issued in an earlier report on '
            'this case — do not repeat or restate any of this; it is shown '
            'only so you know what has already been said):\n'
            '"""\n$priorApprovedText\n"""\n\n'
            'Draft ONLY the new developments since the prior report above, as '
            'a continuation that reads naturally after it. If none of the '
            'context cues above are genuinely new compared to the prior '
            'text, return an empty string.'
        : '';

    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'previous_works_draft'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 500,
        'messages': [
          {
            'role': 'user',
            'content':
                '''Draft the "Previous Work on the Damaged Item" subsection of a marine H&M survey report${reportFormat != null ? ' ($reportFormat format)' : ''}. This records prior repairs, surveys, or interventions carried out on the damaged item before the current incident — factual history only.

Write one short prose paragraph stating what prior work is known to have been carried out on the item, by whom and when, based only on the surveyor's notes below. Do NOT speculate on whether that prior work caused or contributed to the current damage — that judgement belongs elsewhere in the report. Do not add information not provided. Do not use bullet points or headings.

VESSEL: $vesselName

SURVEYOR CONTEXT CUES:
$cuesText
$_writingStyleGuardrails$amendSection

Draft the paragraph now:''',
          },
        ],
      },
    );
    return _extractText(response.data);
  }

  // ── Extra Expenses to Reduce Delay draft (spec §8.5) ──────────────────────

  /// Drafts the "Extra Expenses to Reduce Delay" subsection from tagged
  /// context cues (surveyor_notes with case_section = 'extra_expenses') —
  /// e.g. yard selection premium, overtime, expedited freight of spare
  /// parts. Per spec output rule: states what measures were taken and why
  /// they were necessary to reduce delay — never itemizes actual costs
  /// (those belong in the cost section).
  static Future<String> draftExtraExpenses({
    required String vesselName,
    required List<String> contextCues,
    String? reportFormat,

    /// Successive-report carry-forward (docs/report_builder_editor_notes.md
    /// gap #10) — see [draftOccurrenceNarrative]'s equivalent parameter.
    String? priorApprovedText,
  }) async {
    final cuesText = contextCues.map((c) => '• $c').join('\n');
    final amendSection = priorApprovedText != null &&
            priorApprovedText.isNotEmpty
        ? '\n\nPRIOR APPROVED TEXT (already issued in an earlier report on '
            'this case — do not repeat or restate any of this; it is shown '
            'only so you know what has already been said):\n'
            '"""\n$priorApprovedText\n"""\n\n'
            'Draft ONLY the new developments since the prior report above, as '
            'a continuation that reads naturally after it. If none of the '
            'context cues above are genuinely new compared to the prior '
            'text, return an empty string.'
        : '';

    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'extra_expenses_draft'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 500,
        'messages': [
          {
            'role': 'user',
            'content':
                '''Draft the "Extra Expenses to Reduce Delay" subsection of a marine H&M survey report${reportFormat != null ? ' ($reportFormat format)' : ''}. This covers additional expense reasonably incurred specifically to reduce delay to the vessel — e.g. yard selection premium over a cheaper but slower yard, authorized overtime, expedited/air freight of spare parts, expedited certification.

Write one short prose paragraph stating what measures were taken and why they were necessary to reduce delay, based only on the surveyor's notes below. Do NOT state or estimate any dollar figures — those are covered elsewhere in the report. Do not add information not provided. Do not use bullet points or headings.

VESSEL: $vesselName

SURVEYOR CONTEXT CUES:
$cuesText
$_writingStyleGuardrails$amendSection

Draft the paragraph now:''',
          },
        ],
      },
    );
    return _extractText(response.data);
  }

  // ── Contractual / Hire draft ───────────────────────────────────────────────

  /// Drafts the "Contractual / Hire" subsection from tagged context cues
  /// (surveyor_notes with case_section = 'contractual_hire') — charter
  /// party terms, off-hire periods, contractual notices to owners/
  /// charterers, time-bar considerations. Factual only — states what was
  /// agreed/notified, not a legal opinion on contractual entitlement.
  static Future<String> draftContractualHire({
    required String vesselName,
    required List<String> contextCues,
    String? reportFormat,

    /// Successive-report carry-forward (docs/report_builder_editor_notes.md
    /// gap #10) — see [draftOccurrenceNarrative]'s equivalent parameter.
    String? priorApprovedText,
  }) async {
    final cuesText = contextCues.map((c) => '• $c').join('\n');
    final amendSection = priorApprovedText != null &&
            priorApprovedText.isNotEmpty
        ? '\n\nPRIOR APPROVED TEXT (already issued in an earlier report on '
            'this case — do not repeat or restate any of this; it is shown '
            'only so you know what has already been said):\n'
            '"""\n$priorApprovedText\n"""\n\n'
            'Draft ONLY the new developments since the prior report above, as '
            'a continuation that reads naturally after it. If none of the '
            'context cues above are genuinely new compared to the prior '
            'text, return an empty string.'
        : '';

    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'contractual_hire_draft'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 500,
        'messages': [
          {
            'role': 'user',
            'content':
                '''Draft the "Contractual / Hire" subsection of a marine H&M survey report${reportFormat != null ? ' ($reportFormat format)' : ''}. This covers charter party terms, off-hire periods arising from the incident/repairs, and any contractual notices exchanged between owners/charterers/managers.

Write one short prose paragraph stating what was agreed or notified, by whom and when, based only on the surveyor's notes below. State facts only — do not offer a legal opinion on contractual entitlement or liability. Do not add information not provided. Do not use bullet points or headings.

VESSEL: $vesselName

SURVEYOR CONTEXT CUES:
$cuesText
$_writingStyleGuardrails$amendSection

Draft the paragraph now:''',
          },
        ],
      },
    );
    return _extractText(response.data);
  }

  // ── Other Matters of Relevance draft ───────────────────────────────────────

  /// Drafts the "Other Matters of Relevance" narrative from tagged context
  /// cues (surveyor_notes with case_section = 'other_matters') — general
  /// observations or matters relevant to the case not captured in another
  /// section. Distinct from the "Advice to Assured" clause ticklist
  /// (docs/migrations/018_other_matters_clauses.sql), which this section
  /// was split out from on 5 July 2026.
  static Future<String> draftOtherMatters({
    required String vesselName,
    required List<String> contextCues,
    String? reportFormat,

    /// Successive-report carry-forward (docs/report_builder_editor_notes.md
    /// gap #10) — see [draftOccurrenceNarrative]'s equivalent parameter.
    String? priorApprovedText,
  }) async {
    final cuesText = contextCues.map((c) => '• $c').join('\n');
    final amendSection = priorApprovedText != null &&
            priorApprovedText.isNotEmpty
        ? '\n\nPRIOR APPROVED TEXT (already issued in an earlier report on '
            'this case — do not repeat or restate any of this; it is shown '
            'only so you know what has already been said):\n'
            '"""\n$priorApprovedText\n"""\n\n'
            'Draft ONLY the new developments since the prior report above, as '
            'a continuation that reads naturally after it. If none of the '
            'context cues above are genuinely new compared to the prior '
            'text, return an empty string.'
        : '';

    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'other_matters_draft'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 500,
        'messages': [
          {
            'role': 'user',
            'content':
                '''Draft the "Other Matters of Relevance" subsection of a marine H&M survey report${reportFormat != null ? ' ($reportFormat format)' : ''}. This covers general observations or matters relevant to the case that are not covered in any other section of the report.

Write one short prose paragraph based only on the surveyor's notes below. Do not add information not provided. Do not use bullet points or headings.

VESSEL: $vesselName

SURVEYOR CONTEXT CUES:
$cuesText
$_writingStyleGuardrails$amendSection

Draft the paragraph now:''',
          },
        ],
      },
    );
    return _extractText(response.data);
  }

  // ── §1.9 narrative-pattern drafts (8/9 July 2026) ──────────────────────────
  // Occurrence, Extent of Damage, Nature of the Repairs, and Repairs
  // previously had no AI-draft option at all — they build from deterministic
  // structured-data templates (report_provider.dart's _buildOccurrenceText/
  // _buildDamageText/_buildNatureOfRepairsText/_buildRepairsText), not free
  // narrative. These give the surveyor an alternative: flowing prose drafted
  // from the same underlying structured data + context cues, still editable
  // afterward like every other AI-drafted section.

  /// Drafts the "Occurrence" narrative from the occurrence's own hard fields
  /// (brief description, vessel status at casualty, aftermath) plus any
  /// occurrence-tagged context cues — an alternative to the deterministic
  /// clause-based template in report_provider.dart's _buildOccurrenceText.
  static Future<String> draftOccurrenceSection({
    required String vesselName,
    required String occurrenceSummary,
    required List<String> contextCues,
    String? reportFormat,
    String? priorApprovedText,
  }) async {
    final cuesText = contextCues.isEmpty
        ? '(none)'
        : contextCues.map((c) => '• $c').join('\n');
    final amendSection = priorApprovedText != null &&
            priorApprovedText.isNotEmpty
        ? '\n\nPRIOR APPROVED TEXT (already issued in an earlier report on '
            'this case — do not repeat or restate any of this; it is shown '
            'only so you know what has already been said):\n'
            '"""\n$priorApprovedText\n"""\n\n'
            'Draft ONLY the new developments since the prior report above, as '
            'a continuation that reads naturally after it. If nothing below '
            'is genuinely new compared to the prior text, return an empty '
            'string.'
        : '';

    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'occurrence_section_draft'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 500,
        'messages': [
          {
            'role': 'user',
            'content':
                '''Draft the "Occurrence" section of a marine H&M survey report${reportFormat != null ? ' ($reportFormat format)' : ''}. This states what happened, the vessel's status at the time, and what happened immediately afterward (aftermath).

Write one short prose paragraph based only on the information below. Do not add information not provided. Do not use bullet points or headings.

VESSEL: $vesselName

OCCURRENCE DATA:
$occurrenceSummary

SURVEYOR CONTEXT CUES:
$cuesText
$_writingStyleGuardrails$amendSection

Draft the paragraph now:''',
          },
        ],
      },
    );
    return _extractText(response.data);
  }

  /// Drafts the "Extent of Damage" narrative from the case's damage items
  /// (component, description, condition, confirmation) plus damage-tagged
  /// context cues — an alternative to the deterministic bulleted template in
  /// report_provider.dart's _buildDamageText.
  static Future<String> draftDamageDescriptionSection({
    required String vesselName,
    required List<String> damageItemSummaries,
    required List<String> contextCues,
    String? reportFormat,
    String? priorApprovedText,
  }) async {
    final itemsText = damageItemSummaries.isEmpty
        ? '(none recorded)'
        : damageItemSummaries.map((d) => '• $d').join('\n');
    final cuesText = contextCues.isEmpty
        ? '(none)'
        : contextCues.map((c) => '• $c').join('\n');
    final amendSection = priorApprovedText != null &&
            priorApprovedText.isNotEmpty
        ? '\n\nPRIOR APPROVED TEXT (already issued in an earlier report on '
            'this case — do not repeat or restate any of this; it is shown '
            'only so you know what has already been said):\n'
            '"""\n$priorApprovedText\n"""\n\n'
            'Draft ONLY the new developments since the prior report above, as '
            'a continuation that reads naturally after it. If nothing below '
            'is genuinely new compared to the prior text, return an empty '
            'string.'
        : '';

    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'damage_description_section_draft'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 700,
        'messages': [
          {
            'role': 'user',
            'content':
                '''Draft the "Extent of Damage" section of a marine H&M survey report${reportFormat != null ? ' ($reportFormat format)' : ''}. This is the surveyor's own voice — damage as evidenced observation, item by item, and how it was established.

OPEN with the basis of the findings (this sets the evidentiary weight) — the opener that matches how the damage was established: (a) DIRECT INSPECTION — "The [component] was inspected at [facility] on [date]. The following damage was observed:"; (b) REMOTE / REPORTED (established by discussion, not personally witnessed) — "A [telephone discussion / meeting] was held with [names] on [date]. It was established that the following areas of damage existed:"; (c) THIRD-PARTY SURVEY — "The following damage was reported from the [Diving Survey / Class survey]:". Then work through the damage grouping by component/claim object, carrying each object's identifier, condition/mode of damage, and measurements exactly as recorded — one object is never merged into another. Close with a consequential-damage line only where the evidence supports it ("It is considered that there could have been further damage to [components] due to [reason].").

Write prose (short paragraphs, one per claim object/component group is fine) based only on the damage items and context cues below. Do not add information not provided.

VESSEL: $vesselName

DAMAGE ITEMS:
$itemsText

SURVEYOR CONTEXT CUES:
$cuesText
$_writingStyleGuardrails$_calibratedHedging$_dataCaptureRule$amendSection

Draft the section now:''',
          },
        ],
      },
    );
    return _extractText(response.data);
  }

  /// Ultra-concise Advice-Summary line for Page 2. A claims manager reads only
  /// the front page to gauge how bad the claim is; the detail lives in the
  /// report body. [kind] = 'damage' (one line, what/how-bad) or 'repairs'
  /// (up to two lines: repair approach + commercial exposure such as shoreside
  /// works, long-lead-time parts, expected downtime). Summarises ONLY the hard
  /// data provided (damage register + the full Damage Description / Nature of
  /// Repairs section content).
  static Future<String> draftAdviceSummaryLine({
    required String kind,
    required String vesselName,
    required List<String> damageItemSummaries,
    required String damageSectionContent,
    required String natureOfRepairsContent,
  }) async {
    final repairs = kind == 'repairs';
    final itemsText = damageItemSummaries.isEmpty
        ? '(none recorded)'
        : damageItemSummaries.map((d) => '• $d').join('\n');
    final focus = repairs
        ? 'the REPAIR approach and its commercial exposure — e.g. shoreside/workshop vs in-situ works, long-lead-time parts, and the expected downtime/duration'
        : 'WHAT is damaged and the apparent severity/mode of the damage';
    final example = repairs
        ? 'e.g. "Failed turbocharger to be sent ashore for overhaul and inspection; potential long-lead-time parts, up to ~3 months."'
        : 'e.g. "Multiple components in the turbocharger showing signs of impact."';
    final length = repairs
        ? 'AT MOST two lines (~25–40 words total)'
        : 'A SINGLE line (~12–20 words)';

    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'advice_summary_line'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 200,
        'messages': [
          {
            'role': 'user',
            'content':
                '''You are writing ONE field of the front-page Advice Summary of a marine H&M survey report for the "$vesselName". A claims manager reads only this front page to gauge how bad the claim is; the full detail is in the report body.

Summarise $focus. $example

Rules:
- $length. No heading, no bullet points, no preamble, no "The vessel…" boilerplate — just the summary itself.
- Plain factual register. Summarise ONLY the data below; do not invent facts. If the data is thin, summarise only what is given.

DAMAGE REGISTER ITEMS:
$itemsText

DAMAGE DESCRIPTION (full section):
${damageSectionContent.trim().isEmpty ? '(none yet)' : damageSectionContent.trim()}

NATURE OF REPAIRS (full section):
${natureOfRepairsContent.trim().isEmpty ? '(none yet)' : natureOfRepairsContent.trim()}

Write the summary now:''',
          },
        ],
      },
    );
    return _extractText(response.data).trim();
  }

  /// Drafts the "Nature of the Repairs" narrative from the surveyor's own
  /// flagged considerations (drydocking required, assured's plan formulated,
  /// further inspections planned, long-lead-time parts, foreseeable
  /// difficulties) and the anticipated repair sequence. No CaseSection cue
  /// tag exists for this section (report_provider.dart reads structured
  /// flags/comments, not tagged cues), so there are no context cues to pass.
  static Future<String> draftNatureOfRepairsSection({
    required String vesselName,
    required String flagsSummary,
    String? reportFormat,
    String? priorApprovedText,
  }) async {
    final amendSection = priorApprovedText != null &&
            priorApprovedText.isNotEmpty
        ? '\n\nPRIOR APPROVED TEXT (already issued in an earlier report on '
            'this case — do not repeat or restate any of this; it is shown '
            'only so you know what has already been said):\n'
            '"""\n$priorApprovedText\n"""\n\n'
            'Draft ONLY the new developments since the prior report above, as '
            'a continuation that reads naturally after it. If nothing below '
            'is genuinely new compared to the prior text, return an empty '
            'string.'
        : '';

    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'nature_of_repairs_section_draft'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 500,
        'messages': [
          {
            'role': 'user',
            'content':
                '''Draft the "Nature of the Repairs" section of a marine H&M survey report${reportFormat != null ? ' ($reportFormat format)' : ''}. This is an indicative, forward-looking statement of how repairs are expected to proceed — not a record of repairs already carried out.

Write one short prose paragraph based only on the information below. Do not add information not provided or speculate beyond it. Do not use bullet points or headings. If nothing below indicates a repair consideration worth flagging, return an empty string rather than inventing content.

VESSEL: $vesselName

SURVEYOR'S FLAGGED CONSIDERATIONS:
$flagsSummary
$_writingStyleGuardrails$_calibratedHedging$amendSection

Draft the paragraph now:''',
          },
        ],
      },
    );
    return _extractText(response.data);
  }

  /// Drafts the "Repairs" narrative from the case's repair periods (dates,
  /// location, port context) plus repairs-tagged context cues — an
  /// alternative to the deterministic one-line-per-period template in
  /// report_provider.dart's _buildRepairsText.
  static Future<String> draftRepairsSection({
    required String vesselName,
    required List<String> repairPeriodSummaries,
    required List<String> contextCues,
    String? reportFormat,
    String? priorApprovedText,
  }) async {
    final periodsText = repairPeriodSummaries.isEmpty
        ? '(none recorded)'
        : repairPeriodSummaries.map((p) => '• $p').join('\n');
    final cuesText = contextCues.isEmpty
        ? '(none)'
        : contextCues.map((c) => '• $c').join('\n');
    final amendSection = priorApprovedText != null &&
            priorApprovedText.isNotEmpty
        ? '\n\nPRIOR APPROVED TEXT (already issued in an earlier report on '
            'this case — do not repeat or restate any of this; it is shown '
            'only so you know what has already been said):\n'
            '"""\n$priorApprovedText\n"""\n\n'
            'Draft ONLY the new developments since the prior report above, as '
            'a continuation that reads naturally after it. If nothing below '
            'is genuinely new compared to the prior text, return an empty '
            'string.'
        : '';

    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'repairs_section_draft'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 500,
        'messages': [
          {
            'role': 'user',
            'content':
                '''Draft the "Repairs" section of a marine H&M survey report${reportFormat != null ? ' ($reportFormat format)' : ''}. This records the repair period(s) — when and where repairs took place, and the average (casualty-related) versus Owners' own concurrent work where distinguished.

Write one short prose paragraph per repair period based only on the repair periods and context cues below, carrying each period's dates, location/yard and scope exactly as recorded. Introduce any Owners' own concurrent work separately from the average repairs. Do not sum times across periods. Do not add information not provided. Do not use bullet points or headings.

VESSEL: $vesselName

REPAIR PERIODS:
$periodsText

SURVEYOR CONTEXT CUES:
$cuesText
$_writingStyleGuardrails$_dataCaptureRule$amendSection

Draft the paragraph now:''',
          },
        ],
      },
    );
    return _extractText(response.data);
  }

  // ── Case-screen cue quick summary (NOT report content) ────────────────────

  /// Short synopsis of a case section's cues for the case-screen
  /// presentation only (docs/context_cue_system_review.md §3.3) — helps the
  /// surveyor recall context before attending the vessel. Deliberately NOT
  /// used as report content: the report builder's own dedicated drafting
  /// pipeline (full writing-style guardrails, structured case data) is what
  /// generates actual report text, fully decoupled from this.
  static Future<String> draftCueQuickSummary({
    required String sectionLabel,
    required List<String> cues,
  }) async {
    if (cues.isEmpty) return '';
    final cuesText = cues.map((c) => '• $c').join('\n');
    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'cue_quick_summary'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 120,
        'messages': [
          {
            'role': 'user',
            'content':
                '''Summarise these surveyor context cues for the "$sectionLabel" section of a marine survey case into a single short sentence (max ~20 words) — a quick reminder for the surveyor before attending the vessel, not report text. Plain, direct, no preamble, no quotation marks.

CUES:
$cuesText

Summary sentence:''',
          },
        ],
      },
    );
    return _extractText(response.data).trim();
  }

  /// §3.14: narrative synthesis of a whole email exchange — the one part of
  /// the thread-level trail summary that actually needs an LLM call. The
  /// sequence itself (who/when/subject) is composed deterministically by
  /// correspondence_threads.dart; this only summarises how the exchange
  /// developed. Fetched on demand (a button tap), not auto-generated on
  /// import, to keep this a surveyor-triggered cost like the per-message
  /// extraction summary it sits alongside.
  ///
  /// [messages] — oldest first, each `{'from': ..., 'date': ..., 'text':
  /// ...}` where `text` is that message's own extracted summary if
  /// available, else a short body snippet (never the full raw body, to
  /// keep this call's cost bounded regardless of thread length).
  static Future<String> draftCorrespondenceTrailSummary({
    required String subject,
    required List<Map<String, String?>> messages,
  }) async {
    if (messages.isEmpty) return '';
    final exchangeText = messages
        .map((m) =>
            '${m['date'] ?? 'Unknown date'} — ${m['from'] ?? 'Unknown sender'}: '
            '${m['text']?.trim().isNotEmpty == true ? m['text'] : '(no summary available)'}')
        .join('\n');
    final response = await _dio.post(
      '/messages',
      options: Options(extra: {'feature': 'correspondence_trail_summary'}),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 400,
        'messages': [
          {
            'role': 'user',
            'content':
                '''Summarise this email exchange ("$subject") for a marine surveyor reviewing the case file. Write a short factual narrative (3–6 sentences) describing how the exchange developed — what was asked, what was answered, where it landed. Plain third-person register, no preamble, no quotation marks.

EXCHANGE (oldest first):
$exchangeText

Summary:''',
          },
        ],
      },
    );
    return _extractText(response.data).trim();
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
          if (caseId != null) 'case_id': caseId,
          if (caseId != null) 'call_type': 'extraction',
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
                'text':
                    '''You are extracting data from a marine survey document (category hint: $categoryHint).

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
    "currency": "",
    "pi_insurer": "the P&I club or hull insurer named in this document, e.g. Gard, Skuld, West of England, QBE"
  },
  "context_findings": [
    {
      "text": "Brief factual statement in English about a finding, condition, observation, or recommendation",
      "note_category": "observation|measurement|technical|operations|previous_works|follow_up|interview|policy|general",
      "case_section": "background|occurrence|attendance|timeline|causation|damage|repairs|repair_times|extra_expenses|general_expenses|not_average|other_matters|previous_works|contractual_hire",
      "origin": "assured_owner|third_party|surveyor",
      "page": "the page number this finding appears on (integer, first page = 1), or null if the document has no page structure or it can't be determined"
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
  "detected_contacts": [
    {
      "name": "the person's full name",
      "role": "their professional title / function in context, e.g. Chief Engineer, Master, Owner's Representative, Class Surveyor, Loss Adjuster, Superintendent, Service Engineer, Underwriter, Broker",
      "company": "the organisation they belong to, or empty",
      "email": "",
      "phone": ""
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
    "screw_count": null,
    "propulsion_type": "",
    "propeller_type": "",
    "propulsion_drive_type": "",
    "mcr_power_value": null,
    "mcr_rpm": null,
    "mcr_power_unit": "kW",
    "pi_club": "the P&I club or hull insurer named in this document, e.g. Gard, Skuld, West of England, QBE",
    "class_status": "classed|conditional|suspended|not_classed — the vessel's current class status as stated in this document, if any",
    "official_number": "the vessel's official/registry number, distinct from IMO number",
    "registered_owner": "the registered owner of record, if stated (may differ from operators)",
    "last_drydock_date": "YYYY-MM-DD, if this document states a drydocking date",
    "last_drydock_yard": "the drydock/repair yard name, if stated",
    "psc_last_inspection": "YYYY-MM-DD, if this document is or references a Port State Control inspection",
    "psc_last_result": "clear|deficiencies|detained — the PSC inspection outcome, if this document is a PSC report",
    "psc_summary": "brief summary of PSC findings, if this document is a PSC report",
    "isps_status": "compliant|non_compliant — ISPS compliance status, if stated"
  }
}

Rules:
- hard_fields: include ONLY fields actually present in the document; omit absent fields entirely; dates MUST be YYYY-MM-DD; numeric values must be numbers not strings
- context_findings: each item must have a "text" and a "note_category"; choose the most fitting category; translate text to English
- context_findings order: list findings in the exact order they appear in the document, reading top to bottom and first page to last — do NOT group or reorder by category or topic
- context_findings page: give your best reading of the page number the finding was found on; if the document is a single continuous scan/photo with no distinguishable pages, use null
- context_findings case_section: your best guess at which case section this finding belongs to, from the fixed list given — this is a suggestion only, a human will confirm or correct it, so make your best guess rather than omitting it; omit the field only if truly nothing fits (e.g. a pure hard-field/vessel-data document with no narrative content)
- context_findings origin: who the content originates from — "assured_owner" for the vessel owner/operator/master/crew, "third_party" for class societies, surveyors from other parties, contractors, or other outside parties, "surveyor" only for the attending surveyor's own dictation/statement; omit if genuinely unclear
- detected_incidents: only populate if the document describes a specific physical incident, casualty, accident, or occurrence event; PSC inspections, detentions, and port state deficiencies are NOT incidents — add them as context_findings with note_category "operations"; leave detected_incidents as [] if none
- detected_machinery: list each distinct machinery item that is a subject of the document (surveyed, serviced, inspected, or described with any technical detail); include make/model/serial when present but do not require them; leave as [] only for items mentioned purely in passing with no context
- detected_class_conditions: for class survey reports, condition-of-class documents, and class survey certificates, extract EVERY Condition of Class and Recommendation listed — include reference number, description, and expiry/due date; leave as [] for all other document types
- detected_contacts: list each named PERSON in the document (attendees, signatories, correspondents, crew, surveyors, adjusters, superintendents, owner/manager representatives) with their professional title/function deduced from context — the "role" is a job title/function such as "Chief Engineer" or "Class Surveyor", NOT the company name; include email/phone only when explicitly present; skip generic mentions with no name; leave as [] if the document names no people
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
          if (caseId != null) 'case_id': caseId,
          if (caseId != null) 'call_type': 'invoice_extraction',
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
                  'text':
                      '''You are a marine insurance claims assistant. Extract all data from this invoice/document for a marine survey case account and return ONLY a JSON object.

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
    final response = await _dio.post(
      '/messages',
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
                'text':
                    '''You are a marine insurance claims assistant. This PDF may contain multiple individual invoices or documents bundled together.

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
      final end = clean.lastIndexOf(']');
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
  static Future<Map<String, dynamic>> routeVoiceNote(String transcript) async {
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
          if (caseId != null) 'case_id': caseId,
          if (caseId != null) 'call_type': 'extraction',
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
                'text':
                    '''${hint}This is a marine insurance / survey correspondence document (email trail, letter, or report). Extract the following and return ONLY a JSON object with no preamble or markdown:

{
  "summary": "2-3 sentence summary of the overall correspondence",
  "sender": "primary sender name and organisation",
  "recipient": "primary recipient name and organisation",
  "corr_date": "date of most recent or primary communication in YYYY-MM-DD format, or null",
  "parties": [
    {"name": "", "company": "", "role": "the person's professional title / function, e.g. Chief Engineer, Master, Owner's Representative, Superintendent, Class Surveyor, Loss Adjuster, Underwriter, Broker", "email": "", "phone": ""}
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
    {"name": "", "company": "", "role": "the person's professional title / function, e.g. Chief Engineer, Master, Owner's Representative, Superintendent, Class Surveyor, Loss Adjuster, Underwriter, Broker", "email": "", "phone": ""}
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
      90 => 1,
      180 => 2,
      270 => 3,
      _ => 0,
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
                'text':
                    '''You are assisting a marine insurance surveyor reviewing a repair invoice or document.

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
      final end = clean.lastIndexOf(']');
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

  // ── Timeline Event Relevance Rating (TODO.md §3.16) ──────────────────────

  /// Suggest a relevance rating (important | normal | ignore) for each event in
  /// a case's Full Event Log, so the surveyor curates from an AI first draft
  /// rather than rating everything from scratch. Same judgement-over-content
  /// class of task as the context-cue auto-classification, and — like it —
  /// every suggestion is treated as pending review, never silently trusted.
  ///
  /// [events] items must carry `event_key`, and any of `date`, `title`,
  /// `description`. Returns a JSON list of `{event_key, relevance, reason}`;
  /// unknown/omitted events simply get no suggestion.
  static Future<List<Map<String, dynamic>>> rateTimelineEvents({
    required List<Map<String, dynamic>> events,
    String? caseId,
  }) async {
    if (events.isEmpty) return const [];
    final lines = events.map((e) {
      final key = e['event_key'] ?? '';
      final date = (e['date'] as String?)?.trim();
      final title = (e['title'] as String?)?.trim() ?? '';
      final desc = (e['description'] as String?)?.trim();
      final parts = [
        if (date != null && date.isNotEmpty) date,
        if (title.isNotEmpty) title,
        if (desc != null && desc.isNotEmpty) desc,
      ].join(' — ');
      return '- [$key] $parts';
    }).join('\n');

    final response = await _dio.post(
      '/messages',
      options: Options(extra: {
        'feature': 'timeline_event_rating',
        if (caseId != null) 'case_id': caseId,
        if (caseId != null) 'call_type': 'classification',
      }),
      data: {
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 1500,
        'messages': [
          {
            'role': 'user',
            'content':
                '''You are assisting a marine insurance surveyor building the Chronology of Events for a hull & machinery claim report. Rate how relevant each event below is to that formal chronology.

Use exactly one of:
- "important" — a pivotal claim event (the casualty/occurrence itself, a key survey attendance, drydock entry/exit, commencement or completion of repairs, a decisive inspection).
- "normal" — a genuine dated event worth keeping but not pivotal.
- "ignore" — routine, administrative, duplicative or immaterial to the claim narrative.

For each event return an object with:
- "event_key": the exact bracketed key
- "relevance": important | normal | ignore
- "reason": a very short (max ~12 words) justification

Return ONLY a JSON array, no preamble.

EVENTS:
$lines''',
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
      final end = clean.lastIndexOf(']');
      if (start < 0 || end < 0) return const [];
      clean = clean.substring(start, end + 1);
      return (jsonDecode(clean) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  /// Extracts a title + date from a context cue's free text so it can
  /// become a real Timeline event automatically, instead of just sitting as
  /// a raw listed cue (14 July 2026 walkthrough). E.g. "The vessel departed
  /// Perth for Hobart on 29/10/2025…" -> title "Vessel departed Perth for
  /// Hobart", date 2025-10-29. Returns null date if the text has no clear
  /// date — caller should treat that as "not auto-convertible" and leave
  /// the date for the surveyor to fill in.
  static Future<Map<String, dynamic>> extractEventFromNote({
    required String text,
    String? caseId,
  }) async {
    final response = await _dio.post(
      '/messages',
      options: Options(extra: {
        'feature': 'timeline_event_from_note',
        if (caseId != null) 'case_id': caseId,
        if (caseId != null) 'call_type': 'extraction',
      }),
      data: {
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 300,
        'messages': [
          {
            'role': 'user',
            'content':
                '''A marine surveyor wrote this note about a case. If it describes a real dated event, extract a short factual title (max ~12 words, no surrounding quotes) and the date (YYYY-MM-DD). If there's no clear date in the text, return "date": null.

Return ONLY JSON: {"title": "...", "date": "YYYY-MM-DD" or null}

NOTE:
$text''',
          },
        ],
      },
    );

    final raw = _extractText(response.data).trim();
    try {
      var clean = raw
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start < 0 || end < 0) return const {};
      clean = clean.substring(start, end + 1);
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  /// Post-processing for a saved interview transcript (14 July 2026
  /// walkthrough — "derive summary/cues after the fact"). Produces a short
  /// prose summary plus a handful of candidate follow-up cues the surveyor
  /// can act on; both are surfaced for review, never auto-filed.
  static Future<Map<String, dynamic>> summarizeInterview({
    required String transcript,
    String? caseId,
  }) async {
    final response = await _dio.post(
      '/messages',
      options: Options(extra: {
        'feature': 'interview_summary',
        if (caseId != null) 'case_id': caseId,
        if (caseId != null) 'call_type': 'extraction',
      }),
      data: {
        'model': AppConfig.claudeModel,
        'max_tokens': 900,
        'messages': [
          {
            'role': 'user',
            'content':
                '''You are assisting a marine insurance surveyor. Summarise the following interview transcript for the case file: 3-6 sentences of factual prose covering what was said, by whom (if roles are clear from context), and any dates, causes, or figures mentioned. Do not speculate beyond what was said. Then list up to 5 short follow-up cues (things worth checking or noting elsewhere in the case) as plain statements, or an empty list if none.

Return ONLY JSON: {"summary": "...", "cues": ["...", ...]}

TRANSCRIPT:
$transcript''',
          },
        ],
      },
    );
    return _parseJson(_extractText(response.data));
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
      final end = clean.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        clean = clean.substring(start, end + 1);
      }
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (e) {
      return {'error': 'Failed to parse response', 'raw': text};
    }
  }
}
