import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/survey/providers/attendees_provider.dart';

class FakeAttendeesNotifier extends AttendeesNotifier {
  FakeAttendeesNotifier(this._seed);
  final List<AttendeeModel> _seed;
  int _counter = 0;

  @override
  Future<List<AttendeeModel>> build(String caseId) async => _seed;

  @override
  Future<AttendeeModel> addAttendee(AttendeeModel attendee) async {
    final created = AttendeeModel(
      attendeeId: 'fake-attendee-${++_counter}',
      caseId: attendee.caseId,
      fullName: attendee.fullName,
      attendanceId: attendee.attendanceId,
      title: attendee.title,
      rankPosition: attendee.rankPosition,
      company: attendee.company,
      representing: attendee.representing,
      roleType: attendee.roleType,
      dpCertification: attendee.dpCertification,
      certExpiry: attendee.certExpiry,
      contactEmail: attendee.contactEmail,
      contactPhone: attendee.contactPhone,
      sortOrder: (state.value ?? []).length + 1,
    );
    state = AsyncData([...state.value ?? [], created]);
    return created;
  }

  @override
  Future<void> updateAttendee(AttendeeModel attendee) async {
    final current = state.value ?? [];
    state = AsyncData(current
        .map((a) => a.attendeeId == attendee.attendeeId ? attendee : a)
        .toList());
  }

  @override
  Future<void> deleteAttendee(String attendeeId) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((a) => a.attendeeId != attendeeId).toList());
  }

  @override
  Future<void> reorderAttendees(List<String> orderedIds) async {
    // Not exercised by the current widget tests — no-op.
  }

  @override
  Future<void> refresh() async {}
}
