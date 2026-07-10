// lib/features/reports/providers/report_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/claude_api.dart';
import '../../../core/models/ai_generation_log_model.dart';
import '../../survey/models/repair_period_model.dart';
import '../../survey/providers/damage_provider.dart'
    show ConditionStatus, ConfirmedByRole, CertaintyLevel;
import '../../timeline/models/timeline_entry.dart';
import '../../timeline/models/timeline_event_rating.dart';
import '../../timeline/models/timeline_aggregation.dart';

// ── Report output types ────────────────────────────────────────────────────

enum OutputType {
  preliminary('preliminary', 'Preliminary Report'),
  advice('advice', 'Advice'),
  final_('final', 'Final Report');

  const OutputType(this.value, this.label);
  final String value;
  final String label;

  static OutputType fromValue(String v) => values
      .firstWhere((e) => e.value == v, orElse: () => OutputType.preliminary);
}

enum ReportStatus {
  draft('draft', 'Draft'),
  selfReviewed('self_reviewed', 'Self Reviewed'),
  submittedQc('submitted_qc', 'Submitted for QC'),
  qcComments('qc_comments', 'QC Comments'),
  approved('approved', 'Approved'),
  issued('issued', 'Issued'),
  locked('locked', 'Locked');

  const ReportStatus(this.value, this.label);
  final String value;
  final String label;

  static ReportStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => ReportStatus.draft);
}

// ── Section types ──────────────────────────────────────────────────────────

enum SectionType {
  executiveSummary, // Page 2 — auto-populated summary editable by surveyor
  opening, // §1  Introduction / Opening Certification
  attendees, // §2  Attending Representatives
  vesselParticulars, // §3  Vessel's Particulars
  machineryParticulars, // §4  Machinery & Equipment (conditional)
  classStatutory, // §5  Class & Statutory Certification
  informationSources, // §6  Available Information Sources
  // §7  Chronology — auto-table from timeline_events, no text section
  background, // §8  Background
  occurrence, // §9  Occurrence (brief description)
  damageDescription, // §9  Extent of Damage
  allegation, // §10 Owner's Allegation
  causation, // §10 Cause Consideration / Technical Analysis
  natureOfRepairs, // §11.1 Nature of the Repairs (early indicators,
  // ahead of any repair period existing)
  repairs, // §11.2 Repairs / Repair Periods (narrative)
  generalServices, // §12 General Services & Access
  previousWorks, // §12.4 Previous Work on the Damaged Item
  extraExpenses, // §12.5 Extra Expenses to Reduce Delay
  contractualHire, // §12.6 Contractual / Hire
  otherMatters, // §12.7 Other Matters of Relevance (cue-drafted
  // narrative — distinct from the `surveyorNotes`
  // clause ticklist below, split out 5 July 2026)
  accounts, // §13 Repair Costs (auto-table; summary commentary)
  repairTimes, // §14 Repair Times (auto-table; summary commentary)
  surveyorNotes, // §15 Advice to Assured (enum name kept for
  // DB/historical continuity — this was originally
  // "Other Matters of Relevance" before that
  // section split in two on 5 July 2026; see
  // docs/migrations/018_other_matters_clauses.sql)
  documentsOnFile, // §16 Documents Retained on File
  documentsRequested, // §17 Documents Requested / Outstanding
  // §18 Principal Dates — not implemented; the Chronology auto-table
  // (built from timeline_events, see §7) covers this in practice.
  waiver, // §19 Limitation of Liability / Waiver
  closing, // Sign-off block / Without Prejudice / Closing
}

/// Section display order for the Oceanoservices H&M report format (spec §4.1).
/// Used by the editor tab and preview to display sections in the correct order.
/// Other formats (Nordic, ABL) will have their own ordered lists.
const oceanoSectionOrder = [
  SectionType.executiveSummary,
  SectionType.opening,
  SectionType.attendees,
  SectionType.vesselParticulars,
  SectionType.machineryParticulars,
  SectionType.classStatutory,
  SectionType.informationSources,
  SectionType.background,
  SectionType.occurrence,
  SectionType.damageDescription,
  SectionType.allegation,
  SectionType.causation,
  SectionType.natureOfRepairs,
  SectionType.repairs,
  SectionType.generalServices,
  SectionType.previousWorks,
  SectionType.extraExpenses,
  SectionType.contractualHire,
  SectionType.otherMatters,
  SectionType.accounts,
  SectionType.repairTimes,
  SectionType.surveyorNotes,
  SectionType.documentsOnFile,
  SectionType.documentsRequested,
  SectionType.waiver,
  SectionType.closing,
];

// Returns the Oceanoservices section number (1-based) for display.
// executiveSummary is not a numbered body section — returns null.
// The index in oceanoSectionOrder already encodes the number correctly:
// executiveSummary is at index 0 (→ null), opening at index 1 (→ 1), etc.
int? oceanoSectionNumber(SectionType type) {
  if (type == SectionType.executiveSummary) return null;
  final idx = oceanoSectionOrder.indexOf(type);
  return idx > 0 ? idx : null;
}

// ── Clause model ───────────────────────────────────────────────────────────

@immutable
class ClauseModel {
  const ClauseModel({
    required this.clauseId,
    required this.formatType,
    required this.clauseType,
    required this.clauseLabel,
    required this.clauseText,
    this.isLocked = true,
  });

  final String clauseId;
  final String formatType;
  final String clauseType;
  final String clauseLabel;
  final String clauseText;
  final bool isLocked;

  factory ClauseModel.fromJson(Map<String, dynamic> j) => ClauseModel(
        clauseId: j['clause_id'] as String,
        formatType: j['format_type'] as String,
        clauseType: j['clause_type'] as String,
        clauseLabel: j['clause_label'] as String,
        clauseText: j['clause_text'] as String,
        isLocked: j['is_locked'] as bool? ?? true,
      );
}

// ── Surveyor review status (GPN-AI compliance) ────────────────────────────

enum SurveyorReview {
  reviewedAccepted, // AI draft — reviewed and accepted as-is
  reviewedAmended, // AI draft — reviewed and amended by surveyor
  surveyorAuthored, // No AI — written entirely by the surveyor
}

// ── Report section model ───────────────────────────────────────────────────

@immutable
class ReportSection {
  const ReportSection({
    required this.type,
    required this.title,
    required this.content,
    this.clauseId,
    this.isLocked = false,
    this.aiDrafted = false,
    this.surveyorReview,
    this.sectionId,
    this.carriedForwardContent,
  });

  final SectionType type;
  final String title;

  /// This report output's own new/incremental text. On a successive
  /// report (Progress/Interim/Supplementary/Final) that carries forward
  /// prior narrative, this is the delta only — the prior text lives in
  /// [carriedForwardContent], frozen and read-only. On a first report, or
  /// any section type not eligible for carry-forward, this is the entire
  /// section content, same as before this feature existed.
  final String content;
  final String? clauseId;
  final bool isLocked; // clause text — cannot be edited by surveyor
  final bool aiDrafted;

  /// GPN-AI: surveyor must set this before export is allowed.
  final SurveyorReview? surveyorReview;
  final String? sectionId;

  /// Frozen copy of the prior report output's approved text for this
  /// section (spec: "Successive Report Behaviour" — docs/report_builder_
  /// editor_notes.md gap #10). Null when there is no prior report in the
  /// chain, or this section type doesn't carry forward. Never edited once
  /// set — the surveyor's new work goes in [content] instead. See
  /// [fullContent] for the seamless concatenation used by every renderer.
  final String? carriedForwardContent;

  /// True once the surveyor has set any review status.
  bool get approved => surveyorReview != null;

  /// What every renderer (docx, Preview, reference panels) should display
  /// — the carried-forward base plus this report's new delta, joined with
  /// no visible marker (spec: "the rendered output presents the complete
  /// narrative seamlessly with no visible breaks"). Falls back to plain
  /// [content] when there's nothing carried forward, so call sites can
  /// always use this getter unconditionally.
  String get fullContent {
    final base = carriedForwardContent ?? '';
    if (base.isEmpty) return content;
    if (content.isEmpty) return base;
    return '$base\n\n$content';
  }

  static const _sentinel = Object();

  ReportSection copyWith({
    String? content,
    Object? surveyorReview = _sentinel,
    String? sectionId,
    bool? aiDrafted,
    Object? carriedForwardContent = _sentinel,
  }) =>
      ReportSection(
        type: type,
        title: title,
        content: content ?? this.content,
        clauseId: clauseId,
        isLocked: isLocked,
        aiDrafted: aiDrafted ?? this.aiDrafted,
        surveyorReview: surveyorReview == _sentinel
            ? this.surveyorReview
            : surveyorReview as SurveyorReview?,
        sectionId: sectionId ?? this.sectionId,
        carriedForwardContent: carriedForwardContent == _sentinel
            ? this.carriedForwardContent
            : carriedForwardContent as String?,
      );
}

// ── Report output model ────────────────────────────────────────────────────

@immutable
class ReportOutput {
  const ReportOutput({
    required this.outputId,
    required this.caseId,
    required this.outputType,
    required this.status,
    required this.sections,
    this.reportNumber,
    this.sequenceNo = 1,
    this.issuedDate,
    this.issuedTo,
    this.filePath,
    this.createdAt,
    this.supersedesVersion,
    this.changesSummary,
    this.adviceNatureOfCasualty,
    this.adviceDescriptionOfDamage,
    this.adviceNatureOfRepairs,
    this.adviceStatusOfRepairs,
    this.adviceStatusOfRepairsDetail,
    this.adviceCostAmount,
    this.adviceCostCurrency,
    this.adviceCostIncludesGeneralExpenses,
    this.adviceCostIncludesTowing,
    this.adviceFeeReserveHours,
    this.adviceFeeReserveExpenses,
    this.adviceFollowUpRequired,
    this.adviceFollowUpDetail,
    this.adviceRemarks,
    this.adviceConfirmed = false,
  });

  final String outputId;
  final String caseId;
  final OutputType outputType;
  final ReportStatus status;
  final List<ReportSection> sections;
  final String? reportNumber;
  final int sequenceNo;
  final DateTime? issuedDate;
  final String? issuedTo;
  final String? filePath;
  final DateTime? createdAt;

  /// Version code this report supersedes, e.g. 'R001'. Auto-set at creation.
  final String? supersedesVersion;

  /// Brief summary of changes from the prior version — editable by surveyor.
  final String? changesSummary;

  // ── Advice Summary (Page 2 structured table) — see docs/migrations/014 ──
  final String? adviceNatureOfCasualty;
  final String? adviceDescriptionOfDamage;
  final String? adviceNatureOfRepairs;
  final String? adviceStatusOfRepairs;
  final String? adviceStatusOfRepairsDetail;
  final num? adviceCostAmount;
  final String? adviceCostCurrency;
  final bool? adviceCostIncludesGeneralExpenses;
  final String? adviceCostIncludesTowing;
  final num? adviceFeeReserveHours;
  final num? adviceFeeReserveExpenses;
  final bool? adviceFollowUpRequired;
  final String? adviceFollowUpDetail;
  final String? adviceRemarks;
  final bool adviceConfirmed;

  int get approvedCount => sections.where((s) => s.approved).length;
  bool get allApproved => sections.every((s) => s.approved);
  bool get isLocked => status == ReportStatus.locked;

  /// R001, R002… extracted from the trailing segment of reportNumber,
  /// or formatted from sequenceNo as a fallback.
  String get versionCode {
    if (reportNumber != null) {
      final m = RegExp(r'R\d{3,}$').firstMatch(reportNumber!);
      if (m != null) return m.group(0)!;
    }
    return 'R${sequenceNo.toString().padLeft(3, '0')}';
  }

  factory ReportOutput.fromJson(
          Map<String, dynamic> j, List<ReportSection> sections) =>
      ReportOutput(
        outputId: j['output_id'] as String,
        caseId: j['case_id'] as String,
        outputType: OutputType.fromValue(j['output_type'] as String),
        status: ReportStatus.fromValue(j['status'] as String? ?? 'draft'),
        sections: sections,
        reportNumber: j['report_number'] as String?,
        sequenceNo: j['sequence_no'] as int? ?? 1,
        issuedDate: j['issued_date'] != null
            ? DateTime.tryParse(j['issued_date'] as String)
            : null,
        issuedTo: j['issued_to'] as String?,
        filePath: j['file_path'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        supersedesVersion: j['supersedes_version'] as String?,
        changesSummary: j['changes_summary'] as String?,
        adviceNatureOfCasualty: j['advice_nature_of_casualty'] as String?,
        adviceDescriptionOfDamage: j['advice_description_of_damage'] as String?,
        adviceNatureOfRepairs: j['advice_nature_of_repairs'] as String?,
        adviceStatusOfRepairs: j['advice_status_of_repairs'] as String?,
        adviceStatusOfRepairsDetail:
            j['advice_status_of_repairs_detail'] as String?,
        adviceCostAmount: j['advice_cost_amount'] as num?,
        adviceCostCurrency: j['advice_cost_currency'] as String?,
        adviceCostIncludesGeneralExpenses:
            j['advice_cost_includes_general_expenses'] as bool?,
        adviceCostIncludesTowing: j['advice_cost_includes_towing'] as String?,
        adviceFeeReserveHours: j['advice_fee_reserve_hours'] as num?,
        adviceFeeReserveExpenses: j['advice_fee_reserve_expenses'] as num?,
        adviceFollowUpRequired: j['advice_follow_up_required'] as bool?,
        adviceFollowUpDetail: j['advice_follow_up_detail'] as String?,
        adviceRemarks: j['advice_remarks'] as String?,
        adviceConfirmed: j['advice_confirmed'] as bool? ?? false,
      );
}

// ── Assembled report data — all case data in one place for assembly ─────────

@immutable
class AssembledReportData {
  const AssembledReportData({
    required this.caseData,
    required this.vessel,
    required this.occurrences,
    required this.damageItems,
    required this.attendees,
    required this.attendances,
    required this.certificates,
    required this.repairPeriods,
    required this.clauses,
    required this.outputFormat,
    required this.repairDocuments,
    required this.timelineEvents,
    required this.surveyorNotes,
    required this.machinery,
    required this.classConditions,
    required this.caseDocuments,
    required this.requestedDocuments,
    required this.aiGenerationLog,
    required this.allReportOutputs,
    this.organisation,
    this.natureOfRepairs,
  });

  final Map<String, dynamic> caseData;
  final Map<String, dynamic>? vessel;
  final List<Map<String, dynamic>> occurrences;
  final List<Map<String, dynamic>> damageItems;
  final List<Map<String, dynamic>> attendees;

  /// Attendance/visit records (survey_attendances) ordered oldest-first —
  /// for the first-attendance date/location used in the opening clause (D-3).
  final List<Map<String, dynamic>> attendances;
  final List<Map<String, dynamic>> certificates;

  /// Repair periods (repair_periods table) — the sole repair grouping
  /// concept; feeds both the docx Repairs/Repair Times tables and the
  /// repairs/repairTimes section narratives (the legacy `repair_records`
  /// table had no writer UI and has been retired — see gap #3 in
  /// docs/report_builder_editor_notes.md).
  final List<Map<String, dynamic>> repairPeriods;
  final List<ClauseModel> clauses;
  final String outputFormat;

  /// Repair documents with nested account lines — for cost section assembly.
  final List<Map<String, dynamic>> repairDocuments;

  /// Chronological events ordered by event_date — for timeline table.
  final List<Map<String, dynamic>> timelineEvents;

  /// Surveyor notes ordered by created_at.
  final List<Map<String, dynamic>> surveyorNotes;

  /// Machinery records for the vessel.
  final List<Map<String, dynamic>> machinery;

  /// Class conditions for the case.
  final List<Map<String, dynamic>> classConditions;

  /// Documents on file for this case (for the documents section, Clause K-1).
  final List<Map<String, dynamic>> caseDocuments;

  /// Documents requested but not yet received (Clause K-2).
  final List<Map<String, dynamic>> requestedDocuments;

  /// Org config — present when the case has an organisation_id set.
  final Map<String, dynamic>? organisation;

  /// All AI generation log entries for the case — for Annexure I + disclosure.
  final List<AiGenerationLogModel> aiGenerationLog;

  /// All report outputs for the case ordered newest-first — for version history table.
  final List<Map<String, dynamic>> allReportOutputs;

  /// Nature of the Repairs — case_nature_of_repairs row, null if the
  /// surveyor has never opened that section (§11.1 is then omitted).
  final Map<String, dynamic>? natureOfRepairs;

  ClauseModel? clauseByType(String type) =>
      clauses.where((c) => c.clauseType == type).firstOrNull;
}

// ── Report provider ────────────────────────────────────────────────────────

final reportOutputsProvider = AsyncNotifierProviderFamily<ReportOutputsNotifier,
    List<ReportOutput>, String>(
  ReportOutputsNotifier.new,
);

class ReportOutputsNotifier
    extends FamilyAsyncNotifier<List<ReportOutput>, String> {
  @override
  Future<List<ReportOutput>> build(String caseId) => _fetch(caseId);

  Future<List<ReportOutput>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('report_outputs')
        .select()
        .eq('case_id', caseId)
        .order('created_at', ascending: false);
    return (data as List).map((j) {
      return ReportOutput.fromJson(j as Map<String, dynamic>, const []);
    }).toList();
  }

  Future<ReportOutput> createOutput({
    required String caseId,
    required OutputType type,
    required String reportNumber,
    int sequenceNo = 1,
  }) async {
    // Auto-set supersedes_version to the most recent existing output's version code
    final existing = state.value ?? [];
    String? supersedesVersion;
    if (existing.isNotEmpty) {
      // Most recent is first (ordered by created_at DESC in _fetch)
      supersedesVersion = existing.first.versionCode;
    }

    final data = await SupabaseService.client
        .from('report_outputs')
        .insert({
          'case_id': caseId,
          'output_type': type.value,
          'report_number': reportNumber,
          'sequence_no': sequenceNo,
          'status': 'draft',
          if (supersedesVersion != null)
            'supersedes_version': supersedesVersion,
        })
        .select()
        .single();

    final output = ReportOutput.fromJson(data, const []);
    final current = state.value ?? [];
    state = AsyncData([output, ...current]);
    return output;
  }

  Future<void> updateStatus(String outputId, ReportStatus status) async {
    await SupabaseService.client
        .from('report_outputs')
        .update({'status': status.value}).eq('output_id', outputId);
    await refresh();
  }

  Future<void> updateChangesSummary(String outputId, String summary) async {
    await SupabaseService.client
        .from('report_outputs')
        .update({'changes_summary': summary}).eq('output_id', outputId);
    await refresh();
  }

  /// Patches any subset of the Advice Summary fields (Page 2 structured
  /// table — see docs/migrations/014_advice_summary.sql). Only the keys
  /// present in [fields] are written; callers pass just what changed.
  Future<void> updateAdviceSummary(
      String outputId, Map<String, dynamic> fields) async {
    if (fields.isEmpty) return;
    await SupabaseService.client
        .from('report_outputs')
        .update(fields)
        .eq('output_id', outputId);
    await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}

// ── Assembled data provider ────────────────────────────────────────────────

final assembledDataProvider =
    FutureProvider.family<AssembledReportData, String>((ref, caseId) async {
  // Fetch everything needed to assemble the report
  final results = await Future.wait([
    SupabaseService.client
        .from('cases')
        .select('*, vessels(*), principals_clients!cases_client_id_fkey(name)')
        .eq('case_id', caseId)
        .single(),
    SupabaseService.client
        .from('occurrences')
        .select()
        .eq('case_id', caseId)
        .order('occurrence_no'),
    SupabaseService.client
        .from('damage_items')
        .select()
        .eq('case_id', caseId)
        .order('sequence_no'),
    SupabaseService.client
        .from('attendees')
        .select()
        .eq('case_id', caseId)
        .order('sort_order', nullsFirst: false)
        .order('created_at'),
    SupabaseService.client.from('certificates').select().eq('case_id', caseId),
    SupabaseService.client
        .from('repair_periods')
        .select()
        .eq('case_id', caseId)
        .order('period_no'),
    SupabaseService.client
        .from('survey_attendances')
        .select()
        .eq('case_id', caseId)
        .order('attendance_date', ascending: true),
  ]);

  final caseData = results[0] as Map<String, dynamic>;
  final occurrences = (results[1] as List).cast<Map<String, dynamic>>();
  final damageItems = (results[2] as List).cast<Map<String, dynamic>>();
  final attendees = (results[3] as List).cast<Map<String, dynamic>>();
  final certificates = (results[4] as List).cast<Map<String, dynamic>>();
  final repairPeriods = (results[5] as List).cast<Map<String, dynamic>>();
  final attendances = (results[6] as List).cast<Map<String, dynamic>>();

  final natureOfRepairs = await SupabaseService.client
      .from('case_nature_of_repairs')
      .select()
      .eq('case_id', caseId)
      .maybeSingle();

  final outputFormat = caseData['output_format'] as String? ?? 'abl';

  // Fetch clauses for this format — table may not be seeded yet
  List<ClauseModel> clauses = [];
  try {
    final clauseData = await SupabaseService.client
        .from('clause_library')
        .select()
        .eq('format_type', outputFormat)
        .eq('deprecated', false);
    clauses = (clauseData as List)
        .map((c) => ClauseModel.fromJson(c as Map<String, dynamic>))
        .toList();
  } catch (_) {}

  final vessel = caseData['vessels'] as Map<String, dynamic>?;

  // Fetch repair documents with nested account lines
  List<Map<String, dynamic>> repairDocuments = [];
  try {
    final repairDocData = await SupabaseService.client
        .from('repair_documents')
        .select('*, account_lines(*)')
        .eq('case_id', caseId)
        .order('created_at');
    repairDocuments = (repairDocData as List).cast<Map<String, dynamic>>();
  } catch (_) {}

  // Fetch timeline events ordered by date, then apply the surveyor's
  // Chronology curation (TODO.md §3.16). Each timeline_events row is keyed
  // "manual:<event_id>"; a rating may down-rank it to "ignore" or exclude it
  // from the Chronology. Events with no rating stay included — preserving the
  // report builder's long-standing "list every timeline row" behaviour for
  // un-curated cases. The include rule lives in one shared place
  // (chronologyIncludeForRating) so the in-app selection and the rendered
  // report can never disagree.
  List<Map<String, dynamic>> timelineEvents = [];
  try {
    final timelineData = await SupabaseService.client
        .from('timeline_events')
        .select()
        .eq('case_id', caseId)
        .order('event_date');
    final allTimeline = (timelineData as List).cast<Map<String, dynamic>>();

    final ratingsByKey = <String, TimelineEventRating>{};
    try {
      final ratingRows = await SupabaseService.client
          .from('timeline_event_ratings')
          .select()
          .eq('case_id', caseId);
      for (final row in (ratingRows as List)) {
        final r = TimelineEventRating.fromMap(row as Map<String, dynamic>);
        ratingsByKey[r.eventKey] = r;
      }
    } catch (_) {}

    timelineEvents = allTimeline.where((e) {
      final key = 'manual:${e['event_id']}';
      return chronologyIncludeForRating(
        sourceType: TimelineSourceType.manual,
        rating: ratingsByKey[key],
      );
    }).toList();
  } catch (_) {}

  // Fetch supplementary data in parallel
  final vesselId = vessel?['vessel_id'] as String?;
  final supplementary = await Future.wait([
    SupabaseService.client
        .from('surveyor_notes')
        .select()
        .eq('case_id', caseId)
        .order('created_at'),
    if (vesselId != null)
      SupabaseService.client
          .from('machinery')
          .select()
          .eq('vessel_id', vesselId)
          .order('machinery_type')
    else
      Future.value(<dynamic>[]),
    if (vesselId != null)
      SupabaseService.client
          .from('class_conditions')
          .select()
          .eq('vessel_id', vesselId)
          .order('created_at')
    else
      Future.value(<dynamic>[]),
    SupabaseService.client
        .from('documents')
        .select('doc_id, title, doc_category, doc_date, annexure_assignment, '
            'availability, requested_date, received_date')
        .eq('case_id', caseId)
        .order('doc_category'),
  ]);

  final surveyorNotes = List<Map<String, dynamic>>.from(supplementary[0]);
  final machinery = List<Map<String, dynamic>>.from(supplementary[1]);
  final classConditions = List<Map<String, dynamic>>.from(supplementary[2]);
  final allDocuments = List<Map<String, dynamic>>.from(supplementary[3]);
  // Clause K-1 vs K-2: split by availability rather than fetching twice.
  final caseDocuments =
      allDocuments.where((d) => d['availability'] == 'enclosed').toList();
  final requestedDocuments =
      allDocuments.where((d) => d['availability'] == 'requested').toList();

  // Fetch org config and AI generation log in parallel
  Map<String, dynamic>? organisation;
  final orgId = caseData['organisation_id'] as String?;
  final aiLogFetch = SupabaseService.client
      .from('ai_generation_log')
      .select()
      .eq('case_id', caseId)
      .order('created_at');

  final List<dynamic> aiLogRaw;
  if (orgId != null) {
    final parallel = await Future.wait([
      SupabaseService.client
          .from('organisations')
          .select('*, surveyor_profiles(*)')
          .eq('id', orgId)
          .maybeSingle()
          .then((v) => v as dynamic)
          .catchError((_) => null),
      aiLogFetch,
    ]);
    organisation = parallel[0] as Map<String, dynamic>?;
    aiLogRaw = parallel[1] as List<dynamic>;
  } else {
    aiLogRaw = await aiLogFetch;
  }

  final aiGenerationLog = aiLogRaw
      .cast<Map<String, dynamic>>()
      .map(AiGenerationLogModel.fromJson)
      .toList();

  // Fetch all report outputs for the version history table
  final allOutputsRaw = await SupabaseService.client
      .from('report_outputs')
      .select('output_id, report_number, sequence_no, output_type, status, '
          'created_at, issued_date, supersedes_version, changes_summary')
      .eq('case_id', caseId)
      .order('created_at', ascending: false);
  final allReportOutputs =
      List<Map<String, dynamic>>.from(allOutputsRaw as List);

  return AssembledReportData(
    caseData: caseData,
    vessel: vessel,
    occurrences: occurrences,
    damageItems: damageItems,
    attendees: attendees,
    attendances: attendances,
    certificates: certificates,
    repairPeriods: repairPeriods,
    clauses: clauses,
    outputFormat: outputFormat,
    repairDocuments: repairDocuments,
    timelineEvents: timelineEvents,
    surveyorNotes: surveyorNotes,
    machinery: machinery,
    classConditions: classConditions,
    caseDocuments: caseDocuments,
    requestedDocuments: requestedDocuments,
    aiGenerationLog: aiGenerationLog,
    allReportOutputs: allReportOutputs,
    organisation: organisation,
    natureOfRepairs: natureOfRepairs,
  );
});

// ── Section assembly provider ──────────────────────────────────────────────

/// Key for [sectionDraftProvider] — sections are scoped to a specific report
/// output (Preliminary/Advice/Final), not just the case, since a case can
/// have several outputs that must not share draft state.
typedef SectionDraftKey = ({String caseId, String outputId});

final sectionDraftProvider = StateNotifierProvider.family<SectionDraftNotifier,
    Map<SectionType, ReportSection>, SectionDraftKey>(
  (ref, key) => SectionDraftNotifier(key.caseId, key.outputId),
);

/// A row loaded from `report_sections` — the persisted override for one
/// section of one report output.
@immutable
class _PersistedSection {
  const _PersistedSection({
    required this.content,
    required this.aiDrafted,
    required this.surveyorReview,
    this.carriedForwardContent,
  });
  final String content;
  final bool aiDrafted;
  final SurveyorReview? surveyorReview;
  final String? carriedForwardContent;

  /// Same seamless concatenation as [ReportSection.fullContent] — used
  /// when reading a *prior* output's section as the carry-forward base for
  /// a new one (see [SectionDraftNotifier._priorFullContent]).
  String get fullContent {
    final base = carriedForwardContent ?? '';
    if (base.isEmpty) return content;
    if (content.isEmpty) return base;
    return '$base\n\n$content';
  }
}

class SectionDraftNotifier
    extends StateNotifier<Map<SectionType, ReportSection>> {
  SectionDraftNotifier(this.caseId, this.outputId) : super({});

  final String caseId;
  final String outputId;
  final Map<SectionType, Timer> _saveTimers = {};

  @override
  void dispose() {
    for (final entry in _saveTimers.entries) {
      entry.value.cancel();
      _persist(entry.key);
    }
    _saveTimers.clear();
    super.dispose();
  }

  void setSection(SectionType type, ReportSection section) {
    state = {...state, type: section};
  }

  void updateContent(SectionType type, String content) {
    final existing = state[type];
    if (existing != null) {
      state = {...state, type: existing.copyWith(content: content)};
      _saveTimers[type]?.cancel();
      _saveTimers[type] =
          Timer(const Duration(milliseconds: 700), () => _persist(type));
    }
  }

  void setSurveyorReview(SectionType type, SurveyorReview review) {
    final existing = state[type];
    if (existing != null) {
      state = {
        ...state,
        type: existing.copyWith(surveyorReview: review),
      };
      _persist(type);
    }
  }

  /// Upserts the current in-memory content/review/aiDrafted for [type] into
  /// `report_sections`, scoped by (output_id, section_type) — the table has
  /// no case_id column; report_outputs.case_id is reachable via output_id
  /// if ever needed. Best-effort — a failed save must never crash the
  /// editor (matches [AiLogService]'s swallow-and-continue convention).
  Future<void> _persist(SectionType type) async {
    final section = state[type];
    if (section == null || section.isLocked) return;
    try {
      await SupabaseService.client.from('report_sections').upsert({
        'output_id': outputId,
        'section_type': type.name,
        'content': section.content,
        'ai_drafted': section.aiDrafted,
        'surveyor_review': section.surveyorReview?.name,
        'carried_forward_content': section.carriedForwardContent,
      }, onConflict: 'output_id,section_type');
    } catch (_) {
      // Persistence failure must never break the editor.
    }
  }

  /// Build all sections from assembled data in spec §4.1 order.
  /// Every section is always created — empty string if no data yet.
  Future<void> buildSections(
    AssembledReportData data, {
    required ReportOutput output,
    bool aiDraft = false,
  }) async {
    final sections = <SectionType, ReportSection>{};

    // Fetched up-front (not just at the end) so the auto-draft-on-first-
    // build gates below can tell "never drafted before" apart from "just
    // computed empty this call" — without this, aiDraft:true would re-call
    // the AI on every mount even for sections that already have persisted
    // content, since the persisted overlay only overwrites afterward.
    final persisted = await _fetchPersisted();

    // Successive-report carry-forward (gap #10) — resolve the immediately
    // preceding output in this case's chain (if any) and pull its
    // persisted sections once, up front, for the two carry-forward-
    // eligible types below (background/generalServices) to use.
    final priorOutputId = _priorOutputId(output, data);
    final priorPersisted = priorOutputId != null
        ? await _fetchPersistedFor(priorOutputId)
        : const <SectionType, _PersistedSection>{};

    // ── Page 2: Executive Summary ────────────────────────────────────
    sections[SectionType.executiveSummary] = ReportSection(
      type: SectionType.executiveSummary,
      title: 'Executive Summary',
      content: _buildExecutiveSummaryTemplate(data),
    );

    // ── §1: Introduction / Opening Certification ──────────────────
    final openingClause = data.clauseByType('opening_certification');
    sections[SectionType.opening] = ReportSection(
      type: SectionType.opening,
      title: 'Introduction / Opening Certification',
      content: openingClause != null
          ? _fillOpeningClause(openingClause.clauseText, data)
          : '',
      clauseId: openingClause?.clauseId,
      isLocked: openingClause != null,
    );

    // ── §2: Attending Representatives ─────────────────────────────
    sections[SectionType.attendees] = ReportSection(
      type: SectionType.attendees,
      title: 'Attending Representatives',
      content:
          data.attendees.isNotEmpty ? _buildAttendeesText(data.attendees) : '',
    );

    // ── §3: Vessel's Particulars ──────────────────────────────────
    sections[SectionType.vesselParticulars] = ReportSection(
      type: SectionType.vesselParticulars,
      title: "Vessel's Particulars",
      content: _buildVesselText(data),
    );

    // ── §4: Machinery & Equipment (conditional in export) ─────────
    sections[SectionType.machineryParticulars] = ReportSection(
      type: SectionType.machineryParticulars,
      title: 'Machinery & Equipment Particulars',
      content:
          data.machinery.isNotEmpty ? _buildMachineryText(data.machinery) : '',
    );

    // ── §5: Class & Statutory Certification ───────────────────────
    // Clauses C-6a/b/c/e/f — see _buildClassStatutoryText.
    sections[SectionType.classStatutory] = ReportSection(
      type: SectionType.classStatutory,
      title: 'Class & Statutory Certification',
      content: _buildClassStatutoryText(data),
    );

    // ── §6: Available Information Sources ─────────────────────────
    sections[SectionType.informationSources] = ReportSection(
      type: SectionType.informationSources,
      title: 'Available Information Sources',
      content: data.caseDocuments.isNotEmpty
          ? _buildInfoSourcesText(data.caseDocuments)
          : '',
    );

    // ── §7: Chronology — auto-table from timeline_events, no text box ───

    // ── §8: Background ────────────────────────────────────────────
    // Successive-report carry-forward (gap #10): if this output has never
    // had its own Background saved yet, and a prior report on this case
    // has approved Background text, that text becomes this output's
    // frozen `carriedForwardContent` and the new `content` starts as the
    // incremental delta (blank, or AI-amended) — takes priority over the
    // scratch `background_narrative` field on the occurrence row, since a
    // previously-issued report's actual approved wording is a stronger
    // source of truth than that field.
    String backgroundContent = '';
    String? backgroundCarriedForward;
    final priorBackground = priorPersisted[SectionType.background];
    final backgroundIsFirstBuild =
        !persisted.containsKey(SectionType.background);
    if (backgroundIsFirstBuild &&
        priorBackground != null &&
        priorBackground.fullContent.isNotEmpty) {
      backgroundCarriedForward = priorBackground.fullContent;
      if (aiDraft && data.occurrences.isNotEmpty) {
        final occ = data.occurrences.first;
        try {
          backgroundContent = await ClaudeApi.draftOccurrenceNarrative(
            vesselName: data.vessel?['name'] ?? 'the vessel',
            occurrenceDate: occ['date_time'] as String? ?? '',
            occurrenceLocation: occ['location'] as String? ?? '',
            occurrenceTitle: occ['title'] as String? ?? '',
            damageItems: data.damageItems
                .map((d) => d['component_name'] as String? ?? '')
                .toList(),
            interviewTranscript: null,
            reportFormat: data.outputFormat,
            priorApprovedText: backgroundCarriedForward,
          );
        } catch (_) {
          // Leave blank rather than showing an error placeholder — unlike
          // the from-scratch path below, the carried-forward text is
          // already real content the surveyor can see and extend
          // manually, so a failed amend attempt isn't a dead end.
          backgroundContent = '';
        }
      }
    } else if (data.occurrences.isNotEmpty) {
      backgroundContent =
          data.occurrences.first['background_narrative'] as String? ?? '';
      if (backgroundContent.isEmpty && aiDraft && backgroundIsFirstBuild) {
        final occ = data.occurrences.first;
        try {
          backgroundContent = await ClaudeApi.draftOccurrenceNarrative(
            vesselName: data.vessel?['name'] ?? 'the vessel',
            occurrenceDate: occ['date_time'] as String? ?? '',
            occurrenceLocation: occ['location'] as String? ?? '',
            occurrenceTitle: occ['title'] as String? ?? '',
            damageItems: data.damageItems
                .map((d) => d['component_name'] as String? ?? '')
                .toList(),
            interviewTranscript: null,
            reportFormat: data.outputFormat,
          );
        } catch (_) {
          backgroundContent = '[Draft narrative — edit before issuing]';
        }
      }
    }
    sections[SectionType.background] = ReportSection(
      type: SectionType.background,
      title: 'Background',
      content: backgroundContent,
      aiDrafted: aiDraft && backgroundContent.isNotEmpty,
      carriedForwardContent: backgroundCarriedForward,
    );

    // ── §9: Occurrence + Damage Description ───────────────────────
    sections[SectionType.occurrence] = ReportSection(
      type: SectionType.occurrence,
      title: 'Occurrence',
      content: data.occurrences.isNotEmpty
          ? _buildOccurrenceText(data.occurrences.first, data)
          : '',
    );
    sections[SectionType.damageDescription] = ReportSection(
      type: SectionType.damageDescription,
      title: 'Extent of Damage',
      content: data.damageItems.isNotEmpty
          ? _buildDamageText(data.damageItems, data.machinery)
          : '',
    );

    // ── §10: Allegation + Cause Consideration (three-voice separation) ──
    // Voices are kept in distinct paragraphs, never merged into one
    // sentence: owner's allegation (this section), then per spec §10,
    // third-party findings and the surveyor's assessment always last
    // (causation section, below).
    final occForCause =
        data.occurrences.isNotEmpty ? data.occurrences.first : null;
    final allegationType = occForCause?['allegation_type'] as String? ?? 'tbc';
    final ownersStatedCause = occForCause?['owners_stated_cause'] as String?;
    final ownersStatedCauseSource =
        occForCause?['owners_stated_cause_source'] as String?;

    String allegationContent = '';
    String? allegationClauseId;
    var allegationLocked = false;
    if (allegationType == 'formal_allegation') {
      final clause = data.clauseByType('allegation_formal');
      if (clause != null) {
        allegationContent = clause.clauseText
            .replaceAll('{ALLEGED_CAUSE}', ownersStatedCause ?? '');
        allegationClauseId = clause.clauseId;
        allegationLocked = true;
      }
    } else if (allegationType == 'no_formal_allegation') {
      final clause = data.clauseByType('allegation_none');
      if (clause != null) {
        allegationContent = clause.clauseText;
        allegationClauseId = clause.clauseId;
        allegationLocked = true;
      }
    } else if (allegationType == 'informal_allegation') {
      final sourceClause =
          ownersStatedCauseSource != null && ownersStatedCauseSource.isNotEmpty
              ? ' (as stated in $ownersStatedCauseSource)'
              : '';
      allegationContent = 'It is understood that the Owners have, without '
          'formal written allegation, indicated the cause of the casualty'
          '$sourceClause:\n\n${ownersStatedCause ?? ''}';
    }
    // 'tbc' / null → empty, unchanged from prior behaviour.
    sections[SectionType.allegation] = ReportSection(
      type: SectionType.allegation,
      title: "Owner's Allegation",
      content: allegationContent,
      clauseId: allegationClauseId,
      isLocked: allegationLocked,
    );

    // Third-party findings — one clearly-attributed paragraph per source.
    final causeParts = <String>[];
    final thirdPartyRaw =
        (occForCause?['third_party_findings'] as List?) ?? const [];
    for (final raw in thirdPartyRaw) {
      final f = raw as Map<String, dynamic>;
      final source = f['source_name'] as String? ?? '';
      final docRef = f['document_reference'] as String?;
      final finding = f['finding'] as String? ?? '';
      if (source.isEmpty && finding.isEmpty) continue;
      final attribution =
          docRef != null && docRef.isNotEmpty ? '$source ($docRef)' : source;
      causeParts.add('According to $attribution: $finding');
    }

    // Surveyor's assessment — always last, never merged with the voices
    // above. "Consistent with allegation" uses the locked standard-remarks
    // clause verbatim; other certainty levels use the spec's suggested
    // hedging sentence as a lead-in to the surveyor's free-text assessment.
    final certaintyLevelRaw = occForCause?['certainty_level'] as String?;
    String? assessmentPart;
    if (certaintyLevelRaw == 'consistent_with_allegation') {
      assessmentPart = data.clauseByType('cause_standard_remarks')?.clauseText;
    }
    assessmentPart ??= _certaintyHedgeLanguage(certaintyLevelRaw);
    final surveyorsAssessment = occForCause?['surveyors_assessment'] as String?;
    if (surveyorsAssessment != null && surveyorsAssessment.isNotEmpty) {
      assessmentPart = assessmentPart == null
          ? surveyorsAssessment
          : '$assessmentPart $surveyorsAssessment';
    }
    if (assessmentPart != null && assessmentPart.isNotEmpty) {
      causeParts.add(assessmentPart);
    }

    var causeContent = causeParts.join('\n\n');
    var causeAiDrafted = false;

    // Additional analytical notes (spec §10 item 5) — surveyor's voice,
    // appended last.
    final analyticalNotes = occForCause?['cause_narrative'] as String?;
    if (analyticalNotes != null && analyticalNotes.isNotEmpty) {
      causeContent = causeContent.isEmpty
          ? analyticalNotes
          : '$causeContent\n\n$analyticalNotes';
    }

    if (causeContent.isEmpty &&
        aiDraft &&
        occForCause != null &&
        !persisted.containsKey(SectionType.causation)) {
      try {
        causeContent = await ClaudeApi.draftCauseConsideration(
          vesselName: data.vessel?['name'] ?? 'the vessel',
          occurrenceTitle: occForCause['title'] as String? ?? '',
          damageItems: data.damageItems
              .map((d) => d['component_name'] as String? ?? '')
              .toList(),
          ownersAllegation: ownersStatedCause,
          serviceEngineerFindings: null,
          reportFormat: data.outputFormat,
        );
        causeAiDrafted = true;
      } catch (_) {
        // Marked drafted even on failure (matches Background's behaviour
        // above) so a transient API failure gets persisted as an attempt
        // and edited manually, rather than silently retrying the AI call
        // on every future mount of this report forever.
        causeContent = '[Cause consideration — edit before issuing]';
        causeAiDrafted = true;
      }
    }
    sections[SectionType.causation] = ReportSection(
      type: SectionType.causation,
      title: 'Cause Consideration',
      content: causeContent,
      aiDrafted: causeAiDrafted,
    );

    // ── §11.1: Nature of the Repairs ──────────────────────────────
    // Surveyor-entered structured indicators (not AI-drafted) — usable
    // from the first attendance, before any repair period exists (5 July
    // 2026). Omitted entirely when nothing has been entered, same
    // convention as Other Matters/WNCA.
    sections[SectionType.natureOfRepairs] = ReportSection(
      type: SectionType.natureOfRepairs,
      title: 'Nature of the Repairs',
      content: _buildNatureOfRepairsText(data.natureOfRepairs),
    );

    // ── §11.2: Repairs (narrative) ──────────────────────────────────
    // Clauses F-2/F-5 (services/hot work, from repair_periods) appended
    // after the repair period narrative, if either has content.
    final repairsNarrative = data.repairPeriods.isNotEmpty
        ? _buildRepairsText(data.repairPeriods)
        : '';
    final servicesText = _buildServicesAndHotWorkText(data);
    sections[SectionType.repairs] = ReportSection(
      type: SectionType.repairs,
      title: 'Repairs',
      content: [repairsNarrative, servicesText]
          .where((s) => s.isNotEmpty)
          .join('\n\n'),
    );

    // ── §12: General Services & Access ───────────────────────────
    // Auto-drafted from `general_expenses`-tagged context cues on first
    // build, same as Background/Causation above — never re-drafted once a
    // persisted row exists (see draftGeneralServices() in ClaudeApi for the
    // prompt; the manual "Draft with AI" button in the editor covers the
    // case where cues are added later, after this first pass ran empty).
    //
    // Successive-report carry-forward (gap #10): same pattern as
    // Background above. When this output has no persisted row yet and a
    // prior report's approved text exists, that text is frozen as
    // `carriedForwardContent` and only cues *new since that prior report*
    // (by `created_at`, compared to the prior output's issued/created
    // date) are offered to the amend prompt — passing already-covered cues
    // again risks the model restating them despite instructions not to.
    var generalServicesContent = '';
    var generalServicesAiDrafted = false;
    String? generalServicesCarriedForward;
    final priorGeneralServices = priorPersisted[SectionType.generalServices];
    final generalServicesIsFirstBuild =
        !persisted.containsKey(SectionType.generalServices);
    final allGeneralServiceCues = data.surveyorNotes
        .where((n) =>
            n['case_section'] == 'general_expenses' &&
            n['pending_review'] != true)
        .toList();

    if (generalServicesIsFirstBuild &&
        priorGeneralServices != null &&
        priorGeneralServices.fullContent.isNotEmpty) {
      generalServicesCarriedForward = priorGeneralServices.fullContent;
      if (aiDraft) {
        final priorRaw = data.allReportOutputs
            .where((o) => o['output_id'] == priorOutputId)
            .firstOrNull;
        final cutoff = priorRaw != null
            ? DateTime.tryParse((priorRaw['issued_date'] ??
                    priorRaw['created_at']) as String? ??
                '')
            : null;
        final newCues = allGeneralServiceCues
            .where((n) =>
                cutoff == null ||
                (DateTime.tryParse(n['created_at'] as String? ?? '')
                        ?.isAfter(cutoff) ??
                    true))
            .map((n) => n['content'] as String? ?? '')
            .where((c) => c.isNotEmpty)
            .toList();
        if (newCues.isNotEmpty) {
          try {
            generalServicesContent = await ClaudeApi.draftGeneralServices(
              vesselName: data.vessel?['name'] as String? ?? 'the vessel',
              contextCues: newCues,
              reportFormat: data.outputFormat,
              priorApprovedText: generalServicesCarriedForward,
            );
            generalServicesAiDrafted = generalServicesContent.isNotEmpty;
          } catch (_) {
            // Leave blank rather than an error placeholder — see the same
            // note on Background's amend path above.
            generalServicesContent = '';
          }
        }
      }
    } else if (aiDraft && generalServicesIsFirstBuild) {
      final cues = allGeneralServiceCues
          .map((n) => n['content'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toList();
      if (cues.isNotEmpty) {
        try {
          generalServicesContent = await ClaudeApi.draftGeneralServices(
            vesselName: data.vessel?['name'] as String? ?? 'the vessel',
            contextCues: cues,
            reportFormat: data.outputFormat,
          );
          generalServicesAiDrafted = generalServicesContent.isNotEmpty;
        } catch (_) {
          // Marked drafted even on failure (see the same note on the
          // Cause Consideration attempt above) so a transient API failure
          // doesn't retry silently on every future mount while cues exist.
          generalServicesContent = '[Draft narrative — edit before issuing]';
          generalServicesAiDrafted = true;
        }
      }
    }
    sections[SectionType.generalServices] = ReportSection(
      type: SectionType.generalServices,
      title: 'General Services & Access',
      content: generalServicesContent,
      aiDrafted: generalServicesAiDrafted,
      carriedForwardContent: generalServicesCarriedForward,
    );

    // ── §12.4: Previous Work on the Damaged Item ──────────────────────
    // Auto-drafted from `previous_works`-tagged context cues, same
    // first-build/carry-forward pattern as General Services above (see
    // draftPreviousWorks() in ClaudeApi).
    var previousWorksContent = '';
    var previousWorksAiDrafted = false;
    String? previousWorksCarriedForward;
    final priorPreviousWorks = priorPersisted[SectionType.previousWorks];
    final previousWorksIsFirstBuild =
        !persisted.containsKey(SectionType.previousWorks);
    final allPreviousWorksCues = data.surveyorNotes
        .where((n) =>
            n['case_section'] == 'previous_works' &&
            n['pending_review'] != true)
        .toList();

    if (previousWorksIsFirstBuild &&
        priorPreviousWorks != null &&
        priorPreviousWorks.fullContent.isNotEmpty) {
      previousWorksCarriedForward = priorPreviousWorks.fullContent;
      if (aiDraft) {
        final priorRaw = data.allReportOutputs
            .where((o) => o['output_id'] == priorOutputId)
            .firstOrNull;
        final cutoff = priorRaw != null
            ? DateTime.tryParse((priorRaw['issued_date'] ??
                    priorRaw['created_at']) as String? ??
                '')
            : null;
        final newCues = allPreviousWorksCues
            .where((n) =>
                cutoff == null ||
                (DateTime.tryParse(n['created_at'] as String? ?? '')
                        ?.isAfter(cutoff) ??
                    true))
            .map((n) => n['content'] as String? ?? '')
            .where((c) => c.isNotEmpty)
            .toList();
        if (newCues.isNotEmpty) {
          try {
            previousWorksContent = await ClaudeApi.draftPreviousWorks(
              vesselName: data.vessel?['name'] as String? ?? 'the vessel',
              contextCues: newCues,
              reportFormat: data.outputFormat,
              priorApprovedText: previousWorksCarriedForward,
            );
            previousWorksAiDrafted = previousWorksContent.isNotEmpty;
          } catch (_) {
            previousWorksContent = '';
          }
        }
      }
    } else if (aiDraft && previousWorksIsFirstBuild) {
      final cues = allPreviousWorksCues
          .map((n) => n['content'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toList();
      if (cues.isNotEmpty) {
        try {
          previousWorksContent = await ClaudeApi.draftPreviousWorks(
            vesselName: data.vessel?['name'] as String? ?? 'the vessel',
            contextCues: cues,
            reportFormat: data.outputFormat,
          );
          previousWorksAiDrafted = previousWorksContent.isNotEmpty;
        } catch (_) {
          previousWorksContent = '[Draft narrative — edit before issuing]';
          previousWorksAiDrafted = true;
        }
      }
    }
    sections[SectionType.previousWorks] = ReportSection(
      type: SectionType.previousWorks,
      title: 'Previous Work on the Damaged Item',
      content: previousWorksContent,
      aiDrafted: previousWorksAiDrafted,
      carriedForwardContent: previousWorksCarriedForward,
    );

    // ── §12.5: Extra Expenses to Reduce Delay ────────────────────────
    // Auto-drafted from `extra_expenses`-tagged context cues, same
    // first-build/carry-forward pattern as General Services above (see
    // draftExtraExpenses() in ClaudeApi).
    var extraExpensesContent = '';
    var extraExpensesAiDrafted = false;
    String? extraExpensesCarriedForward;
    final priorExtraExpenses = priorPersisted[SectionType.extraExpenses];
    final extraExpensesIsFirstBuild =
        !persisted.containsKey(SectionType.extraExpenses);
    final allExtraExpenseCues = data.surveyorNotes
        .where((n) =>
            n['case_section'] == 'extra_expenses' &&
            n['pending_review'] != true)
        .toList();

    if (extraExpensesIsFirstBuild &&
        priorExtraExpenses != null &&
        priorExtraExpenses.fullContent.isNotEmpty) {
      extraExpensesCarriedForward = priorExtraExpenses.fullContent;
      if (aiDraft) {
        final priorRaw = data.allReportOutputs
            .where((o) => o['output_id'] == priorOutputId)
            .firstOrNull;
        final cutoff = priorRaw != null
            ? DateTime.tryParse((priorRaw['issued_date'] ??
                    priorRaw['created_at']) as String? ??
                '')
            : null;
        final newCues = allExtraExpenseCues
            .where((n) =>
                cutoff == null ||
                (DateTime.tryParse(n['created_at'] as String? ?? '')
                        ?.isAfter(cutoff) ??
                    true))
            .map((n) => n['content'] as String? ?? '')
            .where((c) => c.isNotEmpty)
            .toList();
        if (newCues.isNotEmpty) {
          try {
            extraExpensesContent = await ClaudeApi.draftExtraExpenses(
              vesselName: data.vessel?['name'] as String? ?? 'the vessel',
              contextCues: newCues,
              reportFormat: data.outputFormat,
              priorApprovedText: extraExpensesCarriedForward,
            );
            extraExpensesAiDrafted = extraExpensesContent.isNotEmpty;
          } catch (_) {
            extraExpensesContent = '';
          }
        }
      }
    } else if (aiDraft && extraExpensesIsFirstBuild) {
      final cues = allExtraExpenseCues
          .map((n) => n['content'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toList();
      if (cues.isNotEmpty) {
        try {
          extraExpensesContent = await ClaudeApi.draftExtraExpenses(
            vesselName: data.vessel?['name'] as String? ?? 'the vessel',
            contextCues: cues,
            reportFormat: data.outputFormat,
          );
          extraExpensesAiDrafted = extraExpensesContent.isNotEmpty;
        } catch (_) {
          extraExpensesContent = '[Draft narrative — edit before issuing]';
          extraExpensesAiDrafted = true;
        }
      }
    }
    sections[SectionType.extraExpenses] = ReportSection(
      type: SectionType.extraExpenses,
      title: 'Extra Expenses to Reduce Delay',
      content: extraExpensesContent,
      aiDrafted: extraExpensesAiDrafted,
      carriedForwardContent: extraExpensesCarriedForward,
    );

    // ── §12.6: Contractual / Hire ──────────────────────────────────
    // Auto-drafted from `contractual_hire`-tagged context cues, same
    // first-build/carry-forward pattern as Extra Expenses above (see
    // draftContractualHire() in ClaudeApi).
    var contractualHireContent = '';
    var contractualHireAiDrafted = false;
    String? contractualHireCarriedForward;
    final priorContractualHire = priorPersisted[SectionType.contractualHire];
    final contractualHireIsFirstBuild =
        !persisted.containsKey(SectionType.contractualHire);
    final allContractualHireCues = data.surveyorNotes
        .where((n) =>
            n['case_section'] == 'contractual_hire' &&
            n['pending_review'] != true)
        .toList();

    if (contractualHireIsFirstBuild &&
        priorContractualHire != null &&
        priorContractualHire.fullContent.isNotEmpty) {
      contractualHireCarriedForward = priorContractualHire.fullContent;
      if (aiDraft) {
        final priorRaw = data.allReportOutputs
            .where((o) => o['output_id'] == priorOutputId)
            .firstOrNull;
        final cutoff = priorRaw != null
            ? DateTime.tryParse((priorRaw['issued_date'] ??
                    priorRaw['created_at']) as String? ??
                '')
            : null;
        final newCues = allContractualHireCues
            .where((n) =>
                cutoff == null ||
                (DateTime.tryParse(n['created_at'] as String? ?? '')
                        ?.isAfter(cutoff) ??
                    true))
            .map((n) => n['content'] as String? ?? '')
            .where((c) => c.isNotEmpty)
            .toList();
        if (newCues.isNotEmpty) {
          try {
            contractualHireContent = await ClaudeApi.draftContractualHire(
              vesselName: data.vessel?['name'] as String? ?? 'the vessel',
              contextCues: newCues,
              reportFormat: data.outputFormat,
              priorApprovedText: contractualHireCarriedForward,
            );
            contractualHireAiDrafted = contractualHireContent.isNotEmpty;
          } catch (_) {
            contractualHireContent = '';
          }
        }
      }
    } else if (aiDraft && contractualHireIsFirstBuild) {
      final cues = allContractualHireCues
          .map((n) => n['content'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toList();
      if (cues.isNotEmpty) {
        try {
          contractualHireContent = await ClaudeApi.draftContractualHire(
            vesselName: data.vessel?['name'] as String? ?? 'the vessel',
            contextCues: cues,
            reportFormat: data.outputFormat,
          );
          contractualHireAiDrafted = contractualHireContent.isNotEmpty;
        } catch (_) {
          contractualHireContent = '[Draft narrative — edit before issuing]';
          contractualHireAiDrafted = true;
        }
      }
    }
    sections[SectionType.contractualHire] = ReportSection(
      type: SectionType.contractualHire,
      title: 'Contractual / Hire',
      content: contractualHireContent,
      aiDrafted: contractualHireAiDrafted,
      carriedForwardContent: contractualHireCarriedForward,
    );

    // ── §12.7: Other Matters of Relevance (cue-drafted narrative) ─────
    // Auto-drafted from `other_matters`-tagged context cues, same
    // first-build/carry-forward pattern as Extra Expenses above (see
    // draftOtherMatters() in ClaudeApi). Distinct from the `surveyorNotes`
    // clause ticklist below (retitled "Advice to Assured", 5 July 2026) —
    // these two used to be one combined section.
    var otherMattersCuesContent = '';
    var otherMattersCuesAiDrafted = false;
    String? otherMattersCuesCarriedForward;
    final priorOtherMattersCues = priorPersisted[SectionType.otherMatters];
    final otherMattersCuesIsFirstBuild =
        !persisted.containsKey(SectionType.otherMatters);
    final allOtherMattersCues = data.surveyorNotes
        .where((n) =>
            n['case_section'] == 'other_matters' && n['pending_review'] != true)
        .toList();

    if (otherMattersCuesIsFirstBuild &&
        priorOtherMattersCues != null &&
        priorOtherMattersCues.fullContent.isNotEmpty) {
      otherMattersCuesCarriedForward = priorOtherMattersCues.fullContent;
      if (aiDraft) {
        final priorRaw = data.allReportOutputs
            .where((o) => o['output_id'] == priorOutputId)
            .firstOrNull;
        final cutoff = priorRaw != null
            ? DateTime.tryParse((priorRaw['issued_date'] ??
                    priorRaw['created_at']) as String? ??
                '')
            : null;
        final newCues = allOtherMattersCues
            .where((n) =>
                cutoff == null ||
                (DateTime.tryParse(n['created_at'] as String? ?? '')
                        ?.isAfter(cutoff) ??
                    true))
            .map((n) => n['content'] as String? ?? '')
            .where((c) => c.isNotEmpty)
            .toList();
        if (newCues.isNotEmpty) {
          try {
            otherMattersCuesContent = await ClaudeApi.draftOtherMatters(
              vesselName: data.vessel?['name'] as String? ?? 'the vessel',
              contextCues: newCues,
              reportFormat: data.outputFormat,
              priorApprovedText: otherMattersCuesCarriedForward,
            );
            otherMattersCuesAiDrafted = otherMattersCuesContent.isNotEmpty;
          } catch (_) {
            otherMattersCuesContent = '';
          }
        }
      }
    } else if (aiDraft && otherMattersCuesIsFirstBuild) {
      final cues = allOtherMattersCues
          .map((n) => n['content'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toList();
      if (cues.isNotEmpty) {
        try {
          otherMattersCuesContent = await ClaudeApi.draftOtherMatters(
            vesselName: data.vessel?['name'] as String? ?? 'the vessel',
            contextCues: cues,
            reportFormat: data.outputFormat,
          );
          otherMattersCuesAiDrafted = otherMattersCuesContent.isNotEmpty;
        } catch (_) {
          otherMattersCuesContent = '[Draft narrative — edit before issuing]';
          otherMattersCuesAiDrafted = true;
        }
      }
    }
    sections[SectionType.otherMatters] = ReportSection(
      type: SectionType.otherMatters,
      title: 'Other Matters of Relevance',
      content: otherMattersCuesContent,
      aiDrafted: otherMattersCuesAiDrafted,
      carriedForwardContent: otherMattersCuesCarriedForward,
    );

    // ── §13: Repair Costs (auto-table in export; narrative commentary here)
    // Clause H-1: fixed approval statement, prepended whenever there are
    // accounts to approve (omitted otherwise, e.g. preliminary reports).
    final accountApprovalClause = data.clauseByType('account_approval_intro');
    // Clause G-1: cost estimate status, once per report.
    final costStatusText = _buildCostStatusText(data);
    final accountsIntro = [
      if (costStatusText != null) costStatusText,
      if (accountApprovalClause?.clauseText != null)
        accountApprovalClause!.clauseText,
    ].join('\n\n');
    sections[SectionType.accounts] = ReportSection(
      type: SectionType.accounts,
      title: 'Repair Costs',
      content: _buildCostSummaryText(data.repairDocuments,
          approvalIntro: accountsIntro.isNotEmpty ? accountsIntro : null),
    );

    // ── §14: Repair Times (auto-table in export; narrative commentary here)
    // Clause I-1: fixed guidance statement, prepended whenever a repair
    // times opinion is actually being given (i.e. there's data to comment on).
    final repairTimesClause = data.clauseByType('repair_times_guidance');
    sections[SectionType.repairTimes] = ReportSection(
      type: SectionType.repairTimes,
      title: 'Repair Times',
      content: _buildRepairTimesText(data.repairPeriods,
          guidanceIntro: repairTimesClause?.clauseText),
    );

    // ── §15: Advice to Assured ──────────────────────────────────────
    // Built from ticked legal clauses (docs/migrations/018_other_matters_
    // clauses.sql) followed by the surveyor's free-text additional notes
    // (docs/migrations/019_other_matters_notes.sql). Originally titled
    // "Other Matters of Relevance"; split and retitled "Advice to Assured"
    // per surveyor direction (5 July 2026) — the cue-driven "Other Matters
    // of Relevance" narrative above (`SectionType.otherMatters`) is now a
    // separate section; this one stays clause-ticklist-driven. isLocked
    // mirrors every other clause-composed section (e.g. `opening`) — both
    // parts are edited at their source (ticklist / notes field on the
    // case screen), not inline in the section textbox here. Empty content
    // here means the section is omitted entirely by both docx's
    // renderTextSection and the Preview tab (report_preview.dart).
    final tickedOtherMattersClauseIds =
        (data.caseData['other_matters_clause_ids'] as List?)?.cast<String>() ??
            const [];
    final otherMattersClauseText = data.clauses
        .where((c) => tickedOtherMattersClauseIds.contains(c.clauseId))
        .map((c) => c.clauseText)
        .join('\n\n');
    final otherMattersNotesText =
        (data.caseData['other_matters_notes'] as String?)?.trim() ?? '';
    final adviceToAssuredText = [otherMattersClauseText, otherMattersNotesText]
        .where((s) => s.isNotEmpty)
        .join('\n\n');
    sections[SectionType.surveyorNotes] = ReportSection(
      type: SectionType.surveyorNotes,
      title: 'Advice to Assured',
      content: adviceToAssuredText,
      isLocked: adviceToAssuredText.isNotEmpty,
    );

    // ── §16: Documents Retained on File (Clause K-1) ──────────────
    sections[SectionType.documentsOnFile] = ReportSection(
      type: SectionType.documentsOnFile,
      title: 'Documents Retained on File',
      content: data.caseDocuments.isNotEmpty
          ? _buildDocumentsOnFileText(data.caseDocuments,
              header: data.clauseByType('documents_on_file_header')?.clauseText)
          : '',
    );

    // ── §17: Documents Requested / Outstanding (Clause K-2) ────────
    sections[SectionType.documentsRequested] = ReportSection(
      type: SectionType.documentsRequested,
      title: 'Documents Requested / Outstanding',
      content: data.requestedDocuments.isNotEmpty
          ? _buildDocumentsRequestedText(data.requestedDocuments,
              header:
                  data.clauseByType('documents_requested_header')?.clauseText)
          : '',
    );

    // ── §19: Waiver ───────────────────────────────────────────────
    final waiverClause = data.clauseByType('waiver');
    final orgWaiver = data.organisation?['waiver_text'] as String?;
    final waiverText = orgWaiver?.isNotEmpty == true
        ? orgWaiver!
        : waiverClause?.clauseText ??
            'The findings and opinions in this report are submitted '
                'without prejudice to the rights of any party. The issuing '
                'firm reserves the right to supplement or amend this report '
                'if additional information becomes available.';
    sections[SectionType.waiver] = ReportSection(
      type: SectionType.waiver,
      title: 'Limitation of Liability / Waiver',
      content: waiverText,
      clauseId: waiverClause?.clauseId,
      isLocked: waiverClause != null,
    );

    // ── Closing disclaimer (spec Clause J-1) ───────────────────────
    // 'closing_disclaimer' clause_type was found mislabeled in the live DB
    // (holding account-approval text) and corrected 2026-07-02 — see
    // docs/legal_clauses.md implementation notes.
    final closingClause = data.clauseByType('closing_disclaimer');
    final orgDisclaimer = data.organisation?['disclaimer_text'] as String?;
    final closingText = orgDisclaimer?.isNotEmpty == true
        ? orgDisclaimer!
        : closingClause?.clauseText ??
            'This report (including any enclosures and attachments) has '
                'been prepared for the exclusive use and benefit of the '
                'addressee(s) and solely for the purpose for which it is '
                'provided. Save to the extent provided for in the Company\'s '
                'Terms and Conditions or such other contract between the '
                'Company (or its affiliate) and the Client (or its affiliate) '
                'governing the issuance of this report, the Company assumes '
                'no liability to the addressee(s) for any claims, loss or '
                'damage whatsoever suffered by the addressee(s) as a result '
                'of any act, omission or default on the part of the Company '
                'or any of its servants, whether due to negligence or '
                'otherwise. No part of this report shall be reproduced, '
                'distributed or communicated to any third party without the '
                'prior written consent of the Company. The Company does not '
                'assume any liability or owe any duty of care if this report '
                'is used for a purpose other than that for which it is '
                'intended or where it is disclosed to or used by a third '
                'party.';
    sections[SectionType.closing] = ReportSection(
      type: SectionType.closing,
      title: 'Disclaimer',
      content: closingText,
      clauseId: closingClause?.clauseId,
      isLocked: closingClause != null,
    );

    // Overlay any previously-saved surveyor edits / review status for this
    // report output — persisted content always wins over the freshly
    // assembled default (locked clause sections are never overridden; the
    // editor never lets the surveyor edit them, so no persisted row for
    // them should exist, but the check is kept defensive). `persisted` was
    // fetched up-front, above.
    for (final entry in persisted.entries) {
      final base = sections[entry.key];
      if (base == null || base.isLocked) continue;
      sections[entry.key] = base.copyWith(
        content: entry.value.content,
        surveyorReview: entry.value.surveyorReview,
        aiDrafted: entry.value.aiDrafted,
        carriedForwardContent: entry.value.carriedForwardContent,
      );
    }

    state = sections;

    // Persist any section auto-drafted just now (no prior persisted row) so
    // the next mount finds it via `persisted` and doesn't call the AI
    // again — auto-drafting is meant to run once per report, not on every
    // screen open. Also persists a freshly-resolved carry-forward base
    // even when the amend draft came back blank/failed (aiDrafted stays
    // false in that case) — otherwise `persisted` would still be empty
    // for that type next mount, and the (cheap but pointless) carry-
    // forward lookup + any AI amend attempt would re-run every time the
    // screen opens instead of once per report.
    for (final type in const [
      SectionType.background,
      SectionType.causation,
      SectionType.generalServices,
    ]) {
      final s = sections[type];
      if (s == null || persisted.containsKey(type)) continue;
      if ((s.aiDrafted && s.content.isNotEmpty) ||
          s.carriedForwardContent != null) {
        await _persist(type);
      }
    }
  }

  Future<Map<SectionType, _PersistedSection>> _fetchPersisted() =>
      _fetchPersistedFor(outputId);

  /// Generalised over [_fetchPersisted] so the carry-forward lookup below
  /// can read a *different* (prior) output's persisted sections, not just
  /// this notifier's own.
  Future<Map<SectionType, _PersistedSection>> _fetchPersistedFor(
      String forOutputId) async {
    try {
      final rows = await SupabaseService.client
          .from('report_sections')
          .select()
          .eq('output_id', forOutputId);
      final map = <SectionType, _PersistedSection>{};
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final type = SectionType.values
            .where((t) => t.name == row['section_type'])
            .firstOrNull;
        if (type == null) continue;
        map[type] = _PersistedSection(
          content: row['content'] as String? ?? '',
          aiDrafted: row['ai_drafted'] as bool? ?? false,
          surveyorReview: SurveyorReview.values
              .where((r) => r.name == row['surveyor_review'])
              .firstOrNull,
          carriedForwardContent: row['carried_forward_content'] as String?,
        );
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Section types eligible for successive-report carry-forward.
  ///
  /// Deliberately narrow — see the design note in gap #10 of
  /// docs/report_builder_editor_notes.md for the full reasoning. In short:
  /// most narrative sections (`occurrence`, `damageDescription`, `repairs`,
  /// `allegation`, `causation`, `surveyorNotes`) are deterministically
  /// *rebuilt from scratch every time* from shared, case-level tables
  /// (occurrences, damage_items, repair_periods, surveyor_notes) that
  /// already accumulate old + new rows regardless of which report output
  /// is open — so they never actually lose data between reports, and
  /// freezing a prior output's text as a carry-forward base for them would
  /// just duplicate everything (the frozen block *and* the fresh rebuild
  /// both containing the same old material).
  ///
  /// `background` and `generalServices` are different: their default is
  /// blank unless AI-drafted (see the sections building them, above) —
  /// there is no deterministic regeneration to fall back on, so whatever
  /// prose the surveyor approved for report N is genuinely gone once
  /// report N+1 starts with a blank slate. These are the two sections this
  /// pass actually fixes.
  static const carryForwardEligibleTypes = {
    SectionType.background,
    SectionType.generalServices,
  };

  /// Version code (e.g. "R002") computed from a raw `report_outputs` row —
  /// same logic as `ReportOutput.versionCode` / the Document Control table
  /// builders, duplicated here because this operates on the raw
  /// `allReportOutputs` maps rather than a parsed `ReportOutput`.
  static String _rawVersionCode(Map<String, dynamic> o) {
    final rn = o['report_number'] as String?;
    if (rn != null) {
      final m = RegExp(r'R\d{3,}$').firstMatch(rn);
      if (m != null) return m.group(0)!;
    }
    final seq = o['sequence_no'] as int? ?? 1;
    return 'R${seq.toString().padLeft(3, '0')}';
  }

  /// Resolves the immediately-preceding report output in this case's
  /// successive chain, via `supersedes_version` (set automatically at
  /// output creation to the then-most-recent output's version code — see
  /// `ReportOutputsNotifier.createOutput`). This is the correct signal for
  /// "prior report", not `sequence_no` (which is scoped per output *type*,
  /// e.g. "Advice No. 2", and not globally chronological) or `created_at`
  /// alone (which doesn't capture the surveyor's own understanding of
  /// which report a new one continues from).
  String? _priorOutputId(ReportOutput output, AssembledReportData data) {
    final supersedes = output.supersedesVersion;
    if (supersedes == null) return null;
    final prior = data.allReportOutputs
        .where((o) => _rawVersionCode(o) == supersedes)
        .firstOrNull;
    return prior?['output_id'] as String?;
  }

  /// Drafts [type] (background or causation only) with AI on demand,
  /// wiring up the AI-drafting code paths that [buildSections] already has
  /// but that are otherwise unreachable from the UI. Marks the result
  /// `aiDrafted: true` so the GPN-AI review gate applies to it.
  Future<void> draftSectionWithAi(
      SectionType type, AssembledReportData data) async {
    final existing = state[type];
    if (existing == null || existing.isLocked) return;

    String content;
    try {
      switch (type) {
        case SectionType.background:
          if (data.occurrences.isEmpty) return;
          final occ = data.occurrences.first;
          content = await ClaudeApi.draftOccurrenceNarrative(
            vesselName: data.vessel?['name'] ?? 'the vessel',
            occurrenceDate: occ['date_time'] as String? ?? '',
            occurrenceLocation: occ['location'] as String? ?? '',
            occurrenceTitle: occ['title'] as String? ?? '',
            damageItems: data.damageItems
                .map((d) => d['component_name'] as String? ?? '')
                .toList(),
            interviewTranscript: null,
            reportFormat: data.outputFormat,
            // Successive-report carry-forward (gap #10) — if this
            // section already has a frozen carried-forward base (set once
            // by buildSections() on the first mount of this output), a
            // manual re-draft via the "Draft with AI" button should also
            // amend rather than redraft from scratch.
            priorApprovedText: existing.carriedForwardContent,
          );
        case SectionType.causation:
          final occ =
              data.occurrences.isNotEmpty ? data.occurrences.first : null;
          content = await ClaudeApi.draftCauseConsideration(
            vesselName: data.vessel?['name'] ?? 'the vessel',
            occurrenceTitle: occ?['title'] as String? ?? '',
            damageItems: data.damageItems
                .map((d) => d['component_name'] as String? ?? '')
                .toList(),
            ownersAllegation: occ?['owners_stated_cause'] as String?,
            serviceEngineerFindings: null,
            reportFormat: data.outputFormat,
          );
        case SectionType.generalServices:
          final cues = data.surveyorNotes
              .where((n) =>
                  n['case_section'] == 'general_expenses' &&
                  n['pending_review'] != true)
              .map((n) => n['content'] as String? ?? '')
              .where((c) => c.isNotEmpty)
              .toList();
          if (cues.isEmpty) return;
          content = await ClaudeApi.draftGeneralServices(
            vesselName: data.vessel?['name'] as String? ?? 'the vessel',
            contextCues: cues,
            reportFormat: data.outputFormat,
            priorApprovedText: existing.carriedForwardContent,
          );
        case SectionType.previousWorks:
          final cues = data.surveyorNotes
              .where((n) =>
                  n['case_section'] == 'previous_works' &&
                  n['pending_review'] != true)
              .map((n) => n['content'] as String? ?? '')
              .where((c) => c.isNotEmpty)
              .toList();
          if (cues.isEmpty) return;
          content = await ClaudeApi.draftPreviousWorks(
            vesselName: data.vessel?['name'] as String? ?? 'the vessel',
            contextCues: cues,
            reportFormat: data.outputFormat,
            priorApprovedText: existing.carriedForwardContent,
          );
        case SectionType.extraExpenses:
          final cues = data.surveyorNotes
              .where((n) =>
                  n['case_section'] == 'extra_expenses' &&
                  n['pending_review'] != true)
              .map((n) => n['content'] as String? ?? '')
              .where((c) => c.isNotEmpty)
              .toList();
          if (cues.isEmpty) return;
          content = await ClaudeApi.draftExtraExpenses(
            vesselName: data.vessel?['name'] as String? ?? 'the vessel',
            contextCues: cues,
            reportFormat: data.outputFormat,
            priorApprovedText: existing.carriedForwardContent,
          );
        case SectionType.contractualHire:
          final cues = data.surveyorNotes
              .where((n) =>
                  n['case_section'] == 'contractual_hire' &&
                  n['pending_review'] != true)
              .map((n) => n['content'] as String? ?? '')
              .where((c) => c.isNotEmpty)
              .toList();
          if (cues.isEmpty) return;
          content = await ClaudeApi.draftContractualHire(
            vesselName: data.vessel?['name'] as String? ?? 'the vessel',
            contextCues: cues,
            reportFormat: data.outputFormat,
            priorApprovedText: existing.carriedForwardContent,
          );
        case SectionType.otherMatters:
          final cues = data.surveyorNotes
              .where((n) =>
                  n['case_section'] == 'other_matters' &&
                  n['pending_review'] != true)
              .map((n) => n['content'] as String? ?? '')
              .where((c) => c.isNotEmpty)
              .toList();
          if (cues.isEmpty) return;
          content = await ClaudeApi.draftOtherMatters(
            vesselName: data.vessel?['name'] as String? ?? 'the vessel',
            contextCues: cues,
            reportFormat: data.outputFormat,
            priorApprovedText: existing.carriedForwardContent,
          );
        default:
          return;
      }
    } catch (_) {
      content = '[Draft narrative — edit before issuing]';
    }
    if (content.isEmpty) return;

    state = {
      ...state,
      type: existing.copyWith(content: content, aiDrafted: true),
    };
    await _persist(type);
  }

  // ── Text builders ─────────────────────────────────────────────────────────

  String _buildExecutiveSummaryTemplate(AssembledReportData data) {
    final vesselName = data.vessel?['name'] as String? ?? '[vessel name]';
    final occ = data.occurrences.isNotEmpty ? data.occurrences.first : null;
    final occTitle = occ?['title'] as String? ?? '[nature of casualty]';
    final occDate =
        occ != null ? _formatDate(occ['date_time'] as String? ?? '') : '[date]';
    final claimRef = data.caseData['claim_reference'] as String? ?? '';
    final claimLine = claimRef.isNotEmpty ? 'Claim Reference: $claimRef\n' : '';
    return 'Vessel: $vesselName\n'
        'Casualty: $occTitle\n'
        'Date: $occDate\n'
        '$claimLine'
        '\n'
        'Advice:\n'
        '[Summarise surveyor\'s principal findings, recommendations, and any '
        'immediate advice given to underwriters / principals. Edit before issuing.]';
  }

  String _fillOpeningClause(String template, AssembledReportData data) {
    final clientName =
        data.caseData['principals_clients']?['name'] as String? ?? '[CLIENT]';

    // Clause D-3: first attendance date/location — from the earliest
    // survey_attendances record (already ordered ascending), not the
    // occurrence's date of loss, which can differ from when the surveyor
    // actually first attended.
    final firstAttendance =
        data.attendances.where((a) => a['attendance_date'] != null).firstOrNull;
    final attendanceDate = firstAttendance?['attendance_date'] as String?;
    final occDate = data.occurrences.isNotEmpty
        ? data.occurrences.first['date_time'] as String?
        : null;
    final firstAttendanceDate = attendanceDate ?? occDate;

    final location = firstAttendance?['location'] as String?;

    final filled = template
        .replaceAll('[CLIENT]', clientName)
        .replaceAll(
            '[FIRST_ATTENDANCE_DATE]',
            firstAttendanceDate != null
                ? _formatDate(firstAttendanceDate)
                : '[DATE]')
        .replaceAll(
            '[LOCATION_DESCRIPTION]',
            location ??
                data.caseData['notes'] as String? ??
                'the survey location');

    // Clause B-2: survey type. Derived from the case's existing claim type
    // rather than a new field — per the surveyor, this practice's H&M cases
    // are always treated as "a hull and machinery damage survey"; the doc's
    // other 5 categories (pure machinery/hull/grounding/collision/fire) are
    // not distinguished here. Only appended for case_type == 'hm'.
    if (data.caseData['case_type'] == 'hm') {
      final surveyType =
          data.clauseByType('survey_type_hull_and_machinery')?.clauseText;
      if (surveyType != null && surveyType.isNotEmpty) {
        return '$filled $surveyType';
      }
    }
    return filled;
  }

  // Clause C-1: only the vessel types below have a matching doc phrase —
  // every other value in the vessel screen's dropdown (Anchor Handling Tug,
  // Products Carrier, Reefer Vessel, etc.) and any Equasis-imported type
  // string intentionally has no entry, so C-1 is simply omitted for them
  // rather than forcing a guessed phrase. Decided 2026-07-02 — see
  // docs/legal_clauses.md implementation notes for the full mapping table
  // and the one judgment call (Passenger Ferry → Ro-Ro/ferry phrase).
  static const _shipTypeClause = {
    'General Cargo Ship': 'ship_type_general_cargo',
    'Bulk Carrier': 'ship_type_bulk_carrier',
    'Container Ship': 'ship_type_container',
    'Container Carrier': 'ship_type_container',
    'Oil Tanker': 'ship_type_tanker_oil',
    'Chemical Tanker': 'ship_type_tanker_chemical',
    'Offshore Support Vessel': 'ship_type_offshore_support',
    'Offshore Supply Vessel': 'ship_type_offshore_support',
    'Tug': 'ship_type_tug',
    'Ro Ro': 'ship_type_roro_ferry',
    'Passenger Ferry': 'ship_type_roro_ferry',
  };

  String _buildVesselText(AssembledReportData data) {
    final v = data.vessel;
    if (v == null) return '[Vessel particulars not yet recorded]';
    final lines = <String>[];

    // Clause C-1: ship type sentence, only when the vessel's type maps to
    // one of the doc's categories (see _shipTypeClause above).
    final vesselType = v['vessel_type'] as String?;
    final shipTypeClauseType = _shipTypeClause[vesselType];
    if (shipTypeClauseType != null) {
      final clause = data.clauseByType(shipTypeClauseType);
      if (clause != null) lines.add(clause.clauseText);
    }

    if (v['name'] != null) {
      lines.add('Vessel Name: ${v['name']}');
    }
    if (v['imo_number'] != null) {
      lines.add('IMO Number: ${v['imo_number']}');
    }
    if (v['vessel_type'] != null) {
      lines.add('Type: ${v['vessel_type']}');
    }
    if (v['flag'] != null) {
      lines.add('Flag: ${v['flag']} / ${v['port_of_registry'] ?? ''}');
    }
    final isDcv = v['regulatory_standard'] == 'dcv';
    if (v['gross_tonnage'] != null) {
      lines.add('GT / DWT: ${v['gross_tonnage']} / ${v['deadweight'] ?? '—'}'
          '${isDcv ? ' (National)' : ''}');
    }
    if (v['year_built'] != null) {
      lines.add(
          'Built: ${v['year_built']} at ${v['build_yard'] ?? ''}, ${v['build_country'] ?? ''}');
    }
    if (v['owners'] != null) {
      lines.add('Owners: ${v['owners']}');
    }
    if (v['class_society'] != null) {
      lines.add('Class: ${v['class_society']} — ${v['class_notation'] ?? ''}');
    }
    // DCV — National Law only: AMSA-specific particulars (spec §3).
    if (v['hull_material'] != null) {
      lines.add('Hull Material: ${v['hull_material']}');
    }
    if (v['unique_vessel_identifier'] != null) {
      lines.add('Unique Vessel Identifier: ${v['unique_vessel_identifier']}');
    }
    if (v['survey_certificate_no'] != null) {
      lines.add('Survey Certificate No.: ${v['survey_certificate_no']}');
    }
    final amsaUseClass = v['amsa_vessel_use_class'] as String?;
    final amsaCategory = v['amsa_service_category'] as String?;
    if (amsaUseClass != null && amsaCategory != null) {
      lines.add('Class: Class $amsaUseClass${amsaCategory.toUpperCase()}');
    }
    if (v['equipment_survey_due'] != null) {
      lines.add(
          'Equipment Due: ${_formatDate(v['equipment_survey_due'] as String)}');
    }
    if (v['hull_survey_due'] != null) {
      lines.add('Hull Due: ${_formatDate(v['hull_survey_due'] as String)}');
    }
    if (v['tail_shaft_survey_due'] != null) {
      lines.add(
          'Tail Shaft Due: ${_formatDate(v['tail_shaft_survey_due'] as String)}');
    }
    return lines.join('\n');
  }

  String _buildAttendeesText(List<Map<String, dynamic>> attendees) {
    return attendees.map((a) {
      final name = a['full_name'] as String? ?? '';
      final rank = a['rank_position'] as String? ?? '';
      final company = a['company'] as String? ?? '';
      final rep = a['representing'] as String? ?? company;
      return '$rank $name — $rep';
    }).join('\n');
  }

  /// Groups damage items by claim object (machinery when linked, else the
  /// item's own component name) and renders one bulleted block per group,
  /// matching the spec §7 suggested layout ("The [component] was inspected…
  /// the following damage was observed: • bullets").
  /// Suggested hedging language per certainty level (spec §10 table) —
  /// same wording as the live preview in causation_sheet.dart; kept as a
  /// separate copy since that file is UI-preview-only and this one feeds
  /// the actual rendered text.
  String? _certaintyHedgeLanguage(String? certaintyLevelRaw) {
    final level = CertaintyLevel.fromValue(certaintyLevelRaw);
    if (level == null) return null;
    return switch (level) {
      CertaintyLevel.agreedNoReservation =>
        'The cause of loss as stated by owners appears to be reasonable '
            'and is agreed with.',
      CertaintyLevel.agreedPendingAnalysis =>
        'The cause of loss as stated by owners is agreed with, on a '
            'preliminary basis, pending further analysis.',
      CertaintyLevel.consistentWithAllegation =>
        'It is the opinion of the Undersigned that the damages detailed '
            'above may reasonably be attributed to a casualty of the '
            'nature of that alleged.',
      CertaintyLevel.preliminaryOnly =>
        'A final conclusion on the cause cannot be reached at this stage. '
            'On a preliminary basis, the following potential causes are '
            'considered:',
      CertaintyLevel.disagreeReserves =>
        'The Undersigned Surveyor is unable to agree with the allegation '
            'as stated, for the following reasons:',
      CertaintyLevel.noOpinion =>
        'At this stage of the investigation, it is not possible to offer '
            'an opinion on cause.',
    };
  }

  String _buildDamageText(
      List<Map<String, dynamic>> items, List<Map<String, dynamic>> machinery) {
    final groups = <String, List<Map<String, dynamic>>>{};
    final groupLabels = <String, String>{};
    for (final d in items) {
      final machineryId = d['machinery_id'] as String?;
      final componentName = d['component_name'] as String? ?? '';
      final key = machineryId ?? 'unlinked:$componentName';
      groups.putIfAbsent(key, () => []).add(d);
      groupLabels.putIfAbsent(key, () {
        if (machineryId == null) return componentName;
        final match = machinery
            .where((row) => row['machinery_id'] == machineryId)
            .firstOrNull;
        if (match == null) return componentName;
        final type = match['machinery_type'] as String? ?? '';
        final role = match['role'] as String? ?? '';
        return role.isNotEmpty ? '$type — $role' : type;
      });
    }

    return groups.entries.map((entry) {
      final label = groupLabels[entry.key] ?? '';
      final buf = StringBuffer();
      if (label.isNotEmpty) {
        buf.writeln('The $label was inspected. The following damage was '
            'observed:');
      }
      for (final d in entry.value) {
        final description = d['damage_description'] as String? ?? '';
        final conditionStatusRaw = d['condition_status'] as String?;
        final conditionFound = d['condition_found'] as String? ?? '';
        final line = StringBuffer('  • ');
        line.write(description.isNotEmpty
            ? description
            : (d['component_name'] as String? ?? ''));
        if (conditionStatusRaw != null) {
          line.write(
              ' (${ConditionStatus.fromValue(conditionStatusRaw).label})');
        } else if (conditionFound.isNotEmpty) {
          line.write(' ($conditionFound)');
        }
        buf.writeln(line.toString());

        // Third-party confirmation sentence (spec §7 "Third-Party
        // Confirmation of Damage") — only when confirmed by someone other
        // than the surveyor themselves.
        final confirmedByRaw =
            (d['confirmed_by'] as List?)?.cast<String>() ?? const [];
        final nonSurveyorConfirmers = confirmedByRaw
            .map(ConfirmedByRole.fromValue)
            .where((r) => r != ConfirmedByRole.undersignedSurveyor)
            .toList();
        final confirmationDate = d['confirmation_date'] as String?;
        final confirmationMethod = d['confirmation_method'] as String?;
        if (nonSurveyorConfirmers.isNotEmpty) {
          final who = nonSurveyorConfirmers.map((r) => r.label).join(', ');
          final componentName = d['component_name'] as String? ?? 'this item';
          final methodClause =
              confirmationMethod != null && confirmationMethod.isNotEmpty
                  ? ' following $confirmationMethod'
                  : '';
          final dateClause = confirmationDate != null
              ? ' on ${_formatDate(confirmationDate)}'
              : '';
          buf.writeln('    Damage to the $componentName was confirmed by '
              '$who$methodClause$dateClause.');
        }

        // Average status — rendered inline per spec, not as a separate
        // section. Prefer the 3-way status when present.
        final averageStatusRaw = d['average_status'] as String?;
        final averagePartialDetail = d['average_partial_detail'] as String?;
        if (averageStatusRaw == 'no') {
          final reason = d['exclusion_reason'] as String?;
          buf.writeln('    This item is unrelated to the casualty'
              '${reason != null && reason.isNotEmpty ? ' ($reason)' : ''}.');
        } else if (averageStatusRaw == 'partial') {
          buf.writeln('    Partially concerning average'
              '${averagePartialDetail != null && averagePartialDetail.isNotEmpty ? ' — $averagePartialDetail' : ''}.');
        } else if (averageStatusRaw == null &&
            (d['is_concerning_average'] as bool? ?? true) == false) {
          final reason = d['exclusion_reason'] as String?;
          buf.writeln('    This item is unrelated to the casualty'
              '${reason != null && reason.isNotEmpty ? ' ($reason)' : ''}.');
        }
      }
      return buf.toString().trimRight();
    }).join('\n\n');
  }

  static const _servicesProvidedClause = {
    'crane_lifting': 'services_crane_lifting',
    'scaffolding': 'services_scaffolding',
    'gas_freeing': 'services_gas_freeing',
    'diving': 'services_diving',
    'class_attendance': 'services_class_attendance',
    'ndt_xray': 'services_ndt_xray',
    'hydraulic_testing': 'services_hydraulic_testing',
    'air_pressure_testing': 'services_air_pressure_testing',
    'hose_testing': 'services_hose_testing',
  };

  /// §11.1 Nature of the Repairs — surveyor-entered flags (each with an
  /// optional comment) plus a free "anticipated sequence of repairs"
  /// bullet list. Each bullet/line is its own paragraph (blank-line
  /// separated) so [splitSectionParagraphs] renders them individually.
  String _buildNatureOfRepairsText(Map<String, dynamic>? n) {
    if (n == null) return '';

    String? bullet(String flagKey, String commentKey, String label) {
      if (n[flagKey] != true) return null;
      final comment = (n[commentKey] as String?)?.trim();
      return comment != null && comment.isNotEmpty
          ? '•  $label: $comment'
          : '•  $label.';
    }

    final bullets = [
      bullet('drydocking_required', 'drydocking_comment',
          'Drydocking of the vessel is anticipated'),
      bullet('assured_plan_formulated', 'assured_plan_comment',
          'The Assured has formulated a plan for the repairs'),
      bullet('further_inspections_planned', 'further_inspections_comment',
          'Further inspections are planned prior to the repairs'),
      bullet('parts_long_lead_time', 'parts_lead_time_comment',
          'Parts with a long lead time are required'),
      bullet('foreseeable_difficulties', 'foreseeable_difficulties_comment',
          'Foreseeable difficulties have been identified'),
    ].whereType<String>().toList();

    final sequenceItems = (n['sequence_items'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map((e) => e['text'] as String? ?? '')
            .where((t) => t.isNotEmpty)
            .toList() ??
        const [];

    return [
      if (bullets.isNotEmpty) bullets.join('\n\n'),
      if (sequenceItems.isNotEmpty)
        [
          'Anticipated Sequence of Repairs:',
          ...sequenceItems.map((t) => '•  $t'),
        ].join('\n\n'),
    ].join('\n\n');
  }

  String _buildRepairsText(List<Map<String, dynamic>> periods) {
    return periods.map((json) {
      final p = RepairPeriodModel.fromJson(json);
      final loc = p.location ?? '';
      final prefix =
          p.portContext == PortContext.diversion ? 'Diversion — ' : '';
      return '$prefix${p.displayTitle}${loc.isNotEmpty ? ', $loc' : ''}';
    }).join('\n');
  }

  /// Clauses F-2/F-5: services provided + hot work compliance, per repair
  /// period — repair_periods is the actively-used table.
  String _buildServicesAndHotWorkText(AssembledReportData data) {
    return data.repairPeriods
        .map((p) {
          final buf = StringBuffer();
          final title = p['title'] as String? ??
              p['location'] as String? ??
              'Repair period';
          buf.write(title);

          final services =
              (p['services_provided'] as List?)?.cast<String>() ?? [];
          for (final key in services) {
            final clauseType = _servicesProvidedClause[key];
            if (clauseType == null) continue;
            final text = data.clauseByType(clauseType)?.clauseText;
            if (text != null && text.isNotEmpty) buf.write('\n  • $text');
          }
          final servicesNotes = p['services_provided_notes'] as String?;
          if (servicesNotes != null && servicesNotes.isNotEmpty) {
            buf.write('\n  $servicesNotes');
          }

          final hotWorkStatus = p['hot_work_status'] as String?;
          final hotWorkClauseType = switch (hotWorkStatus) {
            'certs_valid' => 'hot_work_certs_valid',
            'certs_not_sighted' => 'hot_work_certs_not_sighted',
            _ => null,
          };
          if (hotWorkClauseType != null) {
            final text = data.clauseByType(hotWorkClauseType)?.clauseText;
            if (text != null && text.isNotEmpty) buf.write('\n  • $text');
          }
          final hotWorkNotes = p['hot_work_notes'] as String?;
          if (hotWorkNotes != null && hotWorkNotes.isNotEmpty) {
            buf.write('\n  $hotWorkNotes');
          }

          return buf.toString();
        })
        .where((s) => s.trim().isNotEmpty)
        .join('\n\n');
  }

  String _buildMachineryText(List<Map<String, dynamic>> items) {
    return items.map((m) {
      final type = m['machinery_type'] as String? ?? '';
      final role = m['role'] as String? ?? '';
      final make = m['make'] as String? ?? '';
      final model = m['model'] as String? ?? '';
      final serial = m['serial_number'] as String? ?? '';
      final kw = (m['mcr_kw'] as num?)?.toStringAsFixed(0);
      final buf = StringBuffer(type);
      if (role.isNotEmpty) buf.write(' — $role');
      if (make.isNotEmpty || model.isNotEmpty) {
        buf.write('\n  $make $model'.trimRight());
      }
      if (serial.isNotEmpty) buf.write(' (S/N: $serial)');
      if (kw != null) buf.write('\n  MCR: $kw kW');
      return buf.toString();
    }).join('\n\n');
  }

  String _buildClassStatutoryText(AssembledReportData data) {
    final certs = data.certificates;
    final conditions = data.classConditions;
    final vessel = data.vessel;
    final buf = StringBuffer();

    // Clause C-6a: class status
    final classSociety = vessel?['class_society'] as String?;
    if (classSociety != null && classSociety.isNotEmpty) {
      final clause = data.clauseByType('class_status_statement');
      if (clause != null) {
        buf.writeln(
            clause.clauseText.replaceAll('{CLASS_SOCIETY}', classSociety));
      }
    }

    // Clauses C-6b/C-6c: DOC / SMC certificates
    Map<String, dynamic>? findCert(String type) =>
        certs.where((c) => c['cert_type'] == type).firstOrNull;
    final docCert = findCert('doc');
    if (docCert != null &&
        (docCert['issuing_authority'] as String?)?.isNotEmpty == true) {
      final clause = data.clauseByType('doc_certificate_statement');
      if (clause != null) {
        buf.writeln(clause.clauseText
            .replaceAll('{DOC_ISSUER}', docCert['issuing_authority'] as String)
            .replaceAll('{DOC_ISSUE_DATE}',
                _formatDate(docCert['issue_date'] as String? ?? ''))
            .replaceAll('{DOC_EXPIRY}',
                _formatDate(docCert['expiry_date'] as String? ?? '')));
      }
    }
    final smcCert = findCert('smc');
    if (smcCert != null &&
        (smcCert['issuing_authority'] as String?)?.isNotEmpty == true) {
      final clause = data.clauseByType('smc_certificate_statement');
      if (clause != null) {
        buf.writeln(clause.clauseText
            .replaceAll('{SMC_ISSUER}', smcCert['issuing_authority'] as String)
            .replaceAll('{SMC_ISSUE_DATE}',
                _formatDate(smcCert['issue_date'] as String? ?? ''))
            .replaceAll('{SMC_EXPIRY}',
                _formatDate(smcCert['expiry_date'] as String? ?? '')));
      }
    }

    // Clause C-6e: last drydock
    final lastDdYard = vessel?['last_drydock_yard'] as String?;
    if (lastDdYard != null && lastDdYard.isNotEmpty) {
      final clause = data.clauseByType('last_drydock_statement');
      if (clause != null) {
        final lastDdDate = vessel?['last_drydock_date'] as String?;
        buf.writeln(clause.clauseText
            .replaceAll('{LAST_DD_YARD}', lastDdYard)
            .replaceAll('{LAST_DD_DATE}',
                lastDdDate != null ? _formatDate(lastDdDate) : ''));
      }
    }

    // Clause C-6f: statutory certificate status — mutually exclusive 3-way
    if (certs.isNotEmpty) {
      final expired = certs.where((c) => c['status'] == 'expired').toList();
      final notSighted =
          certs.where((c) => c['status'] == 'not_sighted').toList();
      String? clauseType;
      String certDetails = '';
      if (expired.isNotEmpty) {
        clauseType = 'statutory_certs_expired';
        certDetails = expired
            .map((c) =>
                c['cert_name'] as String? ?? c['cert_type'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .join(', ');
      } else if (notSighted.isNotEmpty) {
        clauseType = 'statutory_certs_not_sighted';
      } else if (certs.every((c) => c['status'] == 'valid')) {
        clauseType = 'statutory_certs_valid';
      }
      if (clauseType != null) {
        final clause = data.clauseByType(clauseType);
        if (clause != null) {
          buf.writeln(
              clause.clauseText.replaceAll('{CERT_DETAILS}', certDetails));
        }
      }
    }

    if (buf.isNotEmpty) buf.writeln();

    if (certs.isNotEmpty) {
      buf.writeln('Certificates on Board:');
      for (final c in certs) {
        final name =
            c['cert_name'] as String? ?? c['cert_type'] as String? ?? '';
        final expiry = c['expiry_date'] as String? ?? '';
        buf.writeln(
            '  • $name${expiry.isNotEmpty ? ' — expires ${_formatDate(expiry)}' : ''}');
      }
    }
    if (conditions.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.writeln('Conditions of Class:');
      for (final cc in conditions) {
        final ref = cc['reference'] as String? ?? '';
        final desc = cc['description'] as String? ?? '';
        final due = cc['expiry_date'] as String? ?? '';
        buf.writeln('  • ${ref.isNotEmpty ? '[$ref] ' : ''}$desc'
            '${due.isNotEmpty ? ' — due ${_formatDate(due)}' : ''}');
      }
    }
    return buf.toString().trimRight();
  }

  String _buildInfoSourcesText(List<Map<String, dynamic>> docs) {
    final categorised = <String, List<String>>{};
    for (final d in docs) {
      final cat = d['doc_category'] as String? ?? 'Other';
      final title = d['title'] as String? ?? 'Untitled';
      categorised.putIfAbsent(cat, () => []).add(title);
    }
    return categorised.entries.map((e) {
      final header = e.key.replaceAll('_', ' ').toUpperCase();
      final items = e.value.map((t) => '  • $t').join('\n');
      return '$header\n$items';
    }).join('\n\n');
  }

  String _buildDocumentsOnFileText(List<Map<String, dynamic>> docs,
      {String? header}) {
    final body = docs.asMap().entries.map((e) {
      final idx = e.key + 1;
      final title = e.value['title'] as String? ?? 'Untitled';
      final annex = e.value['annexure_assignment'] as String?;
      final date = e.value['doc_date'] as String? ?? '';
      final suffix = [
        if (annex != null && annex.isNotEmpty) 'Annexure $annex',
        if (date.isNotEmpty) _formatDate(date),
      ].join(' — ');
      return '$idx. $title${suffix.isNotEmpty ? ' — $suffix' : ''}';
    }).join('\n');
    return header != null && header.isNotEmpty ? '$header\n\n$body' : body;
  }

  static const _vesselStatusClause = {
    'at_sea': 'vessel_status_at_sea',
    'in_port_at_anchor': 'vessel_status_in_port',
    'maintenance': 'vessel_status_maintenance',
    'manoeuvring': 'vessel_status_manoeuvring',
  };

  static const _aftermathClause = {
    'own_power': 'aftermath_own_power',
    'tug_only': 'aftermath_tug_only',
    'tug_and_pilot': 'aftermath_tug_pilot',
    'tug_pilot_lines_gangway': 'aftermath_tug_pilot_lines_gangway',
    'towed': 'aftermath_towed',
    'proceeded_with_operations': 'aftermath_proceeded_operations',
  };

  String _buildOccurrenceText(
      Map<String, dynamic> occ, AssembledReportData data) {
    final lines = <String>[];
    final brief = occ['brief_description'] as String?;
    if (brief != null && brief.isNotEmpty) lines.add(brief);

    // Clause D-2: vessel status at the time of the casualty.
    final vesselStatusType =
        _vesselStatusClause[occ['vessel_status_at_casualty']];
    if (vesselStatusType != null) {
      final text = data.clauseByType(vesselStatusType)?.clauseText;
      if (text != null && text.isNotEmpty) lines.add(text);
    }

    // Clause F-1 (Aftermath): how the vessel proceeded after the casualty,
    // with an optional named port appended before the closing period.
    final aftermathType = _aftermathClause[occ['aftermath_status']];
    if (aftermathType != null) {
      var text = data.clauseByType(aftermathType)?.clauseText;
      final port = occ['aftermath_port'] as String?;
      if (text != null && text.isNotEmpty) {
        if (port != null && port.isNotEmpty && text.endsWith('.')) {
          text = '${text.substring(0, text.length - 1)} at $port.';
        }
        lines.add(text);
      }
    }

    return lines.join('\n\n');
  }

  String _buildDocumentsRequestedText(List<Map<String, dynamic>> docs,
      {String? header}) {
    final body = docs.asMap().entries.map((e) {
      final idx = e.key + 1;
      final title = e.value['title'] as String? ?? 'Untitled';
      final requested = e.value['requested_date'] as String?;
      final suffix = requested != null && requested.isNotEmpty
          ? 'requested ${_formatDate(requested)}'
          : '';
      return '$idx. $title${suffix.isNotEmpty ? ' — $suffix' : ''}';
    }).join('\n');
    return header != null && header.isNotEmpty ? '$header\n\n$body' : body;
  }

  /// Clause G-1: cost estimate status. Three states per the surveyor's own
  /// account-review workflow (not the source doc's original 4 — no CTL
  /// scenario tracked here): no invoices yet, ongoing with partial invoices,
  /// or completed with all invoices in. Returns null if no status is set.
  String? _buildCostStatusText(AssembledReportData data) {
    final status = data.caseData['cost_estimate_status'] as String?;
    if (status == null) return null;
    final currency = data.caseData['base_currency'] as String? ?? '';
    final estimate =
        (data.caseData['estimated_repair_cost'] as num?)?.toString();

    String? fill(String clauseType) => data
        .clauseByType(clauseType)
        ?.clauseText
        .replaceAll('{CURRENCY_CODE}', currency)
        .replaceAll('{ESTIMATED_COST}', estimate ?? '');

    return switch (status) {
      'no_invoices_yet' => estimate != null
          ? fill('cost_status_estimate_obtained')
          : fill('cost_status_estimate_not_obtained'),
      'ongoing_partial_invoices' => fill('cost_status_ongoing'),
      'completed_all_invoices' => fill('cost_status_completed'),
      _ => null,
    };
  }

  String _buildCostSummaryText(List<Map<String, dynamic>> repairDocs,
      {String? approvalIntro}) {
    // Spec §11 "Estimate Caveats (Preliminary/Progress)": the cost-status
    // caveat clause (Clause G-1, via approvalIntro) must still render when
    // no repair accounts have been received yet — previously this returned
    // '' before approvalIntro was ever used, silently dropping the caveat
    // from the Editor/Preview (docx was unaffected — it builds its cost
    // text independently, not from this section's content).
    if (repairDocs.isEmpty) {
      return approvalIntro ?? '';
    }
    var total = 0.0;
    final lines = <String>[];
    for (final doc in repairDocs) {
      final supplier =
          doc['supplier'] as String? ?? doc['title'] as String? ?? '';
      final lines_ =
          (doc['account_lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final docTotal = lines_.fold(
          0.0, (s, l) => s + ((l['amount'] as num?)?.toDouble() ?? 0.0));
      total += docTotal;
      if (supplier.isNotEmpty) {
        lines.add('$supplier: ${_formatAmount(docTotal)}');
      }
    }
    if (lines.isEmpty) return approvalIntro ?? '';
    lines.add('Total: ${_formatAmount(total)}');
    final body = lines.join('\n');
    return approvalIntro != null && approvalIntro.isNotEmpty
        ? '$approvalIntro\n\n$body'
        : body;
  }

  String _buildRepairTimesText(List<Map<String, dynamic>> periods,
      {String? guidanceIntro}) {
    if (periods.isEmpty) return '';
    final lines = <String>[];
    for (final json in periods) {
      final p = RepairPeriodModel.fromJson(json);
      final dd = p.drydockDaysTotal;
      final ad = p.alongsideDaysTotal;
      final od = p.ownerDaysTotal;
      if (dd + ad + od > 0) {
        final parts = [
          if (dd > 0) '${dd.toStringAsFixed(1)} drydock',
          if (ad > 0) '${ad.toStringAsFixed(1)} afloat',
          if (od > 0) '${od.toStringAsFixed(1)} owner',
        ].join(', ');
        lines.add('${p.displayTitle}: $parts days');
      }
    }
    if (lines.isEmpty) return '';
    final body = lines.join('\n');
    return guidanceIntro != null && guidanceIntro.isNotEmpty
        ? '$guidanceIntro\n\n$body'
        : body;
  }

  String _formatAmount(double v) =>
      'USD ${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
