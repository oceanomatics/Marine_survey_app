import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/core/services/gmail_service.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/correspondence/utils/case_inbox_filter.dart';

GmailMessageSummary _msg({
  String id = 'm',
  String subject = '',
  String snippet = '',
}) =>
    GmailMessageSummary(
      id: id,
      subject: subject,
      from: 'someone@ship.com',
      date: null,
      snippet: snippet,
    );

CaseModel _case({
  String fileNo = 'ABL-2026-001',
  String? vessel = 'MV Surveyor',
  String? claim,
}) =>
    CaseModel(
      caseId: 'c1',
      technicalFileNo: fileNo,
      caseType: CaseType.hm,
      status: CaseStatus.open,
      vesselName: vessel,
      claimReference: claim,
    );

void main() {
  group('caseSearchTerms', () {
    test('collects vessel, file no and claim ref', () {
      final t = caseSearchTerms(
          _case(vessel: 'MV Surveyor', fileNo: 'ABL-1', claim: 'CLM-9'));
      expect(t, ['MV Surveyor', 'ABL-1', 'CLM-9']);
    });

    test('skips placeholder file numbers and blanks', () {
      expect(caseSearchTerms(_case(vessel: null, fileNo: 'TMP-abc')), isEmpty);
      expect(caseSearchTerms(_case(vessel: '  ', fileNo: 'TBC')), isEmpty);
    });

    test('null case yields no terms', () {
      expect(caseSearchTerms(null), isEmpty);
    });
  });

  group('caseGmailQuery', () {
    test('quotes and ORs the terms', () {
      expect(caseGmailQuery(['MV Foo', 'ABL-1']), '"MV Foo" OR "ABL-1"');
    });
    test('null when no terms', () {
      expect(caseGmailQuery(const []), isNull);
    });
  });

  group('normaliseSubject', () {
    test('strips re/fw/fwd prefixes, lowercases, collapses whitespace', () {
      expect(normaliseSubject('RE:  Survey  Attendance'),
          'survey attendance');
      expect(normaliseSubject('Fwd: Re: Foo'), 'foo');
      expect(normaliseSubject('FW: Bar'), 'bar');
    });
  });

  group('filterCaseInbox', () {
    final terms = caseSearchTerms(_case()); // MV Surveyor, ABL-2026-001

    test('keeps messages matching a term in subject', () {
      final out = filterCaseInbox(
        messages: [_msg(id: 'a', subject: 'MV Surveyor damage')],
        caseTerms: terms,
        importedTitles: const [],
      );
      expect(out.map((m) => m.id), ['a']);
    });

    test('keeps messages matching a term only in the snippet (body)', () {
      final out = filterCaseInbox(
        messages: [
          _msg(id: 'a', subject: 'Quote', snippet: 'ref ABL-2026-001 attached')
        ],
        caseTerms: terms,
        importedTitles: const [],
      );
      expect(out.map((m) => m.id), ['a']);
    });

    test('drops messages matching no term', () {
      final out = filterCaseInbox(
        messages: [_msg(id: 'a', subject: 'Unrelated newsletter')],
        caseTerms: terms,
        importedTitles: const [],
      );
      expect(out, isEmpty);
    });

    test('excludes already-imported by normalised subject (Re/case-insensitive)',
        () {
      final out = filterCaseInbox(
        messages: [
          _msg(id: 'a', subject: 'Re: MV Surveyor attendance'),
          _msg(id: 'b', subject: 'MV Surveyor new damage report'),
        ],
        caseTerms: terms,
        importedTitles: const ['MV SURVEYOR ATTENDANCE'],
      );
      expect(out.map((m) => m.id), ['b']);
    });

    test('empty terms treats everything as relevant', () {
      final out = filterCaseInbox(
        messages: [_msg(id: 'a', subject: 'anything')],
        caseTerms: const [],
        importedTitles: const [],
      );
      expect(out.map((m) => m.id), ['a']);
    });
  });
}
