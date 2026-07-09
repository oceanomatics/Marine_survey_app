// lib/features/accounts/models/accounts_models.dart

import 'package:flutter/foundation.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum DocumentType {
  invoice('invoice', 'Invoice'),
  estimate('estimate', 'Estimate'),
  creditNote('credit_note', 'Credit Note'),
  proforma('proforma', 'Proforma'),
  quotation('quotation', 'Quotation'),
  purchaseOrder('purchase_order', 'Purchase Order'),
  deliveryNote('delivery_note', 'Delivery Note');

  const DocumentType(this.value, this.label);
  final String value;
  final String label;

  static DocumentType fromValue(String? v) => switch (v) {
        'estimate'       => estimate,
        'credit_note'    => creditNote,
        'proforma'       => proforma,
        'quotation'      => quotation,
        'purchase_order' => purchaseOrder,
        'delivery_note'  => deliveryNote,
        _                => invoice,
      };
}

enum DocStatus {
  pendingReview('pending_review', 'Pending Review'),
  underReview('under_review', 'Under Review'),
  queried('queried', 'Queried / Awaiting Docs'),
  approved('approved', 'Approved'),
  partlyApproved('partly_approved', 'Partly Approved'),
  rejected('rejected', 'Rejected');

  const DocStatus(this.value, this.label);
  final String value;
  final String label;

  static DocStatus fromValue(String? v) => switch (v) {
        'under_review'        => underReview,
        'queried'             => queried,
        'awaiting_docs'       => queried,  // backward compat
        'approved'            => approved,
        'partly_approved'     => partlyApproved,
        'partially_approved'  => partlyApproved,  // backward compat
        'rejected'            => rejected,
        _                     => pendingReview,
      };
}

enum CostNature {
  serviceTechnician('service_technician', 'Service Technician'),
  specialistEngineer('specialist_engineer', 'Specialist Engineer'),
  repairerWorkshop('repairer_workshop', 'Repairer / Workshop'),
  dryDockSlipway('dry_dock_slipway', 'Dry Dock / Slipway'),
  divingContractor('diving_contractor', 'Diving Contractor'),
  inspectionSurvey('inspection_survey', 'Inspection / Survey'),
  superintendency('superintendency', 'Superintendency'),
  accessStaging('access_staging', 'Access / Staging'),
  mobilisation('mobilisation', 'Mobilisation'),
  demobilisation('demobilisation', 'Demobilisation'),
  surfaceTreatment('surface_treatment', 'Surface Treatment'),
  testingCommissioning('testing_commissioning', 'Testing / Commissioning'),
  toolHire('tool_hire', 'Tool Hire'),
  spareParts('spare_parts', 'Spare Parts'),
  equipment('equipment', 'Equipment'),
  freightDomestic('freight_domestic', 'Freight (Domestic)'),
  freightInternational('freight_international', 'Freight (International)'),
  portServices('port_services', 'Port Services'),
  wasteDisposal('waste_disposal', 'Waste Disposal'),
  accommodation('accommodation', 'Accommodation'),
  catering('catering', 'Catering'),
  crewExpenses('crew_expenses', 'Crew Expenses'),
  professionalFees('professional_fees', 'Professional Fees'),
  ownersMaintenance('owners_maintenance', "Owner's Maintenance"),
  classStatutory('class_statutory', 'Class / Statutory'),
  other('other', 'Other');

  const CostNature(this.value, this.label);
  final String value;
  final String label;

  static CostNature fromValue(String? v) =>
      CostNature.values.firstWhere((e) => e.value == v,
          orElse: () => CostNature.other);
}

enum LineItemStatus {
  pendingReview('pending_review', 'Pending Review'),
  queried('queried', 'Queried'),
  approved('approved', 'Approved'),
  apportioned('apportioned', 'Apportioned'),
  betterment('betterment', 'Betterment'),
  rejected('rejected', 'Rejected');

  const LineItemStatus(this.value, this.label);
  final String value;
  final String label;

  static LineItemStatus fromValue(String? v) => switch (v) {
        'queried'     => queried,
        'approved'    => approved,
        'apportioned' => apportioned,
        'betterment'  => betterment,
        'rejected'    => rejected,
        _             => pendingReview,
      };
}

enum SupplierCategory {
  oemDealer('oem_dealer', 'OEM Dealer'),
  oemDirect('oem_direct', 'OEM Direct'),
  independentWorkshop('independent_workshop', 'Independent Workshop'),
  electricalSpecialist('electrical_specialist', 'Electrical Specialist'),
  hydraulicSpecialist('hydraulic_specialist', 'Hydraulic Specialist'),
  ndtSpecialist('ndt_specialist', 'NDT Specialist'),
  divingServices('diving_services', 'Diving Services'),
  dryDockOperator('dry_dock_operator', 'Dry Dock / Slipway'),
  portAuthority('port_authority', 'Port Authority'),
  portServicesCo('port_services_co', 'Port Services'),
  shippingAgency('shipping_agency', 'Shipping Agency'),
  freightDomestic('freight_domestic', 'Freight (Domestic)'),
  freightInternational('freight_international', 'Freight (International)'),
  toolHireCo('tool_hire_co', 'Tool Hire'),
  industrialSupply('industrial_supply', 'Industrial Supply'),
  classSociety('class_society', 'Class Society'),
  navalArchitect('naval_architect', 'Naval Architect'),
  legalProfessional('legal_professional', 'Legal / P&I'),
  other('other', 'Other');

  const SupplierCategory(this.value, this.label);
  final String value;
  final String label;

  static SupplierCategory fromValue(String? v) =>
      SupplierCategory.values.firstWhere((e) => e.value == v,
          orElse: () => SupplierCategory.other);
}

// ── Account line model ─────────────────────────────────────────────────────

@immutable
class AccountLineModel {
  const AccountLineModel({
    required this.id,
    required this.documentId,
    required this.caseId,
    this.lineOrder = 0,
    this.itemNumber,
    this.description,
    this.costNature = CostNature.serviceTechnician,
    this.grossAmount = 0,
    this.ownersPortion = 0,
    this.underwritersPortion = 0,
    this.bettermentDeduction = 0,
    this.apportionmentNotes,
    this.apportionmentType,
    this.apportionmentValue,
    this.status = LineItemStatus.pendingReview,
    this.aiDraft,
    this.presentationStatement,
    this.repairPeriodId,
    this.occurrenceId,
    this.createdAt,
    this.invoiceCurrency,
    this.fxRateToBase,
    this.fxRateDate,
    this.baseCurrencyAmount,
  });

  final String id;
  final String documentId;
  final String caseId;
  final int lineOrder;
  final int? itemNumber;
  final String? description;
  final CostNature costNature;
  final double grossAmount;
  final double ownersPortion;
  final double underwritersPortion;
  final double bettermentDeduction;
  final String? apportionmentNotes;
  final String? apportionmentType;    // 'percentage' | 'amount' | 'defer'
  final double? apportionmentValue;
  final LineItemStatus status;
  final String? aiDraft;
  final String? presentationStatement;
  final String? repairPeriodId;       // UUID or 'preliminary_expense'
  final String? occurrenceId;
  final DateTime? createdAt;
  /// ISO 4217 currency of the original invoice (e.g. 'USD', 'SGD').
  final String? invoiceCurrency;
  /// Rate to convert invoiceCurrency → case base currency, locked at invoice date.
  final double? fxRateToBase;
  /// Date the FX rate was locked.
  final DateTime? fxRateDate;
  /// grossAmount converted to the case base currency.
  final double? baseCurrencyAmount;

  bool get isOwnersAccount =>
      costNature == CostNature.ownersMaintenance ||
      costNature == CostNature.classStatutory;

  factory AccountLineModel.fromJson(Map<String, dynamic> j) => AccountLineModel(
        id:                   j['id'] as String,
        documentId:           j['document_id'] as String,
        caseId:               j['case_id'] as String,
        lineOrder:            j['line_order'] as int? ?? 0,
        itemNumber:           j['item_number'] as int?,
        description:          j['description'] as String?,
        costNature:           CostNature.fromValue(j['cost_nature'] as String?),
        grossAmount:          (j['gross_amount'] as num?)?.toDouble() ?? 0,
        ownersPortion:        (j['owners_portion'] as num?)?.toDouble() ?? 0,
        underwritersPortion:  (j['underwriters_portion'] as num?)?.toDouble() ?? 0,
        bettermentDeduction:  (j['betterment_deduction'] as num?)?.toDouble() ?? 0,
        apportionmentNotes:   j['apportionment_notes'] as String?,
        apportionmentType:    j['apportionment_type'] as String?,
        apportionmentValue:   (j['apportionment_value'] as num?)?.toDouble(),
        status:               LineItemStatus.fromValue(j['surveyor_status'] as String?),
        aiDraft:              j['ai_presentation_draft'] as String?,
        presentationStatement:j['presentation_statement'] as String?,
        repairPeriodId:       j['repair_period_id'] as String?,
        occurrenceId:         j['occurrence_id'] as String?,
        createdAt:            j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        invoiceCurrency:      j['invoice_currency'] as String?,
        fxRateToBase:         (j['fx_rate_to_base'] as num?)?.toDouble(),
        fxRateDate:           j['fx_rate_date'] != null
            ? DateTime.tryParse(j['fx_rate_date'] as String)
            : null,
        baseCurrencyAmount:   (j['base_currency_amount'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toInsertJson() => {
        'document_id':     documentId,
        'case_id':         caseId,
        'line_order':      lineOrder,
        if (itemNumber != null) 'item_number': itemNumber,
        if (description != null) 'description': description,
        'cost_nature':     costNature.value,
        'gross_amount':    grossAmount,
        'owners_portion':       ownersPortion,
        'underwriters_portion': underwritersPortion,
        'betterment_deduction': bettermentDeduction,
        if (apportionmentNotes != null) 'apportionment_notes': apportionmentNotes,
        if (apportionmentType != null)  'apportionment_type': apportionmentType,
        if (apportionmentValue != null) 'apportionment_value': apportionmentValue,
        'surveyor_status': status.value,
        if (aiDraft != null) 'ai_presentation_draft': aiDraft,
        if (presentationStatement != null)
          'presentation_statement': presentationStatement,
        if (repairPeriodId != null) 'repair_period_id': repairPeriodId,
        if (occurrenceId != null) 'occurrence_id': occurrenceId,
        if (invoiceCurrency != null) 'invoice_currency': invoiceCurrency,
        if (fxRateToBase != null) 'fx_rate_to_base': fxRateToBase,
        if (fxRateDate != null)
          'fx_rate_date': fxRateDate!.toIso8601String().split('T').first,
        if (baseCurrencyAmount != null) 'base_currency_amount': baseCurrencyAmount,
      };

  AccountLineModel copyWith({
    String? description,
    CostNature? costNature,
    double? grossAmount,
    double? ownersPortion,
    double? underwritersPortion,
    double? bettermentDeduction,
    Object? apportionmentNotes = _sentinel,
    Object? apportionmentType = _sentinel,
    Object? apportionmentValue = _sentinel,
    LineItemStatus? status,
    Object? aiDraft = _sentinel,
    Object? presentationStatement = _sentinel,
    Object? repairPeriodId = _sentinel,
    Object? occurrenceId = _sentinel,
    Object? invoiceCurrency = _sentinel,
    Object? fxRateToBase = _sentinel,
    Object? fxRateDate = _sentinel,
    Object? baseCurrencyAmount = _sentinel,
  }) =>
      AccountLineModel(
        id: id,
        documentId: documentId,
        caseId: caseId,
        lineOrder: lineOrder,
        itemNumber: itemNumber,
        description: description ?? this.description,
        costNature: costNature ?? this.costNature,
        grossAmount: grossAmount ?? this.grossAmount,
        ownersPortion: ownersPortion ?? this.ownersPortion,
        underwritersPortion: underwritersPortion ?? this.underwritersPortion,
        bettermentDeduction: bettermentDeduction ?? this.bettermentDeduction,
        apportionmentNotes: apportionmentNotes == _sentinel
            ? this.apportionmentNotes : apportionmentNotes as String?,
        apportionmentType: apportionmentType == _sentinel
            ? this.apportionmentType : apportionmentType as String?,
        apportionmentValue: apportionmentValue == _sentinel
            ? this.apportionmentValue : apportionmentValue as double?,
        status: status ?? this.status,
        aiDraft: aiDraft == _sentinel ? this.aiDraft : aiDraft as String?,
        presentationStatement: presentationStatement == _sentinel
            ? this.presentationStatement : presentationStatement as String?,
        repairPeriodId: repairPeriodId == _sentinel
            ? this.repairPeriodId : repairPeriodId as String?,
        occurrenceId: occurrenceId == _sentinel
            ? this.occurrenceId : occurrenceId as String?,
        createdAt: createdAt,
        invoiceCurrency: invoiceCurrency == _sentinel
            ? this.invoiceCurrency : invoiceCurrency as String?,
        fxRateToBase: fxRateToBase == _sentinel
            ? this.fxRateToBase : fxRateToBase as double?,
        fxRateDate: fxRateDate == _sentinel
            ? this.fxRateDate : fxRateDate as DateTime?,
        baseCurrencyAmount: baseCurrencyAmount == _sentinel
            ? this.baseCurrencyAmount : baseCurrencyAmount as double?,
      );
}

// ── Repair document model ──────────────────────────────────────────────────

@immutable
class RepairDocumentModel {
  const RepairDocumentModel({
    required this.id,
    required this.caseId,
    this.displayName,
    this.documentType = DocumentType.invoice,
    this.documentNumber,
    this.documentDate,
    this.contractRef,
    this.supplierName,
    this.supplierCategory = SupplierCategory.other,
    this.currency = 'AUD',
    this.subtotalExTax,
    this.taxTotal,
    this.totalIncTax,
    this.mixedNatureFlag = false,
    this.withoutPrejudice = true,
    this.aiPresentationDraft,
    this.presentationStatement,
    this.status = DocStatus.pendingReview,
    this.statusManuallySet = false,
    this.surveyorNotes,
    this.sourcePdfPath,
    this.aiExtractedAt,
    this.aiConfidence,
    this.pageStart,
    this.pageEnd,
    this.submittedToInsurance = true,
    this.rejectionReason,
    this.thumbnailPath,
    this.accountLines = const [],
    this.createdAt,
  });

  final String id;
  final String caseId;
  final String? displayName;
  final DocumentType documentType;
  final String? documentNumber;
  final DateTime? documentDate;
  final String? contractRef;
  final String? supplierName;
  final SupplierCategory supplierCategory;
  final String currency;
  final double? subtotalExTax;
  final double? taxTotal;
  final double? totalIncTax;
  final bool mixedNatureFlag;
  final bool withoutPrejudice;
  final String? aiPresentationDraft;
  final String? presentationStatement;
  final DocStatus status;
  /// True once the surveyor has manually picked a status via the chip
  /// selector — auto-derivation from line-item statuses (accounts_provider.dart
  /// `_deriveStatus`) skips this document until reset back to auto.
  final bool statusManuallySet;
  final String? surveyorNotes;
  final String? sourcePdfPath;
  final DateTime? aiExtractedAt;
  final double? aiConfidence;
  final int? pageStart;
  final int? pageEnd;
  final bool submittedToInsurance;
  final String? rejectionReason;
  final String? thumbnailPath;
  final List<AccountLineModel> accountLines;
  final DateTime? createdAt;

  bool get isContextOnly => !submittedToInsurance;
  bool get hasPageRange => pageStart != null && pageEnd != null;
  String? get pageRangeLabel =>
      hasPageRange ? 'pp. $pageStart–$pageEnd' : null;

  String get effectiveName =>
      displayName ??
      [
        documentNumber,
        supplierName,
        documentDate != null
            ? '${documentDate!.day.toString().padLeft(2,'0')}/'
              '${documentDate!.month.toString().padLeft(2,'0')}/'
              '${documentDate!.year}'
            : null,
      ].where((s) => s != null && s.isNotEmpty).join(' — ');

  double get totalApprovedUW => accountLines.fold(
      0.0, (s, l) => s + l.underwritersPortion);
  double get totalApprovedOwners =>
      accountLines.fold(0.0, (s, l) => s + l.ownersPortion);

  factory RepairDocumentModel.fromJson(
    Map<String, dynamic> j, {
    List<AccountLineModel> accountLines = const [],
  }) =>
      RepairDocumentModel(
        id:                   j['id'] as String,
        caseId:               j['case_id'] as String,
        displayName:          j['display_name'] as String?,
        documentType:         DocumentType.fromValue(j['document_type'] as String?),
        documentNumber:       j['document_number'] as String?,
        documentDate:         j['document_date'] != null
            ? DateTime.tryParse(j['document_date'] as String)
            : null,
        contractRef:          j['contract_ref'] as String?,
        supplierName:         j['supplier_name'] as String?,
        supplierCategory:     SupplierCategory.fromValue(j['supplier_category'] as String?),
        currency:             j['currency'] as String? ?? 'AUD',
        subtotalExTax:        (j['subtotal_ex_tax'] as num?)?.toDouble(),
        taxTotal:             (j['tax_total'] as num?)?.toDouble(),
        totalIncTax:          (j['total_inc_tax'] as num?)?.toDouble(),
        mixedNatureFlag:      j['mixed_nature_flag'] as bool? ?? false,
        withoutPrejudice:     j['without_prejudice'] as bool? ?? true,
        aiPresentationDraft:  j['ai_presentation_draft'] as String?,
        presentationStatement:j['presentation_statement'] as String?,
        status:               DocStatus.fromValue(j['surveyor_status'] as String?),
        statusManuallySet:    j['status_manually_set'] as bool? ?? false,
        surveyorNotes:        j['surveyor_notes'] as String?,
        sourcePdfPath:        j['source_pdf_path'] as String?,
        aiExtractedAt:        j['ai_extracted_at'] != null
            ? DateTime.tryParse(j['ai_extracted_at'] as String)
            : null,
        aiConfidence:         (j['ai_confidence'] as num?)?.toDouble(),
        pageStart:            j['page_start'] as int?,
        pageEnd:              j['page_end'] as int?,
        submittedToInsurance: j['submitted_to_insurance'] as bool? ?? true,
        rejectionReason:      j['rejection_reason'] as String?,
        thumbnailPath:        j['thumbnail_path'] as String?,
        accountLines:         accountLines,
        createdAt:            j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'case_id':               caseId,
        'document_type':         documentType.value,
        'surveyor_status':       status.value,
        'status_manually_set':   statusManuallySet,
        'currency':              currency,
        'without_prejudice':     withoutPrejudice,
        'mixed_nature_flag':     mixedNatureFlag,
        'submitted_to_insurance':submittedToInsurance,
        if (displayName != null)           'display_name':            displayName,
        if (documentNumber != null)        'document_number':         documentNumber,
        if (documentDate != null)          'document_date':           _fmtDate(documentDate!),
        if (contractRef != null)           'contract_ref':            contractRef,
        if (supplierName != null)          'supplier_name':           supplierName,
        'supplier_category':               supplierCategory.value,
        if (subtotalExTax != null)         'subtotal_ex_tax':         subtotalExTax,
        if (taxTotal != null)              'tax_total':               taxTotal,
        if (totalIncTax != null)           'total_inc_tax':           totalIncTax,
        if (aiPresentationDraft != null)   'ai_presentation_draft':   aiPresentationDraft,
        if (presentationStatement != null) 'presentation_statement':  presentationStatement,
        if (surveyorNotes != null)         'surveyor_notes':          surveyorNotes,
        if (sourcePdfPath != null)         'source_pdf_path':         sourcePdfPath,
        if (aiExtractedAt != null)         'ai_extracted_at':         aiExtractedAt!.toIso8601String(),
        if (aiConfidence != null)          'ai_confidence':           aiConfidence,
        if (pageStart != null)             'page_start':              pageStart,
        if (pageEnd != null)               'page_end':                pageEnd,
        if (rejectionReason != null)       'rejection_reason':        rejectionReason,
        if (thumbnailPath != null)         'thumbnail_path':          thumbnailPath,
      };

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}

// ── Batch split segment (AI analysis result, pre-import) ───────────────────

class BatchInvoiceSegment {
  BatchInvoiceSegment({
    required this.index,
    required this.pageStart,
    required this.pageEnd,
    this.supplierName,
    this.invoiceNumber,
    this.date,
    this.currency,
    this.totalAmount,
    required this.submittedToInsurance,
    this.reason,
    this.confidence = 0.8,
  });

  final int index;
  final int pageStart;
  final int pageEnd;
  final String? supplierName;
  final String? invoiceNumber;
  final String? date;
  final String? currency;
  final double? totalAmount;
  bool submittedToInsurance;  // mutable — user can flip in review step
  final String? reason;
  final double confidence;

  String get displayLabel {
    final parts = [invoiceNumber, supplierName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' — ');
    return parts.isNotEmpty ? parts : 'Document ${index + 1}';
  }

  factory BatchInvoiceSegment.fromJson(Map<String, dynamic> j, int idx) =>
      BatchInvoiceSegment(
        index:                idx,
        pageStart:            (j['page_start'] as num?)?.toInt() ?? 1,
        pageEnd:              (j['page_end'] as num?)?.toInt() ?? 1,
        supplierName:         j['supplier_name'] as String?,
        invoiceNumber:        j['invoice_number'] as String?,
        date:                 j['date'] as String?,
        currency:             j['currency'] as String?,
        totalAmount:          (j['total_amount'] as num?)?.toDouble(),
        submittedToInsurance: j['submitted_to_insurance'] as bool? ?? true,
        reason:               j['reason'] as String?,
        confidence:           (j['confidence'] as num?)?.toDouble() ?? 0.8,
      );
}

// ── Cost estimate line item (Clause G-1 redesign, §3.12 item 42) ───────────

enum CostEstimateCategory {
  generalExpenses('general_expenses', 'General Expenses'),
  towing('towing', 'Towing'),
  dryDocking('dry_docking', 'Dry Docking'),
  parts('parts', 'Parts'),
  labour('labour', 'Labour'),
  pilotage('pilotage', 'Pilotage'),
  wharfage('wharfage', 'Wharfage'),
  surveyFees('survey_fees', 'Survey Fees'),
  classSociety('class_society', 'Class Society'),
  other('other', 'Other');

  const CostEstimateCategory(this.value, this.label);
  final String value;
  final String label;

  static CostEstimateCategory fromValue(String? v) =>
      CostEstimateCategory.values.firstWhere((e) => e.value == v,
          orElse: () => CostEstimateCategory.other);
}

@immutable
class CostEstimateItemModel {
  const CostEstimateItemModel({
    required this.id,
    required this.caseId,
    this.category = CostEstimateCategory.generalExpenses,
    this.description,
    this.amount = 0,
    this.sortOrder = 0,
    this.createdAt,
  });

  final String id;
  final String caseId;
  final CostEstimateCategory category;
  final String? description;
  final double amount;
  final int sortOrder;
  final DateTime? createdAt;

  factory CostEstimateItemModel.fromJson(Map<String, dynamic> j) =>
      CostEstimateItemModel(
        id:          j['id'] as String,
        caseId:      j['case_id'] as String,
        category:    CostEstimateCategory.fromValue(j['category'] as String?),
        description: j['description'] as String?,
        amount:      (j['amount'] as num?)?.toDouble() ?? 0,
        sortOrder:   j['sort_order'] as int? ?? 0,
        createdAt:   j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'case_id':    caseId,
        'category':   category.value,
        if (description != null) 'description': description,
        'amount':     amount,
        'sort_order': sortOrder,
      };

  CostEstimateItemModel copyWith({
    CostEstimateCategory? category,
    Object? description = _sentinel,
    double? amount,
  }) =>
      CostEstimateItemModel(
        id: id,
        caseId: caseId,
        category: category ?? this.category,
        description: description == _sentinel
            ? this.description
            : description as String?,
        amount: amount ?? this.amount,
        sortOrder: sortOrder,
        createdAt: createdAt,
      );
}

// ── Summary DTO ────────────────────────────────────────────────────────────

class AccountsSummary {
  const AccountsSummary({
    this.totalDocuments = 0,
    this.pendingCount = 0,
    this.queriedCount = 0,
    this.approvedCount = 0,
    this.totalSubmitted = 0,
    this.totalApprovedUW = 0,
    this.totalApprovedOwners = 0,
    this.primaryCurrency = 'AUD',
  });

  final int totalDocuments;
  final int pendingCount;
  final int queriedCount;
  final int approvedCount;
  final double totalSubmitted;
  final double totalApprovedUW;
  final double totalApprovedOwners;
  final String primaryCurrency;

  factory AccountsSummary.fromDocuments(List<RepairDocumentModel> docs) {
    if (docs.isEmpty) return const AccountsSummary();
    // Only count submitted-to-insurance items in the claim stats
    final claimed = docs.where((d) => d.submittedToInsurance).toList();
    final currency = docs.first.currency;
    int pending = 0, queried = 0, approved = 0;
    double submitted = 0, approvedUW = 0, approvedOwners = 0;
    for (final d in claimed) {
      submitted += d.totalIncTax ?? 0;
      approvedUW += d.totalApprovedUW;
      approvedOwners += d.totalApprovedOwners;
      if (d.status == DocStatus.pendingReview || d.status == DocStatus.underReview) pending++;
      if (d.status == DocStatus.queried) queried++;
      if (d.status == DocStatus.approved || d.status == DocStatus.partlyApproved) approved++;
    }
    return AccountsSummary(
      totalDocuments: claimed.length,
      pendingCount: pending,
      queriedCount: queried,
      approvedCount: approved,
      totalSubmitted: submitted,
      totalApprovedUW: approvedUW,
      totalApprovedOwners: approvedOwners,
      primaryCurrency: currency,
    );
  }
}

const Object _sentinel = Object();
