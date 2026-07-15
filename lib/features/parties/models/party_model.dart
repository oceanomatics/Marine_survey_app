// lib/features/parties/models/party_model.dart

import 'package:flutter/foundation.dart';

// ── Stakeholder group ─────────────────────────────────────────────────────
// Used to categorise extracted parties in the Stakeholders section.

enum StakeholderGroup {
  insured,
  underwriter,
  broker,
  surveyor,
  technicalContractor,
  other;

  static StakeholderGroup fromValue(String? v) => switch (v) {
        'insured'              => insured,
        'underwriter'          => underwriter,
        'broker'               => broker,
        'surveyor'             => surveyor,
        'technical_contractor' => technicalContractor,
        _                      => other,
      };

  /// Infer group from a free-text role string returned by the AI.
  static StakeholderGroup fromRole(String? role) {
    if (role == null) return other;
    final r = role.toLowerCase();
    if (r.contains('owner')   || r.contains('operator') || r.contains('master') ||
        r.contains('insured') || r.contains('assured')  || r.contains('charterer') ||
        r.contains('manager') || r.contains('crew')) {
      return insured;
    }
    if (r.contains('underwriter') || r.contains('insurer') ||
        r.contains('p&i')         || r.contains('hull')    || r.contains('club')) {
      return underwriter;
    }
    if (r.contains('broker')) { return broker; }
    if (r.contains('surveyor')) { return surveyor; }
    if (r.contains('adjuster')    || r.contains('contractor') ||
        r.contains('expert')      || r.contains('specialist') ||
        r.contains('technical')   || r.contains('engineer')   ||
        r.contains('consultant')  || r.contains('inspector')) {
      return technicalContractor;
    }
    return other;
  }

  String get value => switch (this) {
        technicalContractor => 'technical_contractor',
        _                   => name,
      };

  String get label => switch (this) {
        insured              => 'Insured',
        underwriter          => 'Underwriter',
        broker               => 'Broker',
        surveyor             => 'Surveyors',
        technicalContractor  => 'Technical Contractors',
        other                => 'Other Parties',
      };
}

// ── Case Parties ───────────────────────────────────────────────────────────
// Single record per case (case_id is the PK in Supabase).
// Tracks the key roles: principal → reviewer → underwriter → adjuster → assured rep.
//
// Supabase schema additions required (run once):
//   ALTER TABLE case_parties ADD COLUMN IF NOT EXISTS assured_rep_name TEXT;
//   ALTER TABLE case_parties ADD COLUMN IF NOT EXISTS assured_rep_company TEXT;
//   ALTER TABLE case_parties ADD COLUMN IF NOT EXISTS assured_rep_email TEXT;
//   ALTER TABLE case_parties ADD COLUMN IF NOT EXISTS assured_rep_phone TEXT;

@immutable
class CasePartiesModel {
  const CasePartiesModel({
    required this.caseId,
    this.principalName,
    this.principalCompany,
    this.principalEmail,
    this.reviewerName,
    this.reviewerCompany,
    this.reviewerEmail,
    this.underwriterName,
    this.underwriterCompany,
    this.underwriterEmail,
    this.adjusterName,
    this.adjusterCompany,
    this.adjusterEmail,
    this.adjusterPhone,
    this.assuredRepName,
    this.assuredRepCompany,
    this.assuredRepEmail,
    this.assuredRepPhone,
  });

  final String caseId;

  // Instructing principal (the firm giving us the mandate)
  final String? principalName;
  final String? principalCompany;
  final String? principalEmail;

  // Internal reviewer / QC contact
  final String? reviewerName;
  final String? reviewerCompany;
  final String? reviewerEmail;

  // Underwriter / insurer (e.g. QBE, Gard, Norse)
  final String? underwriterName;
  final String? underwriterCompany;
  final String? underwriterEmail;

  // Loss adjuster (if any)
  final String? adjusterName;
  final String? adjusterCompany;
  final String? adjusterEmail;
  final String? adjusterPhone;

  // Assured / owner's representative
  final String? assuredRepName;
  final String? assuredRepCompany;
  final String? assuredRepEmail;
  final String? assuredRepPhone;

  factory CasePartiesModel.fromJson(Map<String, dynamic> j) => CasePartiesModel(
        caseId:             j['case_id'] as String,
        principalName:      j['principal_name'] as String?,
        principalCompany:   j['principal_company'] as String?,
        principalEmail:     j['principal_email'] as String?,
        reviewerName:       j['reviewer_name'] as String?,
        reviewerCompany:    j['reviewer_company'] as String?,
        reviewerEmail:      j['reviewer_email'] as String?,
        underwriterName:    j['underwriter_name'] as String?,
        underwriterCompany: j['underwriter_company'] as String?,
        underwriterEmail:   j['underwriter_email'] as String?,
        adjusterName:       j['adjuster_name'] as String?,
        adjusterCompany:    j['adjuster_company'] as String?,
        adjusterEmail:      j['adjuster_email'] as String?,
        adjusterPhone:      j['adjuster_phone'] as String?,
        assuredRepName:     j['assured_rep_name'] as String?,
        assuredRepCompany:  j['assured_rep_company'] as String?,
        assuredRepEmail:    j['assured_rep_email'] as String?,
        assuredRepPhone:    j['assured_rep_phone'] as String?,
      );

  Map<String, dynamic> toUpsertJson() => {
        'case_id':              caseId,
        'principal_name':       principalName,
        'principal_company':    principalCompany,
        'principal_email':      principalEmail,
        'reviewer_name':        reviewerName,
        'reviewer_company':     reviewerCompany,
        'reviewer_email':       reviewerEmail,
        'underwriter_name':     underwriterName,
        'underwriter_company':  underwriterCompany,
        'underwriter_email':    underwriterEmail,
        'adjuster_name':        adjusterName,
        'adjuster_company':     adjusterCompany,
        'adjuster_email':       adjusterEmail,
        'adjuster_phone':       adjusterPhone,
        'assured_rep_name':     assuredRepName,
        'assured_rep_company':  assuredRepCompany,
        'assured_rep_email':    assuredRepEmail,
        'assured_rep_phone':    assuredRepPhone,
      };

  bool get isEmpty =>
      principalName == null &&
      principalCompany == null &&
      underwriterName == null &&
      underwriterCompany == null &&
      adjusterName == null &&
      assuredRepName == null;

  /// Used for the AI-extraction "P&I insurer detected but not auto-
  /// populated" fix (14 July 2026 walkthrough) — only the one field is
  /// needed there, so that's all this supports for now.
  CasePartiesModel copyWith({String? underwriterName}) => CasePartiesModel(
        caseId: caseId,
        principalName: principalName,
        principalCompany: principalCompany,
        principalEmail: principalEmail,
        reviewerName: reviewerName,
        reviewerCompany: reviewerCompany,
        reviewerEmail: reviewerEmail,
        underwriterName: underwriterName ?? this.underwriterName,
        underwriterCompany: underwriterCompany,
        underwriterEmail: underwriterEmail,
        adjusterName: adjusterName,
        adjusterCompany: adjusterCompany,
        adjusterEmail: adjusterEmail,
        adjusterPhone: adjusterPhone,
        assuredRepName: assuredRepName,
        assuredRepCompany: assuredRepCompany,
        assuredRepEmail: assuredRepEmail,
        assuredRepPhone: assuredRepPhone,
      );
}

// ── Assured Contact / Stakeholder ─────────────────────────────────────────
// Multiple stakeholders per case — owners, underwriters, brokers, surveyors,
// technical contractors, etc.
//
// Supabase schema additions required (run once):
//   ALTER TABLE assured_contacts ADD COLUMN IF NOT EXISTS company TEXT;
//   ALTER TABLE assured_contacts ADD COLUMN IF NOT EXISTS stakeholder_group TEXT;

@immutable
class AssuredContactModel {
  const AssuredContactModel({
    required this.contactId,
    required this.caseId,
    required this.fullName,
    this.company,
    this.roleTitle,
    this.stakeholderGroup,
    this.phone,
    this.email,
    this.notes,
  });

  final String contactId;
  final String caseId;
  final String fullName;
  final String? company;
  final String? roleTitle;
  final StakeholderGroup? stakeholderGroup;
  final String? phone;
  final String? email;
  final String? notes;

  factory AssuredContactModel.fromJson(Map<String, dynamic> j) =>
      AssuredContactModel(
        contactId:        j['contact_id'] as String,
        caseId:           j['case_id'] as String,
        fullName:         j['full_name'] as String,
        company:          j['company'] as String?,
        roleTitle:        j['role_title'] as String?,
        stakeholderGroup: StakeholderGroup.fromValue(
            j['stakeholder_group'] as String?),
        phone:  j['phone'] as String?,
        email:  j['email'] as String?,
        notes:  j['notes'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'case_id':   caseId,
        'full_name': fullName,
        if (company != null)          'company':          company,
        if (roleTitle != null)        'role_title':       roleTitle,
        if (stakeholderGroup != null)
          'stakeholder_group': stakeholderGroup!.value,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (notes != null) 'notes': notes,
      };
}
