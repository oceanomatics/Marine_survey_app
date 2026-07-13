// §4.7 (13 July 2026): case-level action items.
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/action_items/providers/action_items_provider.dart';

Map<String, dynamic> _baseJson({Map<String, dynamic>? overrides}) => {
      'id': 'item-1',
      'case_id': 'case-1',
      'text': 'Book flights for next attendance',
      ...?overrides,
    };

void main() {
  group('ActionItemStatus.fromValue', () {
    test('defaults to open for null/unknown values', () {
      expect(ActionItemStatus.fromValue(null), ActionItemStatus.open);
      expect(ActionItemStatus.fromValue('bogus'), ActionItemStatus.open);
    });

    test('parses done and dismissed', () {
      expect(ActionItemStatus.fromValue('done'), ActionItemStatus.done);
      expect(
          ActionItemStatus.fromValue('dismissed'), ActionItemStatus.dismissed);
    });
  });

  group('ActionItemModel.fromJson', () {
    test('a manual item has no source and is never pendingReview', () {
      final item = ActionItemModel.fromJson(_baseJson(overrides: {
        'source_type': 'manual',
      }));
      expect(item.sourceType, 'manual');
      expect(item.sourceId, isNull);
      expect(item.pendingReview, isFalse);
    });

    test('a correspondence-sourced candidate defaults pendingReview from '
        'the column, not an assumption', () {
      final item = ActionItemModel.fromJson(_baseJson(overrides: {
        'source_type': 'correspondence',
        'source_id': 'corr-1',
        'pending_review': true,
      }));
      expect(item.sourceType, 'correspondence');
      expect(item.sourceId, 'corr-1');
      expect(item.pendingReview, isTrue);
    });

    test('due_date and completed_at parse when present', () {
      final item = ActionItemModel.fromJson(_baseJson(overrides: {
        'due_date': '2026-08-01',
        'completed_at': '2026-07-20T10:00:00.000Z',
      }));
      expect(item.dueDate, DateTime.parse('2026-08-01'));
      expect(item.completedAt, isNotNull);
    });
  });

  group('ActionItemModel.copyWith', () {
    test('confirming clears pendingReview without touching status', () {
      final item = ActionItemModel.fromJson(_baseJson(overrides: {
        'source_type': 'correspondence',
        'pending_review': true,
      }));
      final confirmed = item.copyWith(pendingReview: false);
      expect(confirmed.pendingReview, isFalse);
      expect(confirmed.status, ActionItemStatus.open);
    });

    test('marking done sets status and completedAt independently', () {
      final item = ActionItemModel.fromJson(_baseJson());
      final now = DateTime(2026, 7, 13);
      final done = item.copyWith(
          status: ActionItemStatus.done, completedAt: now);
      expect(done.status, ActionItemStatus.done);
      expect(done.completedAt, now);
      expect(done.text, item.text); // unrelated fields untouched
    });
  });
}
