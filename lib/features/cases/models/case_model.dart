// lib/features/cases/models/case_model.dart

import 'package:flutter/foundation.dart';

// ── Enums (mirror Supabase enums) ─────────────────────────────────────────

enum CaseType {
  hm('hm', 'H&M'),
  pi('pi', 'P&I'),
  cs('cs', 'C&S'),
  dpTrials('dp_trials', 'DP Trials'),
  mws('mws', 'MWS'),
  deficiency('deficiency', 'Deficiency'),
  consulting('consulting', 'Consulting');

  const CaseType(this.value, this.label);
  final String value;
  final String label;

  static CaseType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => CaseType.hm);
}

enum CaseStatus {
  open('open', 'Open'),
  prelimIssued('prelim_issued', 'Prelim Issued'),
  adviceIssued('advice_issued', 'Advice Issued'),
  finalIssued('final_issued', 'Final Issued'),
  closed('closed', 'Closed');

  const CaseStatus(this.value, this.label);
  final String value;
  final String label;

  static CaseStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => CaseStatus.open);
}

enum OutputFormat {
  abl('abl', 'ABL'),
  nordic('nordic', 'Nordic (Gard)'),
  oceano('oceano_services', 'OceanoServices');

  const OutputFormat(this.value, this.label);
  final String value;
  final String label;

  static OutputFormat fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => OutputFormat.abl);
}

enum PolicyType {
  hm('hm', 'H&M'),
  pi('pi', 'P&I'),
  both('both', 'H&M + P&I');

  const PolicyType(this.value, this.label);
  final String value;
  final String label;

  static PolicyType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => PolicyType.hm);
}

enum InstructingPartyRole {
  hmInsurer('hm_insurer', 'H&M Insurer'),
  piClub('pi_club', 'P&I Club'),
  owner('owner', 'Owner'),
  manager('manager', 'Manager'),
  broker('broker', 'Broker'),
  other('other', 'Other');

  const InstructingPartyRole(this.value, this.label);
  final String value;
  final String label;

  static InstructingPartyRole fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => InstructingPartyRole.other);
}

// ── Case Model ────────────────────────────────────────────────────────────

@immutable
class CaseModel {
  const CaseModel({
    required this.caseId,
    required this.technicalFileNo,
    required this.caseType,
    required this.status,
    this.outputFormat,
    this.clientId,
    this.vesselId,
    this.instructionDate,
    this.title,
    this.claimReference,
    this.principalId,
    this.assignedSurveyor,
    this.inboxEmailTag,
    this.storageFolderPath,
    this.notes,
    this.createdAt,
    this.updatedAt,
    // Report / org fields
    this.organisationId,
    this.baseCurrency,
    this.policyType,
    // Survey details
    this.instructingParty,
    this.instructingPartyRole,
    this.assured,
    this.dateOfFirstAttendance,
    this.surveyLocation,
    // Clause G-1 (cost estimate status)
    this.costEstimateStatus,
    this.estimatedRepairCost,
    // Cost inclusions + Survey Fee Reserve (relocated from the report
    // builder's Advice Summary card — see docs/migrations/017).
    this.costIncludesGeneralExpenses,
    this.costIncludesTowing,
    this.surveyFeeReserveHours,
    this.surveyFeeReserveExpenses,
    // Follow-up attendance (relocated from the report builder — see
    // docs/migrations/017).
    this.followUpRequired,
    this.followUpDetail,
    // Other Matters of Relevance — ticked legal-clause ids (see
    // docs/migrations/018) and free-text additional notes (see
    // docs/migrations/019).
    this.otherMattersClauseIds = const [],
    this.otherMattersNotes,
    // Sign-off
    this.signedOffAttending = false,
    this.signedOffReviewing = false,
    this.signedOffAt,
    this.reviewingPartyId,
    this.signedOffAttendingName,
    this.signedOffAttendingAt,
    this.signedOffAttendingSigPath,
    this.signedOffReviewingName,
    this.signedOffReviewingAt,
    this.signedOffReviewingSigPath,
    // Joined fields
    this.vesselName,
    this.clientName,
    this.checklistProgress,
  });

  final String caseId;
  final String technicalFileNo;
  final CaseType caseType;
  final CaseStatus status;
  final OutputFormat? outputFormat;
  final String? clientId;
  final String? vesselId;
  final DateTime? instructionDate;
  final String? title;
  final String? claimReference;
  final String? principalId;
  final String? assignedSurveyor;
  final String? inboxEmailTag;
  final String? storageFolderPath;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Report / org / policy fields
  final String? organisationId;
  final String? baseCurrency;        // ISO 4217 e.g. 'USD', 'AUD'
  final PolicyType? policyType;

  // Survey details
  final String? instructingParty;
  final InstructingPartyRole? instructingPartyRole;
  final String? assured;
  final DateTime? dateOfFirstAttendance;
  final String? surveyLocation;
  /// Clause G-1: 'no_invoices_yet' / 'ongoing_partial_invoices' / 'completed_all_invoices'.
  final String? costEstimateStatus;
  final double? estimatedRepairCost;
  final bool? costIncludesGeneralExpenses;
  final String? costIncludesTowing; // 'yes' / 'no' / 'n_a'
  final double? surveyFeeReserveHours;
  final double? surveyFeeReserveExpenses;
  /// Is a follow-up survey attendance required before the case can close?
  final bool? followUpRequired;
  final String? followUpDetail;
  /// Ticked `clause_library` ids for the "Other Matters of Relevance"
  /// section — see docs/migrations/018_other_matters_clauses.sql. The
  /// report section is omitted entirely when this is empty.
  final List<String> otherMattersClauseIds;
  /// Free-text additional notes/clarifications for "Other Matters of
  /// Relevance" — see docs/migrations/019_other_matters_notes.sql. Rendered
  /// after the ticked clause text in the same report section.
  final String? otherMattersNotes;

  // Sign-off (dual sign-off gate for Final Report export)
  final bool signedOffAttending;
  final bool signedOffReviewing;
  final DateTime? signedOffAt;
  final String? reviewingPartyId;  // FK to parties table
  final String? signedOffAttendingName;
  final DateTime? signedOffAttendingAt;
  final String? signedOffAttendingSigPath;
  final String? signedOffReviewingName;
  final DateTime? signedOffReviewingAt;
  final String? signedOffReviewingSigPath;

  bool get dualSignOffComplete => signedOffAttending && signedOffReviewing;

  // Computed / joined
  final String? vesselName;
  final String? clientName;
  final double? checklistProgress; // 0.0 to 1.0

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    return CaseModel(
      caseId: json['case_id'] as String,
      technicalFileNo: json['technical_file_no'] as String,
      caseType: CaseType.fromValue(json['case_type'] as String? ?? 'hm'),
      status: CaseStatus.fromValue(json['status'] as String? ?? 'open'),
      outputFormat: json['output_format'] != null
          ? OutputFormat.fromValue(json['output_format'] as String)
          : null,
      clientId: json['client_id'] as String?,
      vesselId: json['vessel_id'] as String?,
      instructionDate: json['instruction_date'] != null
          ? DateTime.tryParse(json['instruction_date'] as String)
          : null,
      title:          json['title'] as String?,
      claimReference: json['claim_reference'] as String?,
      principalId: json['principal_id'] as String?,
      assignedSurveyor: json['assigned_surveyor'] as String?,
      inboxEmailTag: json['inbox_email_tag'] as String?,
      storageFolderPath: json['storage_folder_path'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      organisationId: json['organisation_id'] as String?,
      baseCurrency:   json['base_currency']   as String?,
      policyType:     json['policy_type'] != null
          ? PolicyType.fromValue(json['policy_type'] as String)
          : null,
      instructingParty:     json['instructing_party']      as String?,
      instructingPartyRole: json['instructing_party_role'] != null
          ? InstructingPartyRole.fromValue(
              json['instructing_party_role'] as String)
          : null,
      assured:              json['assured']                as String?,
      dateOfFirstAttendance: json['date_of_first_attendance'] != null
          ? DateTime.tryParse(json['date_of_first_attendance'] as String)
          : null,
      surveyLocation:       json['survey_location']        as String?,
      costEstimateStatus:   json['cost_estimate_status']    as String?,
      estimatedRepairCost:  (json['estimated_repair_cost'] as num?)?.toDouble(),
      costIncludesGeneralExpenses: json['cost_includes_general_expenses'] as bool?,
      costIncludesTowing:   json['cost_includes_towing'] as String?,
      surveyFeeReserveHours: (json['survey_fee_reserve_hours'] as num?)?.toDouble(),
      surveyFeeReserveExpenses:
          (json['survey_fee_reserve_expenses'] as num?)?.toDouble(),
      followUpRequired: json['follow_up_required'] as bool?,
      followUpDetail:   json['follow_up_detail'] as String?,
      otherMattersClauseIds:
          (json['other_matters_clause_ids'] as List?)?.cast<String>() ?? const [],
      otherMattersNotes: json['other_matters_notes'] as String?,
      signedOffAttending: json['signed_off_attending'] as bool? ?? false,
      signedOffReviewing: json['signed_off_reviewing'] as bool? ?? false,
      signedOffAt: json['signed_off_at'] != null
          ? DateTime.tryParse(json['signed_off_at'] as String)
          : null,
      reviewingPartyId: json['reviewing_party_id'] as String?,
      signedOffAttendingName:   json['signed_off_attending_name']    as String?,
      signedOffAttendingAt: json['signed_off_attending_at'] != null
          ? DateTime.tryParse(json['signed_off_attending_at'] as String)
          : null,
      signedOffAttendingSigPath: json['signed_off_attending_sig_path'] as String?,
      signedOffReviewingName:   json['signed_off_reviewing_name']    as String?,
      signedOffReviewingAt: json['signed_off_reviewing_at'] != null
          ? DateTime.tryParse(json['signed_off_reviewing_at'] as String)
          : null,
      signedOffReviewingSigPath: json['signed_off_reviewing_sig_path'] as String?,
      vesselName: json['vessel_name'] as String?,
      clientName: json['client_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'technical_file_no':          technicalFileNo,
    'case_type':           caseType.value,
    'status':              status.value,
    if (outputFormat != null) 'output_format': outputFormat!.value,
    if (clientId != null)     'client_id':     clientId,
    if (vesselId != null)     'vessel_id':     vesselId,
    if (instructionDate != null)
      'instruction_date': instructionDate!.toIso8601String().split('T').first,
    if (title != null)             'title':               title,
    if (claimReference != null)    'claim_reference':     claimReference,
    if (principalId != null)       'principal_id':        principalId,
    if (assignedSurveyor != null)  'assigned_surveyor':   assignedSurveyor,
    if (inboxEmailTag != null)     'inbox_email_tag':     inboxEmailTag,
    if (storageFolderPath != null) 'storage_folder_path': storageFolderPath,
    if (notes != null)             'notes':               notes,
    if (organisationId != null)       'organisation_id':          organisationId,
    if (baseCurrency != null)         'base_currency':            baseCurrency,
    if (policyType != null)           'policy_type':              policyType!.value,
    if (instructingParty != null)     'instructing_party':        instructingParty,
    if (instructingPartyRole != null) 'instructing_party_role':   instructingPartyRole!.value,
    if (assured != null)              'assured':                  assured,
    if (dateOfFirstAttendance != null)
      'date_of_first_attendance': dateOfFirstAttendance!.toIso8601String().split('T').first,
    if (surveyLocation != null)       'survey_location':          surveyLocation,
    if (costEstimateStatus != null)   'cost_estimate_status':     costEstimateStatus,
    if (estimatedRepairCost != null)  'estimated_repair_cost':    estimatedRepairCost,
    if (costIncludesGeneralExpenses != null)
      'cost_includes_general_expenses': costIncludesGeneralExpenses,
    if (costIncludesTowing != null)   'cost_includes_towing':     costIncludesTowing,
    if (surveyFeeReserveHours != null)
      'survey_fee_reserve_hours': surveyFeeReserveHours,
    if (surveyFeeReserveExpenses != null)
      'survey_fee_reserve_expenses': surveyFeeReserveExpenses,
    if (followUpRequired != null)     'follow_up_required':       followUpRequired,
    if (followUpDetail != null)       'follow_up_detail':         followUpDetail,
    'signed_off_attending': signedOffAttending,
    'signed_off_reviewing': signedOffReviewing,
    if (signedOffAt != null)                'signed_off_at':                    signedOffAt!.toIso8601String(),
    if (reviewingPartyId != null)           'reviewing_party_id':               reviewingPartyId,
    if (signedOffAttendingName != null)     'signed_off_attending_name':        signedOffAttendingName,
    if (signedOffAttendingAt != null)       'signed_off_attending_at':          signedOffAttendingAt!.toIso8601String(),
    if (signedOffAttendingSigPath != null)  'signed_off_attending_sig_path':    signedOffAttendingSigPath,
    if (signedOffReviewingName != null)     'signed_off_reviewing_name':        signedOffReviewingName,
    if (signedOffReviewingAt != null)       'signed_off_reviewing_at':          signedOffReviewingAt!.toIso8601String(),
    if (signedOffReviewingSigPath != null)  'signed_off_reviewing_sig_path':    signedOffReviewingSigPath,
  };

  bool get hasPlaceholderFileNo =>
      technicalFileNo.startsWith('TMP-') || technicalFileNo == 'TBC' || technicalFileNo.isEmpty;

  CaseModel copyWith({
    String? technicalFileNo,
    CaseType? caseType,
    CaseStatus? status,
    OutputFormat? outputFormat,
    String? clientId,
    String? vesselId,
    DateTime? instructionDate,
    String? title,
    String? claimReference,
    String? notes,
    String? organisationId,
    String? baseCurrency,
    PolicyType? policyType,
    String? instructingParty,
    InstructingPartyRole? instructingPartyRole,
    String? assured,
    DateTime? dateOfFirstAttendance,
    String? surveyLocation,
    String? costEstimateStatus,
    double? estimatedRepairCost,
    bool? costIncludesGeneralExpenses,
    String? costIncludesTowing,
    double? surveyFeeReserveHours,
    double? surveyFeeReserveExpenses,
    bool? followUpRequired,
    String? followUpDetail,
    List<String>? otherMattersClauseIds,
    String? otherMattersNotes,
    String? vesselName,
    String? clientName,
  }) {
    return CaseModel(
      caseId:                caseId,
      technicalFileNo:             technicalFileNo             ?? this.technicalFileNo,
      caseType:              caseType              ?? this.caseType,
      status:                status                ?? this.status,
      outputFormat:          outputFormat          ?? this.outputFormat,
      clientId:              clientId              ?? this.clientId,
      vesselId:              vesselId              ?? this.vesselId,
      instructionDate:       instructionDate       ?? this.instructionDate,
      title:                 title                 ?? this.title,
      claimReference:        claimReference        ?? this.claimReference,
      principalId:           principalId,
      assignedSurveyor:      assignedSurveyor,
      inboxEmailTag:         inboxEmailTag,
      storageFolderPath:     storageFolderPath,
      notes:                 notes                 ?? this.notes,
      createdAt:             createdAt,
      updatedAt:             updatedAt,
      organisationId:        organisationId        ?? this.organisationId,
      baseCurrency:          baseCurrency          ?? this.baseCurrency,
      policyType:            policyType            ?? this.policyType,
      instructingParty:      instructingParty      ?? this.instructingParty,
      instructingPartyRole:  instructingPartyRole  ?? this.instructingPartyRole,
      assured:               assured               ?? this.assured,
      dateOfFirstAttendance: dateOfFirstAttendance ?? this.dateOfFirstAttendance,
      surveyLocation:        surveyLocation        ?? this.surveyLocation,
      costEstimateStatus:    costEstimateStatus    ?? this.costEstimateStatus,
      estimatedRepairCost:   estimatedRepairCost   ?? this.estimatedRepairCost,
      costIncludesGeneralExpenses:
          costIncludesGeneralExpenses ?? this.costIncludesGeneralExpenses,
      costIncludesTowing:    costIncludesTowing    ?? this.costIncludesTowing,
      surveyFeeReserveHours: surveyFeeReserveHours ?? this.surveyFeeReserveHours,
      surveyFeeReserveExpenses:
          surveyFeeReserveExpenses ?? this.surveyFeeReserveExpenses,
      followUpRequired:      followUpRequired      ?? this.followUpRequired,
      followUpDetail:        followUpDetail        ?? this.followUpDetail,
      otherMattersClauseIds: otherMattersClauseIds ?? this.otherMattersClauseIds,
      otherMattersNotes:     otherMattersNotes     ?? this.otherMattersNotes,
      vesselName:            vesselName            ?? this.vesselName,
      clientName:            clientName            ?? this.clientName,
      checklistProgress:     checklistProgress,
    );
  }
}

// ── Vessel statutory enums ────────────────────────────────────────────────

enum ClassStatus {
  classed('classed', 'Classed'),
  conditional('conditional', 'Conditional'),
  suspended('suspended', 'Suspended'),
  notClassed('not_classed', 'Not Classed');

  const ClassStatus(this.value, this.label);
  final String value;
  final String label;

  static ClassStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => ClassStatus.classed);
}

enum PscResult {
  clear('clear', 'Clear'),
  deficiencies('deficiencies', 'Deficiencies'),
  detained('detained', 'Detained');

  const PscResult(this.value, this.label);
  final String value;
  final String label;

  static PscResult fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => PscResult.clear);
}

enum IspsStatus {
  compliant('compliant', 'Compliant'),
  nonCompliant('non_compliant', 'Non-compliant'),
  tbc('tbc', 'TBC');

  const IspsStatus(this.value, this.label);
  final String value;
  final String label;

  static IspsStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => IspsStatus.tbc);
}

/// Which regulatory framework the vessel is surveyed to — drives which
/// particulars fields apply (see docs/report_builder_editor_notes.md §3).
enum RegulatoryStandard {
  convention('convention', 'Convention Vessel'),
  dcv('dcv', 'DCV — National Law');

  const RegulatoryStandard(this.value, this.label);
  final String value;
  final String label;

  static RegulatoryStandard fromValue(String v) => values
      .firstWhere((e) => e.value == v, orElse: () => RegulatoryStandard.convention);
}

/// AMSA Vessel Use Class (DCV vessels only) — combines with
/// [AmsaServiceCategory] into the displayed notation e.g. "Class 3B".
enum AmsaVesselUseClass {
  class1('1', 'Class 1 — Passenger'),
  class2('2', 'Class 2 — Non-passenger'),
  class3('3', 'Class 3 — Fishing'),
  class4('4', 'Class 4 — Hire and drive');

  const AmsaVesselUseClass(this.value, this.label);
  final String value;
  final String label;

  static AmsaVesselUseClass fromValue(String v) => values
      .firstWhere((e) => e.value == v, orElse: () => AmsaVesselUseClass.class1);
}

/// AMSA Service Category suffix (DCV vessels only) — the operational-area
/// letter appended to [AmsaVesselUseClass], e.g. "3B".
enum AmsaServiceCategory {
  a('a', 'A — Unlimited domestic'),
  b('b', 'B — Offshore (to 200nm)'),
  c('c', 'C — Restricted offshore (to 30nm)'),
  d('d', 'D — Partially smooth water'),
  e('e', 'E — Smooth / sheltered water');

  const AmsaServiceCategory(this.value, this.label);
  final String value;
  final String label;

  static AmsaServiceCategory fromValue(String v) => values
      .firstWhere((e) => e.value == v, orElse: () => AmsaServiceCategory.a);
}

enum HullMaterial {
  steel('steel', 'Steel'),
  aluminium('aluminium', 'Aluminium'),
  grp('grp', 'GRP'),
  frp('frp', 'FRP'),
  timber('timber', 'Timber');

  const HullMaterial(this.value, this.label);
  final String value;
  final String label;

  static HullMaterial fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => HullMaterial.steel);
}

// ── Vessel Model ──────────────────────────────────────────────────────────

@immutable
class VesselModel {
  const VesselModel({
    required this.vesselId,
    required this.name,
    this.previousName,
    this.imoNumber,
    this.callSign,
    this.mmsi,
    this.vesselType,
    this.flag,
    this.portOfRegistry,
    this.grossTonnage,
    this.netTonnage,
    this.deadweight,
    this.holdsCount,
    this.tanksCount,
    this.lengthOa,
    this.lengthBp,
    this.breadth,
    this.breadthQualifier,
    this.depth,
    this.maxDraft,
    this.draftQualifier,
    this.yearBuilt,
    this.buildYard,
    this.buildCountry,
    this.owners,
    this.operators,
    this.classSociety,
    this.classNotation,
    this.serviceSpeed,
    this.propulsionType,
    this.propellerType,
    this.propulsionDriveType,
    this.mcrPowerValue,
    this.mcrRpm,
    this.mcrPowerUnit,
    // Statutory fields
    this.officialNumber,
    this.classStatus,
    this.constructionStandard,
    this.registeredOwner,
    this.lastDrydockDate,
    this.lastDrydockYard,
    this.ismIncidentReported,
    this.classIncidentReported,
    this.pscLastInspection,
    this.pscLastResult,
    this.pscSummary,
    this.piClub,
    this.ispsStatus,
    this.regulatoryStandard,
    this.amsaVesselUseClass,
    this.amsaServiceCategory,
    this.hullMaterial,
    this.uniqueVesselIdentifier,
    this.surveyCertificateNo,
    this.equipmentSurveyDue,
    this.hullSurveyDue,
    this.tailShaftSurveyDue,
    this.createdAt,
    this.updatedAt,
  });

  final String vesselId;
  final String name;
  final String? previousName;
  final String? imoNumber;
  final String? callSign;
  final String? mmsi;
  final String? vesselType;
  final String? flag;
  final String? portOfRegistry;
  final double? grossTonnage;
  final double? netTonnage;
  final double? deadweight;
  final int? holdsCount;
  final int? tanksCount;
  final double? lengthOa;
  final double? lengthBp;
  final double? breadth;
  final String? breadthQualifier;
  final double? depth;
  final double? maxDraft;
  final String? draftQualifier;
  final int? yearBuilt;
  final String? buildYard;
  final String? buildCountry;
  final String? owners;
  final String? operators;
  final String? classSociety;
  final String? classNotation;
  final double? serviceSpeed;
  final String? propulsionType;
  final String? propellerType;
  final String? propulsionDriveType;
  final double? mcrPowerValue;
  final int? mcrRpm;
  final String? mcrPowerUnit;
  // Statutory
  final String? officialNumber;
  final ClassStatus? classStatus;
  final String? constructionStandard;
  final String? pscSummary;
  final String? registeredOwner;
  final DateTime? lastDrydockDate;
  final String? lastDrydockYard;
  final bool? ismIncidentReported;
  final bool? classIncidentReported;
  final DateTime? pscLastInspection;
  final PscResult? pscLastResult;
  final String? piClub;
  final IspsStatus? ispsStatus;
  final RegulatoryStandard? regulatoryStandard;
  final AmsaVesselUseClass? amsaVesselUseClass;
  final AmsaServiceCategory? amsaServiceCategory;
  final HullMaterial? hullMaterial;
  final String? uniqueVesselIdentifier;
  final String? surveyCertificateNo;
  final DateTime? equipmentSurveyDue;
  final DateTime? hullSurveyDue;
  final DateTime? tailShaftSurveyDue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Combined AMSA class notation e.g. "Class 3B" — null until both parts
  /// are set.
  String? get amsaClassDisplay =>
      (amsaVesselUseClass != null && amsaServiceCategory != null)
          ? 'Class ${amsaVesselUseClass!.value}${amsaServiceCategory!.value.toUpperCase()}'
          : null;

  factory VesselModel.fromJson(Map<String, dynamic> json) {
    return VesselModel(
      vesselId:            json['vessel_id'] as String,
      name:                json['name'] as String,
      previousName:        json['previous_name'] as String?,
      imoNumber:           json['imo_number'] as String?,
      callSign:            json['call_sign'] as String?,
      mmsi:                json['mmsi'] as String?,
      vesselType:          json['vessel_type'] as String?,
      flag:                json['flag'] as String?,
      portOfRegistry:      json['port_of_registry'] as String?,
      grossTonnage:        (json['gross_tonnage'] as num?)?.toDouble(),
      netTonnage:          (json['net_tonnage'] as num?)?.toDouble(),
      deadweight:          (json['deadweight'] as num?)?.toDouble(),
      holdsCount:          json['holds_count'] as int?,
      tanksCount:          json['tanks_count'] as int?,
      lengthOa:            (json['length_oa'] as num?)?.toDouble(),
      lengthBp:            (json['length_bp'] as num?)?.toDouble(),
      breadth:             (json['breadth'] as num?)?.toDouble(),
      breadthQualifier:    json['breadth_qualifier'] as String?,
      depth:               (json['depth'] as num?)?.toDouble(),
      maxDraft:            (json['max_draft'] as num?)?.toDouble(),
      draftQualifier:      json['draft_qualifier'] as String?,
      yearBuilt:           json['year_built'] as int?,
      buildYard:           json['build_yard'] as String?,
      buildCountry:        json['build_country'] as String?,
      owners:              json['owners'] as String?,
      operators:           json['operators'] as String?,
      classSociety:        json['class_society'] as String?,
      classNotation:       json['class_notation'] as String?,
      serviceSpeed:        (json['service_speed'] as num?)?.toDouble(),
      propulsionType:      json['propulsion_type'] as String?,
      propellerType:       json['propeller_type'] as String?,
      propulsionDriveType: json['propulsion_drive_type'] as String?,
      mcrPowerValue:       (json['mcr_power_value'] as num?)?.toDouble(),
      mcrRpm:              json['mcr_rpm'] as int?,
      mcrPowerUnit:        json['mcr_power_unit'] as String?,
      officialNumber:      json['official_number'] as String?,
      classStatus:         json['class_status'] != null
          ? ClassStatus.fromValue(json['class_status'] as String)
          : null,
      constructionStandard: json['construction_standard'] as String?,
      registeredOwner:     json['registered_owner'] as String?,
      lastDrydockDate:     json['last_drydock_date'] != null
          ? DateTime.tryParse(json['last_drydock_date'] as String)
          : null,
      lastDrydockYard:     json['last_drydock_yard'] as String?,
      ismIncidentReported: json['ism_incident_reported'] as bool?,
      classIncidentReported: json['class_incident_reported'] as bool?,
      pscLastInspection:   json['psc_last_inspection'] != null
          ? DateTime.tryParse(json['psc_last_inspection'] as String)
          : null,
      pscLastResult:       json['psc_last_result'] != null
          ? PscResult.fromValue(json['psc_last_result'] as String)
          : null,
      pscSummary:          json['psc_summary'] as String?,
      piClub:              json['pi_club'] as String?,
      ispsStatus:          json['isps_status'] != null
          ? IspsStatus.fromValue(json['isps_status'] as String)
          : null,
      regulatoryStandard:  json['regulatory_standard'] != null
          ? RegulatoryStandard.fromValue(json['regulatory_standard'] as String)
          : null,
      amsaVesselUseClass:  json['amsa_vessel_use_class'] != null
          ? AmsaVesselUseClass.fromValue(json['amsa_vessel_use_class'] as String)
          : null,
      amsaServiceCategory: json['amsa_service_category'] != null
          ? AmsaServiceCategory.fromValue(json['amsa_service_category'] as String)
          : null,
      hullMaterial:        json['hull_material'] != null
          ? HullMaterial.fromValue(json['hull_material'] as String)
          : null,
      uniqueVesselIdentifier: json['unique_vessel_identifier'] as String?,
      surveyCertificateNo:    json['survey_certificate_no'] as String?,
      equipmentSurveyDue:  json['equipment_survey_due'] != null
          ? DateTime.tryParse(json['equipment_survey_due'] as String)
          : null,
      hullSurveyDue:       json['hull_survey_due'] != null
          ? DateTime.tryParse(json['hull_survey_due'] as String)
          : null,
      tailShaftSurveyDue:  json['tail_shaft_survey_due'] != null
          ? DateTime.tryParse(json['tail_shaft_survey_due'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (previousName != null)         'previous_name':         previousName,
    if (imoNumber != null)            'imo_number':            imoNumber,
    if (callSign != null)             'call_sign':             callSign,
    if (mmsi != null)                 'mmsi':                  mmsi,
    if (vesselType != null)           'vessel_type':           vesselType,
    if (flag != null)                 'flag':                  flag,
    if (portOfRegistry != null)       'port_of_registry':      portOfRegistry,
    if (grossTonnage != null)         'gross_tonnage':         grossTonnage,
    if (netTonnage != null)           'net_tonnage':           netTonnage,
    if (deadweight != null)           'deadweight':            deadweight,
    if (holdsCount != null)           'holds_count':           holdsCount,
    if (tanksCount != null)           'tanks_count':           tanksCount,
    if (lengthOa != null)             'length_oa':             lengthOa,
    if (lengthBp != null)             'length_bp':             lengthBp,
    if (breadth != null)              'breadth':               breadth,
    if (breadthQualifier != null)     'breadth_qualifier':     breadthQualifier,
    if (depth != null)                'depth':                 depth,
    if (maxDraft != null)             'max_draft':             maxDraft,
    if (draftQualifier != null)       'draft_qualifier':       draftQualifier,
    if (yearBuilt != null)            'year_built':            yearBuilt,
    if (buildYard != null)            'build_yard':            buildYard,
    if (buildCountry != null)         'build_country':         buildCountry,
    if (owners != null)               'owners':                owners,
    if (operators != null)            'operators':             operators,
    if (classSociety != null)         'class_society':         classSociety,
    if (classNotation != null)        'class_notation':        classNotation,
    if (serviceSpeed != null)         'service_speed':         serviceSpeed,
    if (propulsionType != null)       'propulsion_type':       propulsionType,
    if (propellerType != null)        'propeller_type':        propellerType,
    if (propulsionDriveType != null)  'propulsion_drive_type': propulsionDriveType,
    if (mcrPowerValue != null)        'mcr_power_value':        mcrPowerValue,
    if (mcrRpm != null)               'mcr_rpm':                mcrRpm,
    if (mcrPowerUnit != null)         'mcr_power_unit':         mcrPowerUnit,
    if (officialNumber != null)       'official_number':        officialNumber,
    if (classStatus != null)          'class_status':           classStatus!.value,
    if (constructionStandard != null) 'construction_standard':  constructionStandard,
    if (registeredOwner != null)      'registered_owner':       registeredOwner,
    if (lastDrydockDate != null)
      'last_drydock_date': lastDrydockDate!.toIso8601String().split('T').first,
    if (lastDrydockYard != null)      'last_drydock_yard':      lastDrydockYard,
    if (ismIncidentReported != null)  'ism_incident_reported':  ismIncidentReported,
    if (classIncidentReported != null)'class_incident_reported':classIncidentReported,
    if (pscLastInspection != null)
      'psc_last_inspection': pscLastInspection!.toIso8601String().split('T').first,
    if (pscLastResult != null)        'psc_last_result':        pscLastResult!.value,
    if (pscSummary != null)           'psc_summary':            pscSummary,
    if (piClub != null)               'pi_club':                piClub,
    if (ispsStatus != null)           'isps_status':            ispsStatus!.value,
    if (regulatoryStandard != null)   'regulatory_standard':    regulatoryStandard!.value,
    if (amsaVesselUseClass != null)   'amsa_vessel_use_class':  amsaVesselUseClass!.value,
    if (amsaServiceCategory != null)  'amsa_service_category':  amsaServiceCategory!.value,
    if (hullMaterial != null)         'hull_material':          hullMaterial!.value,
    if (uniqueVesselIdentifier != null) 'unique_vessel_identifier': uniqueVesselIdentifier,
    if (surveyCertificateNo != null)  'survey_certificate_no':  surveyCertificateNo,
    if (equipmentSurveyDue != null)
      'equipment_survey_due': equipmentSurveyDue!.toIso8601String().split('T').first,
    if (hullSurveyDue != null)
      'hull_survey_due': hullSurveyDue!.toIso8601String().split('T').first,
    if (tailShaftSurveyDue != null)
      'tail_shaft_survey_due': tailShaftSurveyDue!.toIso8601String().split('T').first,
  };

  /// Apply AI-extracted fields on top of existing data
  VesselModel applyExtraction(Map<String, dynamic> extracted) {
    return VesselModel(
      vesselId:      vesselId,
      name:          extracted['vessel_name']    as String? ?? name,
      previousName:  extracted['previous_name']  as String? ?? previousName,
      imoNumber:     extracted['imo_number']     as String? ?? imoNumber,
      callSign:      extracted['call_sign']   as String? ?? callSign,
      mmsi:          extracted['mmsi']        as String? ?? mmsi,
      vesselType:    extracted['vessel_type'] as String? ?? vesselType,
      flag:          extracted['flag']        as String? ?? flag,
      portOfRegistry: extracted['port_of_registry'] as String? ?? portOfRegistry,
      grossTonnage:  (extracted['gross_tonnage'] as num?)?.toDouble() ?? grossTonnage,
      netTonnage:    (extracted['net_tonnage']   as num?)?.toDouble() ?? netTonnage,
      deadweight:    (extracted['deadweight']    as num?)?.toDouble() ?? deadweight,
      holdsCount:    extracted['holds_count'] as int? ?? holdsCount,
      tanksCount:    extracted['tanks_count'] as int? ?? tanksCount,
      lengthOa:      (extracted['length_oa']     as num?)?.toDouble() ?? lengthOa,
      lengthBp:      (extracted['length_bp']     as num?)?.toDouble() ?? lengthBp,
      breadth:       (extracted['breadth']       as num?)?.toDouble() ?? breadth,
      breadthQualifier: extracted['breadth_qualifier'] as String? ?? breadthQualifier,
      depth:         (extracted['depth']         as num?)?.toDouble() ?? depth,
      maxDraft:      (extracted['max_draft']     as num?)?.toDouble() ?? maxDraft,
      draftQualifier: extracted['draft_qualifier'] as String? ?? draftQualifier,
      yearBuilt:     extracted['year_built']   as int? ?? yearBuilt,
      buildYard:     extracted['build_yard']   as String? ?? buildYard,
      buildCountry:  extracted['build_country'] as String? ?? buildCountry,
      owners:        extracted['owners']       as String? ?? owners,
      operators:     extracted['operators']    as String? ?? operators,
      classSociety:  extracted['class_society'] as String? ?? classSociety,
      classNotation: extracted['class_notation'] as String? ?? classNotation,
      serviceSpeed:  (extracted['service_speed'] as num?)?.toDouble() ?? serviceSpeed,
      propulsionType:      extracted['propulsion_type'] as String? ?? propulsionType,
      propellerType:       extracted['propeller_type'] as String? ?? propellerType,
      propulsionDriveType: extracted['propulsion_drive_type'] as String? ?? propulsionDriveType,
      mcrPowerValue: (extracted['mcr_power_value'] as num?)?.toDouble() ?? mcrPowerValue,
      mcrRpm:        extracted['mcr_rpm'] as int? ?? mcrRpm,
      mcrPowerUnit:  extracted['mcr_power_unit'] as String? ?? mcrPowerUnit,
      // Statutory — not overwritten by AI extraction; preserved as-is
      officialNumber:        officialNumber,
      classStatus:           classStatus,
      constructionStandard:  constructionStandard,
      registeredOwner:       registeredOwner,
      lastDrydockDate:       lastDrydockDate,
      lastDrydockYard:       lastDrydockYard,
      ismIncidentReported:   ismIncidentReported,
      classIncidentReported: classIncidentReported,
      pscLastInspection:     pscLastInspection,
      pscLastResult:         pscLastResult,
      pscSummary:            pscSummary,
      piClub:                piClub,
      ispsStatus:            ispsStatus,
      regulatoryStandard:      regulatoryStandard,
      amsaVesselUseClass:      amsaVesselUseClass,
      amsaServiceCategory:     amsaServiceCategory,
      hullMaterial:            hullMaterial,
      uniqueVesselIdentifier:  uniqueVesselIdentifier,
      surveyCertificateNo:     surveyCertificateNo,
      equipmentSurveyDue:      equipmentSurveyDue,
      hullSurveyDue:           hullSurveyDue,
      tailShaftSurveyDue:      tailShaftSurveyDue,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
