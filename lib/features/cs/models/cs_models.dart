// lib/features/cs/models/cs_models.dart
//
// Data models for the C&S — AHTS module (Module A). Mirrors the modern
// register pattern used by action_items / interviews. See migration
// 063_cs_ahts.sql and docs/addtional modules/PHASE1_DETAILED_PLAN.md §4.

import 'package:flutter/foundation.dart';

// ── Item grade (per inspection item) ────────────────────────────────────────
enum CsGrade {
  satisfactory('SATISFACTORY', 'Satisfactory'),
  good('GOOD', 'Good'),
  unsatisfactory('UNSATISFACTORY', 'Unsatisfactory'),
  na('N_A', 'N/A');

  const CsGrade(this.value, this.label);
  final String value;
  final String label;

  static CsGrade? fromValue(String? v) {
    if (v == null) return null;
    for (final g in values) {
      if (g.value == v) return g;
    }
    return null;
  }
}

// ── Section rating (rolled up from item grades) ─────────────────────────────
// Its OWN three-state scale, distinct from the item grades: a section can be
// "satisfactory with issues" even though no single item has that grade.
enum CsSectionRating {
  good('GOOD', 'Good'),
  satisfactoryWithIssues('SATISFACTORY_WITH_ISSUES', 'Satisfactory (with issues)'),
  unsatisfactory('UNSATISFACTORY', 'Unsatisfactory');

  const CsSectionRating(this.value, this.label);
  final String value;
  final String label;

  static CsSectionRating? fromValue(String? v) {
    if (v == null) return null;
    for (final r in values) {
      if (r.value == v) return r;
    }
    return null;
  }
}

/// Derives a section's rating from its item grades (PLC's rollup, 2026-07-21):
///   - no UNSATISFACTORY items      → GOOD
///   - a minority UNSATISFACTORY    → SATISFACTORY_WITH_ISSUES
///   - half-or-more UNSATISFACTORY  → UNSATISFACTORY
/// N/A and ungraded items are ignored. Returns [CsSectionRating.good] when
/// nothing gradable is present (a section with no findings reads as good).
CsSectionRating deriveSectionRating(Iterable<CsGrade?> itemGrades) {
  final graded = itemGrades
      .where((g) => g != null && g != CsGrade.na)
      .cast<CsGrade>()
      .toList();
  if (graded.isEmpty) return CsSectionRating.good;
  final unsatisfactory =
      graded.where((g) => g == CsGrade.unsatisfactory).length;
  if (unsatisfactory == 0) return CsSectionRating.good;
  // half-or-more failing → unsatisfactory; otherwise a minority → with-issues
  if (unsatisfactory * 2 >= graded.length) return CsSectionRating.unsatisfactory;
  return CsSectionRating.satisfactoryWithIssues;
}

// ── Recommendation status (§1.13 gating list) ───────────────────────────────
enum CsRecommendationStatus {
  open('open', 'Open'),
  closed('closed', 'Closed');

  const CsRecommendationStatus(this.value, this.label);
  final String value;
  final String label;

  static CsRecommendationStatus fromValue(String? v) {
    for (final s in values) {
      if (s.value == v) return s;
    }
    return CsRecommendationStatus.open;
  }
}

// ── Template item (shared reference skeleton) ───────────────────────────────
@immutable
class CsTemplateItemModel {
  const CsTemplateItemModel({
    required this.id,
    required this.templateId,
    required this.section,
    required this.label,
    this.parentItem,
    this.refNo,
    this.guidanceText,
    this.gradeApplicable = true,
    this.gtThreshold,
    this.sortOrder = 0,
  });

  final String id;
  final String templateId;
  final String section; // '1.0' .. '11.0'
  final String label;
  final String? parentItem;
  final String? refNo;
  final String? guidanceText;
  final bool gradeApplicable;
  final double? gtThreshold;
  final int sortOrder;

  factory CsTemplateItemModel.fromJson(Map<String, dynamic> j) =>
      CsTemplateItemModel(
        id: j['id'] as String,
        templateId: j['template_id'] as String,
        section: j['section'] as String,
        label: j['label'] as String,
        parentItem: j['parent_item'] as String?,
        refNo: j['ref_no'] as String?,
        guidanceText: j['guidance_text'] as String?,
        gradeApplicable: j['grade_applicable'] as bool? ?? true,
        gtThreshold: (j['gt_threshold'] as num?)?.toDouble(),
        sortOrder: j['sort_order'] as int? ?? 0,
      );
}

// ── Section (per-case; extends the existing cs_sections scaffold) ───────────
@immutable
class CsSectionModel {
  const CsSectionModel({
    required this.sectionId,
    required this.caseId,
    this.sectionType,
    this.rating,
    this.ratingOverridden = false,
    this.narrative,
    this.templateSectionRef,
    this.vesselType,
  });

  final String sectionId;
  final String caseId;
  final String? sectionType;
  final CsSectionRating? rating;
  final bool ratingOverridden;
  final String? narrative;
  final String? templateSectionRef;
  final String? vesselType;

  factory CsSectionModel.fromJson(Map<String, dynamic> j) => CsSectionModel(
        sectionId: j['section_id'] as String,
        caseId: j['case_id'] as String,
        sectionType: j['section_type'] as String?,
        rating: CsSectionRating.fromValue(j['rating'] as String?),
        ratingOverridden: j['rating_overridden'] as bool? ?? false,
        narrative: j['narrative'] as String?,
        templateSectionRef: j['template_section_ref'] as String?,
        vesselType: j['vessel_type'] as String?,
      );

  CsSectionModel copyWith({
    CsSectionRating? rating,
    bool? ratingOverridden,
    String? narrative,
  }) =>
      CsSectionModel(
        sectionId: sectionId,
        caseId: caseId,
        sectionType: sectionType,
        rating: rating ?? this.rating,
        ratingOverridden: ratingOverridden ?? this.ratingOverridden,
        narrative: narrative ?? this.narrative,
        templateSectionRef: templateSectionRef,
        vesselType: vesselType,
      );
}

// ── Inspection item (per-case register) ─────────────────────────────────────
@immutable
class CsInspectionItemModel {
  const CsInspectionItemModel({
    required this.id,
    required this.caseId,
    this.sectionId,
    this.templateItemId,
    this.grade,
    this.remark,
    this.isNa = false,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String caseId;
  final String? sectionId;
  final String? templateItemId;
  final CsGrade? grade;
  final String? remark;
  final bool isNa;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CsInspectionItemModel.fromJson(Map<String, dynamic> j) =>
      CsInspectionItemModel(
        id: j['id'] as String,
        caseId: j['case_id'] as String,
        sectionId: j['section_id'] as String?,
        templateItemId: j['template_item_id'] as String?,
        grade: CsGrade.fromValue(j['grade'] as String?),
        remark: j['remark'] as String?,
        isNa: j['is_na'] as bool? ?? false,
        sortOrder: j['sort_order'] as int? ?? 0,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        updatedAt: j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'] as String)
            : null,
      );

  CsInspectionItemModel copyWith({
    CsGrade? grade,
    String? remark,
    bool? isNa,
  }) =>
      CsInspectionItemModel(
        id: id,
        caseId: caseId,
        sectionId: sectionId,
        templateItemId: templateItemId,
        grade: grade ?? this.grade,
        remark: remark ?? this.remark,
        isNa: isNa ?? this.isNa,
        sortOrder: sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

// ── Recommendation (§1.13 gating list; the F4 findings instance) ────────────
@immutable
class CsRecommendationModel {
  const CsRecommendationModel({
    required this.id,
    required this.caseId,
    required this.text,
    this.refNo,
    this.sourceItemId,
    this.status = CsRecommendationStatus.open,
    this.closeDate,
    this.sortOrder = 0,
    this.createdAt,
  });

  final String id;
  final String caseId;
  final String text;
  final String? refNo;
  final String? sourceItemId;
  final CsRecommendationStatus status;
  final DateTime? closeDate;
  final int sortOrder;
  final DateTime? createdAt;

  factory CsRecommendationModel.fromJson(Map<String, dynamic> j) =>
      CsRecommendationModel(
        id: j['id'] as String,
        caseId: j['case_id'] as String,
        text: j['text'] as String,
        refNo: j['ref_no'] as String?,
        sourceItemId: j['source_item_id'] as String?,
        status: CsRecommendationStatus.fromValue(j['status'] as String?),
        closeDate: j['close_date'] != null
            ? DateTime.tryParse(j['close_date'] as String)
            : null,
        sortOrder: j['sort_order'] as int? ?? 0,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  CsRecommendationModel copyWith({
    String? text,
    CsRecommendationStatus? status,
    DateTime? closeDate,
  }) =>
      CsRecommendationModel(
        id: id,
        caseId: caseId,
        text: text ?? this.text,
        refNo: refNo,
        sourceItemId: sourceItemId,
        status: status ?? this.status,
        closeDate: closeDate ?? this.closeDate,
        sortOrder: sortOrder,
        createdAt: createdAt,
      );
}

// ── Certificate (§3.0 register) ─────────────────────────────────────────────
@immutable
class CsCertificateModel {
  const CsCertificateModel({
    required this.id,
    required this.caseId,
    required this.certType,
    this.issuedDate,
    this.issuedPlace,
    this.expiryDate,
    this.status,
    this.documentId,
    this.sortOrder = 0,
  });

  final String id;
  final String caseId;
  final String certType;
  final DateTime? issuedDate;
  final String? issuedPlace;
  final DateTime? expiryDate;
  final String? status;
  final String? documentId;
  final int sortOrder;

  factory CsCertificateModel.fromJson(Map<String, dynamic> j) =>
      CsCertificateModel(
        id: j['id'] as String,
        caseId: j['case_id'] as String,
        certType: j['cert_type'] as String,
        issuedDate: j['issued_date'] != null
            ? DateTime.tryParse(j['issued_date'] as String)
            : null,
        issuedPlace: j['issued_place'] as String?,
        expiryDate: j['expiry_date'] != null
            ? DateTime.tryParse(j['expiry_date'] as String)
            : null,
        status: j['status'] as String?,
        documentId: j['document_id'] as String?,
        sortOrder: j['sort_order'] as int? ?? 0,
      );
}
