// lib/features/reports/providers/report_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/claude_api.dart';

// ── Report output types ────────────────────────────────────────────────────

enum OutputType {
  preliminary('preliminary', 'Preliminary Report'),
  advice('advice',           'Advice'),
  final_('final',            'Final Report');

  const OutputType(this.value, this.label);
  final String value;
  final String label;

  static OutputType fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => OutputType.preliminary);
}

enum ReportStatus {
  draft('draft',           'Draft'),
  selfReviewed('self_reviewed', 'Self Reviewed'),
  submittedQc('submitted_qc',  'Submitted for QC'),
  qcComments('qc_comments',    'QC Comments'),
  approved('approved',         'Approved'),
  issued('issued',             'Issued'),
  locked('locked',             'Locked');

  const ReportStatus(this.value, this.label);
  final String value;
  final String label;

  static ReportStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => ReportStatus.draft);
}

// ── Section types ──────────────────────────────────────────────────────────

enum SectionType {
  opening,
  vesselParticulars,
  occurrence,
  attendees,
  background,
  damageDescription,
  repairs,
  causation,
  allegation,
  accounts,
  repairTimes,
  surveyorNotes,
  closing,
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
        clauseId:    j['clause_id'] as String,
        formatType:  j['format_type'] as String,
        clauseType:  j['clause_type'] as String,
        clauseLabel: j['clause_label'] as String,
        clauseText:  j['clause_text'] as String,
        isLocked:    j['is_locked'] as bool? ?? true,
      );
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
    this.approved = false,
    this.sectionId,
  });

  final SectionType type;
  final String title;
  final String content;
  final String? clauseId;
  final bool isLocked;   // clause text — cannot be edited by surveyor
  final bool aiDrafted;
  final bool approved;
  final String? sectionId;

  ReportSection copyWith({
    String? content,
    bool? approved,
    String? sectionId,
  }) =>
      ReportSection(
        type:      type,
        title:     title,
        content:   content   ?? this.content,
        clauseId:  clauseId,
        isLocked:  isLocked,
        aiDrafted: aiDrafted,
        approved:  approved  ?? this.approved,
        sectionId: sectionId ?? this.sectionId,
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

  int get approvedCount => sections.where((s) => s.approved).length;
  bool get allApproved => sections.every((s) => s.approved);
  bool get isLocked => status == ReportStatus.locked;

  factory ReportOutput.fromJson(Map<String, dynamic> j,
      List<ReportSection> sections) =>
      ReportOutput(
        outputId:    j['output_id'] as String,
        caseId:      j['case_id'] as String,
        outputType:  OutputType.fromValue(j['output_type'] as String),
        status:      ReportStatus.fromValue(j['status'] as String? ?? 'draft'),
        sections:    sections,
        reportNumber: j['report_number'] as String?,
        sequenceNo:  j['sequence_no'] as int? ?? 1,
        issuedDate:  j['issued_date'] != null
            ? DateTime.tryParse(j['issued_date'] as String)
            : null,
        issuedTo:    j['issued_to'] as String?,
        filePath:    j['file_path'] as String?,
        createdAt:   j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
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
    required this.certificates,
    required this.repairRecords,
    required this.clauses,
    required this.outputFormat,
  });

  final Map<String, dynamic> caseData;
  final Map<String, dynamic>? vessel;
  final List<Map<String, dynamic>> occurrences;
  final List<Map<String, dynamic>> damageItems;
  final List<Map<String, dynamic>> attendees;
  final List<Map<String, dynamic>> certificates;
  final List<Map<String, dynamic>> repairRecords;
  final List<ClauseModel> clauses;
  final String outputFormat;

  ClauseModel? clauseByType(String type) =>
      clauses.where((c) => c.clauseType == type).firstOrNull;
}

// ── Report provider ────────────────────────────────────────────────────────

final reportOutputsProvider = AsyncNotifierProviderFamily<
    ReportOutputsNotifier, List<ReportOutput>, String>(
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
    final data = await SupabaseService.client
        .from('report_outputs')
        .insert({
          'case_id':       caseId,
          'output_type':   type.value,
          'report_number': reportNumber,
          'sequence_no':   sequenceNo,
          'status':        'draft',
        })
        .select()
        .single();

    final output = ReportOutput.fromJson(
        data, const []);
    final current = state.value ?? [];
    state = AsyncData([output, ...current]);
    return output;
  }

  Future<void> updateStatus(String outputId, ReportStatus status) async {
    await SupabaseService.client
        .from('report_outputs')
        .update({'status': status.value})
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
        .order('created_at'),
    SupabaseService.client
        .from('certificates')
        .select()
        .eq('case_id', caseId),
    SupabaseService.client
        .from('repair_records')
        .select()
        .eq('case_id', caseId),
  ]);

  final caseData    = results[0] as Map<String, dynamic>;
  final occurrences = (results[1] as List).cast<Map<String, dynamic>>();
  final damageItems = (results[2] as List).cast<Map<String, dynamic>>();
  final attendees   = (results[3] as List).cast<Map<String, dynamic>>();
  final certificates = (results[4] as List).cast<Map<String, dynamic>>();
  final repairs     = (results[5] as List).cast<Map<String, dynamic>>();

  final outputFormat =
      caseData['output_format'] as String? ?? 'abl';

  // Fetch clauses for this format
  final clauseData = await SupabaseService.client
      .from('clause_library')
      .select()
      .eq('format_type', outputFormat)
      .eq('deprecated', false);

  final clauses = (clauseData as List)
      .map((c) => ClauseModel.fromJson(c as Map<String, dynamic>))
      .toList();

  final vessel = caseData['vessels'] as Map<String, dynamic>?;

  return AssembledReportData(
    caseData:      caseData,
    vessel:        vessel,
    occurrences:   occurrences,
    damageItems:   damageItems,
    attendees:     attendees,
    certificates:  certificates,
    repairRecords: repairs,
    clauses:       clauses,
    outputFormat:  outputFormat,
  );
});

// ── Section assembly provider ──────────────────────────────────────────────

final sectionDraftProvider =
    StateNotifierProvider.family<SectionDraftNotifier,
        Map<SectionType, ReportSection>, String>(
  (ref, caseId) => SectionDraftNotifier(caseId),
);

class SectionDraftNotifier
    extends StateNotifier<Map<SectionType, ReportSection>> {
  SectionDraftNotifier(this.caseId) : super({});

  final String caseId;

  void setSection(SectionType type, ReportSection section) {
    state = {...state, type: section};
  }

  void updateContent(SectionType type, String content) {
    final existing = state[type];
    if (existing != null) {
      state = {...state, type: existing.copyWith(content: content)};
    }
  }

  void toggleApproved(SectionType type) {
    final existing = state[type];
    if (existing != null) {
      state = {
        ...state,
        type: existing.copyWith(approved: !existing.approved)
      };
    }
  }

  /// Build all sections from assembled data + optional AI drafting
  Future<void> buildSections(
    AssembledReportData data, {
    bool aiDraft = false,
  }) async {
    final sections = <SectionType, ReportSection>{};

    // ── Opening (locked clause) ───────────────────────────────────
    final openingClause = data.clauseByType('opening_certification');
    if (openingClause != null) {
      final text = _fillOpeningClause(openingClause.clauseText, data);
      sections[SectionType.opening] = ReportSection(
        type:     SectionType.opening,
        title:    'Opening Certification',
        content:  text,
        clauseId: openingClause.clauseId,
        isLocked: true,
      );
    }

    // ── Vessel particulars (auto-populated) ───────────────────────
    sections[SectionType.vesselParticulars] = ReportSection(
      type:    SectionType.vesselParticulars,
      title:   'Vessel Particulars',
      content: _buildVesselText(data),
    );

    // ── Attendees (auto-populated) ────────────────────────────────
    if (data.attendees.isNotEmpty) {
      sections[SectionType.attendees] = ReportSection(
        type:    SectionType.attendees,
        title:   'Attending the Survey',
        content: _buildAttendeesText(data.attendees),
      );
    }

    // ── Occurrence / background (AI draft or empty) ───────────────
    for (final occ in data.occurrences) {
      String backgroundContent = occ['background_narrative'] as String? ?? '';

      if (backgroundContent.isEmpty && aiDraft) {
        try {
          backgroundContent = await ClaudeApi.draftOccurrenceNarrative(
            vesselName:     data.vessel?['name'] ?? 'the vessel',
            occurrenceDate: occ['date_time'] as String? ?? '',
            occurrenceLocation: occ['location'] as String? ?? '',
            occurrenceTitle:    occ['title']     as String? ?? '',
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

      sections[SectionType.background] = ReportSection(
        type:      SectionType.background,
        title:     'Background',
        content:   backgroundContent,
        aiDrafted: aiDraft && backgroundContent.isNotEmpty,
      );

      sections[SectionType.occurrence] = ReportSection(
        type:    SectionType.occurrence,
        title:   'Occurrence',
        content: occ['brief_description'] as String? ?? '',
      );
    }

    // ── Damage description (auto-populated) ───────────────────────
    if (data.damageItems.isNotEmpty) {
      sections[SectionType.damageDescription] = ReportSection(
        type:    SectionType.damageDescription,
        title:   'Extent of Damage',
        content: _buildDamageText(data.damageItems),
      );
    }

    // ── Repairs (auto-populated) ──────────────────────────────────
    if (data.repairRecords.isNotEmpty) {
      sections[SectionType.repairs] = ReportSection(
        type:    SectionType.repairs,
        title:   'Repairs',
        content: _buildRepairsText(data.repairRecords),
      );
    }

    // ── Causation / allegation (AI draft + locked clause) ─────────
    if (data.occurrences.isNotEmpty) {
      final occ = data.occurrences.first;
      String causeContent = occ['cause_narrative'] as String? ?? '';

      if (causeContent.isEmpty && aiDraft) {
        try {
          causeContent = await ClaudeApi.draftCauseConsideration(
            vesselName:     data.vessel?['name'] ?? 'the vessel',
            occurrenceTitle: occ['title'] as String? ?? '',
            damageItems: data.damageItems
                .map((d) => d['component_name'] as String? ?? '')
                .toList(),
            serviceEngineerFindings: null,
            reportFormat: data.outputFormat,
          );
        } catch (_) {
          causeContent = '[Cause consideration — edit before issuing]';
        }
      }

      sections[SectionType.causation] = ReportSection(
        type:      SectionType.causation,
        title:     'Cause Consideration',
        content:   causeContent,
        aiDrafted: aiDraft,
      );

      // Allegation clause (locked)
      final allegationType =
          occ['allegation_type'] as String? ?? 'no_formal_allegation';
      final clauseType = allegationType == 'formal_allegation'
          ? 'allegation_formal'
          : 'allegation_none';
      final allegationClause = data.clauseByType(clauseType);
      if (allegationClause != null) {
        sections[SectionType.allegation] = ReportSection(
          type:     SectionType.allegation,
          title:    'Allegation / Causation',
          content:  allegationClause.clauseText,
          clauseId: allegationClause.clauseId,
          isLocked: true,
        );
      }
    }

    // ── Closing / disclaimer (locked clause) ─────────────────────
    final closingClause = data.clauseByType('closing_disclaimer');
    if (closingClause != null) {
      sections[SectionType.closing] = ReportSection(
        type:     SectionType.closing,
        title:    'Without Prejudice / Closing',
        content:  closingClause.clauseText,
        clauseId: closingClause.clauseId,
        isLocked: true,
      );
    }

    state = sections;
  }

  // ── Text builders ─────────────────────────────────────────────────────────

  String _fillOpeningClause(String template, AssembledReportData data) {
    final clientName =
        data.caseData['principals_clients']?['name'] as String? ?? '[CLIENT]';
    final occDate = data.occurrences.isNotEmpty
        ? data.occurrences.first['date_time'] as String? ?? '[DATE]'
        : '[DATE]';

    return template
        .replaceAll('[CLIENT]', clientName)
        .replaceAll('[FIRST_ATTENDANCE_DATE]', _formatDate(occDate))
        .replaceAll('[LOCATION_DESCRIPTION]',
            data.caseData['notes'] as String? ?? 'the survey location');
  }

  String _buildVesselText(AssembledReportData data) {
    final v = data.vessel;
    if (v == null) return '[Vessel particulars not yet recorded]';
    final lines = <String>[];
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
    if (v['gross_tonnage'] != null) {
      lines.add('GT / DWT: ${v['gross_tonnage']} / ${v['deadweight'] ?? '—'}');
    }
    if (v['year_built'] != null) {
      lines.add('Built: ${v['year_built']} at ${v['build_yard'] ?? ''}, ${v['build_country'] ?? ''}');
    }
    if (v['owners'] != null) {
      lines.add('Owners: ${v['owners']}');
    }
    if (v['class_society'] != null) {
      lines.add('Class: ${v['class_society']} — ${v['class_notation'] ?? ''}');
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

  String _buildDamageText(List<Map<String, dynamic>> items) {
    return items.asMap().entries.map((e) {
      final i = e.key + 1;
      final d = e.value;
      final component = d['component_name'] as String? ?? '';
      final description = d['damage_description'] as String? ?? '';
      final condition = d['condition_found'] as String? ?? '';
      final buf = StringBuffer('$i. $component');
      if (description.isNotEmpty) buf.write('\n   $description');
      if (condition.isNotEmpty)   buf.write('\n   Condition: $condition');
      return buf.toString();
    }).join('\n\n');
  }

  String _buildRepairsText(List<Map<String, dynamic>> repairs) {
    return repairs.map((r) {
      final yard = r['yard_contractor'] as String? ?? '';
      final loc  = r['location']        as String? ?? '';
      final type = r['repair_type']      as String? ?? '';
      return '$type repairs — $yard${loc.isNotEmpty ? ', $loc' : ''}';
    }).join('\n');
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
