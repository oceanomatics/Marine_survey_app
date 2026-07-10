import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/reports/utils/section_table_rows.dart';

void main() {
  group('formatSectionDate', () {
    test('formats an ISO date as DD-Mon-YYYY', () {
      expect(formatSectionDate('2026-07-06'), '06-Jul-2026');
    });

    test('empty input returns empty string', () {
      expect(formatSectionDate(''), '');
    });

    test('unparseable input is returned unchanged rather than throwing', () {
      expect(formatSectionDate('not-a-date'), 'not-a-date');
    });
  });

  group('fmtAmount', () {
    test('adds thousands separators and two decimal places', () {
      expect(fmtAmount(1234567.5), '1,234,567.50');
    });

    test('small amounts have no separator', () {
      expect(fmtAmount(42), '42.00');
    });
  });

  group('buildVesselParticularsRows', () {
    test('omits rows with no data', () {
      final rows = buildVesselParticularsRows({'name': 'MV Star'});
      expect(rows, [
        ['Vessel Name', 'MV Star'],
      ]);
    });

    test('uses the custom breadth/draft qualifier as the row label when set', () {
      final rows = buildVesselParticularsRows({
        'name': 'MV Star',
        'breadth': 12.5,
        'breadth_qualifier': 'Beam Moulded',
      });
      expect(rows, contains(equals(['Beam Moulded', '12.5 m'])));
    });

    test('falls back to "Breadth" label when no qualifier is set', () {
      final rows = buildVesselParticularsRows({'name': 'MV Star', 'breadth': 12.5});
      expect(rows, contains(equals(['Breadth', '12.5 m'])));
    });

    test(
        'prefers independent breadth/draft fields over the legacy '
        'qualifier pair when set (TODO.md §2.17)', () {
      final rows = buildVesselParticularsRows({
        'name': 'MV Star',
        'breadth': 20.0,
        'breadth_qualifier': 'Moulded Breadth',
        'breadth_moulded': 18.5,
        'beam_oa': 19.2,
        'max_draft': 8.0,
        'draft_qualifier': 'Load Line Draft',
        'draft_load_line': 7.4,
      });
      expect(rows, contains(equals(['Breadth (Moulded)', '18.5 m'])));
      expect(rows, contains(equals(['Beam (OA)', '19.2 m'])));
      expect(rows, contains(equals(['Draft (Load Line)', '7.4 m'])));
      // The legacy single-value rows must not also appear once the new
      // fields are populated — would double up the same information.
      expect(rows.where((r) => r[0] == 'Moulded Breadth'), isEmpty);
      expect(rows.where((r) => r[0] == 'Breadth'), isEmpty);
      expect(rows.where((r) => r[0] == 'Draft'), isEmpty);
    });

    test('includes registered_owner distinct from owners (TODO.md §2.11)', () {
      final rows = buildVesselParticularsRows({
        'name': 'MV Star',
        'owners': 'Star Shipping Pty Ltd',
        'registered_owner': 'Star Shipping (Registered Owner) Pty Ltd',
      });
      expect(rows, contains(equals(['Owners', 'Star Shipping Pty Ltd'])));
      expect(
          rows,
          contains(equals([
            'Registered Owner',
            'Star Shipping (Registered Owner) Pty Ltd'
          ])));
    });

    test('formats a date field through formatSectionDate', () {
      final rows = buildVesselParticularsRows({
        'name': 'MV Star',
        'last_drydock_date': '2025-01-15',
      });
      expect(rows, contains(equals(['Last Drydock', '15-Jan-2025'])));
    });
  });

  group('buildCertificateRows', () {
    test('empty input returns an empty (no header) table', () {
      expect(buildCertificateRows(const []), isEmpty);
    });

    test('includes a header row plus one row per certificate', () {
      final rows = buildCertificateRows([
        {
          'cert_name': 'Safety Management Certificate',
          'issuing_authority': 'DNV',
          'issue_date': '2024-01-01',
          'expiry_date': '2029-01-01',
        },
      ]);
      expect(rows.first, ['Certificate', 'Issuing Authority', 'Issue Date', 'Expiry']);
      expect(rows[1], ['Safety Management Certificate', 'DNV', '01-Jan-2024', '01-Jan-2029']);
    });

    test('falls back from cert_name to cert_type', () {
      final rows = buildCertificateRows([
        {'cert_type': 'ISM'},
      ]);
      expect(rows[1][0], 'ISM');
    });
  });

  group('buildClassConditionRows', () {
    test('empty input returns empty output', () {
      expect(buildClassConditionRows(const []), isEmpty);
    });

    test('builds header + rows', () {
      final rows = buildClassConditionRows([
        {'reference': 'CC-01', 'description': 'Renew tail shaft', 'expiry_date': '2027-05-01'},
      ]);
      expect(rows.first, ['Reference', 'Description', 'Due Date']);
      expect(rows[1], ['CC-01', 'Renew tail shaft', '01-May-2027']);
    });
  });

  group('buildOccurrenceRows', () {
    test('empty input returns empty output', () {
      expect(buildOccurrenceRows(const []), isEmpty);
    });

    test('uses a placeholder when the occurrence title is missing', () {
      final rows = buildOccurrenceRows([
        {'occurrence_no': 1, 'date_time': '2026-01-01T00:00:00Z', 'title': ''},
      ]);
      expect(rows[1][2], '[occurrence title not yet recorded]');
    });

    test('lists every occurrence, not just the first', () {
      final rows = buildOccurrenceRows([
        {'occurrence_no': 1, 'title': 'Grounding'},
        {'occurrence_no': 2, 'title': 'Collision'},
      ]);
      expect(rows.length, 3); // header + 2
    });
  });

  group('buildChronologyRows', () {
    test('empty input returns empty output', () {
      expect(buildChronologyRows(const []), isEmpty);
    });

    test('falls back from description to title', () {
      final rows = buildChronologyRows([
        {'event_date': '2026-02-01', 'title': 'Attendance commenced'},
      ]);
      expect(rows[1], ['01-Feb-2026', 'Attendance commenced']);
    });
  });

  group('buildMachineryBlocks', () {
    test('label combines type and role when both present', () {
      final blocks = buildMachineryBlocks([
        {'machinery_type': 'Main Engine', 'role': 'Port'},
      ]);
      expect(blocks.first.label, 'Main Engine — Port');
    });

    test('label falls back to "Machinery Item" when type and role are both blank', () {
      final blocks = buildMachineryBlocks([{}]);
      expect(blocks.first.label, 'Machinery Item');
    });

    test('unset fields render as "Not Confirmed"', () {
      final blocks = buildMachineryBlocks([{'machinery_type': 'Generator'}]);
      final rows = Map.fromEntries(blocks.first.rows.map((r) => MapEntry(r[0], r[1])));
      expect(rows['Manufacturer'], 'Not Confirmed');
      expect(rows['Total Running Hours'], 'Not Confirmed');
    });

    test('quantity row only appears when quantity > 1', () {
      final single = buildMachineryBlocks([
        {'machinery_type': 'Generator', 'quantity': 1},
      ]);
      expect(single.first.rows.any((r) => r[0] == 'Quantity'), isFalse);

      final multiple = buildMachineryBlocks([
        {'machinery_type': 'Generator', 'quantity': 3, 'unit_number': 2},
      ]);
      final qtyRow = multiple.first.rows.firstWhere((r) => r[0] == 'Quantity');
      expect(qtyRow[1], '3 (Unit 2)');
    });
  });

  group('buildWncaItems', () {
    test('filters surveyor notes to only case_section == not_average', () {
      final items = buildWncaItems([
        {'case_section': 'not_average', 'content': 'Anodes renewed'},
        {'case_section': 'general', 'content': 'Unrelated note'},
      ]);
      expect(items, ['Anodes renewed']);
    });

    test('drops empty content', () {
      final items = buildWncaItems([
        {'case_section': 'not_average', 'content': ''},
      ]);
      expect(items, isEmpty);
    });
  });

  group('buildAttendanceBlocks', () {
    test('groups attendees under their linked attendance in order', () {
      final blocks = buildAttendanceBlocks(
        [
          {'attendance_id': 'a1', 'attendance_date': '2026-01-01', 'location': 'Singapore'},
          {'attendance_id': 'a2', 'attendance_date': '2026-01-05'},
        ],
        [
          {'attendance_id': 'a1', 'full_name': 'John Smith', 'role_type': 'master'},
          {'attendance_id': 'a2', 'full_name': 'Jane Doe', 'role_type': 'surveyor'},
        ],
      );
      expect(blocks.length, 2);
      expect(blocks[0].label, 'Attendance No. 1');
      // TODO.md §1.8 S2: master/port_captain attendees get a 'Capt.' prefix
      // guess when no explicit title is set.
      expect(blocks[0].rows[1][0], 'Capt. John Smith');
      expect(blocks[1].label, 'Attendance No. 2');
    });

    test('unlinked attendees form the sole, unlabelled block when there are no other blocks', () {
      final blocks = buildAttendanceBlocks(
        const [],
        [
          {'full_name': 'John Smith', 'role_type': 'master'},
        ],
      );
      expect(blocks, hasLength(1));
      expect(blocks.first.label, '');
    });

    test('unlinked attendees form a trailing "Other Attendees" block when linked blocks exist', () {
      final blocks = buildAttendanceBlocks(
        [
          {'attendance_id': 'a1', 'attendance_date': '2026-01-01'},
        ],
        [
          {'attendance_id': 'a1', 'full_name': 'John Smith', 'role_type': 'master'},
          {'full_name': 'Jane Doe', 'role_type': 'broker'},
        ],
      );
      expect(blocks.last.label, 'Other Attendees');
    });

    test('an attendance record with no matching attendees produces no block', () {
      final blocks = buildAttendanceBlocks(
        [
          {'attendance_id': 'a1'},
        ],
        const [],
      );
      expect(blocks, isEmpty);
    });
  });
}
