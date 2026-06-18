// lib/features/parties/models/party_model.dart

import 'package:flutter/foundation.dart';

// ── Case Parties ───────────────────────────────────────────────────────────
// Single record per case (case_id is the PK in Supabase).
// Tracks the instructing chain: principal → reviewer → underwriter → adjuster.

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
      );

  Map<String, dynamic> toUpsertJson() => {
        'case_id':             caseId,
        'principal_name':      principalName,
        'principal_company':   principalCompany,
        'principal_email':     principalEmail,
        'reviewer_name':       reviewerName,
        'reviewer_company':    reviewerCompany,
        'reviewer_email':      reviewerEmail,
        'underwriter_name':    underwriterName,
        'underwriter_company': underwriterCompany,
        'underwriter_email':   underwriterEmail,
        'adjuster_name':       adjusterName,
        'adjuster_company':    adjusterCompany,
        'adjuster_email':      adjusterEmail,
        'adjuster_phone':      adjusterPhone,
      };

  bool get isEmpty =>
      principalName == null &&
      principalCompany == null &&
      underwriterName == null &&
      underwriterCompany == null &&
      adjusterName == null;
}

// ── Assured Contact ────────────────────────────────────────────────────────
// Multiple contacts on the assured / owner side (master, owner rep, etc.)

@immutable
class AssuredContactModel {
  const AssuredContactModel({
    required this.contactId,
    required this.caseId,
    required this.fullName,
    this.roleTitle,
    this.phone,
    this.email,
    this.notes,
  });

  final String contactId;
  final String caseId;
  final String fullName;
  final String? roleTitle;
  final String? phone;
  final String? email;
  final String? notes;

  factory AssuredContactModel.fromJson(Map<String, dynamic> j) =>
      AssuredContactModel(
        contactId: j['contact_id'] as String,
        caseId:    j['case_id'] as String,
        fullName:  j['full_name'] as String,
        roleTitle: j['role_title'] as String?,
        phone:     j['phone'] as String?,
        email:     j['email'] as String?,
        notes:     j['notes'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'case_id':   caseId,
        'full_name': fullName,
        if (roleTitle != null) 'role_title': roleTitle,
        if (phone != null)     'phone':      phone,
        if (email != null)     'email':      email,
        if (notes != null)     'notes':      notes,
      };
}
