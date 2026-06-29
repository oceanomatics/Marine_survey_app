// lib/features/settings/models/organisation_model.dart

import 'package:flutter/foundation.dart';

@immutable
class OrganisationModel {
  const OrganisationModel({
    required this.organisationId,
    required this.name,
    this.abn,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.primaryColour,
    this.secondaryColour,
    this.logoStoragePath,
    this.wpHeaderText,
    this.wpCoverText,
    this.wpCostSectionText,
    this.wpFooterText,
    this.disclaimerText,
    this.waiverText,
    this.createdAt,
    this.updatedAt,
    this.surveyorProfiles = const [],
  });

  final String organisationId;
  final String name;
  final String? abn;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;

  // Branding
  final String? primaryColour;    // hex e.g. '#1A3A5C'
  final String? secondaryColour;
  final String? logoStoragePath;  // path in Supabase Storage 'org-assets' bucket

  // WITHOUT PREJUDICE / legal text blocks
  final String? wpHeaderText;       // running page header notice
  final String? wpCoverText;        // cover page notice
  final String? wpCostSectionText;  // above cost table
  final String? wpFooterText;       // page footer
  final String? disclaimerText;     // end-of-report disclaimer
  final String? waiverText;         // limitation of liability paragraph

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<SurveyorProfileModel> surveyorProfiles;

  factory OrganisationModel.fromJson(Map<String, dynamic> json) {
    final profiles = (json['surveyor_profiles'] as List<dynamic>? ?? [])
        .map((p) => SurveyorProfileModel.fromJson(p as Map<String, dynamic>))
        .toList();
    return OrganisationModel(
      organisationId:   json['id'] as String,
      name:             json['name'] as String,
      abn:              json['abn'] as String?,
      address:          json['address'] as String?,
      phone:            json['phone'] as String?,
      email:            json['email'] as String?,
      website:          json['website'] as String?,
      primaryColour:    json['primary_colour'] as String?,
      secondaryColour:  json['secondary_colour'] as String?,
      logoStoragePath:  json['logo_storage_path'] as String?,
      wpHeaderText:     json['wp_header_text'] as String?,
      wpCoverText:      json['wp_cover_text'] as String?,
      wpCostSectionText: json['wp_cost_section_text'] as String?,
      wpFooterText:     json['wp_footer_text'] as String?,
      disclaimerText:   json['disclaimer_text'] as String?,
      waiverText:       json['waiver_text'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      surveyorProfiles: profiles,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (abn != null)              'abn':                abn,
    if (address != null)          'address':            address,
    if (phone != null)            'phone':              phone,
    if (email != null)            'email':              email,
    if (website != null)          'website':            website,
    if (primaryColour != null)    'primary_colour':     primaryColour,
    if (secondaryColour != null)  'secondary_colour':   secondaryColour,
    if (logoStoragePath != null)  'logo_storage_path':  logoStoragePath,
    if (wpHeaderText != null)     'wp_header_text':     wpHeaderText,
    if (wpCoverText != null)      'wp_cover_text':      wpCoverText,
    if (wpCostSectionText != null) 'wp_cost_section_text': wpCostSectionText,
    if (wpFooterText != null)     'wp_footer_text':     wpFooterText,
    if (disclaimerText != null)   'disclaimer_text':    disclaimerText,
    if (waiverText != null)       'waiver_text':        waiverText,
  };

  OrganisationModel copyWith({
    String? name,
    String? abn,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? primaryColour,
    String? secondaryColour,
    String? logoStoragePath,
    String? wpHeaderText,
    String? wpCoverText,
    String? wpCostSectionText,
    String? wpFooterText,
    String? disclaimerText,
    String? waiverText,
    List<SurveyorProfileModel>? surveyorProfiles,
  }) =>
      OrganisationModel(
        organisationId:    organisationId,
        name:              name              ?? this.name,
        abn:               abn               ?? this.abn,
        address:           address           ?? this.address,
        phone:             phone             ?? this.phone,
        email:             email             ?? this.email,
        website:           website           ?? this.website,
        primaryColour:     primaryColour     ?? this.primaryColour,
        secondaryColour:   secondaryColour   ?? this.secondaryColour,
        logoStoragePath:   logoStoragePath   ?? this.logoStoragePath,
        wpHeaderText:      wpHeaderText      ?? this.wpHeaderText,
        wpCoverText:       wpCoverText       ?? this.wpCoverText,
        wpCostSectionText: wpCostSectionText ?? this.wpCostSectionText,
        wpFooterText:      wpFooterText      ?? this.wpFooterText,
        disclaimerText:    disclaimerText    ?? this.disclaimerText,
        waiverText:        waiverText        ?? this.waiverText,
        createdAt:         createdAt,
        updatedAt:         updatedAt,
        surveyorProfiles:  surveyorProfiles  ?? this.surveyorProfiles,
      );
}

// ── Surveyor Profile ───────────────────────────────────────────────────────

@immutable
class SurveyorProfileModel {
  const SurveyorProfileModel({
    required this.profileId,
    required this.organisationId,
    required this.fullName,
    this.userId,
    this.title,
    this.qualifications,
    this.email,
    this.phone,
    this.signatureStoragePath,
    this.createdAt,
  });

  final String profileId;
  final String organisationId;
  final String? userId;
  final String fullName;
  final String? title;
  final String? qualifications;
  final String? email;
  final String? phone;
  final String? signatureStoragePath;
  final DateTime? createdAt;

  factory SurveyorProfileModel.fromJson(Map<String, dynamic> json) =>
      SurveyorProfileModel(
        profileId:            json['id'] as String,
        organisationId:       json['organisation_id'] as String,
        userId:               json['user_id'] as String?,
        fullName:             json['full_name'] as String,
        title:                json['title'] as String?,
        qualifications:       json['qualifications'] as String?,
        email:                json['email'] as String?,
        phone:                json['phone'] as String?,
        signatureStoragePath: json['signature_storage_path'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
    'organisation_id': organisationId,
    'full_name':       fullName,
    if (userId != null)               'user_id':               userId,
    if (title != null)                'title':                 title,
    if (qualifications != null)       'qualifications':        qualifications,
    if (email != null)                'email':                 email,
    if (phone != null)                'phone':                 phone,
    if (signatureStoragePath != null) 'signature_storage_path': signatureStoragePath,
  };

  SurveyorProfileModel copyWith({
    String? fullName,
    String? title,
    String? qualifications,
    String? email,
    String? phone,
  }) =>
      SurveyorProfileModel(
        profileId:            profileId,
        organisationId:       organisationId,
        userId:               userId,
        fullName:             fullName      ?? this.fullName,
        title:                title         ?? this.title,
        qualifications:       qualifications ?? this.qualifications,
        email:                email         ?? this.email,
        phone:                phone         ?? this.phone,
        signatureStoragePath: signatureStoragePath,
        createdAt:            createdAt,
      );
}
