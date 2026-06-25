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

// ── Case Model ────────────────────────────────────────────────────────────

@immutable
class CaseModel {
  const CaseModel({
    required this.caseId,
    required this.jobNumber,
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
    // Joined fields
    this.vesselName,
    this.clientName,
    this.checklistProgress,
  });

  final String caseId;
  final String jobNumber;
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

  // Computed / joined
  final String? vesselName;
  final String? clientName;
  final double? checklistProgress; // 0.0 to 1.0

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    return CaseModel(
      caseId: json['case_id'] as String,
      jobNumber: json['job_number'] as String,
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
      vesselName: json['vessel_name'] as String?,
      clientName: json['client_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'job_number':          jobNumber,
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
  };

  bool get hasPlaceholderJobNumber =>
      jobNumber.startsWith('TMP-') || jobNumber == 'TBC' || jobNumber.isEmpty;

  CaseModel copyWith({
    String? jobNumber,
    CaseType? caseType,
    CaseStatus? status,
    OutputFormat? outputFormat,
    String? clientId,
    String? vesselId,
    DateTime? instructionDate,
    String? title,
    String? claimReference,
    String? notes,
    String? vesselName,
    String? clientName,
  }) {
    return CaseModel(
      caseId:          caseId,
      jobNumber:       jobNumber       ?? this.jobNumber,
      caseType:        caseType        ?? this.caseType,
      status:          status          ?? this.status,
      outputFormat:    outputFormat    ?? this.outputFormat,
      clientId:        clientId        ?? this.clientId,
      vesselId:        vesselId        ?? this.vesselId,
      instructionDate: instructionDate ?? this.instructionDate,
      title:           title           ?? this.title,
      claimReference:  claimReference  ?? this.claimReference,
      principalId:     principalId,
      assignedSurveyor: assignedSurveyor,
      inboxEmailTag:   inboxEmailTag,
      storageFolderPath: storageFolderPath,
      notes:           notes           ?? this.notes,
      createdAt:       createdAt,
      updatedAt:       updatedAt,
      vesselName:      vesselName      ?? this.vesselName,
      clientName:      clientName      ?? this.clientName,
      checklistProgress: checklistProgress,
    );
  }
}

// ── Vessel Model ──────────────────────────────────────────────────────────

@immutable
class VesselModel {
  const VesselModel({
    required this.vesselId,
    required this.name,
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
    this.createdAt,
    this.updatedAt,
  });

  final String vesselId;
  final String name;
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory VesselModel.fromJson(Map<String, dynamic> json) {
    return VesselModel(
      vesselId:            json['vessel_id'] as String,
      name:                json['name'] as String,
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
    if (mcrPowerValue != null)        'mcr_power_value':       mcrPowerValue,
    if (mcrRpm != null)               'mcr_rpm':               mcrRpm,
    if (mcrPowerUnit != null)         'mcr_power_unit':        mcrPowerUnit,
  };

  /// Apply AI-extracted fields on top of existing data
  VesselModel applyExtraction(Map<String, dynamic> extracted) {
    return VesselModel(
      vesselId:      vesselId,
      name:          extracted['vessel_name'] as String? ?? name,
      imoNumber:     extracted['imo_number']  as String? ?? imoNumber,
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
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
