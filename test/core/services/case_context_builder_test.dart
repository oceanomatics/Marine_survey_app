// test/core/services/case_context_builder_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/core/services/case_context_builder.dart';
import 'package:marine_survey_app/features/interviews/models/interview_model.dart';
import 'package:marine_survey_app/features/correspondence/models/correspondence_model.dart';
import 'package:marine_survey_app/features/documents/providers/document_provider.dart';
import 'package:marine_survey_app/features/parties/models/party_model.dart';
import 'package:marine_survey_app/features/photos/models/photo_model.dart';
import 'package:marine_survey_app/features/accounts/models/accounts_models.dart';

void main() {
  group('CaseContextBuilder — interviews', () {
    test('interview with a summary shows the summary, not the transcript', () {
      final result = CaseContextBuilder.build(
        caseData: null,
        vessel: null,
        damage: null,
        notes: null,
        interviews: [
          InterviewModel(
            interviewId: 'iv1',
            caseId: 'c1',
            createdAt: DateTime(2026, 7, 10),
            participants: const [
              InterviewParticipant(contactId: 'p1', fullName: 'John Samuel', roleTitle: 'Superintendent'),
            ],
            transcript: 'raw transcript text that should not appear',
            summary: 'Superintendent confirmed the engine failure occurred mid-passage.',
          ),
        ],
      );

      expect(result, contains('## INTERVIEWS'));
      expect(result, contains('John Samuel · Superintendent'));
      expect(result, contains('Summary: Superintendent confirmed the engine failure occurred mid-passage.'));
      expect(result, isNot(contains('raw transcript text that should not appear')));
    });

    test('interview with no summary falls back to a transcript excerpt', () {
      final result = CaseContextBuilder.build(
        caseData: null,
        vessel: null,
        damage: null,
        notes: null,
        interviews: [
          InterviewModel(
            interviewId: 'iv1',
            caseId: 'c1',
            createdAt: DateTime(2026, 7, 10),
            participants: const [],
            transcript: 'The master stated the vessel was on passage when the alarm sounded.',
          ),
        ],
      );

      expect(result, contains('Transcript excerpt: The master stated the vessel was on passage when the alarm sounded.'));
    });

    test('transcript excerpt is truncated with an ellipsis past 600 chars', () {
      final longTranscript = 'x' * 700;
      final result = CaseContextBuilder.build(
        caseData: null,
        vessel: null,
        damage: null,
        notes: null,
        interviews: [
          InterviewModel(
            interviewId: 'iv1',
            caseId: 'c1',
            createdAt: DateTime(2026, 7, 10),
            participants: const [],
            transcript: longTranscript,
          ),
        ],
      );

      expect(result, contains('${'x' * 600}…'));
      expect(result, isNot(contains('x' * 601)));
    });

    test('no interviews list produces no INTERVIEWS section', () {
      final result = CaseContextBuilder.build(
        caseData: null, vessel: null, damage: null, notes: null,
      );
      expect(result, isNot(contains('## INTERVIEWS')));
    });
  });

  group('CaseContextBuilder — correspondence', () {
    test('renders title, date, sender and summary when present', () {
      final result = CaseContextBuilder.build(
        caseData: null,
        vessel: null,
        damage: null,
        notes: null,
        correspondence: [
          CorrespondenceModel(
            id: 'corr1',
            caseId: 'c1',
            title: 'Re: Survey attendance confirmation',
            sender: 'owner@vessel.com',
            corrDate: DateTime(2026, 6, 1),
            summary: 'Owner confirmed survey attendance for 27 June.',
            createdAt: DateTime(2026, 6, 1),
          ),
        ],
      );

      expect(result, contains('## CORRESPONDENCE'));
      expect(result,
          contains('- Re: Survey attendance confirmation (01/06/2026) from owner@vessel.com — Owner confirmed survey attendance for 27 June.'));
    });

    test('omits date/sender/summary fragments when absent', () {
      final result = CaseContextBuilder.build(
        caseData: null,
        vessel: null,
        damage: null,
        notes: null,
        correspondence: [
          CorrespondenceModel(
            id: 'corr1',
            caseId: 'c1',
            title: 'Untitled email',
            createdAt: DateTime(2026, 6, 1),
          ),
        ],
      );
      expect(result, contains('- Untitled email'));
      expect(result, isNot(contains('from')));
    });
  });

  group('CaseContextBuilder — documents', () {
    test('renders category, date and availability', () {
      final result = CaseContextBuilder.build(
        caseData: null,
        vessel: null,
        damage: null,
        notes: null,
        documents: [
          DocumentModel(
            docId: 'd1',
            caseId: 'c1',
            title: 'Class Survey Report 2025',
            docCategory: DocCategory.classSurveyReport,
            docDate: DateTime(2025, 8, 1),
            availability: DocAvailability.enclosed,
          ),
        ],
      );

      expect(result, contains('## DOCUMENTS'));
      expect(result,
          contains('- [Class Survey Report] Class Survey Report 2025 (01/08/2025) — Enclosed'));
    });
  });

  group('CaseContextBuilder — parties & contacts', () {
    test('renders principal/underwriter/adjuster/assured rep from CasePartiesModel', () {
      final result = CaseContextBuilder.build(
        caseData: null,
        vessel: null,
        damage: null,
        notes: null,
        parties: const CasePartiesModel(
          caseId: 'c1',
          principalName: 'Jane Doe',
          principalCompany: 'Gard',
          underwriterName: 'Gard AS',
          adjusterName: 'Bob Adjuster',
          assuredRepName: 'Cap Owner',
        ),
      );

      expect(result, contains('## PARTIES'));
      expect(result, contains('Instructing principal: Jane Doe (Gard)'));
      expect(result, contains('Underwriter: Gard AS'));
      expect(result, contains('Adjuster: Bob Adjuster'));
      expect(result, contains('Assured/owner\'s representative: Cap Owner'));
    });

    test('renders contacts list with role, company and stakeholder group', () {
      final result = CaseContextBuilder.build(
        caseData: null,
        vessel: null,
        damage: null,
        notes: null,
        contacts: const [
          AssuredContactModel(
            contactId: 'ct1',
            caseId: 'c1',
            fullName: 'Huy Vu',
            roleTitle: 'Class Surveyor',
            company: 'ABS',
            stakeholderGroup: StakeholderGroup.surveyor,
          ),
        ],
      );

      expect(result, contains('Contacts:'));
      expect(result, contains('  - Huy Vu — Class Surveyor (ABS) [Surveyors]'));
    });

    test('no parties and no contacts produces no PARTIES section', () {
      final result = CaseContextBuilder.build(
        caseData: null, vessel: null, damage: null, notes: null,
      );
      expect(result, isNot(contains('## PARTIES')));
    });

    test('empty contacts list (not null) does not trigger the PARTIES section on its own', () {
      final result = CaseContextBuilder.build(
        caseData: null, vessel: null, damage: null, notes: null,
        contacts: const [],
      );
      expect(result, isNot(contains('## PARTIES')));
    });
  });

  group('CaseContextBuilder — photos', () {
    test('renders only captioned/significant photos, skips bare ones', () {
      final result = CaseContextBuilder.build(
        caseData: null,
        vessel: null,
        damage: null,
        notes: null,
        photos: [
          PhotoModel(
            id: 'p1',
            caseId: 'c1',
            takenAt: DateTime(2026, 6, 1),
            caption: 'Ejected connecting rod',
            locationComponent: 'Main Engine',
            significanceToClaim: 'Shows the primary failure point',
          ),
          PhotoModel(
            id: 'p2',
            caseId: 'c1',
            takenAt: DateTime(2026, 6, 1),
            // No caption, no significance — must not appear.
          ),
        ],
      );

      expect(result, contains('## PHOTOS'));
      expect(result,
          contains('- [Main Engine] Ejected connecting rod — Shows the primary failure point'));
      // Only one photo line should be present.
      expect('- ['.allMatches(result).length, 1);
    });

    test('no captioned photos produces no PHOTOS section', () {
      final result = CaseContextBuilder.build(
        caseData: null, vessel: null, damage: null, notes: null,
        photos: [
          PhotoModel(id: 'p1', caseId: 'c1', takenAt: DateTime(2026, 6, 1)),
        ],
      );
      expect(result, isNot(contains('## PHOTOS')));
    });
  });

  group('CaseContextBuilder — cost estimate', () {
    test('renders line items and a computed total', () {
      final result = CaseContextBuilder.build(
        caseData: null,
        vessel: null,
        damage: null,
        notes: null,
        costEstimateItems: [
          const CostEstimateItemModel(
            id: 'ce1',
            caseId: 'c1',
            category: CostEstimateCategory.towing,
            description: 'Tow to drydock',
            amount: 15000,
          ),
          const CostEstimateItemModel(
            id: 'ce2',
            caseId: 'c1',
            category: CostEstimateCategory.surveyFees,
            description: 'Attendance fees',
            amount: 2500.50,
          ),
        ],
      );

      expect(result, contains('## COST ESTIMATE'));
      expect(result, contains('- [Towing] Tow to drydock — 15,000.00'));
      expect(result, contains('- [Survey Fees] Attendance fees — 2,500.50'));
      expect(result, contains('Total estimate: 17,500.50'));
    });

    test('missing description falls back to a placeholder', () {
      final result = CaseContextBuilder.build(
        caseData: null, vessel: null, damage: null, notes: null,
        costEstimateItems: const [
          CostEstimateItemModel(id: 'ce1', caseId: 'c1', amount: 100),
        ],
      );
      expect(result, contains('(no description) — 100.00'));
    });
  });
}
