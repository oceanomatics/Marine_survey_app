import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';

CaseModel fixtureCase({
  String caseId = 'case-1',
  String technicalFileNo = 'AU-M53-056789',
  bool signedOffAttending = false,
  bool signedOffReviewing = false,
}) =>
    CaseModel(
      caseId: caseId,
      technicalFileNo: technicalFileNo,
      caseType: CaseType.hm,
      status: CaseStatus.open,
      signedOffAttending: signedOffAttending,
      signedOffReviewing: signedOffReviewing,
    );

AssembledReportData fixtureAssembledData({
  Map<String, dynamic> caseData = const {},
}) =>
    AssembledReportData(
      caseData: caseData,
      vessel: null,
      occurrences: const [],
      damageItems: const [],
      attendees: const [],
      attendances: const [],
      certificates: const [],
      repairPeriods: const [],
      clauses: const [],
      outputFormat: 'oceano_services',
      repairDocuments: const [],
      timelineEvents: const [],
      surveyorNotes: const [],
      machinery: const [],
      classConditions: const [],
      detentions: const [],
      caseDocuments: const [],
      requestedDocuments: const [],
      photos: const [],
      aiGenerationLog: const [],
      allReportOutputs: const [],
    );

ReportOutput fixtureOutput({
  String outputId = 'output-1',
  String caseId = 'case-1',
  OutputType outputType = OutputType.preliminary,
  ReportStatus status = ReportStatus.draft,
  int sequenceNo = 1,
  String? supersedesVersion,
  String? changesSummary,
}) =>
    ReportOutput(
      outputId: outputId,
      caseId: caseId,
      outputType: outputType,
      status: status,
      sections: const [],
      sequenceNo: sequenceNo,
      supersedesVersion: supersedesVersion,
      changesSummary: changesSummary,
    );

ReportSection fixtureSection(
  SectionType type, {
  String content = 'Some content.',
  bool approved = true,
  bool isLocked = false,
}) =>
    ReportSection(
      type: type,
      title: type.name,
      content: content,
      isLocked: isLocked,
      surveyorReview: approved ? SurveyorReview.reviewedAccepted : null,
    );

/// One ReportSection per non-executiveSummary type in [oceanoSectionOrder]
/// (the Editor tab's own filter — see report_builder_screen.dart _EditorTab),
/// all pre-approved with placeholder content so the Editor/Preview/
/// Postprocessing tabs render without triggering "Draft with AI".
Map<SectionType, ReportSection> fixtureAllSections() => {
      for (final type in oceanoSectionOrder)
        if (type != SectionType.executiveSummary) type: fixtureSection(type),
    };
