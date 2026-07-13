// §3.11 (13 July 2026): reorderedList() backs
// NatureOfRepairsNotifier.reorderSequenceItems() — pinned here since the
// provider itself hits Supabase and isn't unit-testable in isolation.
// Semantics match ReorderableListView's onReorderItem contract (newIndex
// already adjusted for the removed item), NOT the deprecated onReorder.
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/survey/providers/nature_of_repairs_provider.dart';

void main() {
  group('reorderedList', () {
    test('moving the first item down to the end', () {
      expect(reorderedList(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
    });

    test('moving the last item up to the front', () {
      expect(reorderedList(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    });

    test('moving an item one position down', () {
      expect(reorderedList(['a', 'b', 'c'], 0, 1), ['b', 'a', 'c']);
    });

    test('moving an item to its own position is a no-op', () {
      expect(reorderedList(['a', 'b', 'c'], 1, 1), ['a', 'b', 'c']);
    });

    test('single-item list is unaffected', () {
      expect(reorderedList(['a'], 0, 0), ['a']);
    });
  });
}
