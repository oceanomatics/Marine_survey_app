// Widget-test double for ReportOutputsNotifier — same rationale as
// fake_checklist_notifier.dart: skip SupabaseService.client entirely, keep
// the same optimistic-update shape as the real notifier. ReportOutput has no
// copyWith, so the update methods rebuild the object field-by-field.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';

ReportOutput _withStatus(ReportOutput o, ReportStatus status) => ReportOutput(
      outputId: o.outputId,
      caseId: o.caseId,
      outputType: o.outputType,
      status: status,
      sections: o.sections,
      reportNumber: o.reportNumber,
      sequenceNo: o.sequenceNo,
      issuedDate: o.issuedDate,
      issuedTo: o.issuedTo,
      filePath: o.filePath,
      createdAt: o.createdAt,
      supersedesVersion: o.supersedesVersion,
      changesSummary: o.changesSummary,
      adviceNatureOfCasualty: o.adviceNatureOfCasualty,
      adviceDescriptionOfDamage: o.adviceDescriptionOfDamage,
      adviceNatureOfRepairs: o.adviceNatureOfRepairs,
      adviceStatusOfRepairs: o.adviceStatusOfRepairs,
      adviceStatusOfRepairsDetail: o.adviceStatusOfRepairsDetail,
      adviceCostAmount: o.adviceCostAmount,
      adviceCostCurrency: o.adviceCostCurrency,
      adviceCostIncludesGeneralExpenses: o.adviceCostIncludesGeneralExpenses,
      adviceCostIncludesTowing: o.adviceCostIncludesTowing,
      adviceFeeReserveHours: o.adviceFeeReserveHours,
      adviceFeeReserveExpenses: o.adviceFeeReserveExpenses,
      adviceFollowUpRequired: o.adviceFollowUpRequired,
      adviceFollowUpDetail: o.adviceFollowUpDetail,
      adviceRemarks: o.adviceRemarks,
      adviceConfirmed: o.adviceConfirmed,
    );

ReportOutput _withChangesSummary(ReportOutput o, String summary) =>
    ReportOutput(
      outputId: o.outputId,
      caseId: o.caseId,
      outputType: o.outputType,
      status: o.status,
      sections: o.sections,
      reportNumber: o.reportNumber,
      sequenceNo: o.sequenceNo,
      issuedDate: o.issuedDate,
      issuedTo: o.issuedTo,
      filePath: o.filePath,
      createdAt: o.createdAt,
      supersedesVersion: o.supersedesVersion,
      changesSummary: summary,
      adviceNatureOfCasualty: o.adviceNatureOfCasualty,
      adviceDescriptionOfDamage: o.adviceDescriptionOfDamage,
      adviceNatureOfRepairs: o.adviceNatureOfRepairs,
      adviceStatusOfRepairs: o.adviceStatusOfRepairs,
      adviceStatusOfRepairsDetail: o.adviceStatusOfRepairsDetail,
      adviceCostAmount: o.adviceCostAmount,
      adviceCostCurrency: o.adviceCostCurrency,
      adviceCostIncludesGeneralExpenses: o.adviceCostIncludesGeneralExpenses,
      adviceCostIncludesTowing: o.adviceCostIncludesTowing,
      adviceFeeReserveHours: o.adviceFeeReserveHours,
      adviceFeeReserveExpenses: o.adviceFeeReserveExpenses,
      adviceFollowUpRequired: o.adviceFollowUpRequired,
      adviceFollowUpDetail: o.adviceFollowUpDetail,
      adviceRemarks: o.adviceRemarks,
      adviceConfirmed: o.adviceConfirmed,
    );

class FakeReportOutputsNotifier extends ReportOutputsNotifier {
  FakeReportOutputsNotifier(this._seed);
  final List<ReportOutput> _seed;

  @override
  Future<List<ReportOutput>> build(String caseId) async => _seed;

  @override
  Future<ReportOutput> createOutput({
    required String caseId,
    required OutputType type,
    required String reportNumber,
    int sequenceNo = 1,
  }) async {
    final existing = state.value ?? [];
    final supersedesVersion =
        existing.isNotEmpty ? existing.first.versionCode : null;
    final output = ReportOutput(
      outputId: 'fake-output-${existing.length + 1}',
      caseId: caseId,
      outputType: type,
      status: ReportStatus.draft,
      sections: const [],
      reportNumber: reportNumber,
      sequenceNo: sequenceNo,
      supersedesVersion: supersedesVersion,
    );
    state = AsyncData([output, ...existing]);
    return output;
  }

  @override
  Future<void> updateStatus(String outputId, ReportStatus status) async {
    final current = state.value ?? [];
    state = AsyncData([
      for (final o in current) o.outputId == outputId ? _withStatus(o, status) : o,
    ]);
  }

  @override
  Future<void> updateChangesSummary(String outputId, String summary) async {
    final current = state.value ?? [];
    state = AsyncData([
      for (final o in current)
        o.outputId == outputId ? _withChangesSummary(o, summary) : o,
    ]);
  }

  /// Records the fields passed to [updateAdviceSummary] so tests can assert on
  /// advice-summary persistence (e.g. the AI-summary lines / Remarks).
  final Map<String, dynamic> recordedAdvice = {};

  @override
  Future<void> updateAdviceSummary(
      String outputId, Map<String, dynamic> fields) async {
    recordedAdvice.addAll(fields);
  }
}
