// §3.14 (13 July 2026): thread-level trail grouping — the deterministic
// half of the "AI-generated thread-level trail summary" feature (only the
// narrative synthesis on top of this is an LLM call).
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/correspondence/models/correspondence_model.dart';
import 'package:marine_survey_app/features/correspondence/utils/correspondence_threads.dart';

CorrespondenceModel _msg({
  required String id,
  required String title,
  DateTime? corrDate,
  DateTime? createdAt,
}) =>
    CorrespondenceModel(
      id: id,
      caseId: 'case-1',
      title: title,
      corrDate: corrDate,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
    );

void main() {
  group('normalizeSubjectForThreading', () {
    test('strips a single Re: prefix, case-insensitively', () {
      expect(normalizeSubjectForThreading('Re: Engine damage'), 'engine damage');
      expect(normalizeSubjectForThreading('RE: Engine damage'), 'engine damage');
    });

    test('strips repeated Re:/Fwd: prefixes in any combination', () {
      expect(normalizeSubjectForThreading('Re: Fwd: Re: Engine damage'),
          'engine damage');
    });

    test('a bare subject with no prefix is unchanged (just lower-cased)', () {
      expect(normalizeSubjectForThreading('Engine damage'), 'engine damage');
    });
  });

  group('groupCorrespondenceThreads', () {
    test('messages with the same normalized subject group into one thread',
        () {
      final items = [
        _msg(id: '1', title: 'Engine damage', corrDate: DateTime(2026, 1, 1)),
        _msg(id: '2', title: 'Re: Engine damage', corrDate: DateTime(2026, 1, 2)),
        _msg(id: '3', title: 'RE: Engine damage', corrDate: DateTime(2026, 1, 3)),
      ];
      final threads = groupCorrespondenceThreads(items);
      expect(threads, hasLength(1));
      expect(threads.first.messages, hasLength(3));
      expect(threads.first.isMultiMessage, isTrue);
    });

    test('messages within a thread are ordered oldest-first, regardless of '
        'input order', () {
      final items = [
        _msg(id: '2', title: 'Re: Engine damage', corrDate: DateTime(2026, 1, 2)),
        _msg(id: '1', title: 'Engine damage', corrDate: DateTime(2026, 1, 1)),
      ];
      final threads = groupCorrespondenceThreads(items);
      expect(threads.first.messages.map((m) => m.id), ['1', '2']);
    });

    test('the thread subject is the earliest message\'s own title, not a '
        'normalized/reply-prefixed one', () {
      final items = [
        _msg(id: '2', title: 'Re: Engine damage', corrDate: DateTime(2026, 1, 2)),
        _msg(id: '1', title: 'Engine damage', corrDate: DateTime(2026, 1, 1)),
      ];
      final threads = groupCorrespondenceThreads(items);
      expect(threads.first.subject, 'Engine damage');
    });

    test('unrelated subjects produce separate single-message threads', () {
      final items = [
        _msg(id: '1', title: 'Engine damage', corrDate: DateTime(2026, 1, 1)),
        _msg(id: '2', title: 'Invoice query', corrDate: DateTime(2026, 1, 2)),
      ];
      final threads = groupCorrespondenceThreads(items);
      expect(threads, hasLength(2));
      expect(threads.every((t) => !t.isMultiMessage), isTrue);
    });

    test('threads sort newest-first by their latest message', () {
      final items = [
        _msg(id: '1', title: 'Old topic', corrDate: DateTime(2026, 1, 1)),
        _msg(id: '2', title: 'New topic', corrDate: DateTime(2026, 6, 1)),
      ];
      final threads = groupCorrespondenceThreads(items);
      expect(threads.map((t) => t.subject), ['New topic', 'Old topic']);
    });

    test('blank-title messages never collide into one thread', () {
      final items = [
        _msg(id: '1', title: '', corrDate: DateTime(2026, 1, 1)),
        _msg(id: '2', title: '', corrDate: DateTime(2026, 1, 2)),
      ];
      final threads = groupCorrespondenceThreads(items);
      expect(threads, hasLength(2));
    });

    test('falls back to createdAt when corrDate is null', () {
      final items = [
        _msg(id: '1', title: 'Topic', createdAt: DateTime(2026, 1, 5)),
        _msg(id: '2', title: 'Re: Topic', createdAt: DateTime(2026, 1, 1)),
      ];
      final threads = groupCorrespondenceThreads(items);
      expect(threads.first.messages.map((m) => m.id), ['2', '1']);
    });
  });
}
